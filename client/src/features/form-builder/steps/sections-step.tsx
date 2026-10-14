"use client"

import { ChevronDown, ChevronUp, Layers, Plus, Trash2, Type, AlignLeft } from "lucide-react"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Badge } from "@/components/ui/badge"
import { useI18n } from "@/lib/i18n"
import { cn } from "@/lib/utils"
import { emptySection, type FieldDraft, type SectionDraft } from "../types"

interface Props {
  sections: SectionDraft[]
  fields: FieldDraft[]
  setSections: (next: SectionDraft[] | ((prev: SectionDraft[]) => SectionDraft[])) => void
}

function move<T>(items: T[], from: number, to: number): T[] {
  if (to < 0 || to >= items.length) return items
  const next = [...items]
  const [item] = next.splice(from, 1)
  next.splice(to, 0, item)
  return next
}

export function SectionsStep({ sections, fields, setSections }: Props) {
  const { t } = useI18n()

  const patch = (key: string, changes: Partial<SectionDraft>) =>
    setSections((prev) => prev.map((s) => (s.key === key ? { ...s, ...changes } : s)))

  const countFor = (key: string) => fields.filter((f) => f.sectionKey === key).length

  return (
    <div className="space-y-4">
      <div className="flex items-start gap-3 rounded-xl border border-primary/20 bg-primary/[0.04] px-4 py-3">
        <Layers className="mt-0.5 h-4 w-4 shrink-0 text-primary" aria-hidden="true" />
        <p className="text-[0.82rem] leading-relaxed text-muted-foreground">{t("fb.sections.helperTitle")}</p>
      </div>

      {sections.length === 0 ? (
        <div className="rounded-2xl border border-dashed border-border/70 px-6 py-12 text-center">
          <Layers className="mx-auto mb-3 h-8 w-8 text-muted-foreground/40" aria-hidden="true" />
          <p className="text-[0.88rem] text-muted-foreground">{t("fb.sections.empty")}</p>
        </div>
      ) : (
        <ul className="space-y-3">
          {sections.map((s, idx) => (
            <li
              key={s.key}
              className={cn(
                "rounded-2xl border border-border/70 bg-card p-4 shadow-sm transition-opacity",
                !s.is_enabled && "opacity-60",
              )}
            >
              <div className="flex items-start gap-3">
                <span className="mt-0.5 grid h-7 w-7 shrink-0 place-items-center rounded-lg bg-primary/10 text-[0.75rem] font-bold text-primary">
                  {idx + 1}
                </span>

                <div className="min-w-0 flex-1 space-y-3">
                  <div>
                    <Label htmlFor={`sec-my-${s.key}`} className="mb-1 flex items-center gap-1.5 text-[0.72rem] font-semibold uppercase tracking-wide text-muted-foreground">
                      <Type className="h-3 w-3" aria-hidden="true" /> {t("fb.sections.titleMy")}
                    </Label>
                    <Input
                      id={`sec-my-${s.key}`}
                      value={s.title_burmese}
                      onChange={(e) => patch(s.key, { title_burmese: e.target.value })}
                      placeholder="လူတွေ့မေးမြန်းခြင်းဆိုင်ရာ အချက်များ"
                      className="h-10 rounded-lg text-[0.9rem] font-medium"
                    />
                  </div>

                  <div>
                    <Label htmlFor={`sec-en-${s.key}`} className="mb-1 block text-[0.72rem] font-semibold uppercase tracking-wide text-muted-foreground">
                      {t("fb.sections.titleEn")}
                    </Label>
                    <Input
                      id={`sec-en-${s.key}`}
                      value={s.title_english}
                      onChange={(e) => patch(s.key, { title_english: e.target.value })}
                      placeholder="Interview and household information"
                      className="h-10 rounded-lg"
                    />
                  </div>

                  <details className="group">
                    <summary className="inline-flex cursor-pointer list-none items-center gap-1 text-[0.72rem] font-medium text-muted-foreground hover:text-foreground">
                      <AlignLeft className="h-3 w-3" aria-hidden="true" />
                      {t("common.description")}
                    </summary>
                    <div className="mt-2 grid gap-2 sm:grid-cols-2">
                      <Input
                        value={s.description_burmese}
                        onChange={(e) => patch(s.key, { description_burmese: e.target.value })}
                        placeholder={t("fb.sections.descMy")}
                        className="h-9 rounded-lg text-[0.8rem]"
                      />
                      <Input
                        value={s.description_english}
                        onChange={(e) => patch(s.key, { description_english: e.target.value })}
                        placeholder={t("fb.sections.descEn")}
                        className="h-9 rounded-lg text-[0.8rem]"
                      />
                    </div>
                  </details>
                </div>

                <div className="flex flex-col items-end gap-2">
                  <Badge variant="outline" className="rounded-full bg-muted text-[0.62rem] text-muted-foreground">
                    {t("fb.sections.fieldsCount", { count: countFor(s.key) })}
                  </Badge>
                  <div className="flex items-center gap-1">
                    <button
                      type="button"
                      onClick={() => setSections((prev) => move(prev, idx, idx - 1))}
                      disabled={idx === 0}
                      aria-label={t("fb.sections.moveUp")}
                      className="grid h-7 w-7 place-items-center rounded-md text-muted-foreground hover:bg-muted disabled:opacity-30"
                    >
                      <ChevronUp className="h-3.5 w-3.5" />
                    </button>
                    <button
                      type="button"
                      onClick={() => setSections((prev) => move(prev, idx, idx + 1))}
                      disabled={idx === sections.length - 1}
                      aria-label={t("fb.sections.moveDown")}
                      className="grid h-7 w-7 place-items-center rounded-md text-muted-foreground hover:bg-muted disabled:opacity-30"
                    >
                      <ChevronDown className="h-3.5 w-3.5" />
                    </button>
                    <button
                      type="button"
                      onClick={() => {
                        if (!window.confirm(t("fb.sections.deleteConfirm"))) return
                        setSections((prev) => prev.filter((x) => x.key !== s.key))
                      }}
                      aria-label={t("common.delete")}
                      className="grid h-7 w-7 place-items-center rounded-md text-muted-foreground transition-colors hover:bg-destructive/10 hover:text-[var(--destructive)]"
                    >
                      <Trash2 className="h-3.5 w-3.5" />
                    </button>
                  </div>
                </div>
              </div>

              <label className="mt-3 flex cursor-pointer items-center gap-2 text-[0.75rem] font-medium text-muted-foreground">
                <input
                  type="checkbox"
                  checked={s.is_enabled}
                  onChange={(e) => patch(s.key, { is_enabled: e.target.checked })}
                  className="h-3.5 w-3.5 accent-[#1b4d3e]"
                />
                {t("common.enabled")}
              </label>
            </li>
          ))}
        </ul>
      )}

      <Button
        variant="outline"
        className="h-10 w-full gap-2 rounded-xl border-dashed"
        onClick={() => setSections((prev) => [...prev, emptySection()])}
      >
        <Plus className="h-4 w-4" /> {t("fb.sections.add")}
      </Button>
    </div>
  )
}
