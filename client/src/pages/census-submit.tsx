"use client"

import { useMemo, useState } from "react"
import { useQuery } from "@tanstack/react-query"
import { useNavigate } from "react-router-dom"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Badge } from "@/components/ui/badge"
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select"
import { Checkbox } from "@/components/ui/checkbox"
import {
  User,
  Home,
  Egg,
  Sprout,
  ClipboardCheck,
  Trash2,
  Plus,
  Loader2,
  ArrowLeft,
  CheckCircle2,
} from "lucide-react"
import { api } from "@/lib/api"
import { useToast } from "@/components/ui/use-toast"
import { cn } from "@/lib/utils"

/* ------------------------------------------------------------- API types */

interface GenderRow { id: number; code: string; burmese_name: string; english_name: string | null }
interface AnimalTypeRow { id: number; code: string; burmese_name: string; english_name: string | null }
interface CategoryRow { id: number; code: string; burmese_name: string; english_name: string | null; animal_type_id: number | null }
interface SpeciesRow { id: number; code: string; burmese_name: string; english_name: string | null; animal_type_id: number; animal_category_code: string | null }
interface AgeGroupRow { id: number; code: string; burmese_name: string; english_name: string | null }
interface BreedingCategoryRow { id: number; code: string; burmese_name: string }

interface GeoNode {
  id: number
  burmese_name: string
  english_name: string | null
  districts?: GeoNode[]
  townships?: GeoNode[]
  village_tracts?: GeoNode[]
  wards?: GeoNode[]
}

/** One field as published by the admin in the form builder. */
interface FormFieldDef {
  id: number
  name: string
  title_burmese: string
  title_english: string | null
  field_type: string
  is_required: boolean
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

interface FormSectionDef {
  id: number
  title_burmese: string
  title_english: string | null
  description_burmese: string | null
  description_english: string | null
  display_order: number
}

interface CurrentForm {
  form_id: string | null
  burmese_title: string | null
  english_title: string | null
  version_number: number
  form_version_id: number
  publication_status: string
  sections: FormSectionDef[]
  fields: FormFieldDef[]
}

/* ------------------------------------------------ fixed-schema knowledge */

// Columns that exist on the server's SubmissionCreate schema. Anything the
// admin adds beyond these travels in `additional_data` (stored as typed
// FormFieldAnswer rows), so the form can evolve without a migration.
const KNOWN_COLUMNS = new Set([
  "state_region_id", "district_id", "township_id", "village_tract_id", "ward_id",
  "household_no", "interview_date",
  "respondent_name_burmese", "respondent_name_english", "respondent_gender_id",
  "respondent_age", "respondent_age_group_id", "respondent_education", "respondent_phone",
  "household_head_name_burmese", "household_head_name_english", "household_head_gender_id",
  "household_head_age", "household_head_age_group_id", "household_head_education", "household_head_phone",
  "interviewer_name", "interviewer_phone", "has_raised_animals", "has_poultry",
])
const INT_COLUMNS = new Set([
  "state_region_id", "district_id", "township_id", "village_tract_id", "ward_id",
  "respondent_gender_id", "respondent_age", "respondent_age_group_id",
  "household_head_gender_id", "household_head_age", "household_head_age_group_id",
])

// Geographic cascade order — drives the parent/child dropdowns.
const GEO_LEVELS = ["state_region", "district", "township", "village_tract", "ward"] as const
type GeoLevel = (typeof GEO_LEVELS)[number]
const GEO_LABELS: Record<GeoLevel, string> = {
  state_region: "တိုင်းဒေသကြီး/ပြည်နယ် · State / Region",
  district: "ခရိုင် · District",
  township: "မြို့နယ် · Township",
  village_tract: "ရပ်ကွက်/ကျေးရွာအုပ်စု · Ward / Village tract",
  ward: "ကျေးရွာ · Village",
}

// Mirrors the workbook's ageType sheet (which age groups apply to which animal type / poultry category).
const LARGE_AGE_CODES = ["ageID01", "ageID02", "ageID03"]
const POULTRY_AGE_CODES: Record<string, string[]> = {
  lsID01: ["ageID07", "ageID08", "ageID09"],
  lsID03: ["ageID10", "ageID11"],
  lsID04: ["ageID12", "ageID13", "ageID14"],
  lsID07: ["ageID07", "ageID15", "ageID16"],
}

interface AnimalRow {
  key: number
  categoryId: number | null
  speciesId: number | null
  ageGroupId: number | null
  male: number | null
  castrated: number | null
  female: number | null
}
interface PoultryRow {
  key: number
  categoryId: number | null
  speciesId: number | null
  ageGroupId: number | null
  male: number | null
  female: number | null
}
interface BreedingRow {
  categoryId: number
  male: number | null
  female: number | null
}

let rowKey = 1
const newRow = () => rowKey++

/* --------------------------------------------------------------- helpers */

function toInt(v: number | null | undefined): number | null {
  const n = Number(v)
  return v === null || v === undefined || Number.isNaN(n) ? null : n
}

const countInputCls =
  "h-9 rounded-lg border-border bg-card text-center text-sm font-medium transition-colors focus-visible:ring-primary"

function FieldError({ show, message }: { show: boolean; message?: string }) {
  if (!show) return null
  return <p className="text-[0.72rem] font-medium text-[var(--destructive)]">{message ?? "Required"}</p>
}

function SectionShell({
  index,
  icon,
  burmese,
  english,
  children,
}: {
  index: number
  icon: React.ReactNode
  burmese: string
  english: string
  children: React.ReactNode
}) {
  return (
    <section data-reveal className="rounded-2xl border border-border/80 bg-card shadow-[0_1px_2px_rgb(17_34_15/0.04),0_8px_24px_-8px_rgb(17_34_15/0.06)]">
      <header className="flex items-start gap-3 border-b border-border/70 px-5 py-4 sm:px-6">
        <span className="grid h-9 w-9 shrink-0 place-items-center rounded-xl bg-primary/10 text-primary">
          {icon}
        </span>
        <div>
          <p className="text-[0.66rem] font-bold uppercase tracking-[0.14em] text-primary">Section {index}</p>
          <h3 className="font-display text-[1.05rem] font-bold leading-snug">{burmese}</h3>
          {english && <p className="text-[0.78rem] text-muted-foreground">{english}</p>}
        </div>
      </header>
      <div className="px-5 py-5 sm:px-6">{children}</div>
    </section>
  )
}

const SECTION_ICONS = [User, Home, Egg, Sprout, ClipboardCheck]

/* ================================================================ page */

export function CensusSubmitPage() {
  const navigate = useNavigate()
  const { toast } = useToast()

  const masters = useQuery({
    queryKey: ["census-masters"],
    queryFn: async () => {
      const [form, genders, types, categories, species, ageGroups, breeding, geo] = await Promise.all([
        api.get<CurrentForm>("/api/v1/meta/form/current"),
        api.get<GenderRow[]>("/api/v1/master/genders"),
        api.get<AnimalTypeRow[]>("/api/v1/master/animal-types"),
        api.get<CategoryRow[]>("/api/v1/master/animal-categories"),
        api.get<SpeciesRow[]>("/api/v1/master/species"),
        api.get<AgeGroupRow[]>("/api/v1/master/age-groups"),
        api.get<BreedingCategoryRow[]>("/api/v1/master/breeding-categories"),
        api.get<GeoNode[]>("/api/v1/meta/geography"),
      ])
      return { form, genders, types, categories, species, ageGroups, breeding, geo }
    },
  })
  const d = masters.data

  /* ---- form state (driven entirely by the published definition) ---- */
  const [values, setValues] = useState<Record<string, string | number | boolean | null>>({})
  const [largeRows, setLargeRows] = useState<AnimalRow[]>([])
  const [smallRows, setSmallRows] = useState<AnimalRow[]>([])
  const [poultryRows, setPoultryRows] = useState<PoultryRow[]>([])
  const [breedingOverrides, setBreedingOverrides] = useState<Record<number, { male: number | null; female: number | null }>>({})
  const [touched, setTouched] = useState(false)
  const [submitting, setSubmitting] = useState(false)

  const byId = useMemo(() => {
    if (!d) return undefined
    return {
      types: new Map(d.types.map((t) => [t.id, t])),
      categories: new Map(d.categories.map((c) => [c.id, c])),
      categoriesByCode: new Map(d.categories.map((c) => [c.code, c])),
      typesByCode: new Map(d.types.map((t) => [t.code, t])),
      species: d.species,
      ageGroups: new Map(d.ageGroups.map((a) => [a.id, a])),
      genders: new Map(d.genders.map((g) => [g.id, g])),
    }
  }, [d])

  const fieldByName = useMemo(() => {
    const m = new Map<string, FormFieldDef>()
    for (const f of d?.form.fields ?? []) m.set(f.name, f)
    return m
  }, [d])

  /** Value for a field: explicit state, else the default the admin defined. */
  const getVal = (name: string): string | number | boolean | null => {
    if (name in values) return values[name]
    const f = fieldByName.get(name)
    if (!f) return null
    if (f.field_type === "boolean") {
      return f.name === "has_raised_animals" || f.name === "has_poultry" ? true : f.default_value === "true"
    }
    if (f.default_value != null && f.default_value !== "") return f.default_value
    return null
  }

  /** Breeding rows come from master data; entered counts live in overrides. */
  const breedingRows: BreedingRow[] = useMemo(
    () =>
      (d?.breeding ?? []).map((b) => ({
        categoryId: b.id,
        male: breedingOverrides[b.id]?.male ?? null,
        female: breedingOverrides[b.id]?.female ?? null,
      })),
    [d, breedingOverrides]
  )

  /* ---- sections + fields from the definition ---- */
  const sections = useMemo(
    () => (d ? [...d.form.sections].sort((a, b) => a.display_order - b.display_order) : []),
    [d]
  )
  const fieldsBySection = useMemo(() => {
    const m = new Map<number, FormFieldDef[]>()
    if (d) {
      for (const f of d.form.fields) {
        const key = f.associated_section_id ?? -1
        const arr = m.get(key) ?? []
        arr.push(f)
        m.set(key, arr)
      }
      for (const arr of m.values()) arr.sort((a, b) => a.display_order - b.display_order)
    }
    return m
  }, [d])

  /* ---- geographic cascade ---- */
  const geoNameByLevel = useMemo(() => {
    const m: Partial<Record<GeoLevel, string>> = {}
    for (const f of d?.form.fields ?? []) {
      if (f.field_type === "geographic" && f.data_binding && (GEO_LEVELS as readonly string[]).includes(f.data_binding)) {
        m[f.data_binding as GeoLevel] = f.name
      }
    }
    return m
  }, [d])

  const geoValue = (level: GeoLevel): number | null => {
    const name = geoNameByLevel[level]
    const v = name ? getVal(name) : null
    return v == null || v === "" ? null : Number(v)
  }

  const geoOptions = (level: GeoLevel): GeoNode[] => {
    if (!d) return []
    if (level === "state_region") return d.geo
    const region = d.geo.find((r) => r.id === geoValue("state_region"))
    if (level === "district") return region?.districts ?? []
    const district = region?.districts?.find((x) => x.id === geoValue("district"))
    if (level === "township") return district?.townships ?? []
    const township = district?.townships?.find((x) => x.id === geoValue("township"))
    if (level === "village_tract") return township?.village_tracts ?? []
    const tract = township?.village_tracts?.find((x) => x.id === geoValue("village_tract"))
    return tract?.wards ?? []
  }

  const setGeoLevel = (level: GeoLevel, id: number | null) => {
    setValues((prev) => {
      const next = { ...prev }
      const start = GEO_LEVELS.indexOf(level)
      for (let i = start; i < GEO_LEVELS.length; i++) {
        const name = geoNameByLevel[GEO_LEVELS[i]]
        if (name) next[name] = i === start ? id : null
      }
      return next
    })
  }

  /* ---- master-data option resolvers (admin controlled) ---- */
  const speciesForCategory = (categoryId: number | null) => {
    if (!byId || !categoryId) return []
    const cat = byId.categories.get(categoryId)
    if (!cat) return []
    return byId.species.filter(
      (s) => s.animal_type_id === cat.animal_type_id && (!s.animal_category_code || s.animal_category_code === cat.code)
    )
  }

  const ageOptionsFor = (categoryId: number | null): AgeGroupRow[] => {
    if (!d || !byId || !categoryId) return []
    const cat = byId.categories.get(categoryId)
    if (!cat) return []
    if (cat.animal_type_id) {
      const type = byId.types.get(cat.animal_type_id)
      if (type?.code === "atID03") {
        const codes = POULTRY_AGE_CODES[cat.code] ?? POULTRY_AGE_CODES.lsID01
        return codes.map((c) => d.ageGroups.find((a) => a.code === c)!).filter(Boolean)
      }
      if (type?.code === "atID02") return LARGE_AGE_CODES.map((c) => d.ageGroups.find((a) => a.code === c)!).filter(Boolean)
      return LARGE_AGE_CODES.map((c) => d.ageGroups.find((a) => a.code === c)!).filter(Boolean)
    }
    return d.ageGroups
  }

  const catsByTypeCode = (code: string): CategoryRow[] =>
    d?.categories.filter((c) => byId?.types.get(c.animal_type_id ?? -1)?.code === code) ?? []

  const selectOptionsFor = (f: FormFieldDef): { id: number; label: string }[] | null => {
    if (!d || f.option_source !== "master" || !f.data_binding) return null
    switch (f.data_binding) {
      case "gender":
        return d.genders.filter((g) => g.code !== "g02").map((g) => ({ id: g.id, label: `${g.burmese_name}${g.english_name ? ` · ${g.english_name}` : ""}` }))
      case "animal_types":
        return d.types.map((t) => ({ id: t.id, label: t.burmese_name }))
      case "animal_categories":
        return d.categories.map((c) => ({ id: c.id, label: c.burmese_name }))
      case "species":
        return d.species.map((s) => ({ id: s.id, label: s.burmese_name }))
      case "age_groups":
        return d.ageGroups.map((a) => ({ id: a.id, label: a.burmese_name }))
      case "breeding_categories":
        return d.breeding.map((b) => ({ id: b.id, label: b.burmese_name }))
      default:
        return null
    }
  }

  const setValue = (name: string, v: string | number | boolean | null) =>
    setValues((prev) => ({ ...prev, [name]: v }))

  /* ---- row mutations ---- */
  const upsert = <T extends AnimalRow | PoultryRow>(
    setter: (fn: (rows: T[]) => T[]) => void,
    key: number,
    patch: Partial<T>
  ) => setter((prev) => prev.map((r) => (r.key === key ? { ...r, ...patch } : r)))

  const addLarge = () => setLargeRows((prev) => [...prev, { key: newRow(), categoryId: null, speciesId: null, ageGroupId: null, male: null, castrated: null, female: null }])
  const addSmall = () => setSmallRows((prev) => [...prev, { key: newRow(), categoryId: null, speciesId: null, ageGroupId: null, male: null, castrated: null, female: null }])
  const addPoultry = () => setPoultryRows((prev) => [...prev, { key: newRow(), categoryId: null, speciesId: null, ageGroupId: null, male: null, female: null }])

  /* ---- validation, driven by is_required in the definition ---- */
  const missing: string[] = (() => {
    if (!d) return []
    const out: string[] = []
    const rowsForBinding = (binding: string | null) => {
      if (binding === "breeding_rows") return breedingRows.filter((r) => (r.male ?? 0) + (r.female ?? 0) > 0).length
      if (binding === "poultry_rows") return poultryRows.length
      if (binding === "animal_rows") return largeRows.length + smallRows.length
      return 0
    }
    for (const f of d.form.fields) {
      if (!f.is_required) continue
      if (f.field_type === "repeating_group") {
        if (rowsForBinding(f.data_binding) === 0) out.push(f.title_burmese)
        continue
      }
      if (f.field_type === "boolean") continue
      const v = getVal(f.name)
      if (v === undefined || v === null || String(v).trim() === "") out.push(f.title_burmese)
    }
    return out
  })()

  /* ---- payload, fixed schema + admin extras ---- */
  const buildPayload = () => {
    const animalCounts: Array<Record<string, unknown>> = []
    const pushCounts = (rows: AnimalRow[], poultry = false) => {
      for (const r of rows) {
        const cat = byId?.categories.get(r.categoryId!)
        if (!cat) continue
        const base = { animal_type_id: cat.animal_type_id!, species_id: toInt(r.speciesId), age_group_id: toInt(r.ageGroupId) }
        const cells = poultry
          ? ([["male", r.male], ["female", r.female]] as const)
          : ([["male", r.male], ["castrated", r.castrated], ["female", r.female]] as const)
        for (const [gender, count] of cells) {
          const value = toInt(count) ?? 0
          if (value > 0) animalCounts.push({ ...base, gender, count: value })
        }
      }
    }
    pushCounts(largeRows)
    pushCounts(smallRows)
    for (const r of poultryRows) pushCounts([r as unknown as AnimalRow], true)

    const breedingCounts = breedingRows
      .map((b) => ({ breeding_category_id: b.categoryId, male_count: toInt(b.male) ?? 0, female_count: toInt(b.female) ?? 0 }))
      .filter((b) => b.male_count + b.female_count > 0)

    const payload: Record<string, unknown> = {
      form_version_id: d?.form.form_version_id,
      animal_counts: animalCounts,
      breeding_counts: breedingCounts,
    }
    const extra: Record<string, unknown> = {}
    for (const f of d?.form.fields ?? []) {
      if (f.field_type === "repeating_group" || f.field_type === "heading" || f.field_type === "paragraph") continue
      const raw = getVal(f.name)
      let val: unknown
      if (f.field_type === "boolean") {
        val = Boolean(raw)
      } else {
        if (raw === undefined || raw === null || String(raw).trim() === "") continue
        if (f.field_type === "integer" || f.field_type === "number" || INT_COLUMNS.has(f.name)) {
          const n = Number(raw)
          val = Number.isNaN(n) ? null : n
        } else {
          val = String(raw).trim()
        }
      }
      if (KNOWN_COLUMNS.has(f.name)) payload[f.name] = val
      else extra[f.name] = val
    }
    if (Object.keys(extra).length > 0) payload.additional_data = extra
    return payload
  }

  const submit = async () => {
    setTouched(true)
    if (missing.length > 0) {
      toast({ title: "Please complete the required fields", description: missing.join(" · "), variant: "destructive" })
      return
    }
    setSubmitting(true)
    try {
      await api.post<{ id: number }>("/api/v1/submissions", buildPayload())
      toast({ title: "Submission recorded", description: `Household ${getVal("household_no") ?? ""} saved to the census.`, variant: "success" })
      navigate("/census-responses")
    } catch (e) {
      const err = e as { message?: string }
      toast({ title: "Could not submit", description: err.message ?? "Unexpected server error", variant: "destructive" })
    } finally {
      setSubmitting(false)
    }
  }

  if (masters.isLoading) {
    return (
      <div className="flex min-h-[50vh] items-center justify-center gap-3 text-sm text-muted-foreground">
        <Loader2 className="h-5 w-5 animate-spin" /> Loading census form…
      </div>
    )
  }
  if (masters.error) {
    return (
      <div className="py-16 text-center text-sm text-[var(--destructive)]">
        Could not load the census form.{(masters.error as { message?: string })?.message}
      </div>
    )
  }
  if (!d || !d.form) {
    return (
      <div className="py-16 text-center text-sm text-muted-foreground">
        No published census form is available yet – an administrator must publish a form first.
      </div>
    )
  }

  const form = d.form
  const activeSections = sections
  const orphanFields = fieldsBySection.get(-1)
  const sectionCount = activeSections.length + (orphanFields && orphanFields.length > 0 ? 1 : 0)

  /* ---- field renderers ---- */
  const renderScalar = (f: FormFieldDef) => {
    const label = f.title_english ? f.title_english : f.title_burmese
    const showReq = f.is_required
    const v = getVal(f.name)
    const req = showReq ? <span className="text-[var(--destructive)]"> *</span> : null

    const labelNode = (
      <Label className="mb-1.5 block text-[0.78rem] font-semibold">
        {label}
        {req}
        {f.unit && <span className="ml-1 font-normal text-muted-foreground">({f.unit})</span>}
      </Label>
    )
    const subLabel = f.title_english && f.title_burmese ? (
      <span className="mb-1.5 block text-[0.72rem] text-muted-foreground">{f.title_burmese}</span>
    ) : null

    const err = touched && showReq && f.field_type !== "boolean" && (v === undefined || v === null || String(v).trim() === "")

    if (f.field_type === "boolean") {
      return (
        <label key={f.id} className="flex items-center gap-3 sm:col-span-2 lg:col-span-3">
          <Checkbox name={f.name} checked={Boolean(v)} onCheckedChange={(val) => setValue(f.name, !!val)} />
          <span className="text-sm">
            {f.title_burmese}
            {f.title_english ? ` · ${f.title_english}` : ""}
            {req}
          </span>
        </label>
      )
    }

    if (f.field_type === "single_select" || f.field_type === "radio") {
      const options = selectOptionsFor(f)
      if (options && options.length > 0) {
        return (
          <div key={f.id}>
            {labelNode}
            {subLabel}
            <Select value={v != null ? String(v) : ""} onValueChange={(val) => setValue(f.name, val)}>
              <SelectTrigger className="h-10 rounded-xl">
                <SelectValue placeholder="Select…" />
              </SelectTrigger>
              <SelectContent>
                {options.map((o) => (
                  <SelectItem key={o.id} value={String(o.id)}>{o.label}</SelectItem>
                ))}
              </SelectContent>
            </Select>
            <FieldError show={err} />
          </div>
        )
      }
    }

    if (f.field_type === "multi_select" || f.field_type === "checkbox") {
      const options = selectOptionsFor(f)
      const selected = new Set(String(v ?? "").split(",").filter(Boolean))
      if (options && options.length > 0) {
        return (
          <div key={f.id} className="sm:col-span-2 lg:col-span-3">
            {labelNode}
            <div className="flex flex-wrap gap-3">
              {options.map((o) => {
                const id = String(o.id)
                return (
                  <label key={o.id} className="flex items-center gap-2 text-sm">
                    <Checkbox
                      checked={selected.has(id)}
                      onCheckedChange={(val) => {
                        const next = new Set(selected)
                        if (val) next.add(id)
                        else next.delete(id)
                        setValue(f.name, Array.from(next).join(","))
                      }}
                    />
                    {o.label}
                  </label>
                )
              })}
            </div>
            <FieldError show={err} />
          </div>
        )
      }
    }

    const common = {
      name: f.name,
      className: "h-10 rounded-xl",
      value: v == null ? "" : String(v),
      placeholder: f.placeholder_burmese ?? undefined,
    }
    if (f.field_type === "long_text") {
      return (
        <div key={f.id} className="sm:col-span-2 lg:col-span-3">
          {labelNode}
          {subLabel}
          <textarea
            name={f.name}
            className="min-h-[80px] w-full rounded-xl border border-input bg-card px-3 py-2 text-sm"
            value={v == null ? "" : String(v)}
            placeholder={f.placeholder_burmese ?? undefined}
            maxLength={f.max_value ?? undefined}
            onChange={(e) => setValue(f.name, e.target.value)}
          />
          <FieldError show={err} />
        </div>
      )
    }
    if (f.field_type === "date" || f.field_type === "datetime") {
      return (
        <div key={f.id}>
          {labelNode}
          {subLabel}
          <Input
            type="date"
            name={f.name}
            className="h-10 rounded-xl"
            value={v == null ? "" : String(v)}
            max={f.name === "interview_date" ? new Date().toISOString().slice(0, 10) : undefined}
            onChange={(e) => setValue(f.name, e.target.value)}
          />
          <FieldError show={err} />
        </div>
      )
    }
    if (f.field_type === "integer" || f.field_type === "number" || f.field_type === "number_counter" || f.field_type === "decimal") {
      const isDecimal = f.field_type === "decimal"
      return (
        <div key={f.id}>
          {labelNode}
          {subLabel}
          <Input
            inputMode={isDecimal ? "decimal" : "numeric"}
            type="number"
            name={f.name}
            step={isDecimal ? "any" : undefined}
            className="h-10 rounded-xl"
            min={f.min_value ?? 0}
            max={f.max_value ?? undefined}
            value={v == null ? "" : String(v)}
            onChange={(e) => setValue(f.name, e.target.value)}
          />
          <FieldError show={err} />
        </div>
      )
    }
    if (f.field_type === "telephone") {
      return (
        <div key={f.id}>
          {labelNode}
          {subLabel}
          <Input {...common} type="tel" inputMode="tel" onChange={(e) => setValue(f.name, e.target.value)} />
          <FieldError show={err} />
        </div>
      )
    }
    if (f.field_type === "email") {
      return (
        <div key={f.id}>
          {labelNode}
          {subLabel}
          <Input {...common} type="email" onChange={(e) => setValue(f.name, e.target.value)} />
          <FieldError show={err} />
        </div>
      )
    }
    if (f.field_type === "heading" || f.field_type === "paragraph") {
      return (
        <div key={f.id} className="sm:col-span-2 lg:col-span-3">
          <p className="font-display text-[0.95rem] font-bold">{f.title_burmese}</p>
          {f.title_english && <p className="text-[0.8rem] text-muted-foreground">{f.title_english}</p>}
        </div>
      )
    }
    // short_text and any unknown scalar type fall back to a text input.
    return (
      <div key={f.id}>
        {labelNode}
        {subLabel}
        <Input {...common} maxLength={f.max_value ?? undefined} onChange={(e) => setValue(f.name, e.target.value)} />
        <FieldError show={err} />
      </div>
    )
  }

  const renderGeoBlock = (geoFields: FormFieldDef[]) => (
    <div key="__geo" className="sm:col-span-2 lg:col-span-3">
      <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
        {geoFields.map((f) => {
          const level = f.data_binding as GeoLevel
          const options = geoOptions(level)
          const val = geoValue(level)
          const req = f.is_required ? <span className="text-[var(--destructive)]"> *</span> : null
          const err = touched && f.is_required && !val
          return (
            <div key={f.id} className={level === "state_region" ? "sm:col-span-2 lg:col-span-3" : undefined}>
              <Label className="mb-1.5 block text-[0.78rem] font-semibold">
                {GEO_LABELS[level] ?? f.title_burmese}
                {req}
              </Label>
              <Select
                value={val != null ? String(val) : ""}
                onValueChange={(v) => setGeoLevel(level, v ? Number(v) : null)}
                disabled={options.length === 0}
              >
                <SelectTrigger className="h-10 rounded-xl">
                  <SelectValue placeholder={options.length === 0 ? "No options yet" : "Select…"} />
                </SelectTrigger>
                <SelectContent>
                  {options.map((o) => (
                    <SelectItem key={o.id} value={String(o.id)}>{o.burmese_name}</SelectItem>
                  ))}
                </SelectContent>
              </Select>
              <FieldError show={err} />
            </div>
          )
        })}
      </div>
    </div>
  )

  const renderRepeatingGroup = (f: FormFieldDef) => {
    const binding = f.data_binding
    const heading = (
      <div key={`${f.id}-h`} className="mb-2 flex items-center justify-between sm:col-span-2 lg:col-span-3">
        <h4 className="text-[0.8rem] font-bold uppercase tracking-wider text-muted-foreground">{f.title_burmese}</h4>
        {binding === "animal_rows" ? (
          <Button
            variant="outline" size="sm" className="h-8 gap-1 rounded-lg"
            onClick={f.name.toLowerCase().includes("small") ? addSmall : addLarge}
          >
            <Plus className="h-3.5 w-3.5" /> Add row
          </Button>
        ) : binding === "poultry_rows" ? (
          <Button variant="outline" size="sm" className="h-8 gap-1 rounded-lg" onClick={addPoultry}>
            <Plus className="h-3.5 w-3.5" /> Add row
          </Button>
        ) : null}
      </div>
    )

    if (binding === "poultry_rows") {
      return [
        heading,
        <PoultryTable
          key={f.id}
          rows={poultryRows}
          categories={catsByTypeCode("atID03")}
          update={(key, patch) => upsert(setPoultryRows, key, patch)}
          remove={(key) => setPoultryRows((p) => p.filter((r) => r.key !== key))}
          speciesFor={speciesForCategory}
          ageOptions={ageOptionsFor}
        />,
      ]
    }
    if (binding === "breeding_rows") {
      return [
        heading,
        <BreedingTable
          key={f.id}
          rows={breedingRows}
          categories={d.breeding}
          onChange={(categoryId, field, value) =>
            setBreedingOverrides((p) => ({
              ...p,
              [categoryId]: {
                male: p[categoryId]?.male ?? null,
                female: p[categoryId]?.female ?? null,
                [field]: value,
              },
            }))
          }
        />,
      ]
    }
    if (binding === "animal_rows") {
      const isSmall = f.name.toLowerCase().includes("small")
      const rows = isSmall ? smallRows : largeRows
      return [
        heading,
        <AnimalTable
          key={f.id}
          rows={rows}
          categories={isSmall ? catsByTypeCode("atID02") : catsByTypeCode("atID01")}
          update={(key, patch) => upsert(isSmall ? setSmallRows : setLargeRows, key, patch)}
          remove={(key) => (isSmall ? setSmallRows : setLargeRows)((p) => p.filter((r) => r.key !== key))}
          speciesFor={speciesForCategory}
          ageOptions={ageOptionsFor}
        />,
      ]
    }
    return (
      <p key={f.id} className="rounded-xl border border-dashed border-border/70 px-4 py-4 text-[0.8rem] text-muted-foreground sm:col-span-2 lg:col-span-3">
        “{f.title_burmese}” uses an unsupported repeating-group binding
        {binding ? ` (${binding})` : ""} — this table is not available in the web collector.
      </p>
    )
  }

  const renderSectionBody = (sectionFields: FormFieldDef[]) => {
    const geoFields = sectionFields
      .filter((f) => f.field_type === "geographic" && f.data_binding && (GEO_LEVELS as readonly string[]).includes(f.data_binding))
      .sort((a, b) => GEO_LEVELS.indexOf(a.data_binding as GeoLevel) - GEO_LEVELS.indexOf(b.data_binding as GeoLevel))
    const groupFields = sectionFields.filter((f) => f.field_type === "repeating_group")
    const scalarFields = sectionFields.filter((f) => f.field_type !== "geographic" && f.field_type !== "repeating_group")
    const gate = scalarFields.find((f) => f.field_type === "boolean")
    const gateOn = gate ? Boolean(getVal(gate.name)) : true

    return (
      <>
        {geoFields.length > 0 && (
          <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">{renderGeoBlock(geoFields)}</div>
        )}
        {scalarFields.length > 0 && (
          <div className={cn("grid gap-4 sm:grid-cols-2 lg:grid-cols-3", geoFields.length > 0 && "mt-5")}>
            {scalarFields.map((f) => renderScalar(f))}
          </div>
        )}
        {groupFields.length > 0 && gateOn && (
          <div className={cn("grid gap-4", (geoFields.length > 0 || scalarFields.length > 0) && "mt-5")}>
            {groupFields.flatMap((f) => renderRepeatingGroup(f))}
          </div>
        )}
      </>
    )
  }

  const totalAnimalRows = largeRows.length + smallRows.length
  const breedingEntered = breedingRows.filter((b) => (b.male ?? 0) + (b.female ?? 0) > 0).length

  return (
    <main className="w-full max-w-full overflow-x-hidden">
      {/* ---- header ---- */}
      <section className="flex flex-col gap-6 lg:flex-row lg:items-end lg:justify-between">
        <div>
          <Button variant="ghost" className="-ml-3 mb-2 h-8 gap-1.5 rounded-lg text-sm text-muted-foreground" onClick={() => navigate("/census-responses")}>
            <ArrowLeft className="h-4 w-4" /> Back to census responses
          </Button>
          <h1 className="font-display text-[clamp(1.8rem,3.4vw,2.6rem)] font-black leading-tight tracking-tight">
            {form.burmese_title}
          </h1>
          <p className="mt-2 max-w-2xl text-[0.92rem] leading-relaxed text-muted-foreground">
            {form.english_title} — v{form.version_number}. This form is defined by the administrator; every section,
            field and option below comes from the published definition and master data.
          </p>
          <div className="mt-3 flex flex-wrap gap-2">
            {activeSections.map((s) => (
              <Badge key={s.id} variant="outline" className="rounded-full border-border/80 text-[0.7rem]">
                {s.display_order} · {s.title_burmese}
              </Badge>
            ))}
          </div>
        </div>
      </section>

      <div className="mt-8 space-y-6">
        {activeSections.map((section, idx) => {
          const Icon = SECTION_ICONS[idx % SECTION_ICONS.length]
          return (
            <SectionShell
              key={section.id}
              index={idx + 1}
              icon={<Icon className="h-4 w-4" />}
              burmese={section.title_burmese}
              english={section.title_english ?? ""}
            >
              {renderSectionBody(fieldsBySection.get(section.id) ?? [])}
            </SectionShell>
          )
        })}

        {orphanFields && orphanFields.length > 0 && (
          <SectionShell
            index={sectionCount}
            icon={<ClipboardCheck className="h-4 w-4" />}
            burmese="အခြား အချက်အလက်များ"
            english="Other information"
          >
            <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">{orphanFields.map((f) => renderScalar(f))}</div>
          </SectionShell>
        )}

        {/* ---- summary + submit ---- */}
        <section data-reveal className="rounded-2xl border border-primary/25 bg-primary/[0.04] p-5 sm:p-6">
          <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
            <div>
              <span className="text-[0.7rem] uppercase tracking-wider text-muted-foreground">Large + small rows</span>
              <strong className="mt-1 block font-display text-xl">{totalAnimalRows}</strong>
            </div>
            <div>
              <span className="text-[0.7rem] uppercase tracking-wider text-muted-foreground">Poultry rows</span>
              <strong className="mt-1 block font-display text-xl">{poultryRows.length}</strong>
            </div>
            <div>
              <span className="text-[0.7rem] uppercase tracking-wider text-muted-foreground">Breeding entries</span>
              <strong className="mt-1 block font-display text-xl">{breedingEntered}</strong>
            </div>
            <div>
              <span className="text-[0.7rem] uppercase tracking-wider text-muted-foreground">Missing required</span>
              <strong className="mt-1 block font-display text-xl text-[var(--destructive)]">{missing.length}</strong>
            </div>
          </div>
          <div className="mt-5 flex flex-wrap items-center gap-3 border-t border-border/60 pt-5">
            <Button className="h-11 gap-2 rounded-xl px-6" onClick={submit} disabled={submitting}>
              {submitting ? <Loader2 className="h-4 w-4 animate-spin" /> : <CheckCircle2 className="h-4 w-4" />}
              {submitting ? "Submitting…" : "Submit census record"}
            </Button>
            <Button variant="ghost" onClick={() => navigate("/census-responses")}>
              Cancel
            </Button>
            {touched && missing.length > 0 && (
              <p className="text-[0.78rem] text-[var(--destructive)]">Missing: {missing.join(", ")}</p>
            )}
          </div>
        </section>
      </div>
    </main>
  )
}

/* --------------------------------------------------------- sub-components */

function SpeciesSelect({ species, value, onValue }: { species: SpeciesRow[]; value: number | null; onValue: (id: number | null) => void }) {
  return (
    <Select value={value ? String(value) : ""} onValueChange={(v) => onValue(v ? Number(v) : null)} disabled={species.length === 0}>
      <SelectTrigger className="h-9 min-w-[150px] rounded-lg text-sm">
        <SelectValue placeholder={species.length === 0 ? "No species" : "မျိုး…"} />
      </SelectTrigger>
      <SelectContent>
        {species.map((s) => (
          <SelectItem key={s.id} value={String(s.id)}>{s.burmese_name}</SelectItem>
        ))}
      </SelectContent>
    </Select>
  )
}

function CategorySelect({ value, onValue, data }: { value: number | null; onValue: (id: number | null) => void; data: CategoryRow[] }) {
  return (
    <Select value={value ? String(value) : ""} onValueChange={(v) => onValue(v ? Number(v) : null)}>
      <SelectTrigger className="h-9 min-w-[150px] rounded-lg text-sm">
        <SelectValue placeholder="Select category…" />
      </SelectTrigger>
      <SelectContent>
        {data.map((c) => (
          <SelectItem key={c.id} value={String(c.id)}>{c.burmese_name}</SelectItem>
        ))}
      </SelectContent>
    </Select>
  )
}

function AgeSelect({ groups, value, onValue }: { groups: AgeGroupRow[]; value: number | null; onValue: (id: number | null) => void }) {
  return (
    <Select value={value ? String(value) : ""} onValueChange={(v) => onValue(v ? Number(v) : null)} disabled={groups.length === 0}>
      <SelectTrigger className="h-9 min-w-[160px] rounded-lg text-sm">
        <SelectValue placeholder="Age group…" />
      </SelectTrigger>
      <SelectContent>
        {groups.map((g) => (
          <SelectItem key={g.id} value={String(g.id)}>{g.burmese_name}</SelectItem>
        ))}
      </SelectContent>
    </Select>
  )
}

function AnimalTable({
  rows,
  categories,
  update,
  remove,
  speciesFor,
  ageOptions,
}: {
  rows: AnimalRow[]
  categories: CategoryRow[]
  update: (key: number, patch: Partial<AnimalRow>) => void
  remove: (key: number) => void
  speciesFor: (categoryId: number | null) => SpeciesRow[]
  ageOptions: (categoryId: number | null) => AgeGroupRow[]
}) {
  return (
    <div className="overflow-x-auto rounded-xl border border-border/80">
      <table className="w-full min-w-[840px] text-sm">
        <thead>
          <tr className="border-b border-border/70 bg-muted/40 text-left text-[0.72rem] uppercase tracking-wider text-muted-foreground">
            <th className="px-3 py-2.5 font-semibold">အမျိုးအစား · Category</th>
            <th className="px-3 py-2.5 font-semibold">မျိုး · Breed</th>
            <th className="px-3 py-2.5 font-semibold">အသက်ပိုင်း · Age</th>
            <th className="px-3 py-2.5 text-right font-semibold">အထီး</th>
            <th className="px-3 py-2.5 text-right font-semibold">သင်းကွပ်</th>
            <th className="px-3 py-2.5 text-right font-semibold">အမ</th>
            <th className="w-12" />
          </tr>
        </thead>
        <tbody>
          {rows.map((r) => (
            <tr key={r.key} className="border-b border-border/50 last:border-0">
              <td className="px-3 py-2">
                <CategorySelect
                  value={r.categoryId}
                  onValue={(id) => update(r.key, { categoryId: id, speciesId: null, ageGroupId: null })}
                  data={categories}
                />
              </td>
              <td className="px-3 py-2">
                <SpeciesSelect species={speciesFor(r.categoryId)} value={r.speciesId} onValue={(id) => update(r.key, { speciesId: id })} />
              </td>
              <td className="px-3 py-2">
                <AgeSelect groups={ageOptions(r.categoryId)} value={r.ageGroupId} onValue={(id) => update(r.key, { ageGroupId: id })} />
              </td>
              {(["male", "castrated", "female"] as const).map((g) => (
                <td key={g} className="px-3 py-2">
                  <input
                    type="number"
                    min={0}
                    value={r[g] ?? ""}
                    onChange={(e) => update(r.key, { [g]: e.target.value === "" ? null : Number(e.target.value) } as Partial<AnimalRow>)}
                    className={cn("w-20", countInputCls)}
                    data-lpignore="true"
                    placeholder="0"
                  />
                </td>
              ))}
              <td className="px-3 py-2">
                <button onClick={() => remove(r.key)} className="grid h-7 w-7 place-items-center rounded-lg text-muted-foreground transition-colors hover:bg-destructive/10 hover:text-[var(--destructive)]" aria-label="Remove row">
                  <Trash2 className="h-3.5 w-3.5" />
                </button>
              </td>
            </tr>
          ))}
          {rows.length === 0 && (
            <tr>
              <td colSpan={7} className="px-3 py-6 text-center text-[0.8rem] text-muted-foreground">
                No rows yet – press “Add row” above.
              </td>
            </tr>
          )}
        </tbody>
      </table>
    </div>
  )
}

function PoultryTable({
  rows,
  categories,
  update,
  remove,
  speciesFor,
  ageOptions,
}: {
  rows: PoultryRow[]
  categories: CategoryRow[]
  update: (key: number, patch: Partial<PoultryRow>) => void
  remove: (key: number) => void
  speciesFor: (categoryId: number | null) => SpeciesRow[]
  ageOptions: (categoryId: number | null) => AgeGroupRow[]
}) {
  return (
    <div className="overflow-x-auto rounded-xl border border-border/80">
      <table className="w-full min-w-[720px] text-sm">
        <thead>
          <tr className="border-b border-border/70 bg-muted/40 text-left text-[0.72rem] uppercase tracking-wider text-muted-foreground">
            <th className="px-3 py-2.5 font-semibold">အမျိုးအစား</th>
            <th className="px-3 py-2.5 font-semibold">မျိုး (Breed)</th>
            <th className="px-3 py-2.5 font-semibold">အသက်ပိုင်း</th>
            <th className="px-3 py-2.5 text-right font-semibold">အထီး</th>
            <th className="px-3 py-2.5 text-right font-semibold">အမ</th>
            <th className="w-12" />
          </tr>
        </thead>
        <tbody>
          {rows.map((r) => (
            <tr key={r.key} className="border-b border-border/50 last:border-0">
              <td className="px-3 py-2">
                <CategorySelect value={r.categoryId} onValue={(id) => update(r.key, { categoryId: id, speciesId: null, ageGroupId: null })} data={categories} />
              </td>
              <td className="px-3 py-2">
                <SpeciesSelect species={speciesFor(r.categoryId)} value={r.speciesId} onValue={(id) => update(r.key, { speciesId: id })} />
              </td>
              <td className="px-3 py-2">
                <AgeSelect groups={ageOptions(r.categoryId)} value={r.ageGroupId} onValue={(id) => update(r.key, { ageGroupId: id })} />
              </td>
              <td className="px-3 py-2">
                <input type="number" min={0} value={r.male ?? ""} onChange={(e) => update(r.key, { male: e.target.value === "" ? null : Number(e.target.value) })} className={cn("w-20", countInputCls)} placeholder="0" />
              </td>
              <td className="px-3 py-2">
                <input type="number" min={0} value={r.female ?? ""} onChange={(e) => update(r.key, { female: e.target.value === "" ? null : Number(e.target.value) })} className={cn("w-20", countInputCls)} placeholder="0" />
              </td>
              <td className="px-3 py-2">
                <button onClick={() => remove(r.key)} className="grid h-7 w-7 place-items-center rounded-lg text-muted-foreground transition-colors hover:bg-destructive/10 hover:text-[var(--destructive)]" aria-label="Remove row">
                  <Trash2 className="h-3.5 w-3.5" />
                </button>
              </td>
            </tr>
          ))}
          {rows.length === 0 && (
            <tr>
              <td colSpan={6} className="px-3 py-6 text-center text-[0.8rem] text-muted-foreground">
                No poultry rows yet – press “Add row”.
              </td>
            </tr>
          )}
        </tbody>
      </table>
    </div>
  )
}

function BreedingTable({
  rows,
  categories,
  onChange,
}: {
  rows: BreedingRow[]
  categories: BreedingCategoryRow[]
  onChange: (categoryId: number, field: "male" | "female", value: number | null) => void
}) {
  return (
    <div className="overflow-x-auto rounded-xl border border-border/80">
      <table className="w-full min-w-[520px] text-sm">
        <thead>
          <tr className="border-b border-border/70 bg-muted/40 text-left text-[0.72rem] uppercase tracking-wider text-muted-foreground">
            <th className="px-3 py-2.5 font-semibold">မျိုးတိရစ္ဆာန် · Category</th>
            <th className="px-3 py-2.5 text-right font-semibold">အထီး · Male</th>
            <th className="px-3 py-2.5 text-right font-semibold">အမ · Female</th>
          </tr>
        </thead>
        <tbody>
          {rows.map((r) => {
            const name = categories.find((b) => b.id === r.categoryId)?.burmese_name
            return (
              <tr key={r.categoryId} className="border-b border-border/50 last:border-0">
                <td className="px-3 py-2 font-medium">{name ?? "—"}</td>
                <td className="px-3 py-2">
                  <input type="number" min={0} value={r.male ?? ""} onChange={(e) => onChange(r.categoryId, "male", e.target.value === "" ? null : Number(e.target.value))} className={cn("w-24", countInputCls)} data-lpignore="true" />
                </td>
                <td className="px-3 py-2">
                  <input type="number" min={0} value={r.female ?? ""} onChange={(e) => onChange(r.categoryId, "female", e.target.value === "" ? null : Number(e.target.value))} className={cn("w-24", countInputCls)} data-lpignore="true" />
                </td>
              </tr>
            )
          })}
        </tbody>
      </table>
    </div>
  )
}
