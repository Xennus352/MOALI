"use client"

/**
 * Field-type catalog and the master-data lists a question can draw its answer
 * options from. Keeping this in one place means the wizard, the preview and
 * the review step all agree on which types need options and where those
 * options come from.
 */

export interface FieldTypeMeta {
  value: string
  /** i18n key into `fieldType.*`. */
  labelKey: string
  /** True when the type renders a list of choices. */
  needsOptions: boolean
  /** Which option sources make sense (selects vs. the geography hierarchy). */
  kind: "text" | "number" | "temporal" | "choice" | "boolean" | "special" | "layout"
}

export const FIELD_TYPES: FieldTypeMeta[] = [
  { value: "short_text", labelKey: "fieldType.short_text", needsOptions: false, kind: "text" },
  { value: "long_text", labelKey: "fieldType.long_text", needsOptions: false, kind: "text" },
  { value: "integer", labelKey: "fieldType.integer", needsOptions: false, kind: "number" },
  { value: "decimal", labelKey: "fieldType.decimal", needsOptions: false, kind: "number" },
  { value: "date", labelKey: "fieldType.date", needsOptions: false, kind: "temporal" },
  { value: "time", labelKey: "fieldType.time", needsOptions: false, kind: "temporal" },
  { value: "datetime", labelKey: "fieldType.datetime", needsOptions: false, kind: "temporal" },
  { value: "telephone", labelKey: "fieldType.telephone", needsOptions: false, kind: "text" },
  { value: "email", labelKey: "fieldType.email", needsOptions: false, kind: "text" },
  { value: "single_select", labelKey: "fieldType.single_select", needsOptions: true, kind: "choice" },
  { value: "radio", labelKey: "fieldType.radio", needsOptions: true, kind: "choice" },
  { value: "multi_select", labelKey: "fieldType.multi_select", needsOptions: true, kind: "choice" },
  { value: "checkbox", labelKey: "fieldType.checkbox", needsOptions: true, kind: "choice" },
  { value: "boolean", labelKey: "fieldType.boolean", needsOptions: false, kind: "boolean" },
  { value: "number_counter", labelKey: "fieldType.number_counter", needsOptions: false, kind: "number" },
  { value: "geographic", labelKey: "fieldType.geographic", needsOptions: false, kind: "special" },
  { value: "repeating_group", labelKey: "fieldType.repeating_group", needsOptions: false, kind: "special" },
  { value: "heading", labelKey: "fieldType.heading", needsOptions: false, kind: "layout" },
  { value: "paragraph", labelKey: "fieldType.paragraph", needsOptions: false, kind: "layout" },
]

export const FIELD_TYPE_MAP: Record<string, FieldTypeMeta> = Object.fromEntries(
  FIELD_TYPES.map((t) => [t.value, t]),
)

export function fieldTypeMeta(value: string): FieldTypeMeta {
  return FIELD_TYPE_MAP[value] ?? FIELD_TYPES[0]
}

/** i18n label for a field type, e.g. "Choose one option". */
export function fieldTypeLabel(t: (k: string) => string, value: string): string {
  return t(fieldTypeMeta(value).labelKey)
}

export interface BindingMeta {
  /** Value stored in `data_binding`. */
  binding: string
  /** Master-data resource path segment (e.g. `genders`). */
  resource: string
  /** i18n key for a friendly list name. */
  labelKey: string
  /** i18n key for the list's description. */
  descKey: string
}

/**
 * The option lists a select-type question can be bound to. These are exactly
 * the lists the collector app (web + mobile) knows how to resolve at runtime.
 */
export const OPTION_BINDINGS: BindingMeta[] = [
  { binding: "gender", resource: "genders", labelKey: "md.genders", descKey: "md.genders.desc" },
  { binding: "animal_types", resource: "animal-types", labelKey: "md.animal-types", descKey: "md.animal-types.desc" },
  { binding: "animal_categories", resource: "animal-categories", labelKey: "md.animal-categories", descKey: "md.animal-categories.desc" },
  { binding: "species", resource: "species", labelKey: "md.species", descKey: "md.species.desc" },
  { binding: "age_groups", resource: "age-groups", labelKey: "md.age-groups", descKey: "md.age-groups.desc" },
  { binding: "breeding_categories", resource: "breeding-categories", labelKey: "md.breeding-categories", descKey: "md.breeding-categories.desc" },
]

export const BINDING_MAP: Record<string, BindingMeta> = Object.fromEntries(
  OPTION_BINDINGS.map((b) => [b.binding, b]),
)

/** Geography levels used by the `geographic` field type (State → Ward). */
export const GEO_BINDINGS: BindingMeta[] = [
  { binding: "state_region", resource: "state-regions", labelKey: "md.state-regions", descKey: "md.state-regions.desc" },
  { binding: "district", resource: "districts", labelKey: "md.districts", descKey: "md.districts.desc" },
  { binding: "township", resource: "townships", labelKey: "md.townships", descKey: "md.townships.desc" },
  { binding: "village_tract", resource: "village-tracts", labelKey: "md.village-tracts", descKey: "md.village-tracts.desc" },
  { binding: "ward", resource: "wards", labelKey: "md.wards", descKey: "md.wards.desc" },
]

/** All bindings (options + geography) keyed by binding value. */
export const ALL_BINDINGS: BindingMeta[] = [...OPTION_BINDINGS, ...GEO_BINDINGS]

export function bindingFor(value: string): BindingMeta | undefined {
  return ALL_BINDINGS.find((b) => b.binding === value)
}

/** Master-data items expose either `*_name` or `*_label` depending on the list. */
export interface MasterItem {
  id: number
  code?: string | null
  burmese_name?: string | null
  english_name?: string | null
  burmese_label?: string | null
  english_label?: string | null
  is_active?: boolean
}

export function itemLabel(item: MasterItem, lang: "my" | "en"): string {
  const my = item.burmese_name ?? item.burmese_label ?? item.code ?? `#${item.id}`
  const en = item.english_name ?? item.english_label ?? item.code ?? `#${item.id}`
  return lang === "en" ? en || my : my || en
}
