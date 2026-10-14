"use client"

/**
 * Collector-style form preview used inside the Form Builder.
 *
 * It renders the *same* field definitions the real data-entry screen and the
 * mobile app consume, and resolves answer options from the same Master Data
 * endpoints at runtime — so what an admin sees here is what an enumerator will
 * see. Nothing entered here is ever submitted; every control is disabled.
 */
import { useMemo } from "react"
import { useQueries } from "@tanstack/react-query"
import { api } from "@/lib/api"
import { cn } from "@/lib/utils"
import { useI18n, type Lang } from "@/lib/i18n"
import { Badge } from "@/components/ui/badge"
import { Info, Table2, MapPin, AlertCircle } from "lucide-react"
import {
  ALL_BINDINGS,
  BINDING_MAP,
  fieldTypeMeta,
  itemLabel,
  type MasterItem,
} from "./field-types"
import type { FieldDraft, SectionDraft } from "./types"

export type PreviewLang = Lang | "both"

interface PreviewProps {
  sections: SectionDraft[]
  fields: FieldDraft[]
  previewLang: PreviewLang
}

/** Query the master-data lists referenced by the current draft. */
function useBindingOptions(fields: FieldDraft[]) {
  const resources = useMemo(() => {
    const set = new Set<string>()
    for (const f of fields) {
      if (!f.data_binding) continue
      const meta = BINDING_MAP[f.data_binding] ?? ALL_BINDINGS.find((b) => b.binding === f.data_binding)
      if (meta) set.add(meta.resource)
    }
    return [...set].sort()
  }, [fields])

  const results = useQueries({
    queries: resources.map((resource) => ({
      queryKey: ["master", resource],
      queryFn: () => api.get<MasterItem[]>(`/api/v1/master/${resource}`),
      staleTime: 1000 * 60 * 5,
    })),
  })

  return useMemo(() => {
    const map: Record<string, MasterItem[]> = {}
    resources.forEach((resource, i) => {
      map[resource] = (results[i]?.data as MasterItem[] | undefined) ?? []
    })
    return map
  }, [resources, results])
}

function TwoLine({
  primary,
  secondary,
  className,
}: {
  primary: string
  secondary?: string
  className?: string
}) {
  return (
    <span className={cn("block leading-snug", className)}>
      <span>{primary}</span>
      {secondary ? (
        <span className="mt-0.5 block text-[0.72rem] font-normal text-muted-foreground">{secondary}</span>
      ) : null}
    </span>
  )
}

function FieldLabel({
  field,
  previewLang,
  required,
}: {
  field: FieldDraft
  previewLang: PreviewLang
  required: boolean
}) {
  const my = field.title_burmese || field.name
  const en = field.title_english
  const label =
    previewLang === "en" ? (
      <TwoLine primary={en || my} />
    ) : previewLang === "my" ? (
      <TwoLine primary={my} secondary={en || undefined} />
    ) : (
      <TwoLine primary={my} secondary={en || undefined} />
    )
  return (
    <span className="text-[0.82rem] font-semibold text-foreground">
      {label}
      {required && <span className="ml-1 text-[var(--destructive)]">*</span>}
    </span>
  )
}

function PreviewField({
  field,
  previewLang,
  options,
}: {
  field: FieldDraft
  previewLang: PreviewLang
  options: Record<string, MasterItem[]>
}) {
  const { t, lang } = useI18n()
  const meta = fieldTypeMeta(field.field_type)
  const binding = field.data_binding ? BINDING_MAP[field.data_binding] ?? ALL_BINDINGS.find((b) => b.binding === field.data_binding) : undefined
  const list = binding ? options[binding.resource] ?? [] : []

  const inputBase =
    "w-full rounded-lg border border-input bg-muted/40 px-3 py-2 text-[0.82rem] text-muted-foreground"

  if (field.field_type === "heading") {
    return (
      <div className="pt-1">
        <p className="text-[0.95rem] font-bold text-foreground">
          {(previewLang !== "en" ? field.title_burmese : "") || field.title_english || field.name}
        </p>
        {previewLang === "both" && field.title_english ? (
          <p className="text-[0.78rem] font-medium text-muted-foreground">{field.title_english}</p>
        ) : null}
      </div>
    )
  }

  if (field.field_type === "paragraph") {
    return (
      <p className="text-[0.82rem] leading-relaxed text-muted-foreground">
        {(previewLang !== "en" ? field.title_burmese : "") || field.title_english}
      </p>
    )
  }

  return (
    <div className="space-y-1.5">
      <FieldLabel field={field} previewLang={previewLang} required={field.is_required} />

      {field.field_type === "boolean" ? (
        <div className="flex gap-4 pt-0.5 text-[0.82rem] text-muted-foreground">
          <label className="flex items-center gap-2">
            <input type="radio" disabled className="accent-[#1b4d3e]" /> {t("common.yes")}
          </label>
          <label className="flex items-center gap-2">
            <input type="radio" disabled className="accent-[#1b4d3e]" /> {t("common.no")}
          </label>
        </div>
      ) : field.field_type === "geographic" ? (
        <div className={cn(inputBase, "flex items-center gap-2")}>
          <MapPin className="h-3.5 w-3.5 shrink-0" aria-hidden="true" />
          <span>{binding ? t(binding.labelKey) : t("fieldType.geographic")}</span>
          <span className="ml-auto text-[0.68rem] text-muted-foreground/70">
            {list.length > 0 ? t("fb.opt.optionsCount", { count: list.length }) : t("fb.opt.noList")}
          </span>
        </div>
      ) : field.field_type === "repeating_group" ? (
        <div className="rounded-lg border border-dashed border-border/70 bg-muted/20 p-3">
          <div className="flex items-center gap-2 text-[0.8rem] font-medium text-muted-foreground">
            <Table2 className="h-3.5 w-3.5" aria-hidden="true" />
            {t("fieldType.repeating_group")}
          </div>
          <p className="mt-1 text-[0.72rem] text-muted-foreground/80">{t("fb.q.repeatingHint")}</p>
          <div className="mt-2 grid grid-cols-4 gap-2">
            {[0, 1, 2, 3].map((i) => (
              <div key={i} className="h-6 rounded bg-border/40" />
            ))}
          </div>
        </div>
      ) : meta.needsOptions ? (
        binding && list.length > 0 ? (
          field.field_type === "multi_select" || field.field_type === "checkbox" ? (
            <div className="flex flex-wrap gap-x-4 gap-y-1.5 pt-0.5">
              {list.slice(0, 6).map((item) => (
                <label key={item.id} className="flex items-center gap-2 text-[0.8rem] text-muted-foreground">
                  <input type="checkbox" disabled className="accent-[#1b4d3e]" />
                  {itemLabel(item, lang)}
                </label>
              ))}
              {list.length > 6 ? <span className="text-[0.72rem] text-muted-foreground/70">+{list.length - 6}</span> : null}
            </div>
          ) : (
            <div className={cn(inputBase, "flex items-center justify-between")}>
              <span>{itemLabel(list[0], lang)}…</span>
              <span className="text-[0.68rem] text-muted-foreground/70">
                {t("fb.opt.optionsCount", { count: list.length })}
              </span>
            </div>
          )
        ) : (
          <div className="flex items-center gap-2 rounded-lg border border-dashed border-[var(--warning)]/50 bg-[var(--warning)]/5 px-3 py-2 text-[0.76rem] text-[var(--warning)]">
            <AlertCircle className="h-3.5 w-3.5" aria-hidden="true" />
            {t("fb.q.noOptions")}
          </div>
        )
      ) : field.field_type === "number_counter" ? (
        <div className="inline-flex items-center gap-3 rounded-lg border border-input bg-muted/40 px-3 py-1.5 text-[0.82rem] text-muted-foreground">
          − <span className="font-semibold">0</span> +
        </div>
      ) : field.field_type === "long_text" ? (
        <div className={cn(inputBase, "h-16")} />
      ) : (
        <div className={cn(inputBase)}>
          {field.field_type === "date"
            ? "yyyy-mm-dd"
            : field.field_type === "time"
              ? "--:--"
              : field.field_type === "email"
                ? "name@example.com"
                : field.unit || "\u00a0"}
        </div>
      )}

      {(field.help_burmese || field.help_english) && (
        <p className="text-[0.72rem] text-muted-foreground/80">
          <Info className="mr-1 inline h-3 w-3" aria-hidden="true" />
          {previewLang === "en" ? field.help_english || field.help_burmese : field.help_burmese || field.help_english}
        </p>
      )}
    </div>
  )
}

export function CollectorPreview({ sections, fields, previewLang }: PreviewProps) {
  const { t, lang } = useI18n()
  const options = useBindingOptions(fields)

  const orderedSections = useMemo(
    () => sections.filter((s) => s.is_enabled),
    [sections],
  )

  const unassigned = fields.filter((f) => f.is_enabled && (f.sectionKey == null || !sections.some((s) => s.key === f.sectionKey)))

  return (
    <div className="space-y-5">
      <div className="flex items-center gap-2 rounded-lg border border-[var(--warning)]/40 bg-[var(--warning)]/5 px-3 py-2 text-[0.76rem] font-medium text-[var(--warning)]">
        <Info className="h-3.5 w-3.5" aria-hidden="true" />
        {t("fb.prev.submitDisabled")}
      </div>

      {orderedSections.map((section, idx) => {
        const sectionFields = fields.filter((f) => f.is_enabled && f.sectionKey === section.key)
        if (sectionFields.length === 0) return null
        return (
          <section key={section.key} className="rounded-xl border border-border/70 bg-card p-4 shadow-sm">
            <div className="mb-3 flex items-start gap-2 border-b border-border/60 pb-2">
              <Badge variant="outline" className="mt-0.5 shrink-0 rounded-full bg-primary/10 text-[0.62rem] font-bold text-primary">
                {idx + 1}
              </Badge>
              <div className="min-w-0">
                <h3 className="text-[0.9rem] font-bold text-foreground">
                  {previewLang === "en"
                    ? section.title_english || section.title_burmese
                    : section.title_burmese || section.title_english}
                </h3>
                {previewLang === "both" && section.title_english ? (
                  <p className="text-[0.74rem] text-muted-foreground">{section.title_english}</p>
                ) : null}
                {(section.description_burmese || section.description_english) && (
                  <p className="mt-0.5 text-[0.74rem] text-muted-foreground">
                    {lang === "en"
                      ? section.description_english || section.description_burmese
                      : section.description_burmese || section.description_english}
                  </p>
                )}
              </div>
            </div>
            <div className="space-y-4">
              {sectionFields.map((f) => (
                <PreviewField key={f.key} field={f} previewLang={previewLang} options={options} />
              ))}
            </div>
          </section>
        )
      })}

      {unassigned.length > 0 && (
        <section className="rounded-xl border border-dashed border-border/70 bg-muted/10 p-4">
          <h3 className="mb-3 text-[0.85rem] font-bold text-muted-foreground">{t("common.unassigned")}</h3>
          <div className="space-y-4">
            {unassigned.map((f) => (
              <PreviewField key={f.key} field={f} previewLang={previewLang} options={options} />
            ))}
          </div>
        </section>
      )}
    </div>
  )
}
