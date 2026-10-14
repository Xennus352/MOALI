"use client"

/**
 * Header notification bell.
 *
 * Reads the durable `/notifications` feed (the same rows the Messages page
 * shows) so it survives reloads, and the realtime WebSocket invalidates the
 * `notifications` query whenever a submission or review happens — the badge and
 * list therefore update live without a manual refresh.
 */
import { useQuery, useQueryClient } from "@tanstack/react-query"
import { Bell } from "lucide-react"
import { useNavigate } from "react-router-dom"
import { Button } from "@/components/ui/button"
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu"
import { api, timeAgo } from "@/lib/api"
import { pickLocalized, useI18n } from "@/lib/i18n"
import { cn } from "@/lib/utils"

interface NotificationItem {
  id: number
  title_burmese: string | null
  title_english: string | null
  message_burmese: string | null
  message_english: string | null
  type: string
  is_read: boolean
  created_at: string | null
}

interface NotificationsResponse {
  unread: number
  items: NotificationItem[]
}

export function NotificationsBell() {
  const { t, lang } = useI18n()
  const navigate = useNavigate()
  const qc = useQueryClient()

  const { data } = useQuery<NotificationsResponse>({
    queryKey: ["notifications"],
    queryFn: () => api.get<NotificationsResponse>("/api/v1/notifications?limit=8"),
    retry: 1,
    // A slow safety net; realtime provides the instant update.
    refetchInterval: 45_000,
  })

  const unread = data?.unread ?? 0
  const items = data?.items ?? []

  const markAllRead = async () => {
    await api.post("/api/v1/notifications/read-all")
    qc.invalidateQueries({ queryKey: ["notifications"] })
  }

  return (
    <DropdownMenu>
      <DropdownMenuTrigger asChild>
        <Button
          variant="ghost"
          size="icon"
          className="relative text-muted-foreground hover:text-foreground"
          aria-label={t("bell.title")}
        >
          <Bell className="h-5 w-5" />
          {unread > 0 && (
            <span className="absolute -right-0.5 -top-0.5 grid h-4 min-w-4 place-items-center rounded-full bg-[#e67e22] px-1 text-[0.58rem] font-bold leading-none text-white ring-2 ring-background">
              {unread > 9 ? "9+" : unread}
            </span>
          )}
        </Button>
      </DropdownMenuTrigger>
      <DropdownMenuContent align="end" className="w-80 p-0">
        <div className="flex items-center justify-between border-b border-border px-3 py-2.5">
          <span className="text-[0.85rem] font-bold text-foreground">{t("bell.title")}</span>
          {unread > 0 && (
            <button
              onClick={markAllRead}
              className="text-[0.72rem] font-semibold text-primary hover:underline"
            >
              {t("bell.markAllRead")}
            </button>
          )}
        </div>

        <div className="max-h-[330px] overflow-y-auto">
          {items.length === 0 ? (
            <p className="px-4 py-8 text-center text-[0.8rem] text-muted-foreground">
              {t("bell.empty")}
            </p>
          ) : (
            items.map((n) => (
              <div
                key={n.id}
                className={cn(
                  "border-b border-border/60 px-3 py-2.5 last:border-0",
                  !n.is_read && "bg-primary/5",
                )}
              >
                <p className="text-[0.8rem] font-semibold text-foreground">
                  {pickLocalized(lang, n.title_burmese, n.title_english)}
                </p>
                <p className="mt-0.5 line-clamp-2 text-[0.72rem] text-muted-foreground">
                  {pickLocalized(lang, n.message_burmese, n.message_english)}
                </p>
                <p className="mt-0.5 text-[0.66rem] text-muted-foreground/70">
                  {timeAgo(n.created_at, lang)}
                </p>
              </div>
            ))
          )}
        </div>

        <button
          onClick={() => navigate("/messages")}
          className="w-full border-t border-border px-3 py-2.5 text-center text-[0.78rem] font-semibold text-primary transition-colors hover:bg-muted/50"
        >
          {t("bell.viewAll")}
        </button>
      </DropdownMenuContent>
    </DropdownMenu>
  )
}
