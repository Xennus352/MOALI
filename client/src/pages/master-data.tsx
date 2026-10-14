"use client"

/**
 * Master Data (the `/database` screen).
 *
 * A friendly, bilingual catalog of every reusable list the census forms draw
 * their answer options from. Lists are grouped into business categories (people
 * & household, administrative locations, livestock, other), each showing how
 * many form questions actually use it. Selecting a list deep-links in the URL
 * so the Form Builder can link straight to the answer list a question needs,
 * and return the admin to exactly where they were.
 */
import { useMemo, useState } from "react"
import { Link, useSearchParams } from "react-router-dom"
import { useQuery, useQueryClient } from "@tanstack/react-query"
import {
  ArrowLeft,
  ArrowRight,
  Database,
  Loader2,
  Pencil,
  Plus,
  Power,
  Search,
} from "lucide-react"
import { PageHeader } from "@/components/layout/page-header"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { Card } from "@/components/ui/card"
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table"
import { useToast } from "@/components/ui/use-toast"
import { api } from "@/lib/api"
import { useI18n } from "@/lib/i18n"
import { cn } from "@/lib/utils"

interface FieldMeta {
  name: string
  label: string
  type: string
  required: boolean
  maxLength?: number
  enum?: string[]
}

interface ResourceMeta {
  resource: string
  label: string
  fields: FieldMeta[]
}

interface MetaResponse {
  resources: ResourceMeta[]
}

interface UsageResponse {
  usage: Record<string, { questions: number; forms: number }>
}

const HIDDEN_COLUMNS = ["created_at", "updated_at", "id", "description", "is_populated", "sort_order"]

/** Business grouping of the raw resources. */
const CATEGORIES: { key: string; resources: string[] }[] = [
  {
    key: "masterData.cat.people",
    resources: ["genders", "age-groups", "age-types"],
  },
  {
    key: "masterData.cat.locations",
    resources: ["state-regions", "districts", "townships", "village-tracts", "wards"],
  },
  {
    key: "masterData.cat.livestock",
    resources: ["animal-types", "animal-categories", "breeds", "species", "breeding-categories"],
  },
  { key: "masterData.cat.other", resources: ["options"] },
]

/** Foreign-key field → the parent list it points at, for relationship selectors. */
const PARENT_BY_FIELD: Record<string, string> = {
  state_region_id: "state-regions",
  district_id: "districts",
  township_id: "townships",
  village_tract_id: "village-tracts",
  animal_type_id: "animal-types",
}

function humanize(name: string): string {
  return name.replace(/_/g, " ")
}

export function MasterDataPage() {
  const { t } = useI18n()
  const [params, setParams] = useSearchParams()
  const resourceParam = params.get("resource") ?? ""
  const returnTo = params.get("return")

  const { data: meta, isLoading: metaLoading } = useQuery<MetaResponse>({
    queryKey: ["master-meta"],
    queryFn: () => api.get<MetaResponse>("/api/v1/master/meta"),
    retry: 1,
  })

  const { data: usageData } = useQuery<UsageResponse>({
    queryKey: ["master-usage"],
    queryFn: () => api.get<UsageResponse>("/api/v1/master/usage"),
    retry: 1,
  })
  const usage = usageData?.usage ?? {}

  const resources = useMemo(() => meta?.resources ?? [], [meta])

  const resLabel = (resource: string, fallback: string) => {
    const key = `md.${resource}`
    const v = t(key)
    return v === key ? fallback : v
  }
  const resDesc = (resource: string) => {
    const key = `md.${resource}.desc`
    const v = t(key)
    return v === key ? "" : v
  }

  const byResource = useMemo(() => {
    const map = new Map<string, ResourceMeta>()
    for (const r of resources) map.set(r.resource, r)
    return map
  }, [resources])

  const [navQuery, setNavQuery] = useState("")

  const groups = useMemo(
    () =>
      CATEGORIES.map((cat) => ({
        key: cat.key,
        items: cat.resources
          .map((slug) => byResource.get(slug))
          .filter((r): r is ResourceMeta => Boolean(r)),
      })).filter((g) => g.items.length > 0),
    [byResource],
  )

  const activeResource =
    resources.find((r) => r.resource === resourceParam) ?? resources[0] ?? null

  const filteredGroups = useMemo(() => {
    const q = navQuery.trim().toLowerCase()
    if (!q) return groups
    return groups
      .map((g) => ({
        ...g,
        items: g.items.filter(
          (r) =>
            resLabel(r.resource, r.label).toLowerCase().includes(q) ||
            r.resource.toLowerCase().includes(q),
        ),
      }))
      .filter((g) => g.items.length > 0)
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [groups, navQuery])

  const selectResource = (resource: string) => {
    const next = new URLSearchParams(params)
    next.set("resource", resource)
    setParams(next)
  }

  return (
    <main className="w-full">
      <PageHeader title={t("masterData.title")} description={t("masterData.description")} />

      {returnTo && (
        <div className="mb-5 flex flex-wrap items-center justify-between gap-3 rounded-2xl border border-primary/20 bg-primary/[0.04] px-4 py-3">
          <p className="text-[0.82rem] text-muted-foreground">{t("masterData.relationshipNote")}</p>
          <Button asChild variant="outline" className="h-9 gap-2 rounded-lg border-border bg-card">
            <Link to={returnTo}>
              <ArrowLeft className="h-3.5 w-3.5" /> {t("common.back")}
            </Link>
          </Button>
        </div>
      )}

      <div className="grid gap-5 lg:grid-cols-[17rem_minmax(0,1fr)]">
        {/* Category navigation */}
        <aside data-reveal className="space-y-4">
          <div className="relative">
            <Search className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground" />
            <Input
              value={navQuery}
              onChange={(e) => setNavQuery(e.target.value)}
              placeholder={t("masterData.searchPlaceholder")}
              aria-label={t("common.search")}
              className="h-10 rounded-xl pl-9"
            />
          </div>

          {metaLoading ? (
            <div className="flex items-center gap-2 px-2 py-6 text-[0.82rem] text-muted-foreground">
              <Loader2 className="h-4 w-4 animate-spin" /> {t("common.loading")}
            </div>
          ) : (
            <nav className="space-y-5" aria-label={t("masterData.title")}>
              {filteredGroups.map((group) => (
                <div key={group.key}>
                  <p className="px-1 pb-1.5 text-[0.62rem] font-bold uppercase tracking-[0.18em] text-muted-foreground/70">
                    {t(group.key)}
                  </p>
                  <ul className="space-y-1">
                    {group.items.map((r) => {
                      const active = activeResource?.resource === r.resource
                      const used = usage[r.resource]?.questions ?? 0
                      return (
                        <li key={r.resource}>
                          <button
                            type="button"
                            onClick={() => selectResource(r.resource)}
                            aria-current={active ? "true" : undefined}
                            className={cn(
                              "flex w-full items-center gap-2 rounded-xl px-3 py-2 text-left text-[0.82rem] font-medium transition-colors",
                              active
                                ? "bg-[#1b4d3e] text-white dark:bg-white dark:text-[#123626]"
                                : "text-muted-foreground hover:bg-muted/60 hover:text-foreground",
                            )}
                          >
                            <span className="min-w-0 flex-1 truncate">{resLabel(r.resource, r.label)}</span>
                            {used > 0 && (
                              <span
                                className={cn(
                                  "shrink-0 rounded-full px-1.5 py-0.5 text-[0.6rem] font-bold",
                                  active ? "bg-white/20" : "bg-primary/10 text-primary",
                                )}
                                title={t("masterData.usage", {
                                  questions: used,
                                  forms: usage[r.resource]?.forms ?? 0,
                                })}
                              >
                                {used}
                              </span>
                            )}
                          </button>
                        </li>
                      )
                    })}
                  </ul>
                </div>
              ))}
              {filteredGroups.length === 0 && (
                <p className="px-1 py-4 text-[0.82rem] text-muted-foreground">
                  {t("masterData.emptyList")}
                </p>
              )}
            </nav>
          )}
        </aside>

        {/* Resource table */}
        {activeResource ? (
          <ResourcePanel
            key={activeResource.resource}
            resource={activeResource}
            label={resLabel(activeResource.resource, activeResource.label)}
            description={resDesc(activeResource.resource)}
            usage={usage[activeResource.resource]}
          />
        ) : (
          <Card className="grid place-items-center border-border/80 bg-card py-20 text-[0.85rem] text-muted-foreground">
            {t("masterData.needSource")}
          </Card>
        )}
      </div>
    </main>
  )
}

function ResourcePanel({
  resource,
  label,
  description,
  usage,
}: {
  resource: ResourceMeta
  label: string
  description: string
  usage?: { questions: number; forms: number }
}) {
  const { t } = useI18n()
  const qc = useQueryClient()
  const { toast } = useToast()

  const [q, setQ] = useState("")
  const [search, setSearch] = useState("")
  const [includeInactive, setIncludeInactive] = useState(false)
  const [editing, setEditing] = useState<Record<string, unknown> | null>(null)
  const [creating, setCreating] = useState(false)
  const [formValues, setFormValues] = useState<Record<string, unknown>>({})
  const [saving, setSaving] = useState(false)

  const fieldLabel = (name: string, fallback: string) => {
    const key = `md.field.${name}`
    const v = t(key)
    return v === key ? humanize(fallback || name) : v
  }

  const { data: rows, isLoading } = useQuery<Record<string, unknown>[]>({
    queryKey: ["master-list", resource.resource, search, includeInactive],
    queryFn: () => {
      const p = new URLSearchParams()
      if (search) p.set("q", search)
      if (includeInactive) p.set("include_inactive", "true")
      return api.get<Record<string, unknown>[]>(`/api/v1/master/${resource.resource}?${p}`)
    },
  })

  const columns = useMemo(() => {
    const fromData = new Set<string>()
    for (const row of rows ?? []) for (const k of Object.keys(row)) fromData.add(k)
    const pri = resource.fields.filter((f) => !HIDDEN_COLUMNS.includes(f.name)).map((f) => f.name)
    const ordered = pri.filter((c) => fromData.has(c))
    return ordered.length > 0 ? ordered : [...fromData].filter((c) => !HIDDEN_COLUMNS.includes(c))
  }, [resource, rows])

  const openCreate = () => {
    const init: Record<string, unknown> = {}
    for (const f of resource.fields) {
      init[f.name] = f.type === "boolean" ? true : ""
    }
    setFormValues(init)
    setCreating(true)
  }

  const openEdit = (row: Record<string, unknown>) => {
    setFormValues({ ...row })
    setEditing(row)
  }

  const closeDialog = () => {
    setCreating(false)
    setEditing(null)
  }

  const save = async () => {
    setSaving(true)
    try {
      const allowed = new Set(resource.fields.map((f) => f.name))
      const payload: Record<string, unknown> = {}
      for (const [k, v] of Object.entries(formValues)) {
        if (!allowed.has(k)) continue
        const field = resource.fields.find((f) => f.name === k)!
        payload[k] =
          field.type === "integer" || field.type === "number"
            ? v === "" || v == null
              ? null
              : Number(v)
            : field.type === "boolean"
              ? Boolean(v)
              : typeof v === "string"
                ? v.trim() === ""
                  ? null
                  : v
                : v
      }
      if (editing != null) {
        await api.patch(`/api/v1/master/${resource.resource}/${editing.id}`, payload)
        toast({ title: t("masterData.updated"), description: `${label} · #${editing.id}`, variant: "success" })
      } else {
        await api.post(`/api/v1/master/${resource.resource}`, payload)
        toast({ title: t("masterData.created"), description: label, variant: "success" })
      }
      closeDialog()
      qc.invalidateQueries({ queryKey: ["master-list"] })
      qc.invalidateQueries({ queryKey: ["master-usage"] })
      qc.invalidateQueries({ queryKey: ["master", resource.resource] })
    } catch (err) {
      toast({
        title: t("masterData.saveFailed"),
        description: err instanceof Error ? err.message : t("common.tryAgain"),
        variant: "destructive",
      })
    } finally {
      setSaving(false)
    }
  }

  const deactivate = async (row: Record<string, unknown>) => {
    if (!window.confirm(t("masterData.deactivateConfirm", { name: String(row.burmese_name ?? row.burmese_label ?? `#${row.id}`) })))
      return
    try {
      await api.delete(`/api/v1/master/${resource.resource}/${row.id}`)
      toast({ title: t("masterData.deactivated"), description: `#${row.id}`, variant: "success" })
      qc.invalidateQueries({ queryKey: ["master-list"] })
    } catch (err) {
      toast({
        title: t("masterData.saveFailed"),
        description: err instanceof Error ? err.message : t("common.tryAgain"),
        variant: "destructive",
      })
    }
  }

  const renderField = (f: FieldMeta) => {
    const parent = PARENT_BY_FIELD[f.name]
    if (parent) {
      return (
        <ParentSelect
          resource={parent}
          value={formValues[f.name] == null ? "" : String(formValues[f.name])}
          onChange={(v) => setFormValues({ ...formValues, [f.name]: v === "" ? null : Number(v) })}
        />
      )
    }
    if (f.enum) {
      return (
        <select
          value={String(formValues[f.name] ?? "")}
          onChange={(e) => setFormValues({ ...formValues, [f.name]: e.target.value })}
          className="h-10 w-full rounded-xl border border-input bg-card px-3 text-[0.85rem] text-foreground focus:outline-none focus-visible:ring-2 focus-visible:ring-ring"
        >
          <option value="">—</option>
          {f.enum.map((v) => (
            <option key={v} value={v}>
              {v}
            </option>
          ))}
        </select>
      )
    }
    if (f.type === "boolean") {
      return (
        <button
          type="button"
          onClick={() => setFormValues({ ...formValues, [f.name]: !formValues[f.name] })}
          className={cn(
            "h-9 w-16 rounded-lg border text-[0.78rem] font-semibold transition-colors",
            formValues[f.name]
              ? "border-[#2e8b57]/40 bg-[#2e8b57]/15 text-[var(--success)]"
              : "border-border bg-muted text-muted-foreground",
          )}
        >
          {formValues[f.name] ? t("common.on") : t("common.off")}
        </button>
      )
    }
    if (f.type === "integer" || f.type === "number") {
      return (
        <Input
          inputMode="numeric"
          value={String(formValues[f.name] ?? "")}
          onChange={(e) => setFormValues({ ...formValues, [f.name]: e.target.value })}
          className="rounded-xl"
        />
      )
    }
    return (
      <Input
        value={String(formValues[f.name] ?? "")}
        maxLength={f.maxLength}
        onChange={(e) => setFormValues({ ...formValues, [f.name]: e.target.value })}
        className="rounded-xl"
      />
    )
  }

  const formFields = resource.fields.filter((f) => f.name !== "is_active")
  const hasIsActive = resource.fields.some((f) => f.name === "is_active")

  return (
    <Card data-reveal className="overflow-hidden border-border/80 bg-card">
      <div className="flex flex-col gap-3 border-b border-border/70 p-4 sm:flex-row sm:items-start sm:justify-between">
        <div className="min-w-0">
          <div className="flex flex-wrap items-center gap-2">
            <Database className="h-4 w-4 text-primary" aria-hidden="true" />
            <h2 className="text-[1rem] font-bold text-foreground">{label}</h2>
            {usage && usage.questions > 0 && (
              <Link
                to="/form-builder"
                className="inline-flex items-center gap-1 rounded-full bg-primary/10 px-2.5 py-0.5 text-[0.66rem] font-semibold text-primary hover:bg-primary/15"
              >
                {t("masterData.openInBuilder")} <ArrowRight className="h-3 w-3" />
              </Link>
            )}
          </div>
          {description && <p className="mt-1 max-w-2xl text-[0.8rem] text-muted-foreground">{description}</p>}
          <p className="mt-1.5 text-[0.75rem] font-medium text-muted-foreground/80">
            {usage
              ? usage.questions > 0
                ? t("masterData.usage", { questions: usage.questions, forms: usage.forms })
                : t("masterData.usageNone")
              : t("masterData.usageUnavailable")}
          </p>
        </div>
        <Button className="h-9 shrink-0 gap-1.5 rounded-lg" onClick={openCreate}>
          <Plus className="h-3.5 w-3.5" /> {t("masterData.newItem")}
        </Button>
      </div>

      <div className="flex flex-col gap-3 border-b border-border/70 p-4 md:flex-row md:items-center">
        <div className="relative md:max-w-sm md:flex-1">
          <Search className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground" />
          <Input
            value={q}
            onChange={(e) => setQ(e.target.value)}
            onKeyDown={(e) => e.key === "Enter" && setSearch(q)}
            placeholder={t("masterData.searchPlaceholder")}
            aria-label={t("common.search")}
            className="h-9 rounded-xl pl-9"
          />
        </div>
        <div className="flex items-center gap-4">
          <Button
            variant="outline"
            size="sm"
            className="h-8 rounded-lg border-border bg-card"
            onClick={() => setSearch(q)}
          >
            {t("common.apply")}
          </Button>
          <label className="flex cursor-pointer items-center gap-2 text-[0.8rem] font-medium text-muted-foreground">
            <input
              type="checkbox"
              checked={includeInactive}
              onChange={(e) => setIncludeInactive(e.target.checked)}
              className="h-4 w-4 rounded border-border accent-[#1b4d3e]"
            />
            {t("masterData.includeInactive")}
          </label>
          <span className="whitespace-nowrap text-[0.78rem] text-muted-foreground">
            {t("common.count")}: {rows?.length ?? 0}
          </span>
        </div>
      </div>

      <div className="overflow-x-auto">
        <Table>
          <TableHeader className="bg-muted/40">
            <TableRow className="hover:bg-transparent">
              {columns.map((c) => (
                <TableHead key={c} className="text-[0.72rem] uppercase tracking-wider text-muted-foreground">
                  {fieldLabel(c, resource.fields.find((f) => f.name === c)?.label ?? c)}
                </TableHead>
              ))}
              <TableHead className="text-right">{t("common.actions")}</TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {isLoading && (
              <TableRow>
                <TableCell colSpan={columns.length + 1} className="h-28 text-center text-muted-foreground">
                  <Loader2 className="mx-auto h-5 w-5 animate-spin" />
                </TableCell>
              </TableRow>
            )}
            {!isLoading && (rows ?? []).length === 0 && (
              <TableRow>
                <TableCell colSpan={columns.length + 1} className="py-12 text-center">
                  <p className="text-[0.85rem] text-muted-foreground">{t("masterData.emptyList")}</p>
                  <p className="mt-1 text-[0.78rem] text-muted-foreground/80">{t("masterData.emptyListHint")}</p>
                </TableCell>
              </TableRow>
            )}
            {(rows ?? []).map((row) => {
              const inactive = row.is_active === false || String(row.is_active) === "false"
              return (
                <TableRow key={String(row.id)} className={inactive ? "opacity-55" : ""}>
                  {columns.map((c) => {
                    const v = row[c]
                    if (c === "is_active") {
                      return (
                        <TableCell key={c}>
                          <Badge
                            variant="outline"
                            className={cn(
                              "border-transparent font-semibold",
                              v ? "bg-[var(--success)]/15 text-[var(--success)]" : "bg-muted text-muted-foreground",
                            )}
                          >
                            {v ? t("common.active") : t("common.inactive")}
                          </Badge>
                        </TableCell>
                      )
                    }
                    if (typeof v === "boolean") {
                      return (
                        <TableCell key={c} className="text-muted-foreground">
                          {v ? t("common.yes") : t("common.no")}
                        </TableCell>
                      )
                    }
                    return (
                      <TableCell key={c} className="max-w-[18rem] truncate text-muted-foreground">
                        {v == null || v === "" ? "—" : String(v)}
                      </TableCell>
                    )
                  })}
                  <TableCell>
                    <div className="flex justify-end gap-1.5">
                      <Button
                        variant="ghost"
                        size="sm"
                        className="h-8 gap-1.5 rounded-lg text-primary"
                        onClick={() => openEdit(row)}
                      >
                        <Pencil className="h-3.5 w-3.5" /> {t("common.edit")}
                      </Button>
                      <Button
                        variant="ghost"
                        size="sm"
                        className="h-8 rounded-lg text-muted-foreground hover:text-[var(--destructive)]"
                        onClick={() => deactivate(row)}
                        aria-label={t("masterData.deactivate")}
                        title={t("masterData.deactivate")}
                      >
                        <Power className="h-3.5 w-3.5" />
                      </Button>
                    </div>
                  </TableCell>
                </TableRow>
              )
            })}
          </TableBody>
        </Table>
      </div>

      <Dialog open={creating || editing != null} onOpenChange={(o) => !o && closeDialog()}>
        <DialogContent className="max-h-[90vh] overflow-y-auto sm:max-w-2xl">
          <DialogHeader>
            <DialogTitle>{editing ? `${t("common.edit")} · ${label}` : `${t("masterData.newItem")} · ${label}`}</DialogTitle>
            <DialogDescription>
              {editing
                ? `${label} #${editing.id}`
                : description || t("masterData.relationshipNote")}
            </DialogDescription>
          </DialogHeader>

          <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
            {formFields.map((f) => (
              <div
                key={f.name}
                className={cn(
                  f.type === "boolean" ? "flex items-center justify-between gap-3 sm:col-span-2" : "space-y-1.5",
                )}
              >
                <Label className="text-[0.8rem] font-semibold text-foreground">
                  {fieldLabel(f.name, f.label)}
                  {f.required && <span className="ml-1 text-[var(--destructive)]">*</span>}
                </Label>
                {renderField(f)}
              </div>
            ))}
            {hasIsActive && (
              <div className="flex items-center justify-between gap-3 sm:col-span-2">
                <Label className="text-[0.8rem] font-semibold text-foreground">
                  {fieldLabel("is_active", "Active")}
                </Label>
                {renderField(resource.fields.find((f) => f.name === "is_active")!)}
              </div>
            )}
          </div>

          <DialogFooter>
            <Button variant="outline" className="rounded-xl border-border bg-card" onClick={closeDialog}>
              {t("common.cancel")}
            </Button>
            <Button className="rounded-xl" onClick={save} disabled={saving}>
              {saving ? <Loader2 className="h-4 w-4 animate-spin" /> : null}
              {editing ? t("common.save") : t("common.add")}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </Card>
  )
}

/** Select of items from a parent list (used for hierarchy foreign keys). */
function ParentSelect({
  resource,
  value,
  onChange,
}: {
  resource: string
  value: string
  onChange: (value: string) => void
}) {
  const { t, lang } = useI18n()
  const { data } = useQuery<Record<string, unknown>[]>({
    queryKey: ["master-list-parent", resource],
    queryFn: () => api.get<Record<string, unknown>[]>(`/api/v1/master/${resource}?include_inactive=true`),
    staleTime: 1000 * 60 * 5,
  })
  return (
    <select
      value={value}
      onChange={(e) => onChange(e.target.value)}
      className="h-10 w-full rounded-xl border border-input bg-card px-3 text-[0.85rem] text-foreground focus:outline-none focus-visible:ring-2 focus-visible:ring-ring"
    >
      <option value="">—</option>
      {(data ?? []).map((item) => {
        const my = String(item.burmese_name ?? item.burmese_label ?? item.code ?? `#${item.id}`)
        const en = String(item.english_name ?? item.english_label ?? item.code ?? `#${item.id}`)
        const text = lang === "en" ? en || my : my || en
        return (
          <option key={String(item.id)} value={String(item.id)}>
            {text}
          </option>
        )
      })}
      {(!data || data.length === 0) && <option value="">{t("common.none")}</option>}
    </select>
  )
}
