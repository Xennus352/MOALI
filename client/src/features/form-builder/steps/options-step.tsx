"use client"

import { useMemo } from "react"
import { Link, useLocation } from "react-router-dom"
import { useQueries } from "@tanstack/react-query"
import { CircleHelp, ExternalLink, ListTree, MapPin, Table2 } from "lucide-react"
import { api } from "@/lib/api"
import { useI18n } from "@/lib/i18n"
import { cn } from "@/lib/utils"
import { Badge } from "@/components/ui/badge"
import {
  GEO_BINDINGS,
  OPTION_BINDINGS,
  fieldTypeMeta,
  itemLabel,
  type MasterItem,
} from "../field-types"
import type { FieldDraft, SectionDraft } from "../types"

interface Props {
  sections: SectionDraft[]
  fields: FieldDraft[]
  setFields: (next: FieldDraft[] | ((prev: FieldDraft[]) => FieldDraft[])) => void
  formId: string
  stepIndex: number
}

const selectClass =
  "h-9 w-auto min-w-[12rem] max-w-full rounded-lg border border-input bg-card px-2.5 text-[0.82rem] text-foreground focus:border-primary/50 focus:outline-none focus:ring-4 focus:ring-primary/10"

export function OptionsStep({ sections, fields, setFields, formId, stepIndex }: Props) {
  const { t, lang } = useI18n()
  const location = useLocation()

  // Fetch every option list once so we can show real counts and examples.
  const results = useQueries({
    queries: OPTION_BINDINGS.map((b) => ({
      queryKey: ["master", b.resource],
      queryFn: () => api.get<MasterItem[]>(`/api/v1/master/${b.resource}`),
      staleTime: 1000 * 60 * 5,
    })),
  })
  const itemsByResource = useMemo(() => {
    const map: Record<string, MasterItem[]> = {}
    OPTION_BINDINGS.forEach((b, i) => {
      map[b.resource] = (results[i]?.data as MasterItem[] | undefined) ?? []
    })
    return map
  }, [results])

  const choiceFields = fields.filter((f) => fieldTypeMeta(f.field_type).needsOptions)
  const geoFields = fields.filter((f) => f.field_type === "geographic")
  const repeatingFields = fields.filter((f) => f.field_type === "repeating_group")

  const patch = (key: string, changes: Partial<FieldDraft>) =>
    setFields((prev) => prev.map((f) => (f.key === key ? { ...f, ...changes } : f)))

  const sectionName = (key: string | null) =>
    sections.find((s) => s.key === key)?.title_burmese || t("common.unassigned")

  const manageHref = (resource: string) => {
    const ret = `${location.pathname}?form=${encodeURIComponent(formId)}&step=${stepIndex}`
    return `/database?resource=${resource}&return=${encodeURIComponent(ret)}`
  }

  return (
    <div className="space-y-5">
      <div className="flex items-start gap-3 rounded-xl border border-primary/20 bg-primary/[0.04] px-4 py-3">
        <ListTree className="mt-0.5 h-4 w-4 shrink-0 text-primary" aria-hidden="true" />
        <div>
          <p className="text-[0.85rem] font-semibold text-foreground">{t("fb.opt.whereFrom")}</p>
          <p className="mt-0.5 text-[0.8rem] leading-relaxed text-muted-foreground">{t("fb.opt.whereFromBody")}</p>
        </div>
      </div>

      {choiceFields.length === 0 ? (
        <div className="rounded-2xl border border-dashed border-border/70 px-6 py-12 text-center">
          <ListTree className="mx-auto mb-3 h-8 w-8 text-muted-foreground/40" aria-hidden="true" />
          <p className="text-[0.88rem] text-muted-foreground">{t("fb.opt.noneNeeding")}</p>
        </div>
      ) : (
        <ul className="space-y-3">
          {choiceFields.map((f) => {
            const activeBinding = OPTION_BINDINGS.find((b) => b.binding === f.data_binding)
            const items = activeBinding ? itemsByResource[activeBinding.resource] ?? [] : []
            return (
              <li key={f.key} className="rounded-2xl border border-border/70 bg-card p-4">
                <div className="flex flex-wrap items-start justify-between gap-3">
                  <div className="min-w-0">
                    <p className="truncate text-[0.88rem] font-semibold text-foreground">
                      {f.title_burmese || f.title_english || t("common.unnamed")}
                    </p>
                    <div className="mt-0.5 flex items-center gap-2 text-[0.7rem] text-muted-foreground">
                      <Badge variant="outline" className="rounded-full text-[0.58rem]">
                        {t(fieldTypeMeta(f.field_type).labelKey)}
                      </Badge>
                      <span className="truncate">{sectionName(f.sectionKey)}</span>
                    </div>
                  </div>

                  <div className="flex flex-wrap items-center gap-2">
                    <label className="text-[0.72rem] font-medium text-muted-foreground" htmlFor={`opt-${f.key}`}>
                      {t("fb.opt.sourceLabel")}
                    </label>
                    <select
                      id={`opt-${f.key}`}
                      value={f.data_binding}
                      onChange={(e) =>
                        patch(f.key, {
                          option_source: e.target.value ? "master" : "static",
                          data_binding: e.target.value,
                        })
                      }
                      className={selectClass}
                    >
                      <option value="">{t("fb.opt.notChosen")}</option>
                      {OPTION_BINDINGS.map((b) => (
                        <option key={b.binding} value={b.binding}>
                          {t(b.labelKey)}
                        </option>
                      ))}
                    </select>
                    {activeBinding && (
                      <Link
                        to={manageHref(activeBinding.resource)}
                        className="inline-flex items-center gap-1 rounded-lg border border-border px-2.5 py-1.5 text-[0.72rem] font-semibold text-primary hover:bg-primary/5"
                      >
                        <ExternalLink className="h-3 w-3" aria-hidden="true" />
                        {t("fb.opt.manageFor")}
                      </Link>
                    )}
                  </div>
                </div>

                {activeBinding ? (
                  items.length > 0 ? (
                    <div className="mt-3">
                      <p className="text-[0.72rem] font-medium text-muted-foreground">
                        {t("fb.opt.optionsCount", { count: items.length })}
                      </p>
                      <div className="mt-1.5 flex flex-wrap gap-1.5">
                        {items.slice(0, 6).map((item) => (
                          <span
                            key={item.id}
                            className="rounded-full bg-muted px-2.5 py-0.5 text-[0.7rem] text-muted-foreground"
                          >
                            {itemLabel(item, lang)}
                          </span>
                        ))}
                        {items.length > 6 && (
                          <span className="rounded-full bg-muted px-2.5 py-0.5 text-[0.7rem] text-muted-foreground">
                            +{items.length - 6}
                          </span>
                        )}
                      </div>
                    </div>
                  ) : (
                    <p className="mt-3 text-[0.75rem] text-[var(--warning)]">{t("fb.opt.noList")}</p>
                  )
                ) : (
                  <p className={cn("mt-3 text-[0.75rem] text-muted-foreground")}>{t("fb.q.noOptions")}</p>
                )}
              </li>
            )
          })}
        </ul>
      )}

      {geoFields.length > 0 && (
        <div className="flex items-start gap-2 rounded-xl border border-border/60 bg-muted/20 p-3 text-[0.78rem] text-muted-foreground">
          <MapPin className="mt-0.5 h-4 w-4 shrink-0 text-primary" aria-hidden="true" />
          <div>
            <p>{t("fb.opt.geographicNote")}</p>
            <div className="mt-1.5 flex flex-wrap gap-1.5">
              {GEO_BINDINGS.map((b) => (
                <Link
                  key={b.binding}
                  to={manageHref(b.resource)}
                  className="inline-flex items-center gap-1 rounded-full bg-card px-2.5 py-1 text-[0.68rem] text-primary ring-1 ring-border hover:bg-primary/5"
                >
                  {t(b.labelKey)}
                  <ExternalLink className="h-2.5 w-2.5" aria-hidden="true" />
                </Link>
              ))}
            </div>
          </div>
        </div>
      )}

      {repeatingFields.length > 0 && (
        <div className="flex items-start gap-2 rounded-xl border border-border/60 bg-muted/20 p-3 text-[0.78rem] text-muted-foreground">
          <Table2 className="mt-0.5 h-4 w-4 shrink-0 text-primary" aria-hidden="true" />
          {t("fb.opt.repeatingNote")}
        </div>
      )}

      <div className="flex items-start gap-2 text-[0.72rem] text-muted-foreground/80">
        <CircleHelp className="mt-0.5 h-3.5 w-3.5 shrink-0" aria-hidden="true" />
        {t("fb.opt.reselectNote")}
      </div>
    </div>
  )
}
