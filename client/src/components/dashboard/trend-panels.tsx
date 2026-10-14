"use client"

import { Card, CardHeader, CardTitle, CardDescription, CardContent } from "@/components/ui/card"
import { AreaChart, BarChart, HBarChart, DonutChart } from "@/components/charts"
import { useI18n } from "@/lib/i18n"
import { useTrends } from "./use-trends"

function Panel({
  title,
  description,
  className = "",
  children,
}: {
  title: string
  description: string
  className?: string
  children: React.ReactNode
}) {
  return (
    <Card
      data-reveal
      className={`border-border/80 bg-card shadow-[0_1px_2px_rgb(17_34_15/0.04),0_8px_24px_-8px_rgb(17_34_15/0.06)] ${className}`}
    >
      <CardHeader className="pb-2 pt-5">
        <CardTitle className="text-[0.95rem] font-bold tracking-tight">{title}</CardTitle>
        <CardDescription className="text-[0.72rem]">{description}</CardDescription>
      </CardHeader>
      <CardContent className="pb-5">{children}</CardContent>
    </Card>
  )
}

function NoData({ label }: { label: string }) {
  const { t } = useI18n()
  return (
    <div className="py-8 text-center text-[0.8rem] text-muted-foreground">
      {t("trend.none", { label })}
    </div>
  )
}

/** The dashboard's 6-cell real analytics bento, fed by /dashboard/trends. */
export function TrendPanels({ days = 30 }: { days?: number }) {
  const { t } = useI18n()
  const { data, isLoading } = useTrends(days)
  const s = data?.submissionsOverTime ?? []
  const byRegion = data?.submissionsByRegion ?? []
  const byTownship = data?.submissionsByTownship ?? []
  const byStatus = (data?.submissionsByStatus ?? [])
    .filter((x) => x.status)
    .map((d) => {
      const key = `sstatus.${d.status}`
      const label = t(key)
      return { label: label === key ? d.status : label, value: d.count }
    })
  const byType = (data?.animalsByType ?? []).map((d) => ({
    label: d.animalType,
    value: d.count,
  }))
  const breeding = (data?.breedingByCategory ?? []).map((d) => ({
    label: d.category,
    value: d.count,
  }))

  if (isLoading) {
    return (
      <div className="grid grid-flow-dense grid-cols-1 gap-4 md:grid-cols-2 xl:grid-cols-3">
        {Array.from({ length: 6 }).map((_, i) => (
          <div
            key={i}
            className={`h-[230px] animate-pulse rounded-2xl border border-border/70 bg-muted/40 ${
              i === 0 || i === 5 ? "md:col-span-2" : ""
            }`}
          />
        ))}
      </div>
    )
  }

  const hasOverTime = s.length > 0
  const hasRegion = byRegion.some((r) => r.region && r.count)
  const hasTownship = byTownship.some((t2) => t2.township && t2.count)
  const hasType = byType.some((t2) => t2.value > 0)
  const hasBreeding = breeding.some((b) => b.value > 0)

  return (
    <div className="grid grid-flow-dense grid-cols-1 gap-4 md:grid-cols-2 xl:grid-cols-3">
      <Panel
        title={t("trend.overTimeTitle")}
        description={t("trend.overTimeDesc")}
        className="md:col-span-2"
      >
        {hasOverTime ? (
          <AreaChart data={s.map((d) => ({ label: d.date, value: d.count }))} />
        ) : (
          <NoData label={t("trend.lblActivity")} />
        )}
      </Panel>

      <Panel title={t("trend.reviewTitle")} description={t("trend.reviewDesc")}>
        {byStatus.length > 0 && byStatus.some((x) => x.value > 0) ? (
          <DonutChart data={byStatus} />
        ) : (
          <NoData label={t("trend.lblSubmissions")} />
        )}
      </Panel>

      <Panel title={t("trend.regionTitle")} description={t("trend.regionDesc")}>
        {hasRegion ? (
          <HBarChart data={byRegion.map((r) => ({ label: r.region, value: r.count }))} color="var(--chart-2)" />
        ) : (
          <NoData label={t("trend.lblRegion")} />
        )}
      </Panel>

      <Panel title={t("trend.townshipTitle")} description={t("trend.townshipDesc")}>
        {hasTownship ? (
          <BarChart data={byTownship.map((t2) => ({ label: t2.township, value: t2.count }))} color="var(--chart-4)" />
        ) : (
          <NoData label={t("trend.lblTownship")} />
        )}
      </Panel>

      <Panel title={t("trend.livestockTitle")} description={t("trend.livestockDesc")}>
        {hasType ? (
          <HBarChart data={byType} color="var(--chart-1)" />
        ) : (
          <NoData label={t("trend.lblLivestock")} />
        )}
      </Panel>

      <Panel
        title={t("trend.breedingTitle")}
        description={t("trend.breedingDesc")}
        className="md:col-span-2"
      >
        {hasBreeding ? (
          <BarChart data={breeding} color="#e67e22" />
        ) : (
          <NoData label={t("trend.lblBreeding")} />
        )}
      </Panel>
    </div>
  )
}
