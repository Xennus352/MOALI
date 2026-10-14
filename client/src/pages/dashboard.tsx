"use client"

import { useQuery } from "@tanstack/react-query"
import { useMemo } from "react"
import { useNavigate } from "react-router-dom"
import { StatCard, type StatCardProps } from "@/components/dashboard/stats-cards"
import { TrendPanels } from "@/components/dashboard/trend-panels"
import { useTrends } from "@/components/dashboard/use-trends"
import { RecentSubmissions, type RecentSubmission } from "@/components/dashboard/recent-submissions"
import { RecentActivity, type ActivityEntry } from "@/components/dashboard/recent-activity"
import { EmptyState } from "@/components/dashboard/empty-state"
import { Logo } from "@/components/logo"
import moaliLogo from "@/assets/moali-logo.png"
import lbvdLogo from "@/assets/lbvd-logo.png"
import { Button } from "@/components/ui/button"
import { useAuth } from "@/context/auth-context"
import { useReveal, useScrollReveal } from "@/hooks/use-reveal"
import { api, downloadCsv } from "@/lib/api"
import { useI18n } from "@/lib/i18n"
import {
  FileText,
  Calendar,
  Layers,
  CheckCircle2,
  Plus,
  Download,
  Inbox,
  Radio,
  Users,
} from "lucide-react"

interface Kpi {
  totalSubmissions: number
  submissionsToday: number
  submissionsThisWeek: number
  submissionsThisMonth: number
  totalHouseholds: number
  totalUsers: number
  activeUsers: number
  pendingReview: number
  approvedSubmissions: number
  rejectedSubmissions: number
  totalAnimals: number
  totalBreedingStock: number
  configuredFields: number
  formPublicationStatus: Record<string, number>
}

interface RecentResponse {
  submissions: RecentSubmission[]
  activity: ActivityEntry[]
}

/* --- helpers ----------------------------------------------------------- */

function greetingKey(): string {
  const h = new Date().getHours()
  if (h < 5) return "dashboard.greetingLate"
  if (h < 12) return "dashboard.greetingMorning"
  if (h < 18) return "dashboard.greetingAfternoon"
  return "dashboard.greetingEvening"
}

function weekDelta(series: { count: number }[] | undefined): number {
  if (!series || series.length < 14) return 0
  const last7 = series.slice(-7).reduce((a, b) => a + b.count, 0)
  const prev7 = series.slice(-14, -7).reduce((a, b) => a + b.count, 0)
  if (prev7 === 0) return last7 > 0 ? 100 : 0
  return Math.round(((last7 - prev7) / prev7) * 100)
}

/* --- page -------------------------------------------------------------- */

export function DashboardPage() {
  const { user } = useAuth()
  const navigate = useNavigate()
  const { t, lang } = useI18n()

  const { data: kpi } = useQuery<Kpi>({
    queryKey: ["dashboard-kpi"],
    queryFn: () => api.get<Kpi>("/api/v1/dashboard/kpi"),
    retry: 1,
  })

  const { data: trends } = useTrends(30)

  const { data: recent } = useQuery<RecentResponse>({
    queryKey: ["dashboard-recent"],
    queryFn: () => api.get<RecentResponse>("/api/v1/dashboard/recent?limit=6"),
    retry: 1,
  })

  const heroRef = useReveal<HTMLDivElement>([])
  const lowerRef = useScrollReveal<HTMLDivElement>()

  const firstName = useMemo(
    () => (user?.name || "Admin").split(" ")[0].replace(/[^\p{L}\p{N}]/gu, "") || "Admin",
    [user]
  )

  const delta = weekDelta(trends?.submissionsOverTime)

  const cards: StatCardProps[] = useMemo(
    () => [
      {
        title: t("dashboard.cardTotal"),
        value: String(kpi?.totalSubmissions ?? 0),
        icon: <FileText className="h-[1.1rem] w-[1.1rem]" />,
        description: t("dashboard.cardTotalDesc", { n: kpi?.totalSubmissions ?? 0 }),
      },
      {
        title: t("dashboard.cardToday"),
        value: String(kpi?.submissionsToday ?? 0),
        icon: <Calendar className="h-[1.1rem] w-[1.1rem]" />,
        description: t("dashboard.cardTodayDesc"),
      },
      {
        title: t("dashboard.cardWeek"),
        value: String(kpi?.submissionsThisWeek ?? 0),
        icon: <Layers className="h-[1.1rem] w-[1.1rem]" />,
        delta: `${delta >= 0 ? "+" : ""}${delta}%`,
        deltaType: delta >= 0 ? "increase" : "decrease",
        description: t("dashboard.cardWeekDesc"),
      },
      {
        title: t("dashboard.cardApproved"),
        value: String(kpi?.approvedSubmissions ?? 0),
        icon: <CheckCircle2 className="h-[1.1rem] w-[1.1rem]" />,
        description: t("dashboard.cardApprovedDesc", { n: kpi?.pendingReview ?? 0 }),
        deltaType: "increase",
      },
      {
        title: t("dashboard.cardAnimals"),
        value: String(kpi?.totalAnimals ?? 0),
        icon: <Users className="h-[1.1rem] w-[1.1rem]" />,
        description: t("dashboard.cardAnimalsDesc", { n: kpi?.totalBreedingStock ?? 0 }),
      },
    ],
    [kpi, delta, t]
  )

  const publishedForms = kpi?.formPublicationStatus?.published ?? 0
  const today = useMemo(
    () =>
      new Intl.DateTimeFormat(lang === "en" ? "en-GB" : "my-MM", {
        weekday: "long",
        day: "numeric",
        month: "long",
        year: "numeric",
      }).format(new Date()),
    [lang]
  )

  return (
    <main className="w-full max-w-full overflow-x-hidden">
      {/* ---- Hero / Attention ---- */}
      <section ref={heroRef} className="relative">
        <div className="flex flex-col gap-8 lg:flex-row lg:items-end lg:justify-between">
          <div className="min-w-0">
            <div data-reveal className="mb-6">
              <Logo src={moaliLogo} markSize={52} className="origin-left" />
            </div>

            <h1
              data-reveal
              className="max-w-4xl font-display text-[clamp(1.9rem,4.2vw,3.4rem)] font-black leading-[1.04] tracking-tight text-balance"
            >
              {t(greetingKey())}, {firstName}{" "}
              <span className="inline-flex translate-y-[-0.12em] items-center gap-2 rounded-full bg-primary px-3.5 py-1.5 align-middle text-[0.62em] font-bold uppercase tracking-[0.14em] text-primary-foreground shadow-[0_10px_24px_-10px_rgb(27_77_62/0.6)]">
                <span className="relative flex h-2 w-2">
                  <span className="absolute inline-flex h-full w-full animate-ping rounded-full bg-[#e67e22] opacity-75" />
                  <span className="relative inline-flex h-2 w-2 rounded-full bg-[#e67e22]" />
                </span>
                {t("dashboard.live")}
              </span>
            </h1>

            <p data-reveal className="mt-4 max-w-xl text-[0.95rem] leading-relaxed text-muted-foreground">
              {t("dashboard.intro")}
            </p>
          </div>

          <div data-reveal className="flex shrink-0 flex-col items-start gap-5 lg:items-end">
            {/* LBVD emblem — top-right corner of the dashboard */}
            <img
              src={lbvdLogo}
              alt="LBVD"
              className="h-16 w-16 rounded-xl bg-white/70 object-contain p-1 shadow-sm ring-1 ring-border"
            />
            <span className="text-[0.82rem] font-medium text-muted-foreground">{today}</span>
            <div className="flex flex-wrap gap-3">
              <Button
                onClick={() => navigate("/census-responses/new")}
                className="h-11 rounded-xl px-5 shadow-[0_12px_28px_-12px_rgb(27_77_62/0.7)]"
              >
                <Plus className="h-4 w-4" /> {t("dashboard.newSubmission")}
              </Button>
              <Button
                variant="outline"
                onClick={() => downloadCsv("/api/v1/submissions/export.csv")}
                className="h-11 rounded-xl border-border bg-card px-5 text-foreground hover:bg-muted"
              >
                <Download className="h-4 w-4" /> {t("dashboard.exportCsv")}
              </Button>
            </div>
          </div>
        </div>

        {/* ---- KPI band / Interest ---- */}
        <div className="mt-10 grid grid-flow-dense grid-cols-1 gap-4 md:grid-cols-2 xl:grid-cols-5" data-reveal>
          {cards.map((card) => (
            <StatCard key={card.title} {...card} />
          ))}
        </div>
      </section>

      {/* ---- Charts bento / Desire ---- */}
      <section className="mt-10">
        <div className="mb-5 flex items-end justify-between gap-4">
          <div>
            <h2 className="font-display text-[1.4rem] font-bold tracking-tight">{t("dashboard.trendsTitle")}</h2>
            <p className="mt-1 text-sm text-muted-foreground">{t("dashboard.trendsSubtitle")}</p>
          </div>
          <Button
            variant="ghost"
            onClick={() => navigate("/analytics")}
            className="text-sm text-primary hover:bg-primary/10"
          >
            {t("dashboard.openAnalytics")}
          </Button>
        </div>

        <TrendPanels days={30} />
      </section>

      {/* ---- Lower grid: submissions + activity ---- */}
      <section ref={lowerRef} className="mt-10">
        <div className="grid grid-flow-dense grid-cols-1 gap-4 xl:grid-cols-5">
          <div className="xl:col-span-3" data-reveal>
            {recent && recent.submissions.length > 0 ? (
              <RecentSubmissions submissions={recent.submissions} />
            ) : (
              <EmptyState
                icon={<Inbox className="h-7 w-7" />}
                title={t("dashboard.noSubmissions")}
                description={t("dashboard.noSubmissionsDesc")}
                action={
                  <Button className="rounded-xl" onClick={() => navigate("/census-responses/new")}>
                    <Plus className="h-4 w-4" /> {t("dashboard.firstSubmission")}
                  </Button>
                }
              />
            )}
          </div>
          <div className="xl:col-span-2" data-reveal>
            <RecentActivity activity={recent?.activity ?? []} />
          </div>
        </div>
      </section>

      {/* ---- System status strip / Action ---- */}
      <section className="mt-10 pb-2">
        <div
          data-reveal
          className="flex flex-col gap-4 rounded-2xl border border-border/80 bg-gradient-to-br from-primary to-[#0f2f26] p-6 text-white shadow-[0_24px_60px_-24px_rgb(27_77_62/0.55)] sm:flex-row sm:items-center sm:justify-between"
        >
          <div className="flex items-start gap-4">
            <span className="grid h-11 w-11 shrink-0 place-items-center rounded-xl bg-white/10">
              <Radio className="h-5 w-5 text-[#e67e22]" />
            </span>
            <div>
              <p className="font-display text-[1.05rem] font-bold">{t("dashboard.statusTitle")}</p>
              <p className="mt-0.5 text-sm text-white/60">
                {publishedForms > 0
                  ? t("dashboard.statusPublished", {
                      count: publishedForms,
                      fields: kpi?.configuredFields ?? 0,
                    })
                  : t("dashboard.statusNoForm")}
              </p>
            </div>
          </div>
          <div className="flex items-center gap-3">
            <span className="grid place-items-center rounded-xl bg-white/10 px-4 py-2.5 text-center">
              <span className="block font-display text-lg font-bold leading-none">{kpi?.activeUsers ?? 0}</span>
              <span className="text-[0.66rem] uppercase tracking-wider text-white/55">{t("dashboard.users")}</span>
            </span>
            <span className="grid place-items-center rounded-xl bg-white/10 px-4 py-2.5 text-center">
              <span className="block font-display text-lg font-bold leading-none">{kpi?.totalHouseholds ?? 0}</span>
              <span className="text-[0.66rem] uppercase tracking-wider text-white/55">{t("dashboard.households")}</span>
            </span>
          </div>
        </div>
      </section>
    </main>
  )
}
