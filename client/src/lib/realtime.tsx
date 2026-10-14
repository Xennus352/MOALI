"use client"
/* eslint-disable react-refresh/only-export-components -- cohesive realtime module: provider, status hook and badge are intentionally co-located. */

/**
 * Real-time bridge over the authenticated backend WebSocket (`/api/v1/ws`).
 *
 * The server publishes events only after the originating transaction commits
 * (submission created / reviewed, user changed). On every event we refresh the
 * affected react-query caches so the dashboard, submission list and trend
 * panels update live — no manual reload — and surface a short toast.
 *
 * The connection only opens once a user is authenticated; the signed session
 * cookie is attached to the WebSocket handshake automatically. If the socket
 * drops, we reconnect with exponential backoff.
 */
import { createContext, useContext, useEffect, useRef, useState } from "react"
import { useQueryClient } from "@tanstack/react-query"
import { useToast } from "@/components/ui/use-toast"
import { useAuth } from "@/context/auth-context"
import { useI18n } from "@/lib/i18n"
import { cn } from "@/lib/utils"

export type RealtimeStatus = "connecting" | "connected" | "offline"

const RealtimeStatusContext = createContext<RealtimeStatus>("connecting")

export function useRealtimeStatus(): RealtimeStatus {
  return useContext(RealtimeStatusContext)
}

const API_WS_PATH = "/api/v1/ws"

// Default to a same-origin socket (works through the Vite dev proxy and in a
// production reverse-proxy/backend-served setup). Set VITE_WS_URL only when the
// realtime API lives on a different origin than the app.
const WS_URL =
  (import.meta.env.VITE_WS_URL as string | undefined) ??
  `${window.location.protocol === "https:" ? "wss" : "ws"}://${window.location.host}${API_WS_PATH}`

const EVENT_LABEL_KEYS: Record<string, string> = {
  "submission.created": "rt.submission.created",
  "submission.status_changed": "rt.submission.status_changed",
  "user.changed": "rt.user.changed",
}

export function RealtimeProvider({ children }: { children: React.ReactNode }) {
  const qc = useQueryClient()
  const { toast } = useToast()
  const { user } = useAuth()
  const { t } = useI18n()
  const [status, setStatus] = useState<RealtimeStatus>("connecting")
  const attemptRef = useRef(0)
  const userId = user?.id

  useEffect(() => {
    if (!userId) return

    let socket: WebSocket | null = null
    let ping: number | undefined
    let reconnect: number | undefined
    let closed = false

    const connect = () => {
      socket = new WebSocket(WS_URL)

      socket.onopen = () => {
        attemptRef.current = 0
        setStatus("connected")
        ping = window.setInterval(() => {
          if (socket?.readyState === WebSocket.OPEN) {
            socket.send(JSON.stringify({ type: "ping" }))
          }
        }, 25000)
      }

      socket.onmessage = (event) => {
        let message: { type?: string }
        try {
          message = JSON.parse(event.data)
        } catch {
          return
        }
        const type = message.type
        if (!type || type === "connected" || type === "pong") return

        qc.invalidateQueries({ queryKey: ["dashboard-kpi"] })
        qc.invalidateQueries({ queryKey: ["dashboard-trends"] })
        qc.invalidateQueries({ queryKey: ["dashboard-recent"] })
        qc.invalidateQueries({ queryKey: ["submissions"] })
        qc.invalidateQueries({ queryKey: ["users"] })
        qc.invalidateQueries({ queryKey: ["notifications"] })

        toast({
          title: t(EVENT_LABEL_KEYS[type] ?? "rt.liveUpdate"),
          description: t("rt.refreshed"),
        })
      }

      socket.onerror = () => socket?.close()

      socket.onclose = () => {
        if (ping) window.clearInterval(ping)
        if (closed) return
        setStatus("offline")
        attemptRef.current += 1
        const delay = Math.min(1000 * 2 ** attemptRef.current, 15000)
        reconnect = window.setTimeout(() => {
          setStatus("connecting")
          connect()
        }, delay)
      }
    }

    connect()
    return () => {
      closed = true
      if (ping) window.clearInterval(ping)
      if (reconnect) window.clearTimeout(reconnect)
      socket?.close()
    }
  }, [qc, toast, userId, t])

  // Unauthenticated visitors have no realtime session to speak of.
  const effectiveStatus: RealtimeStatus = userId ? status : "offline"

  return <RealtimeStatusContext.Provider value={effectiveStatus}>{children}</RealtimeStatusContext.Provider>
}

/** Small live-connection pill for the header. */
export function RealtimeBadge() {
  const { t } = useI18n()
  const status = useRealtimeStatus()
  const label =
    status === "connected"
      ? t("header.live")
      : status === "connecting"
        ? t("header.reconnecting")
        : t("header.offline")
  return (
    <span
      className="hidden items-center gap-1.5 rounded-full border border-border px-2.5 py-1 text-[0.68rem] font-semibold text-muted-foreground md:flex"
      title={`${t("bell.title")}: ${label}`}
    >
      <span
        className={cn(
          "h-1.5 w-1.5 rounded-full",
          status === "connected"
            ? "bg-[var(--success)]"
            : status === "connecting"
              ? "animate-pulse bg-[var(--warning)]"
              : "bg-[var(--destructive)]"
        )}
      />
      {label}
    </span>
  )
}