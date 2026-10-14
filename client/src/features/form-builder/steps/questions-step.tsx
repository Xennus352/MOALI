"use client"

import { useMemo, useState } from "react"
import {
  ChevronDown,
  ChevronUp,
  CircleHelp,
  ListChecks,
  Lock,
  Plus,
  Search,
  Table2,
  Trash2,
} from "lucide-react"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Badge } from "@/components/ui/badge"
import { useI18n } from "@/lib/i18n"
import { cn } from "@/lib/utils"
import {
  FIELD_TYPES,
  GEO_BINDINGS,
  fieldTypeMeta,
} from "../field-types"
import { emptyField, slugifyName, type FieldDraft, type SectionDraft } from "../types"

interface Props {
  sections: SectionDraft[]
  fields: FieldDraft[]
  setFields: (next: FieldDraft[] | ((prev: FieldDraft[]) => FieldDraft[])) => void
}

const selectClass =
  "h-10 w-full rounded-lg border border-input bg-card px-3 text-[0.85rem] text-foreground focus:border-primary/50 focus:outline-none focus:ring-4 focus:ring-primary/10"

export function QuestionsStep({ sections, fields, setFields }: Props) {
  const { t } = useI18n()
  const [query, setQuery] = useState("")
  const [sectionFilter, setSectionFilter] = useState<string>("all")
  const [selectedKey, setSelectedKey] = useState<string | null>(fields[0]?.key ?? null)

  const selected = fields.find((f) => f.key === selectedKey) ?? null

  const filtered = useMemo(() => {
    const q = query.trim().toLowerCase()
    return fields.filter((f) => {
      if (sectionFilter !== "all" && f.sectionKey !== sectionFilter) return false
      if (!q) return true
      return (
        f.title_burmese.toLowerCase().includes(q) ||
        f.title_english.toLowerCase().includes(q) ||
        f.name.toLowerCase().includes(q)
      )
    })
  }, [fields, query, sectionFilter])

  const sectionName = (key: string | null) =>
    sections.find((s) => s.key === key)?.title_burmese || t("common.unassigned")

  const patch = (key: string, changes: Partial<FieldDraft>) =>
    setFields((prev) => prev.map((f) => (f.key === key ? { ...f, ...changes } : f)))

  const duplicateNames = useMemo(() => {
    const counts = new Map<string, number>()
    for (const f of fields) counts.set(f.name.trim(), (counts.get(f.name.trim()) ?? 0) + 1)
    return new Set([...counts.entries()].filter(([, n]) => n > 1).map(([name]) => name))
  }, [fields])

  const addQuestion = () => {
    const sectionKey = sectionFilter !== "all" ? sectionFilter : sections[0]?.key ?? null
    const f = emptyField(sectionKey)
    setFields((prev) => [...prev, f])
    setSelectedKey(f.key)
  }

  const move = (from: number, to: number) => {
    if (to < 0 || to >= fields.length) return
    setFields((prev) => {
      const next = [...prev]
      const [item] = next.splice(from, 1)
      next.splice(to, 0, item)
      return next
    })
  }

  return (
    <div className="grid gap-4 lg:grid-cols-[minmax(0,22rem)_minmax(0,1fr)]">
      {/* List panel */}
      <div className="flex min-h-0 flex-col rounded-2xl border border-border/70 bg-card">
        <div className="space-y-3 border-b border-border/60 p-3">
          <div className="relative">
            <Search className="absolute left-3 top-1/2 h-3.5 w-3.5 -translate-y-1/2 text-muted-foreground" aria-hidden="true" />
            <Input
              value={query}
              onChange={(e) => setQuery(e.target.value)}
              placeholder={t("fb.q.searchPlaceholder")}
              className="h-9 rounded-lg pl-9 text-[0.82rem]"
            />
          </div>
          <select
            value={sectionFilter}
            onChange={(e) => setSectionFilter(e.target.value)}
            aria-label={t("fb.q.filterType")}
            className="h-9 w-full rounded-lg border border-input bg-card px-2 text-[0.8rem]"
          >
            <option value="all">{t("fb.q.allSections")}</option>
            {sections.map((s) => (
              <option key={s.key} value={s.key}>
                {s.title_burmese || t("common.unnamed")}
              </option>
            ))}
          </select>
          <Button className="h-9 w-full gap-1.5 rounded-lg" onClick={addQuestion}>
            <Plus className="h-4 w-4" /> {t("fb.q.add")}
          </Button>
        </div>

        <ul className="max-h-[60vh] space-y-1 overflow-y-auto p-2">
          {filtered.map((f) => {
            const globalIdx = fields.findIndex((x) => x.key === f.key)
            const active = f.key === selectedKey
            return (
              <li key={f.key}>
                <div
                  className={cn(
                    "flex items-center gap-2 rounded-xl border border-transparent px-2.5 py-2 text-left transition-colors",
                    active ? "border-primary/30 bg-primary/[0.07]" : "hover:bg-muted/60",
                  )}
                >
                  <button
                    type="button"
                    onClick={() => setSelectedKey(f.key)}
                    className="min-w-0 flex-1 text-left"
                  >
                    <div className="flex items-center gap-1.5">
                      <span className="truncate text-[0.82rem] font-medium text-foreground">
                        {f.title_burmese || f.title_english || t("common.unnamed")}
                      </span>
                      {f.is_required && <span className="text-[var(--destructive)]">*</span>}
                      {!f.is_enabled && <Badge variant="outline" className="rounded-full text-[0.55rem]">{t("common.disabled")}</Badge>}
                    </div>
                    <div className="mt-0.5 flex items-center gap-1.5 truncate text-[0.68rem] text-muted-foreground">
                      <span className="truncate">{f.name || "—"}</span>
                      <span aria-hidden="true">·</span>
                      <span className="truncate">{sectionName(f.sectionKey)}</span>
                    </div>
                  </button>
                  <div className="flex shrink-0 flex-col">
                    <button
                      type="button"
                      onClick={() => move(globalIdx, globalIdx - 1)}
                      disabled={globalIdx <= 0}
                      aria-label={t("fb.sections.moveUp")}
                      className="grid h-5 w-5 place-items-center rounded text-muted-foreground hover:bg-muted disabled:opacity-30"
                    >
                      <ChevronUp className="h-3 w-3" />
                    </button>
                    <button
                      type="button"
                      onClick={() => move(globalIdx, globalIdx + 1)}
                      disabled={globalIdx >= fields.length - 1}
                      aria-label={t("fb.sections.moveDown")}
                      className="grid h-5 w-5 place-items-center rounded text-muted-foreground hover:bg-muted disabled:opacity-30"
                    >
                      <ChevronDown className="h-3 w-3" />
                    </button>
                  </div>
                </div>
              </li>
            )
          })}
          {filtered.length === 0 && (
            <li className="px-3 py-8 text-center text-[0.82rem] text-muted-foreground">
              {fields.length === 0 ? t("fb.q.empty") : t("fb.q.emptySection")}
            </li>
          )}
        </ul>
      </div>

      {/* Editor panel */}
      <div className="rounded-2xl border border-border/70 bg-card p-4 sm:p-5">
        {!selected ? (
          <div className="flex h-full min-h-[16rem] flex-col items-center justify-center gap-2 text-center">
            <ListChecks className="h-8 w-8 text-muted-foreground/40" aria-hidden="true" />
            <p className="text-[0.85rem] text-muted-foreground">{t("fb.q.selectHint")}</p>
          </div>
        ) : (
          <QuestionEditor
            key={selected.key}
            field={selected}
            sections={sections}
            patch={patch}
            duplicate={duplicateNames.has(selected.name.trim())}
            onDelete={() => {
              setFields((prev) => prev.filter((f) => f.key !== selected.key))
              setSelectedKey(null)
            }}
          />
        )}
      </div>
    </div>
  )
}

function QuestionEditor({
  field,
  sections,
  patch,
  duplicate,
  onDelete,
}: {
  field: FieldDraft
  sections: SectionDraft[]
  patch: (key: string, changes: Partial<FieldDraft>) => void
  duplicate: boolean
  onDelete: () => void
}) {
  const { t } = useI18n()
  const meta = fieldTypeMeta(field.field_type)

  return (
    <div className="space-y-5">
      <div className="flex items-start justify-between gap-3">
        <div className="min-w-0">
          <h3 className="text-[0.95rem] font-bold text-foreground">{t("fb.q.edit")}</h3>
          <p className="mt-0.5 text-[0.72rem] text-muted-foreground">{t("fb.q.changesUnsaved")}</p>
        </div>
        <button
          type="button"
          onClick={onDelete}
          aria-label={t("common.delete")}
          className="grid h-8 w-8 shrink-0 place-items-center rounded-lg text-muted-foreground transition-colors hover:bg-destructive/10 hover:text-[var(--destructive)]"
        >
          <Trash2 className="h-4 w-4" />
        </button>
      </div>

      <div className="grid gap-4 sm:grid-cols-2">
        <div>
          <Label className="mb-1 block text-[0.75rem] font-semibold">{t("fb.q.labelMy")}</Label>
          <Input
            value={field.title_burmese}
            onChange={(e) => {
              const title = e.target.value
              const changes: Partial<FieldDraft> = { title_burmese: title }
              // New questions auto-derive an internal name until one is set.
              if (!field.nameLocked && !field.name) changes.name = slugifyName(field.title_english || title)
              patch(field.key, changes)
            }}
            placeholder="မေးခွန်း…"
            className="h-10 rounded-lg font-medium"
          />
        </div>
        <div>
          <Label className="mb-1 block text-[0.75rem] font-semibold">{t("fb.q.labelEn")}</Label>
          <Input
            value={field.title_english}
            onChange={(e) => patch(field.key, { title_english: e.target.value })}
            placeholder="Question in English"
            className="h-10 rounded-lg"
          />
        </div>
      </div>

      <div className="grid gap-4 sm:grid-cols-2">
        <div>
          <Label className="mb-1 block text-[0.75rem] font-semibold">{t("fb.q.type")}</Label>
          <select
            value={field.field_type}
            onChange={(e) => patch(field.key, { field_type: e.target.value })}
            className={selectClass}
          >
            {FIELD_TYPES.map((ft) => (
              <option key={ft.value} value={ft.value}>
                {t(ft.labelKey)}
              </option>
            ))}
          </select>
        </div>
        <div>
          <Label className="mb-1 block text-[0.75rem] font-semibold">{t("fb.q.section")}</Label>
          <select
            value={field.sectionKey ?? ""}
            onChange={(e) => patch(field.key, { sectionKey: e.target.value || null })}
            className={selectClass}
          >
            <option value="">{t("common.unassigned")}</option>
            {sections.map((s) => (
              <option key={s.key} value={s.key}>
                {s.title_burmese || t("common.unnamed")}
              </option>
            ))}
          </select>
        </div>
      </div>

      {/* Type-specific configuration */}
      {field.field_type === "geographic" && (
        <div className="rounded-xl border border-border/60 bg-muted/20 p-3">
          <Label className="mb-1.5 block text-[0.75rem] font-semibold">{t("fb.q.dataBinding")}</Label>
          <select
            value={field.data_binding}
            onChange={(e) => patch(field.key, { option_source: "master", data_binding: e.target.value })}
            className={selectClass}
          >
            <option value="">{t("fb.q.chooseList")}</option>
            {GEO_BINDINGS.map((b) => (
              <option key={b.binding} value={b.binding}>
                {t(b.labelKey)}
              </option>
            ))}
          </select>
          <p className="mt-2 flex items-start gap-1.5 text-[0.72rem] text-muted-foreground">
            <CircleHelp className="mt-0.5 h-3 w-3 shrink-0" aria-hidden="true" />
            {t("fb.q.geographicHint")}
          </p>
        </div>
      )}

      {field.field_type === "repeating_group" && (
        <div className="flex items-start gap-2 rounded-xl border border-border/60 bg-muted/20 p-3 text-[0.76rem] text-muted-foreground">
          <Table2 className="mt-0.5 h-3.5 w-3.5 shrink-0" aria-hidden="true" />
          {t("fb.q.repeatingHint")}
        </div>
      )}

      {meta.needsOptions && (
        <div className="flex items-start gap-2 rounded-xl border border-primary/20 bg-primary/[0.04] p-3 text-[0.76rem] text-muted-foreground">
          <CircleHelp className="mt-0.5 h-3.5 w-3.5 shrink-0 text-primary" aria-hidden="true" />
          {field.data_binding ? t("fb.opt.chosen") + " " + field.data_binding : t("fb.q.noOptions")}
        </div>
      )}

      {meta.kind === "number" && (
        <div className="grid gap-4 sm:grid-cols-3">
          <div>
            <Label className="mb-1 block text-[0.75rem] font-semibold">{t("fb.q.unit")}</Label>
            <Input
              value={field.unit}
              onChange={(e) => patch(field.key, { unit: e.target.value })}
              placeholder="kg"
              className="h-9 rounded-lg"
            />
          </div>
          <div>
            <Label className="mb-1 block text-[0.75rem] font-semibold">{t("fb.q.minValue")}</Label>
            <Input
              type="number"
              value={field.min_value ?? ""}
              onChange={(e) => patch(field.key, { min_value: e.target.value === "" ? null : Number(e.target.value) })}
              className="h-9 rounded-lg"
            />
          </div>
          <div>
            <Label className="mb-1 block text-[0.75rem] font-semibold">{t("fb.q.maxValue")}</Label>
            <Input
              type="number"
              value={field.max_value ?? ""}
              onChange={(e) => patch(field.key, { max_value: e.target.value === "" ? null : Number(e.target.value) })}
              className="h-9 rounded-lg"
            />
          </div>
        </div>
      )}

      <details className="group">
        <summary className="inline-flex cursor-pointer list-none items-center gap-1.5 text-[0.75rem] font-medium text-muted-foreground hover:text-foreground">
          <CircleHelp className="h-3.5 w-3.5" aria-hidden="true" />
          {t("common.advanced")}
        </summary>
        <div className="mt-3 space-y-4">
          <div className="grid gap-4 sm:grid-cols-2">
            <div>
              <Label className="mb-1 block text-[0.75rem] font-semibold">{t("fb.q.helpMy")}</Label>
              <Input
                value={field.help_burmese}
                onChange={(e) => patch(field.key, { help_burmese: e.target.value })}
                className="h-9 rounded-lg"
              />
            </div>
            <div>
              <Label className="mb-1 block text-[0.75rem] font-semibold">{t("fb.q.helpEn")}</Label>
              <Input
                value={field.help_english}
                onChange={(e) => patch(field.key, { help_english: e.target.value })}
                className="h-9 rounded-lg"
              />
            </div>
          </div>
          <div>
            <Label className="mb-1 flex items-center gap-1.5 text-[0.75rem] font-semibold">
              {field.nameLocked && <Lock className="h-3 w-3 text-muted-foreground" aria-hidden="true" />}
              {t("fb.q.nameLabel")}
            </Label>
            <Input
              value={field.name}
              readOnly={field.nameLocked}
              disabled={field.nameLocked}
              onChange={(e) => patch(field.key, { name: e.target.value })}
              placeholder="household_no"
              className={cn("h-9 rounded-lg font-mono text-[0.8rem]", field.nameLocked && "bg-muted/50")}
            />
            <p className="mt-1 text-[0.68rem] text-muted-foreground">
              {field.nameLocked ? t("fb.q.typeReadonlyHint") : t("fb.q.nameHint")}
            </p>
          </div>
          <div>
            <Label className="mb-1 block text-[0.75rem] font-semibold">{t("fb.q.defaultValue")}</Label>
            <Input
              value={field.default_value}
              onChange={(e) => patch(field.key, { default_value: e.target.value })}
              className="h-9 rounded-lg"
            />
          </div>
        </div>
      </details>

      <div className="flex flex-wrap items-center gap-5 border-t border-border/60 pt-4">
        <label className="flex cursor-pointer items-center gap-2 text-[0.8rem] font-medium text-muted-foreground">
          <input
            type="checkbox"
            checked={field.is_required}
            onChange={(e) => patch(field.key, { is_required: e.target.checked })}
            className="h-4 w-4 accent-[#1b4d3e]"
          />
          {t("fb.q.required")}
        </label>
        <label className="flex cursor-pointer items-center gap-2 text-[0.8rem] font-medium text-muted-foreground">
          <input
            type="checkbox"
            checked={field.is_enabled}
            onChange={(e) => patch(field.key, { is_enabled: e.target.checked })}
            className="h-4 w-4 accent-[#1b4d3e]"
          />
          {t("common.enabled")}
        </label>
        {duplicate && (
          <span className="text-[0.75rem] font-medium text-[var(--destructive)]">
            {t("fb.q.duplicateName", { name: field.name })}
          </span>
        )}
      </div>
    </div>
  )
}
