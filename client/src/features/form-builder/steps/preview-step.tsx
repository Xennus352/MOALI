"use client"

import { useState } from "react"
import { Monitor } from "lucide-react"
import { LANG_LABEL, useI18n } from "@/lib/i18n"
import { cn } from "@/lib/utils"
import { CollectorPreview, type PreviewLang } from "../collector-preview"
import type { FieldDraft, SectionDraft } from "../types"

interface Props {
  sections: SectionDraft[]
  fields: FieldDraft[]
}

export function PreviewStep({ sections, fields }: Props) {
  const { t } = useI18n()
  const [previewLang, setPreviewLang] = useState<PreviewLang>("my")

  const options: { value: PreviewLang; label: string }[] = [
    { value: "my", label: LANG_LABEL.my },
    { value: "en", label: LANG_LABEL.en },
    { value: "both", label: t("fb.prev.both") },
  ]

  return (
    <div className="space-y-4">
      <div className="flex flex-wrap items-center justify-between gap-3 rounded-xl border border-border/70 bg-card px-4 py-3">
        <div className="flex items-center gap-2">
          <Monitor className="h-4 w-4 text-primary" aria-hidden="true" />
          <p className="text-[0.82rem] text-muted-foreground">{t("fb.prev.subtitle")}</p>
        </div>
        <div className="flex items-center gap-2">
          <span className="text-[0.72rem] font-medium text-muted-foreground">{t("fb.prev.language")}</span>
          <div className="inline-flex rounded-lg border border-border p-0.5" role="group" aria-label={t("fb.prev.language")}>
            {options.map((opt) => (
              <button
                key={opt.value}
                type="button"
                onClick={() => setPreviewLang(opt.value)}
                aria-pressed={previewLang === opt.value}
                className={cn(
                  "rounded-md px-3 py-1 text-[0.75rem] font-semibold transition-colors",
                  previewLang === opt.value
                    ? "bg-primary text-primary-foreground"
                    : "text-muted-foreground hover:text-foreground",
                )}
              >
                {opt.label}
              </button>
            ))}
          </div>
        </div>
      </div>

      {fields.length === 0 ? (
        <div className="rounded-2xl border border-dashed border-border/70 px-6 py-12 text-center text-[0.88rem] text-muted-foreground">
          {t("fb.prev.noFields")}
        </div>
      ) : (
        <div className="rounded-2xl border border-border/70 bg-muted/10 p-4 sm:p-5">
          <CollectorPreview sections={sections} fields={fields} previewLang={previewLang} />
        </div>
      )}
    </div>
  )
}
