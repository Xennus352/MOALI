"use client"
/* eslint-disable react-refresh/only-export-components -- shadcn-style file that intentionally exports the useToast hook and the global <Toaster /> together. */

import { useSyncExternalStore } from "react"
import { CheckCircle2, AlertTriangle, Info, X } from "lucide-react"
import { cn } from "@/lib/utils"

type ToastVariant = "default" | "destructive" | "success"

export interface ToastItem {
  id: string
  title: string
  description: string
  variant: ToastVariant
}

interface ToastOptions {
  title: string
  description: string
  variant?: ToastVariant
  duration?: number
}

let items: ToastItem[] = []
const listeners = new Set<() => void>()

function subscribe(listener: () => void): () => void {
  listeners.add(listener)
  return () => listeners.delete(listener)
}

function getSnapshot(): ToastItem[] {
  return items
}

function commit(next: ToastItem[]) {
  items = next
  listeners.forEach((l) => l())
}

function addToast(opts: ToastOptions) {
  const id = Math.random().toString(36).slice(2, 11)
  const duration = opts.duration ?? 5000
  commit([
    ...items,
    { id, title: opts.title, description: opts.description, variant: opts.variant ?? "default" },
  ])
  if (duration > 0) {
    window.setTimeout(() => removeToast(id), duration)
  }
}

function removeToast(id?: string) {
  commit(id ? items.filter((t) => t.id !== id) : [])
}

export function useToast() {
  const toasts = useSyncExternalStore(subscribe, getSnapshot)
  return { toast: addToast, dismiss: removeToast, toasts }
}

const VARIANT_STYLES: Record<ToastVariant, { icon: React.ReactNode; ring: string }> = {
  success: {
    icon: <CheckCircle2 className="h-5 w-5 text-[#2e8b57]" />,
    ring: "border-l-[#2e8b57]",
  },
  destructive: {
    icon: <AlertTriangle className="h-5 w-5 text-[#dc2626]" />,
    ring: "border-l-[#dc2626]",
  },
  default: {
    icon: <Info className="h-5 w-5 text-primary" />,
    ring: "border-l-primary",
  },
}

/** Global toast stack — mount once at the app root. */
export function Toaster() {
  const toasts = useSyncExternalStore(subscribe, getSnapshot)
  return (
    <div
      className="pointer-events-none fixed inset-x-4 top-4 z-[100] flex flex-col items-end gap-2 sm:inset-x-auto sm:right-6"
      aria-live="polite"
    >
      {toasts.map((t) => {
        const style = VARIANT_STYLES[t.variant]
        return (
          <div
            key={t.id}
            className={cn(
              "pointer-events-auto flex w-full max-w-sm items-start gap-3 rounded-xl border border-l-4 border-border bg-card p-4 shadow-[0_16px_40px_-16px_rgb(17_34_15/0.35)]",
              style.ring
            )}
          >
            <span className="mt-0.5 shrink-0">{style.icon}</span>
            <div className="min-w-0 flex-1">
              <p className="text-[0.9rem] font-semibold text-foreground">{t.title}</p>
              <p className="mt-0.5 text-[0.8rem] leading-relaxed text-muted-foreground">{t.description}</p>
            </div>
            <button
              onClick={() => removeToast(t.id)}
              className="shrink-0 rounded-md p-1 text-muted-foreground transition-colors hover:bg-muted hover:text-foreground"
              aria-label="Dismiss notification"
            >
              <X className="h-4 w-4" />
            </button>
          </div>
        )
      })}
    </div>
  )
}