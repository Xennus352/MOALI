"use client"

import { useMemo, useState } from "react"
import {
  AlertTriangle,
  CheckCircle2,
  Layers,
  ListChecks,
  ListTree,
  Lock,
  Send,
  ShieldCheck,
  Sparkles,
} from "lucide-react"
import { Button } from "@/components/ui/button"
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog"
import { useI18n } from "@/lib/i18n"
import { cn } from "@/lib/utils"
import { fieldTypeMeta } from "../field-types"
import type { ApiForm, FieldDraft, SectionDraft } from "../types"

interface Props {
  form: ApiForm
  sections: SectionDraft[]
  fields: FieldDraft[]
  publishing: boolean
  onPublish: () => void
  goToStep: (index: number) => void
}

export function PublishStep({ form, sections, fields, publishing, onPublish, goToStep }: Props) {
  const { t } = useI18n()
  const [confirmOpen, setConfirmOpen] = useState(false)

  const checks = useMemo(() => {
    const enabledSections = sections.filter((s) => s.is_enabled)
    const enabledFields = fields.filter((f) => f.is_enabled)
    const missingEn = enabledFields.filter((f) => !f.title_english.trim()).length
    const emptySections = enabledSections.filter((s) => !enabledFields.some((f) => f.sectionKey === s.key)).length
    const missingList = enabledFields.filter(
      (f) => fieldTypeMeta(f.field_type).needsOptions && !f.data_binding,
    ).length
    const missingLabel = fields.filter((f) => !f.title_burmese.trim()).length
    const names = fields.map((f) => f.name.trim())
    const duplicateNames = names.find((n, i) => names.indexOf(n) !== i) ?? null
    const sectionNoTitle = sections.filter((s) => !s.title_burmese.trim()).length

    const blockers: string[] = []
    if (missingLabel > 0) blockers.push(t("fb.pub.checkMissingLabel", { count: missingLabel }))
    if (duplicateNames) blockers.push(t("fb.q.duplicateName", { name: duplicateNames }))
    if (sectionNoTitle > 0) blockers.push(t("fb.sections.titleRequired"))

    const warnings: string[] = []
    if (missingEn > 0) warnings.push(t("fb.pub.checkMissingEn", { count: missingEn }))
    if (emptySections > 0) warnings.push(t("fb.pub.checkSectionEmpty", { count: emptySections }))
    if (missingList > 0) warnings.push(t("fb.pub.checkMissingList", { count: missingList }))

    return {
      enabledSections: enabledSections.length,
      enabledFields: enabledFields.length,
      requiredFields: enabledFields.filter((f) => f.is_required).length,
      listFields: enabledFields.filter((f) => f.option_source === "master").length,
      blockers,
      warnings,
    }
  }, [sections, fields, t])

  const summary = [
    { label: t("fb.pub.sections"), value: checks.enabledSections, icon: Layers, step: 1 },
    { label: t("fb.pub.enabledQuestions"), value: checks.enabledFields, icon: ListChecks, step: 2 },
    { label: t("fb.pub.requiredQuestions"), value: checks.requiredFields, icon: ShieldCheck, step: 2 },
    { label: t("fb.pub.answerLists"), value: checks.listFields, icon: ListTree, step: 3 },
  ]

  const canPublish = checks.blockers.length === 0 && checks.enabledFields > 0

  return (
    <div className="space-y-5">
      {/* Summary */}
      <div className="grid grid-cols-2 gap-3 lg:grid-cols-4">
        {summary.map((s) => (
          <button
            key={s.label}
            type="button"
            onClick={() => goToStep(s.step)}
            className="rounded-2xl border border-border/70 bg-card p-4 text-left transition-colors hover:border-primary/40 hover:bg-primary/[0.03]"
          >
            <s.icon className="h-4 w-4 text-primary" aria-hidden="true" />
            <p className="mt-2 text-[1.6rem] font-black leading-none text-foreground">{s.value}</p>
            <p className="mt-1 text-[0.72rem] font-medium text-muted-foreground">{s.label}</p>
          </button>
        ))}
      </div>

      {/* Form identity */}
      <div className="rounded-2xl border border-border/70 bg-card p-4">
        <div className="flex flex-wrap items-center justify-between gap-2">
          <div className="min-w-0">
            <p className="text-[0.95rem] font-bold text-foreground">
              {form.burmese_title}
              {form.english_title ? <span className="ml-2 text-[0.8rem] font-medium text-muted-foreground">{form.english_title}</span> : null}
            </p>
            <p className="mt-0.5 font-mono text-[0.72rem] text-muted-foreground">
              {form.form_id} · {t("fb.pub.version")} v{form.version_number}
            </p>
          </div>
        </div>
      </div>

      {/* Checks */}
      <div className="rounded-2xl border border-border/70 bg-card p-4">
        <h3 className="mb-3 text-[0.85rem] font-bold text-foreground">{t("fb.pub.checks")}</h3>

        {checks.blockers.length === 0 && checks.warnings.length === 0 ? (
          <div className="flex items-center gap-2 text-[0.82rem] font-medium text-[var(--success)]">
            <CheckCircle2 className="h-4 w-4" aria-hidden="true" />
            {t("fb.pub.allGood")}
          </div>
        ) : (
          <ul className="space-y-2">
            {checks.blockers.map((msg) => (
              <li key={msg} className="flex items-start gap-2 rounded-lg bg-destructive/10 px-3 py-2 text-[0.8rem] font-medium text-[var(--destructive)]">
                <AlertTriangle className="mt-0.5 h-3.5 w-3.5 shrink-0" aria-hidden="true" />
                {msg}
              </li>
            ))}
            {checks.warnings.map((msg) => (
              <li key={msg} className="flex items-start gap-2 rounded-lg bg-[var(--warning)]/10 px-3 py-2 text-[0.8rem] font-medium text-[var(--warning)]">
                <AlertTriangle className="mt-0.5 h-3.5 w-3.5 shrink-0" aria-hidden="true" />
                {msg}
              </li>
            ))}
          </ul>
        )}
      </div>

      <div className="flex items-start gap-2 rounded-xl border border-border/60 bg-muted/20 p-3 text-[0.76rem] text-muted-foreground">
        <Lock className="mt-0.5 h-3.5 w-3.5 shrink-0" aria-hidden="true" />
        {t("fb.pub.immutableNote")}
      </div>

      <div className="flex flex-wrap items-center gap-3">
        <Button
          className={cn(
            "h-11 gap-2 rounded-xl px-5 text-[0.88rem]",
            canPublish ? "bg-[var(--success)] text-white hover:bg-[var(--success)]/90" : "",
          )}
          onClick={() => setConfirmOpen(true)}
          disabled={publishing || !canPublish}
        >
          {publishing ? <Sparkles className="h-4 w-4 animate-pulse" /> : <Send className="h-4 w-4" />}
          {publishing ? t("fb.pub.publishing") : t("fb.pub.publish")}
        </Button>
        {!canPublish && (
          <span className="text-[0.78rem] text-muted-foreground">{t("fb.pub.blockers")}</span>
        )}
      </div>

      <Dialog open={confirmOpen} onOpenChange={setConfirmOpen}>
        <DialogContent className="sm:max-w-md">
          <DialogHeader>
            <DialogTitle>{t("fb.pub.publishConfirmTitle")}</DialogTitle>
            <DialogDescription>
              {t("fb.pub.publishConfirmBody", { version: form.version_number })}
            </DialogDescription>
          </DialogHeader>
          <DialogFooter>
            <Button variant="outline" className="rounded-xl border-border bg-card" onClick={() => setConfirmOpen(false)}>
              {t("common.cancel")}
            </Button>
            <Button
              className="rounded-xl bg-[var(--success)] text-white hover:bg-[var(--success)]/90"
              onClick={() => {
                setConfirmOpen(false)
                onPublish()
              }}
            >
              <Send className="h-4 w-4" /> {t("fb.pub.publish")}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  )
}
