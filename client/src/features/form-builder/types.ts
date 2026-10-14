"use client"

/**
 * Shared types and draft-mapping helpers for the Form Builder wizard.
 *
 * The API exposes a form's *latest version* as a flat list of sections and
 * fields where a field points at its section by database id. In the wizard we
 * edit everything locally first (so nothing is written until the admin presses
 * Save), keeping stable client-side keys and remembering the last saved
 * snapshot so we can show an accurate "unsaved changes" state — even across a
 * trip to Master Data and back.
 */

export interface ApiFormSection {
  id: number
  title_burmese: string
  title_english: string | null
  description_burmese: string | null
  description_english: string | null
  display_order: number
  is_enabled: boolean
  is_conditional: boolean
  condition_json: string | null
  navigation_order: string
}

export interface ApiFormField {
  id: number
  name: string
  title_burmese: string
  title_english: string | null
  field_type: string
  is_required: boolean
  is_enabled: boolean
  display_order: number
  associated_section_id: number | null
  option_source: string
  data_binding: string | null
  placeholder_burmese: string | null
  unit: string | null
  min_value: number | null
  max_value: number | null
  default_value: string | null
}

export interface ApiForm {
  id: number
  form_id: string
  burmese_title: string
  english_title: string | null
  description: string | null
  publication_status: string
  version_number: number
  created_at: string | null
  form_version_id: number | null
  form_sections: ApiFormSection[]
  form_fields: ApiFormField[]
}

export interface SectionDraft {
  /** Stable client key; never sent to the server. */
  key: string
  serverId: number | null
  title_burmese: string
  title_english: string
  description_burmese: string
  description_english: string
  is_enabled: boolean
}

export interface FieldDraft {
  key: string
  serverId: number | null
  name: string
  /** System fields keep their identifier to protect the collector payload. */
  nameLocked: boolean
  title_burmese: string
  title_english: string
  field_type: string
  is_required: boolean
  is_enabled: boolean
  /** Client key of the owning section (or null when unassigned). */
  sectionKey: string | null
  option_source: "static" | "master"
  data_binding: string
  help_burmese: string
  help_english: string
  unit: string
  min_value: number | null
  max_value: number | null
  default_value: string
}

let counter = 0
export function uid(prefix = "k"): string {
  counter += 1
  return `${prefix}-${Date.now().toString(36)}-${counter}`
}

export function sectionKeyFor(serverId: number): string {
  return `sec-${serverId}`
}

export function mapSections(form: ApiForm): SectionDraft[] {
  return [...form.form_sections]
    .sort((a, b) => (a.display_order ?? 0) - (b.display_order ?? 0))
    .map((s) => ({
      key: sectionKeyFor(s.id),
      serverId: s.id,
      title_burmese: s.title_burmese ?? "",
      title_english: s.title_english ?? "",
      description_burmese: s.description_burmese ?? "",
      description_english: s.description_english ?? "",
      is_enabled: s.is_enabled,
    }))
}

export function mapFields(form: ApiForm): FieldDraft[] {
  return [...form.form_fields]
    .sort((a, b) => (a.display_order ?? 0) - (b.display_order ?? 0))
    .map((f) => ({
      key: `fld-${f.id}`,
      serverId: f.id,
      name: f.name,
      nameLocked: true,
      title_burmese: f.title_burmese ?? "",
      title_english: f.title_english ?? "",
      field_type: f.field_type,
      is_required: f.is_required,
      is_enabled: f.is_enabled,
      sectionKey: f.associated_section_id != null ? sectionKeyFor(f.associated_section_id) : null,
      option_source: f.option_source === "master" ? "master" : "static",
      data_binding: f.data_binding ?? "",
      help_burmese: f.placeholder_burmese ?? "",
      help_english: "",
      unit: f.unit ?? "",
      min_value: f.min_value,
      max_value: f.max_value,
      default_value: f.default_value ?? "",
    }))
}

export function emptySection(): SectionDraft {
  return {
    key: uid("sec"),
    serverId: null,
    title_burmese: "",
    title_english: "",
    description_burmese: "",
    description_english: "",
    is_enabled: true,
  }
}

export function emptyField(sectionKey: string | null): FieldDraft {
  return {
    key: uid("fld"),
    serverId: null,
    name: "",
    nameLocked: false,
    title_burmese: "",
    title_english: "",
    field_type: "short_text",
    is_required: false,
    is_enabled: true,
    sectionKey,
    option_source: "static",
    data_binding: "",
    help_burmese: "",
    help_english: "",
    unit: "",
    min_value: null,
    max_value: null,
    default_value: "",
  }
}

export function slugifyName(input: string): string {
  const slug = input
    .toLowerCase()
    .trim()
    .replace(/[^a-z0-9]+/g, "_")
    .replace(/^_+|_+$/g, "")
  return slug || `field_${Math.random().toString(36).slice(2, 7)}`
}

export interface DraftSnapshot {
  sections: SectionDraft[]
  fields: FieldDraft[]
  /** JSON of the last saved (or server) state, for dirty detection. */
  baseline: string
}

export function serializeDraft(sections: SectionDraft[], fields: FieldDraft[]): string {
  return JSON.stringify({ sections, fields })
}
