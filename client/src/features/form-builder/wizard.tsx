"use client"

/**
 * The editing workbench for a single form.
 *
 * Owns the six-step wizard (choose → sections → questions → options → preview
 * → publish), the stepper, and the save/publish orchestration. Draft state is
 * kept by `useFormDraft`, so nothing is written to the server until the admin
 * presses Save — and edits survive a trip to Master Data and back.
 */
import { useEffect, useState } from "react"
import { useQueryClient } from "@tanstack/react-query"
import { ArrowLeft, Check, CircleAlert, Loader2, Save } from "lucide-react"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { useToast } from "@/components/ui/use-toast"
import { api } from "@/lib/api"
import { useI18n } from "@/lib/i18n"
import { cn } from "@/lib/utils"
import { useFormDraft } from "./draft"
import { SectionsStep } from "./steps/sections-step"
import { QuestionsStep } from "./steps/questions-step"
import { OptionsStep } from "./steps/options-step"
import { PreviewStep } from "./steps/preview-step"
import { PublishStep } from "./steps/publish-step"
import type { ApiForm } from "./types"

const STEP_META: { id: number; labelKey: string; hintKey: string }[] = [
  { id: 0, labelKey: "formBuilder.steps.select", hintKey: "formBuilder.steps.selectHint" },
  { id: 1, labelKey: "formBuilder.steps.sections", hintKey: "formBuilder.steps.sectionsHint" },
  { id: 2, labelKey: "formBuilder.steps.questions", hintKey: "formBuilder.steps.questionsHint" },
  { id: 3, labelKey: "formBuilder.steps.options", hintKey: "formBuilder.steps.optionsHint" },
  { id: 4, labelKey: "formBuilder.steps.preview", hintKey: "formBuilder.steps.previewHint" },
  { id: 5, labelKey: "formBuilder.steps.publish", hintKey: "formBuilder.steps.publishHint" },
]

function Stepper({
  current,
  onSelect,
  dirty,
}: {
  current: number
  onSelect: (step: number) => void
  dirty: boolean
}) {
  const { t } = useI18n()
  return (
    <ol className="flex gap-1 overflow-x-auto pb-1" aria-label={t("formBuilder.title")}>
      {STEP_META.map((step) => {
        const active = step.id === current
        const done = step.id < current
        return (
          <li key={step.id} className="min-w-0 flex-1">
            <button
              type="button"
              onClick={() => onSelect(step.id)}
              aria-current={active ? "step" : undefined}
              className={cn(
                "flex w-full items-center gap-2 rounded-xl border px-3 py-2.5 text-left transition-colors",
                active
                  ? "border-primary/40 bg-primary/[0.06]"
                  : "border-transparent hover:bg-muted/60",
              )}
            >
              <span
                className={cn(
                  "grid h-6 w-6 shrink-0 place-items-center rounded-full text-[0.7rem] font-bold",
                  active
                    ? "bg-primary text-primary-foreground"
                    : done
                      ? "bg-[var(--success)]/15 text-[var(--success)]"
                      : "bg-muted text-muted-foreground",
                )}
              >
                {done ? <Check className="h-3.5 w-3.5" /> : step.id + 1}
              </span>
              <span className="hidden min-w-0 truncate text-[0.78rem] font-semibold text-foreground sm:block">
                {t(step.labelKey)}
              </span>
              {step.id === 1 && dirty ? (
                <span className="ml-auto h-1.5 w-1.5 shrink-0 rounded-full bg-[var(--warning)]" />
              ) : null}
            </button>
          </li>
        )
      })}
    </ol>
  )
}

export function FormWorkbench({
  form,
  initialStep = 1,
  onBackToPicker,
}: {
  form: ApiForm
  initialStep?: number
  onBackToPicker: () => void
}) {
  const { t } = useI18n()
  const { toast } = useToast()
  const qc = useQueryClient()
  const draft = useFormDraft(form)
  const [step, setStep] = useState(() => Math.min(Math.max(initialStep, 1), 5))
  const [publishing, setPublishing] = useState(false)

  const published = form.publication_status === "published"

  // Guard against accidental tab close while there are unsaved edits. Edits
  // themselves are already mirrored to sessionStorage, so this is a courtesy.
  useEffect(() => {
    if (!draft.dirty) return
    const handler = (e: BeforeUnloadEvent) => {
      e.preventDefault()
      e.returnValue = ""
    }
    window.addEventListener("beforeunload", handler)
    return () => window.removeEventListener("beforeunload", handler)
  }, [draft.dirty])

  const goToStep = (next: number) => setStep(Math.min(Math.max(next, 1), 5))

  const handleSave = async () => {
    await draft.save()
  }

  const handlePublish = async () => {
    setPublishing(true)
    try {
      // Persist any pending edits first so we publish exactly what's on screen.
      if (draft.dirty) {
        const ok = await draft.save()
        if (!ok) return
      }
      await api.post(`/api/v1/forms/${form.form_id}/publish`, {})
      draft.clearLocal()
      qc.invalidateQueries({ queryKey: ["forms"] })
      qc.invalidateQueries({ queryKey: ["form-published"] })
      qc.invalidateQueries({ queryKey: ["meta", "form", "current"] })
      toast({
        title: t("fb.toast.published"),
        description: t("fb.pub.publishedBody", { version: form.version_number }),
        variant: "success",
      })
      onBackToPicker()
    } catch (err) {
      toast({
        title: t("fb.toast.publishFailed"),
        description: err instanceof Error ? err.message : t("fb.toast.tryAgain"),
        variant: "destructive",
      })
    } finally {
      setPublishing(false)
    }
  }

  return (
    <div className="space-y-5">
      {/* Workbench header */}
      <div className="flex flex-col gap-4 rounded-2xl border border-border/70 bg-card p-4 sm:p-5 lg:flex-row lg:items-center lg:justify-between">
        <div className="flex min-w-0 items-start gap-3">
          <Button
            variant="ghost"
            size="icon"
            className="mt-0.5 shrink-0 rounded-xl"
            onClick={onBackToPicker}
            aria-label={t("formBuilder.chooseForm")}
          >
            <ArrowLeft className="h-4 w-4" />
          </Button>
          <div className="min-w-0">
            <div className="flex flex-wrap items-center gap-2">
              <h2 className="truncate text-[1.05rem] font-bold text-foreground">{form.burmese_title}</h2>
              <Badge
                variant="outline"
                className={cn(
                  "rounded-full text-[0.62rem] font-semibold",
                  published
                    ? "border-transparent bg-[var(--success)]/12 text-[var(--success)]"
                    : "border-transparent bg-[var(--warning)]/12 text-[var(--warning)]",
                )}
              >
                {published ? t("formBuilder.currentlyPublished") : t("formBuilder.notPublished")}
              </Badge>
            </div>
            <p className="mt-0.5 truncate font-mono text-[0.72rem] text-muted-foreground">
              {form.form_id} · {t("formBuilder.version")} v{form.version_number}
              {form.english_title ? ` · ${form.english_title}` : ""}
            </p>
          </div>
        </div>

        <div className="flex items-center gap-2 pl-11 lg:pl-0">
          <span
            className={cn(
              "inline-flex items-center gap-1.5 text-[0.74rem] font-medium",
              draft.dirty ? "text-[var(--warning)]" : "text-muted-foreground",
            )}
          >
            {draft.dirty ? (
              <>
                <CircleAlert className="h-3.5 w-3.5" aria-hidden="true" />
                {t("formBuilder.dirty")}
              </>
            ) : (
              <>
                <Check className="h-3.5 w-3.5 text-[var(--success)]" aria-hidden="true" />
                {t("formBuilder.savedAt")}
              </>
            )}
          </span>
          <Button
            className="h-10 gap-2 rounded-xl"
            onClick={handleSave}
            disabled={draft.saving || !draft.dirty}
          >
            {draft.saving ? <Loader2 className="h-4 w-4 animate-spin" /> : <Save className="h-4 w-4" />}
            {draft.saving ? t("common.saving") : t("formBuilder.saveDraft")}
          </Button>
        </div>
      </div>

      {published ? (
        <div className="flex items-start gap-2 rounded-xl border border-[var(--warning)]/40 bg-[var(--warning)]/5 px-4 py-3 text-[0.8rem] text-[var(--warning)]">
          <CircleAlert className="mt-0.5 h-4 w-4 shrink-0" aria-hidden="true" />
          {t("formBuilder.publishedFrozen")}
        </div>
      ) : null}

      <Stepper
        current={step}
        dirty={draft.dirty}
        onSelect={(next) => {
          if (next === 0) onBackToPicker()
          else goToStep(next)
        }}
      />

      <div>
        {step === 1 && (
          <SectionsStep
            sections={draft.sections}
            fields={draft.fields}
            setSections={draft.setSections}
          />
        )}
        {step === 2 && (
          <QuestionsStep sections={draft.sections} fields={draft.fields} setFields={draft.setFields} />
        )}
        {step === 3 && (
          <OptionsStep
            sections={draft.sections}
            fields={draft.fields}
            setFields={draft.setFields}
            formId={form.form_id}
            stepIndex={3}
          />
        )}
        {step === 4 && <PreviewStep sections={draft.sections} fields={draft.fields} />}
        {step === 5 && (
          <PublishStep
            form={form}
            sections={draft.sections}
            fields={draft.fields}
            publishing={publishing}
            onPublish={handlePublish}
            goToStep={goToStep}
          />
        )}
      </div>

      {/* Step footer navigation */}
      {step < 5 && (
        <div className="flex items-center justify-between gap-3 border-t border-border/60 pt-4">
          <Button
            variant="outline"
            className="h-10 gap-2 rounded-xl border-border bg-card"
            onClick={() => (step === 1 ? onBackToPicker() : goToStep(step - 1))}
          >
            <ArrowLeft className="h-4 w-4" />
            {step === 1 ? t("formBuilder.chooseForm") : t("common.previous")}
          </Button>
          <Button className="h-10 gap-2 rounded-xl" onClick={() => goToStep(step + 1)}>
            {t("common.next")}
          </Button>
        </div>
      )}
    </div>
  )
}
