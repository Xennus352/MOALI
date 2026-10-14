"use client"

/**
 * Draft authoring state for one form.
 *
 * All edits are held locally. They are mirrored to `sessionStorage` (never the
 * server) so that navigating to Master Data and back — or an accidental
 * refresh — does not lose work. The server is only written when the admin
 * presses Save, and always as two atomic wholesale replacements (sections,
 * then fields) so the definition never ends up half-updated.
 */
import { useCallback, useEffect, useMemo, useState } from "react"
import { useQueryClient } from "@tanstack/react-query"
import { api } from "@/lib/api"
import { useToast } from "@/components/ui/use-toast"
import { useI18n } from "@/lib/i18n"
import {
  mapFields,
  mapSections,
  serializeDraft,
  type ApiForm,
  type FieldDraft,
  type SectionDraft,
} from "./types"

interface DraftState {
  sections: SectionDraft[]
  fields: FieldDraft[]
  baseline: string
  lastSavedAt: string | null
}

function initialDraft(form: ApiForm): DraftState {
  const sections = mapSections(form)
  const fields = mapFields(form)
  const baseline = serializeDraft(sections, fields)
  const storageKey = `moali_fb_draft_${form.form_id}`
  try {
    const raw = window.sessionStorage.getItem(storageKey)
    if (raw) {
      const parsed = JSON.parse(raw) as DraftState
      if (
        parsed &&
        Array.isArray(parsed.sections) &&
        Array.isArray(parsed.fields) &&
        typeof parsed.baseline === "string"
      ) {
        return {
          sections: parsed.sections,
          fields: parsed.fields,
          baseline: parsed.baseline,
          lastSavedAt: parsed.lastSavedAt ?? null,
        }
      }
    }
  } catch {
    // Corrupt or unavailable storage: fall back to the server definition.
  }
  return { sections, fields, baseline, lastSavedAt: null }
}

export function useFormDraft(form: ApiForm) {
  const qc = useQueryClient()
  const { toast } = useToast()
  const { t } = useI18n()
  const storageKey = `moali_fb_draft_${form.form_id}`
  const [draft, setDraft] = useState<DraftState>(() => initialDraft(form))
  const [saving, setSaving] = useState(false)

  // Mirror to session storage on every change (cheap, local, no network).
  useEffect(() => {
    try {
      window.sessionStorage.setItem(storageKey, JSON.stringify(draft))
    } catch {
      // Ignore quota/private-mode failures.
    }
  }, [draft, storageKey])

  const setSections = useCallback((next: SectionDraft[] | ((prev: SectionDraft[]) => SectionDraft[])) => {
    setDraft((d) => ({ ...d, sections: typeof next === "function" ? next(d.sections) : next }))
  }, [])

  const setFields = useCallback((next: FieldDraft[] | ((prev: FieldDraft[]) => FieldDraft[])) => {
    setDraft((d) => ({ ...d, fields: typeof next === "function" ? next(d.fields) : next }))
  }, [])

  const clearLocal = useCallback(() => {
    try {
      window.sessionStorage.removeItem(storageKey)
    } catch {
      // ignore
    }
  }, [storageKey])

  const dirty = useMemo(
    () => serializeDraft(draft.sections, draft.fields) !== draft.baseline,
    [draft],
  )

  /** Produce field payloads, mapping client section keys to saved section ids. */
  const buildFieldPayload = useCallback(
    (fields: FieldDraft[], sections: SectionDraft[], idByIndex: number[]) => {
      const indexByKey = new Map(sections.map((s, i) => [s.key, i]))
      return fields.map((f, i) => {
        const sectionIdx = f.sectionKey != null ? indexByKey.get(f.sectionKey) : undefined
        return {
          name: f.name.trim(),
          title_burmese: f.title_burmese.trim(),
          title_english: f.title_english.trim() || null,
          field_type: f.field_type,
          is_required: f.is_required,
          is_enabled: f.is_enabled,
          display_order: i,
          associated_section_id:
            sectionIdx != null && idByIndex[sectionIdx] != null ? idByIndex[sectionIdx] : null,
          option_source: f.option_source,
          data_binding: f.data_binding.trim() || null,
          placeholder_burmese: f.help_burmese.trim() || null,
          placeholder_english: f.help_english.trim() || null,
          unit: f.unit.trim() || null,
          min_value: f.min_value,
          max_value: f.max_value,
          default_value: f.default_value.trim() || null,
        }
      })
    },
    [],
  )

  const validate = useCallback((): { key: string; vars?: Record<string, string> } | null => {
    for (const f of draft.fields) {
      if (!f.title_burmese.trim() || !f.name.trim()) return { key: "fb.toast.fillRequired" }
    }
    const names = draft.fields.map((f) => f.name.trim())
    const dupe = names.find((n, i) => names.indexOf(n) !== i)
    if (dupe) return { key: "fb.q.duplicateName", vars: { name: dupe } }
    for (const s of draft.sections) {
      if (!s.title_burmese.trim()) return { key: "fb.sections.titleRequired" }
    }
    return null
  }, [draft])

  const setBaselineToCurrent = useCallback(() => {
    setDraft((d) => ({
      ...d,
      baseline: serializeDraft(d.sections, d.fields),
      lastSavedAt: new Date().toISOString(),
    }))
  }, [])

  const save = useCallback(async (): Promise<boolean> => {
    const problem = validate()
    if (problem) {
      toast({
        title: t("fb.toast.cannotSave"),
        description: t(problem.key, problem.vars),
        variant: "destructive",
      })
      return false
    }

    setSaving(true)
    try {
      const sectionPayload = draft.sections.map((s, i) => ({
        title_burmese: s.title_burmese.trim(),
        title_english: s.title_english.trim() || null,
        description_burmese: s.description_burmese.trim() || null,
        description_english: s.description_english.trim() || null,
        display_order: i,
        is_enabled: s.is_enabled,
      }))

      const afterSections = await api.put<ApiForm>(
        `/api/v1/forms/${form.form_id}/sections`,
        sectionPayload,
      )
      const idByIndex = [...afterSections.form_sections]
        .sort((a, b) => (a.display_order ?? 0) - (b.display_order ?? 0))
        .map((s) => s.id)

      await api.put<ApiForm>(
        `/api/v1/forms/${form.form_id}/fields`,
        buildFieldPayload(draft.fields, draft.sections, idByIndex),
      )

      setBaselineToCurrent()
      qc.invalidateQueries({ queryKey: ["forms"] })
      toast({
        title: t("fb.toast.saved"),
        description: t("fb.toast.savedDesc", {
          sections: draft.sections.length,
          fields: draft.fields.length,
        }),
        variant: "success",
      })
      return true
    } catch (err) {
      const detail = err instanceof Error ? err.message : t("fb.toast.tryAgain")
      toast({
        title: t("fb.toast.saveFailed"),
        description: `${detail} ${t("fb.toast.saveFailedHint")}`,
        variant: "destructive",
      })
      return false
    } finally {
      setSaving(false)
    }
  }, [buildFieldPayload, draft, form.form_id, qc, setBaselineToCurrent, t, toast, validate])

  return {
    sections: draft.sections,
    fields: draft.fields,
    setSections,
    setFields,
    dirty,
    saving,
    lastSavedAt: draft.lastSavedAt,
    save,
    clearLocal,
    setBaselineToCurrent,
  }
}

/** Count how many questions a section owns. */
export function countFields(sectionKey: string, fields: FieldDraft[]): number {
  return fields.filter((f) => f.sectionKey === sectionKey).length
}
