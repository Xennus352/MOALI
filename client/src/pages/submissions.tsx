"use client"

import { useState } from "react"
import { useInfiniteQuery, useQuery, useQueryClient } from "@tanstack/react-query"
import { useToast } from "@/components/ui/use-toast"
import { api, downloadCsv, timeAgo, type ListResponse } from "@/lib/api"
import { useInfiniteScroll } from "@/hooks/use-infinite-scroll"
import { pickLocalized, useI18n } from "@/lib/i18n"
import { PageHeader } from "@/components/layout/page-header"
import { Card } from "@/components/ui/card"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Textarea } from "@/components/ui/textarea"
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table"
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogDescription,
  DialogFooter,
} from "@/components/ui/dialog"
import {
  Search,
  Download,
  Eye,
  X,
  CheckCircle2,
  Undo2,
  Loader2,
  RotateCcw,
} from "lucide-react"

interface AnimalCount {
  id: number
  animal_type: string | null
  animal_type_code?: string | null
  species?: string | null
  breed?: string | null
  age_group?: string | null
  gender: string
  count: number
}

interface BreedingCount {
  id: number
  breeding_category: string | null
  male_count: number
  female_count: number
}

interface ReviewEntry {
  id: number
  actor_id: string | null
  action: string
  created_at: string | null
}

interface Submission {
  id: number
  household_no: string | null
  // respondent
  respondent_name_burmese: string | null
  respondent_name_english: string | null
  respondent_phone: string | null
  respondent_age: number | null
  respondent_gender?: string | null
  respondent_age_group?: string | null
  respondent_education?: string | null
  // household head
  household_head_name_burmese: string | null
  household_head_name_english?: string | null
  household_head_age: number | null
  household_head_phone?: string | null
  household_head_gender?: string | null
  household_head_age_group?: string | null
  household_head_education?: string | null
  // geography (denormalised names)
  state_region_burmese?: string | null
  state_region_english?: string | null
  district_burmese?: string | null
  township_burmese?: string | null
  village_tract_burmese?: string | null
  ward_burmese?: string | null
  // interview
  interview_date: string | null
  interviewer_name?: string | null
  interviewer_phone?: string | null
  // workflow
  collection_status: string | null
  review_status: string | null
  has_raised_animals?: boolean | null
  has_poultry?: boolean | null
  animal_total?: number | null
  animal_counts?: AnimalCount[]
  breeding_counts?: BreedingCount[]
  additional_data?: Record<string, unknown> | null
  review_history?: ReviewEntry[]
  created_at: string | null
}

interface StateRegion {
  id: number
  burmese_name: string
  english_name: string
}

type ReviewAction = "start_review" | "approve" | "reject" | "return" | "reopen"

// Mirrors the backend's allowed transitions. Showing only valid actions means a
// reviewer never triggers the 409 Conflict that a stale status would cause.
const ACTIONS_BY_STATUS: Record<string, ReviewAction[]> = {
  pending: ["start_review", "approve", "reject"],
  submitted: ["start_review", "approve", "reject"],
  under_review: ["approve", "reject", "return"],
  returned: ["start_review", "approve", "reject"],
  approved: ["reopen"],
  rejected: ["reopen"],
  reopened: ["start_review", "approve", "reject"],
}

const REVIEW_ICON: Record<ReviewAction, React.ComponentType<{ className?: string }>> = {
  start_review: Eye,
  approve: CheckCircle2,
  reject: X,
  return: Undo2,
  reopen: RotateCcw,
}

const STATUS_STYLES: Record<string, string> = {
  draft: "bg-muted text-muted-foreground",
  pending: "bg-chart-4/15 text-chart-4",
  submitted: "bg-chart-4/15 text-chart-4",
  under_review: "bg-primary/10 text-primary",
  approved: "bg-success/15 text-[var(--success)]",
  rejected: "bg-destructive/10 text-[var(--destructive)]",
  returned: "bg-warning/15 text-[var(--warning)]",
  reopened: "bg-warning/15 text-[var(--warning)]",
  completed: "bg-success/15 text-[var(--success)]",
}

function humanize(value: string): string {
  return value.replace(/[._]/g, " ").replace(/\b\w/g, (c) => c.toUpperCase())
}

function Field({ label, value }: { label: string; value: React.ReactNode }) {
  const empty = value === null || value === undefined || value === ""
  return (
    <div className="rounded-xl border border-border/60 bg-muted/30 px-3.5 py-3">
      <p className="text-[0.66rem] font-semibold uppercase tracking-wider text-muted-foreground">
        {label}
      </p>
      <p className="mt-1 break-words text-[0.9rem] font-medium text-foreground">{empty ? "—" : value}</p>
    </div>
  )
}

export function SubmissionsPage() {
  const qc = useQueryClient()
  const { toast } = useToast()
  const { t, lang } = useI18n()

  const [q, setQ] = useState("")
  const [search, setSearch] = useState("")
  const [status, setStatus] = useState("")
  const [stateRegionId, setStateRegionId] = useState("")
  const [dateFrom, setDateFrom] = useState("")
  const [dateTo, setDateTo] = useState("")
  const [selected, setSelected] = useState<number | null>(null)
  const [reviewNotes, setReviewNotes] = useState("")
  const [actionLoading, setActionLoading] = useState<string | null>(null)

  // Filter fingerprint (no page): changing any filter yields a new query key and
  // the infinite list restarts from page 1 automatically.
  const filterParams = new URLSearchParams({ page_size: "25" })
  if (search) filterParams.set("q", search)
  if (status) filterParams.set("status", status)
  if (stateRegionId) filterParams.set("state_region_id", stateRegionId)
  if (dateFrom) filterParams.set("date_from", dateFrom)
  if (dateTo) filterParams.set("date_to", dateTo)
  const filterKey = filterParams.toString()

  const {
    data,
    isLoading,
    isFetchingNextPage,
    hasNextPage,
    fetchNextPage,
  } = useInfiniteQuery<ListResponse<Submission>>({
    queryKey: ["submissions", filterKey],
    queryFn: ({ pageParam }) => {
      const p = new URLSearchParams(filterParams)
      p.set("page", String(pageParam))
      return api.get<ListResponse<Submission>>(`/api/v1/submissions?${p.toString()}`)
    },
    initialPageParam: 1,
    getNextPageParam: (last) => (last.page < last.pages ? last.page + 1 : undefined),
    retry: 1,
  })

  const rows = data?.pages.flatMap((p) => p.items) ?? []
  const total = data?.pages[0]?.total ?? 0
  const pages = data?.pages[0]?.pages ?? 1

  const sentinelRef = useInfiniteScroll(
    () => { if (hasNextPage && !isFetchingNextPage) fetchNextPage() },
    Boolean(hasNextPage) && !isFetchingNextPage,
  )

  const { data: regions } = useQuery<StateRegion[]>({
    queryKey: ["state-regions"],
    queryFn: () => api.get<StateRegion[]>("/api/v1/master/state-regions"),
    staleTime: 60_000 * 5,
  })

  const {
    data: detail,
    isLoading: detailLoading,
    isError: detailError,
  } = useQuery<Submission>({
    queryKey: ["submission-detail", selected],
    queryFn: () => api.get<Submission>(`/api/v1/submissions/${selected}`),
    enabled: selected != null,
    retry: false,
  })

  const statusLabel = (value?: string | null): string => {
    if (!value) return "—"
    const key = `sstatus.${value}`
    const label = t(key)
    return label === key ? humanize(value) : label
  }

  const actionLabel = (value: string): string => {
    const key = `act.${value}`
    const label = t(key)
    return label === key ? humanize(value) : label
  }

  const applyFilters = () => setSearch(q)

  const resetFilters = () => {
    setQ("")
    setSearch("")
    setStatus("")
    setStateRegionId("")
    setDateFrom("")
    setDateTo("")
  }

  const runReviewAction = async (action: ReviewAction) => {
    if (!selected) return
    setActionLoading(action)
    try {
      await api.post(`/api/v1/submissions/${selected}/review`, { action, notes: reviewNotes })
      toast({
        title: t("submissions.updated"),
        description: t("submissions.markedAs", { action: t(`act.${action}`) }),
        variant: "success",
      })
      setReviewNotes("")
      qc.invalidateQueries({ queryKey: ["submissions"] })
      qc.invalidateQueries({ queryKey: ["dashboard-kpi"] })
      qc.invalidateQueries({ queryKey: ["dashboard-trends"] })
      qc.invalidateQueries({ queryKey: ["dashboard-recent"] })
      qc.invalidateQueries({ queryKey: ["submission-detail"] })
      qc.invalidateQueries({ queryKey: ["notifications"] })
    } catch (err) {
      toast({
        title: t("submissions.actionFailed"),
        description: err instanceof Error ? err.message : t("submissions.couldNotUpdate"),
        variant: "destructive",
      })
    } finally {
      setActionLoading(null)
    }
  }

  const exportCsv = () => {
    const p = new URLSearchParams()
    if (search) p.set("q", search)
    if (status) p.set("status", status)
    if (stateRegionId) p.set("state_region_id", stateRegionId)
    if (dateFrom) p.set("date_from", dateFrom)
    if (dateTo) p.set("date_to", dateTo)
    downloadCsv(`/api/v1/submissions/export.csv?${p}`)
  }

  const reviewActions = detail ? ACTIONS_BY_STATUS[detail.collection_status ?? ""] ?? [] : []

  return (
    <main className="w-full">
      <PageHeader
        title={t("submissions.title")}
        description={t("submissions.description")}
        actions={
          <Button variant="outline" onClick={exportCsv} className="rounded-xl border-border bg-card">
            <Download className="h-4 w-4" /> {t("submissions.exportCsv")}
          </Button>
        }
      />

      {/* Filters */}
      <Card data-reveal className="mb-5 border-border/80 bg-card p-4">
        <div className="grid grid-flow-dense grid-cols-1 gap-3 md:grid-cols-2 xl:grid-cols-6">
          <div className="relative xl:col-span-2">
            <Search className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground" />
            <Input
              value={q}
              onChange={(e) => setQ(e.target.value)}
              onKeyDown={(e) => e.key === "Enter" && applyFilters()}
              placeholder={t("submissions.searchPlaceholder")}
              className="h-10 rounded-xl pl-9"
            />
          </div>
          <select
            value={status}
            onChange={(e) => setStatus(e.target.value)}
            className="h-10 rounded-xl border border-input bg-card px-3 text-[0.85rem] text-foreground focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring"
          >
            <option value="">{t("submissions.allStatuses")}</option>
            {["draft", "submitted", "under_review", "approved", "rejected", "returned"].map((s) => (
              <option key={s} value={s}>{statusLabel(s)}</option>
            ))}
          </select>
          <select
            value={stateRegionId}
            onChange={(e) => setStateRegionId(e.target.value)}
            className="h-10 rounded-xl border border-input bg-card px-3 text-[0.85rem] text-foreground focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring"
          >
            <option value="">{t("submissions.allRegions")}</option>
            {regions?.map((r) => (
              <option key={r.id} value={r.id}>{pickLocalized(lang, r.burmese_name, r.english_name)}</option>
            ))}
          </select>
          <Input type="date" value={dateFrom} onChange={(e) => setDateFrom(e.target.value)} className="h-10 rounded-xl" />
          <Input type="date" value={dateTo} onChange={(e) => setDateTo(e.target.value)} className="h-10 rounded-xl" />
        </div>
        <div className="mt-3 flex items-center justify-between gap-3">
          <div className="flex gap-2">
            <Button onClick={applyFilters} className="h-9 rounded-xl">
              <Search className="h-3.5 w-3.5" /> {t("common.apply")}
            </Button>
            <Button variant="outline" onClick={resetFilters} className="h-9 rounded-xl border-border bg-card">
              <X className="h-3.5 w-3.5" /> {t("submissions.reset")}
            </Button>
          </div>
          <span className="text-[0.8rem] text-muted-foreground">
            {data ? t("submissions.summary", { total, shown: rows.length, pages }) : ""}
          </span>
        </div>
      </Card>

      {/* Table */}
      <Card data-reveal className="overflow-hidden border-border/80 bg-card">
        <div className="overflow-x-auto">
          <Table>
            <TableHeader className="bg-muted/40">
              <TableRow className="hover:bg-transparent">
                <TableHead className="w-[70px]">#</TableHead>
                <TableHead>{t("submissions.colHousehold")}</TableHead>
                <TableHead>{t("submissions.colRespondent")}</TableHead>
                <TableHead>{t("submissions.colTownship")}</TableHead>
                <TableHead>{t("submissions.colRegion")}</TableHead>
                <TableHead>{t("submissions.colStatus")}</TableHead>
                <TableHead>{t("submissions.colSubmitted")}</TableHead>
                <TableHead className="text-right">{t("submissions.colAction")}</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {isLoading && (
                <TableRow>
                  <TableCell colSpan={8} className="h-28 text-center text-muted-foreground">
                    <Loader2 className="mx-auto h-5 w-5 animate-spin" /> {t("submissions.loading")}
                  </TableCell>
                </TableRow>
              )}
              {!isLoading && rows.length === 0 && (
                <TableRow>
                  <TableCell colSpan={8} className="h-28 text-center text-muted-foreground">
                    {t("submissions.noMatch")}
                  </TableCell>
                </TableRow>
              )}
              {rows.map((sub) => {
                const style = STATUS_STYLES[sub.collection_status ?? ""] ?? "bg-muted text-muted-foreground"
                return (
                  <TableRow key={sub.id} className="group">
                    <TableCell className="font-semibold text-muted-foreground">#{sub.id}</TableCell>
                    <TableCell className="font-semibold text-foreground">{sub.household_no || "—"}</TableCell>
                    <TableCell className="max-w-[12rem] truncate text-muted-foreground">
                      {sub.respondent_name_burmese || sub.respondent_name_english || "—"}
                    </TableCell>
                    <TableCell className="text-muted-foreground">
                      {pickLocalized(lang, sub.township_burmese, sub.township_burmese) || "—"}
                    </TableCell>
                    <TableCell className="text-muted-foreground">
                      {pickLocalized(lang, sub.state_region_burmese, sub.state_region_english) || "—"}
                    </TableCell>
                    <TableCell>
                      <Badge variant="outline" className={`border-transparent font-semibold ${style}`}>
                        {statusLabel(sub.collection_status)}
                      </Badge>
                    </TableCell>
                    <TableCell className="whitespace-nowrap text-[0.78rem] text-muted-foreground">
                      {timeAgo(sub.created_at, lang)}
                    </TableCell>
                    <TableCell className="text-right">
                      <Button variant="ghost" size="sm" className="h-8 rounded-lg text-primary" onClick={() => setSelected(sub.id)}>
                        <Eye className="h-3.5 w-3.5" /> {t("submissions.view")}
                      </Button>
                    </TableCell>
                  </TableRow>
                )
              })}
            </TableBody>
          </Table>
        </div>

        {/* Infinite scroll: fetches the next page as this sentinel enters view */}
        <div ref={sentinelRef} className="flex items-center justify-center border-t border-border/70 px-4 py-4 text-[0.78rem] text-muted-foreground">
          {isFetchingNextPage ? (
            <span className="inline-flex items-center gap-2"><Loader2 className="h-3.5 w-3.5 animate-spin" /> {t("common.loadingMore")}</span>
          ) : hasNextPage ? (
            <span>{t("common.scrollForMore")} · {rows.length} / {total}</span>
          ) : rows.length > 0 ? (
            <span>{t("common.endOfResults")} · {t("common.records")} {total}</span>
          ) : null}
        </div>
      </Card>

      {/* Detail dialog */}
      <Dialog open={selected != null} onOpenChange={(open) => { if (!open) setSelected(null) }}>
        <DialogContent className="max-h-[90vh] overflow-y-auto sm:max-w-3xl">
          <DialogHeader>
            <DialogTitle className="inline-flex items-center gap-2">
              #{detail?.id ?? selected}
              {detail && (
                <Badge variant="outline" className={`border-transparent font-semibold ${STATUS_STYLES[detail.collection_status ?? ""] ?? "bg-muted"}`}>
                  {statusLabel(detail.collection_status)}
                </Badge>
              )}
            </DialogTitle>
            <DialogDescription>{t("submissions.detailDescription")}</DialogDescription>
          </DialogHeader>

          {detailLoading && !detailError && (
            <div className="grid place-items-center py-16 text-muted-foreground">
              <Loader2 className="h-6 w-6 animate-spin" />
            </div>
          )}

          {detailError && (
            <p className="py-12 text-center text-[0.9rem] text-muted-foreground">
              {t("submissions.notFound")}
            </p>
          )}

          {detail && (
            <div className="space-y-6">
              {/* Location & interview */}
              <div className="grid grid-flow-dense grid-cols-1 gap-4 sm:grid-cols-2 xl:grid-cols-3">
                <Field label={t("submissions.colHousehold")} value={detail.household_no} />
                <Field
                  label={t("submissions.colRegion")}
                  value={pickLocalized(lang, detail.state_region_burmese, detail.state_region_english)}
                />
                <Field label={t("submissions.field.district")} value={detail.district_burmese} />
                <Field label={t("submissions.colTownship")} value={detail.township_burmese} />
                <Field label={t("submissions.field.villageTract")} value={detail.village_tract_burmese} />
                <Field label={t("submissions.field.ward")} value={detail.ward_burmese} />
                <Field label={t("submissions.field.interviewDate")} value={detail.interview_date} />
                <Field label={t("submissions.field.interviewer")} value={detail.interviewer_name} />
                <Field label={t("submissions.field.interviewerPhone")} value={detail.interviewer_phone} />
              </div>

              {/* Respondent */}
              <div>
                <h4 className="mb-2 text-[0.8rem] font-bold uppercase tracking-wider text-muted-foreground">
                  {t("submissions.colRespondent")}
                </h4>
                <div className="grid grid-flow-dense grid-cols-1 gap-4 sm:grid-cols-2 xl:grid-cols-3">
                  <Field label={t("submissions.field.respondentMy")} value={detail.respondent_name_burmese} />
                  <Field label={t("submissions.field.respondentEn")} value={detail.respondent_name_english} />
                  <Field label={t("submissions.field.gender")} value={detail.respondent_gender} />
                  <Field label={t("submissions.field.age")} value={detail.respondent_age != null ? String(detail.respondent_age) : null} />
                  <Field label={t("submissions.field.ageGroup")} value={detail.respondent_age_group} />
                  <Field label={t("submissions.field.education")} value={detail.respondent_education} />
                  <Field label={t("submissions.field.phone")} value={detail.respondent_phone} />
                  <Field label={t("submissions.field.hasAnimals")} value={detail.has_raised_animals == null ? null : detail.has_raised_animals ? t("submissions.yes") : t("submissions.no")} />
                  <Field label={t("submissions.field.poultry")} value={detail.has_poultry == null ? null : detail.has_poultry ? t("submissions.yes") : t("submissions.no")} />
                </div>
              </div>

              {/* Household head */}
              <div>
                <h4 className="mb-2 text-[0.8rem] font-bold uppercase tracking-wider text-muted-foreground">
                  {t("submissions.field.headMy").replace(/\s*\(.*\)$/, "")}
                </h4>
                <div className="grid grid-flow-dense grid-cols-1 gap-4 sm:grid-cols-2 xl:grid-cols-3">
                  <Field label={t("submissions.field.headMy")} value={detail.household_head_name_burmese} />
                  <Field label={t("submissions.field.headEn")} value={detail.household_head_name_english} />
                  <Field label={t("submissions.field.headGender")} value={detail.household_head_gender} />
                  <Field label={t("submissions.field.headAge")} value={detail.household_head_age != null ? String(detail.household_head_age) : null} />
                  <Field label={t("submissions.field.headAgeGroup")} value={detail.household_head_age_group} />
                  <Field label={t("submissions.field.headEducation")} value={detail.household_head_education} />
                  <Field label={t("submissions.field.headPhone")} value={detail.household_head_phone} />
                </div>
              </div>

              {detail.animal_counts && detail.animal_counts.length > 0 && (
                <div>
                  <h4 className="mb-2 text-[0.8rem] font-bold uppercase tracking-wider text-muted-foreground">
                    {t("submissions.animalCounts")} · {t("submissions.field.animalTotal")}: {detail.animal_total ?? 0}
                  </h4>
                  <div className="grid grid-flow-dense grid-cols-1 gap-2 sm:grid-cols-2 xl:grid-cols-3">
                    {detail.animal_counts.map((a) => (
                      <div key={a.id} className="rounded-xl border border-border/60 px-3.5 py-2.5 text-[0.85rem]">
                        <div className="flex items-center justify-between">
                          <span className="font-medium text-foreground">{a.animal_type || a.animal_type_code || "—"}</span>
                          <span className="text-muted-foreground">
                            {a.gender} · <b className="text-foreground">{a.count}</b>
                          </span>
                        </div>
                        {(a.species || a.breed || a.age_group) && (
                          <p className="mt-1 text-[0.72rem] text-muted-foreground">
                            {[a.species, a.breed, a.age_group].filter(Boolean).join(" · ")}
                          </p>
                        )}
                      </div>
                    ))}
                  </div>
                </div>
              )}

              {detail.breeding_counts && detail.breeding_counts.length > 0 && (
                <div>
                  <h4 className="mb-2 text-[0.8rem] font-bold uppercase tracking-wider text-muted-foreground">
                    {t("submissions.breedingStock")}
                  </h4>
                  <div className="grid grid-flow-dense grid-cols-1 gap-2 sm:grid-cols-2 xl:grid-cols-3">
                    {detail.breeding_counts.map((b) => (
                      <div key={b.id} className="flex items-center justify-between rounded-xl border border-border/60 px-3.5 py-2.5 text-[0.85rem]">
                        <span className="font-medium text-foreground">{b.breeding_category || "—"}</span>
                        <span className="text-muted-foreground">♂ {b.male_count} · ♀ {b.female_count}</span>
                      </div>
                    ))}
                  </div>
                </div>
              )}

              {detail.additional_data && Object.keys(detail.additional_data).length > 0 && (
                <div>
                  <h4 className="mb-2 text-[0.8rem] font-bold uppercase tracking-wider text-muted-foreground">
                    {t("submissions.additionalFields")}
                  </h4>
                  <div className="grid grid-flow-dense grid-cols-1 gap-2 sm:grid-cols-2 xl:grid-cols-3">
                    {Object.entries(detail.additional_data).map(([key, value]) => (
                      <Field
                        key={key}
                        label={humanize(key)}
                        value={value === null || value === undefined ? null : Array.isArray(value) ? value.join(", ") : String(value)}
                      />
                    ))}
                  </div>
                </div>
              )}

              {detail.review_history && detail.review_history.length > 0 && (
                <div>
                  <h4 className="mb-2 text-[0.8rem] font-bold uppercase tracking-wider text-muted-foreground">
                    {t("submissions.reviewHistory")}
                  </h4>
                  <ul className="space-y-2">
                    {detail.review_history.slice(0, 8).map((h) => (
                      <li key={h.id} className="flex items-center justify-between rounded-xl border border-border/60 px-3.5 py-2.5 text-[0.82rem]">
                        <span className="font-semibold text-foreground">{actionLabel(h.action)}</span>
                        <span className="text-muted-foreground">
                          {h.actor_id ? t("activity.user", { id: h.actor_id }) : t("activity.system")} · {timeAgo(h.created_at, lang)}
                        </span>
                      </li>
                    ))}
                  </ul>
                </div>
              )}

              {reviewActions.length > 0 && (
                <div className="space-y-3 rounded-xl border border-border/60 bg-muted/20 p-4">
                  <div>
                    <Label htmlFor="review-notes" className="text-[0.8rem] font-semibold">
                      {t("submissions.reviewNotes")}
                    </Label>
                    <Textarea
                      id="review-notes"
                      value={reviewNotes}
                      onChange={(e) => setReviewNotes(e.target.value)}
                      placeholder={t("submissions.notePlaceholder")}
                      className="mt-1.5 min-h-[70px] rounded-xl"
                    />
                  </div>
                  <div className="flex flex-wrap gap-2">
                    {reviewActions.map((action) => {
                      const Icon = REVIEW_ICON[action]
                      const destructive = action === "reject"
                      const approve = action === "approve"
                      const outline = action === "return"
                      return (
                        <Button
                          key={action}
                          variant={destructive ? "destructive" : outline ? "outline" : "default"}
                          className={
                            approve
                              ? "h-9 rounded-xl bg-[#2e8b57] hover:bg-[#256e45]"
                              : outline
                                ? "h-9 rounded-xl border-border bg-card"
                                : "h-9 rounded-xl"
                          }
                          onClick={() => runReviewAction(action)}
                          disabled={actionLoading != null}
                        >
                          {actionLoading === action ? (
                            <Loader2 className="h-4 w-4 animate-spin" />
                          ) : (
                            <Icon className="h-4 w-4" />
                          )}
                          {t(`act.${action}`)}
                        </Button>
                      )
                    })}
                  </div>
                </div>
              )}
            </div>
          )}

          <DialogFooter>
            <Button variant="outline" className="rounded-xl border-border bg-card" onClick={() => setSelected(null)}>
              {t("common.close")}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </main>
  )
}
