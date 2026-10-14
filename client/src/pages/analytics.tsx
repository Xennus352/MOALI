"use client"

import { useQuery } from "@tanstack/react-query"
import { api } from "@/lib/api"
import { PageHeader } from "@/components/layout/page-header"
import { TrendPanels } from "@/components/dashboard/trend-panels"
import { MiniStat } from "@/components/charts"
import { LoadingBlock } from "@/components/layout/loading-block"
import { FileText, Egg, Clock } from "lucide-react"

interface Kpi {
  totalSubmissions: number
  submissionsThisMonth: number
  approvedSubmissions: number
  rejectedSubmissions: number
  pendingReview: number
  totalAnimals: number
  totalBreedingStock: number
}

export function AnalyticsPage() {
  const { data: kpi, isLoading } = useQuery<Kpi>({
    queryKey: ["dashboard-kpi"],
    queryFn: () => api.get<Kpi>("/api/v1/dashboard/kpi"),
    retry: 1,
  })

  return (
    <main className="w-full">
      <PageHeader
        title="Analytics"
        description="Full-width trend panels computed live from the census database — no synthetic numbers."
      />

      {isLoading && <LoadingBlock />}

      <div className="mb-6 grid grid-cols-2 gap-3 lg:grid-cols-4">
        <MiniStat label="Submissions (all time)" value={kpi?.totalSubmissions ?? 0} color="var(--chart-1)" hint={"month: " + (kpi?.submissionsThisMonth ?? 0)} />
        <MiniStat label="Approved" value={kpi?.approvedSubmissions ?? 0} color="var(--chart-2)" />
        <MiniStat label="Pending review" value={kpi?.pendingReview ?? 0} color="var(--warning)" hint={String(kpi?.rejectedSubmissions ?? 0) + " rejected"} />
        <MiniStat label="Animals reported" value={kpi?.totalAnimals ?? 0} color="#e67e22" hint={String(kpi?.totalBreedingStock ?? 0) + " breeding stock"} />
      </div>

      <section className="mb-8">
        <TrendPanels days={30} />
      </section>

      <div className="grid grid-cols-1 gap-4 md:grid-cols-3">
        {[
          { icon: FileText, title: "Collection velocity", body: "The area chart tracks daily submissions over the last 30 days straight from the submissions table." },
          { icon: Egg, title: "Livestock mix", body: "Animal-type and gender breakdowns aggregate every reported animal_count row by count." },
          { icon: Clock, title: "Review health", body: "Status donut and breeding-stock bars reflect the live review workflow state." },
        ].map((c) => (
          <div key={c.title} className="rounded-2xl border border-border/70 bg-card p-5">
            <c.icon className="mb-3 h-5 w-5 text-primary" />
            <h3 className="font-display text-[0.98rem] font-bold text-foreground">{c.title}</h3>
            <p className="mt-1.5 text-[0.82rem] leading-relaxed text-muted-foreground">{c.body}</p>
          </div>
        ))}
      </div>
    </main>
  )
}