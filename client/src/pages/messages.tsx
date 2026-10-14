"use client"

import { useQuery, useQueryClient } from "@tanstack/react-query"
import { useState } from "react"
import { api, timeAgo } from "@/lib/api"
import { PageHeader } from "@/components/layout/page-header"
import { Card } from "@/components/ui/card"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { LoadingBlock } from "@/components/layout/loading-block"
import { useI18n } from "@/lib/i18n"
import { Bell, BellOff, CheckCheck, Inbox } from "lucide-react"

interface Notification {
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
  items: Notification[]
  total: number
}

export function MessagesPage() {
  const { t, lang } = useI18n()
  const qc = useQueryClient()
  const [page, setPage] = useState<number>(1)

  const {
    data,
    isLoading,
  } = useQuery<NotificationsResponse>({
    queryKey: ["notifications", page],
    queryFn: () => api.get<NotificationsResponse>(`/api/v1/notifications?limit=25&page=${page}`),
    staleTime: 30_000,
    retry: 1,
  })

  const markRead = async (id: number) => {
    await api.post(`/api/v1/notifications/${id}/read`)
    qc.invalidateQueries({ queryKey: ["notifications", page] })
  }

  const markAll = async () => {
    for (const n of data?.items ?? []) {
      if (!n.is_read) await api.post(`/api/v1/notifications/${n.id}/read`)
    }
    qc.invalidateQueries({ queryKey: ["notifications", page] })
  }

  return (
    <main className="w-full">
      <PageHeader
        title={t("messages.title")}
        description={t("messages.description")}
        actions={
          data && data.unread > 0 ? (
            <Button variant="outline" className="rounded-xl border-border bg-card" onClick={markAll}>
              <CheckCheck className="h-4 w-4" /> {t("actions.markAllRead")}
            </Button>
          ) : undefined}
      />

      {isLoading && <LoadingBlock />}

      <div className="mb-4 flex items-center gap-2 text-[0.82rem] text-muted-foreground" data-reveal>
        <Bell className="h-4 w-4" />
        <span>
          {data && data.unread > 0 ? data.unread : 0} {t("notifications.unread")} of{" "}
          {data?.total ?? 0} {t("notifications.total")}
        </span>
      </div>

      <div className="space-y-3">
        {(data?.items ?? []).length === 0 && !isLoading && (
          <Card className="border-border/80 bg-card p-12 text-center">
            <Inbox className="mx-auto mb-3 h-8 w-8 text-muted-foreground/50" />
            <p className="text-[0.9rem] text-muted-foreground">{t("notifications.empty")}</p>
          </Card>
        )}

        {(data?.items ?? []).map((n) => (
          <Card
            key={n.id}
            data-reveal
            className={`flex items-start gap-4 border-border/80 bg-card p-5 ${!n.is_read ? "border-l-4 !border-l-[#e67e22]" : ""}`}
          >
            <span
              className={`mt-1 grid h-10 w-10 shrink-0 place-items-center rounded-xl ${!n.is_read ? "bg-primary/10 text-primary" : "bg-muted text-muted-foreground"}`}
            >
              {n.is_read ? <BellOff className="h-5 w-5" /> : <Bell className="h-5 w-5" />}
            </span>
            <div className="min-w-0 flex-1">
              <div className="flex flex-wrap items-center gap-2">
                <h3 className="font-display text-[0.98rem] font-bold text-foreground">
                  {n.title_english || n.title_burmese || t("notifications.notification")}
                </h3>
                <Badge variant="outline" className="border-transparent bg-muted text-muted-foreground">
                  {n.type}
                </Badge>
                {!n.is_read && (
                  <Badge variant="outline" className="border-transparent bg-[#e67e22]/15 font-semibold text-[#e67e22]">
                    {t("notifications.new")}
                  </Badge>
                )}
              </div>
              <p className="mt-1.5 text-[0.85rem] leading-relaxed text-muted-foreground">
                {n.message_english || n.message_burmese}
              </p>
              <div className="mt-3 flex items-center justify-between">
                <span className="text-[0.72rem] text-muted-foreground">
                  {timeAgo(n.created_at, lang)}
                </span>
                {!n.is_read && (
                  <Button variant="ghost" size="sm" className="h-7 rounded-lg text-primary" onClick={() => markRead(n.id)}>
                    {t("actions.markAsRead")}
                  </Button>
                )}
              </div>
            </div>
          </Card>
        ))}

        {data && !isLoading && (
          <div className="mt-8 border-t border-border/60 pt-6 text-center">
            <Button
              variant="outline"
              onClick={() => setPage((prev) => prev + 1)}
              className="w-full py-3 rounded-xl text-[0.9rem] font-medium text-primary hover:bg-muted"
            >
              {t("common.loadMore")}
            </Button>
            {data.items.length < (data.total ?? data.items.length) && (
              <span className="mt-2 text-[0.78rem] text-muted-foreground">
                {t("common.endOfResults")} · {data.items.length} / {data.total ?? data.items.length} {t("notifications.notifications")}
              </span>
            )}
          </div>
        )}
      </div>
    </main>
  )
}