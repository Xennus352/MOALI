"use client"
/* eslint-disable react-refresh/only-export-components -- cohesive i18n module: provider, hook and helpers are intentionally co-located. */

/**
 * Lightweight localization for the admin console.
 *
 * Supports exactly two languages — Myanmar (`my`, the default) and English
 * (`en`) — which matches the mobile collector app. No third-party dependency
 * is needed: translations are plain dictionaries and the current language is
 * persisted to `localStorage` so it survives reloads. Switching language is a
 * pure React state change, so unsaved form drafts are never lost.
 */
import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useState,
} from "react"
import {
  DEFAULT_LANG,
  LANG_LABEL,
  SUPPORTED_LANGS,
  translate,
  type Lang,
} from "./dictionaries"

export { SUPPORTED_LANGS, LANG_LABEL, DEFAULT_LANG }
export type { Lang }

const STORAGE_KEY = "moali_lang"

interface I18nValue {
  /** Active language code. */
  lang: Lang
  /** Change the active language; persists and re-renders without a reload. */
  setLang: (lang: Lang) => void
  /** Translate a key, with optional `{placeholder}` interpolation. */
  t: (key: string, vars?: Record<string, string | number>) => string
}

const I18nContext = createContext<I18nValue | null>(null)

function readStoredLang(): Lang {
  if (typeof window === "undefined") return DEFAULT_LANG
  try {
    const stored = window.localStorage.getItem(STORAGE_KEY)
    if (stored && (SUPPORTED_LANGS as readonly string[]).includes(stored)) {
      return stored as Lang
    }
  } catch {
    // localStorage may be unavailable (private mode); fall through.
  }
  return DEFAULT_LANG
}

export function I18nProvider({ children }: { children: React.ReactNode }) {
  const [lang, setLangState] = useState<Lang>(readStoredLang)

  // Reflect the language on <html lang> for accessibility / correct font
  // shaping. Setting a DOM attribute is not React state, so this is safe in an
  // effect (and only runs when the language actually changes).
  useEffect(() => {
    document.documentElement.lang = lang
  }, [lang])

  const setLang = useCallback((next: Lang) => {
    setLangState(next)
    try {
      window.localStorage.setItem(STORAGE_KEY, next)
    } catch {
      // Ignore persistence failures; the in-memory language still applies.
    }
  }, [])

  const value = useMemo<I18nValue>(
    () => ({
      lang,
      setLang,
      t: (key, vars) => translate(lang, key, vars),
    }),
    [lang, setLang],
  )

  return <I18nContext.Provider value={value}>{children}</I18nContext.Provider>
}

export function useI18n(): I18nValue {
  const ctx = useContext(I18nContext)
  if (!ctx) {
    throw new Error("useI18n must be used within an I18nProvider")
  }
  return ctx
}

/** Convenience hook when only the translator is needed. */
export function useT() {
  return useI18n().t
}

/**
 * Pick the right string for the active language from a pair of bilingual
 * values, falling back to whichever is present. Used to render bilingual
 * master-data / form definitions.
 */
export function pickLocalized(
  lang: Lang,
  burmese: string | null | undefined,
  english: string | null | undefined,
): string {
  if (lang === "en") return english || burmese || ""
  return burmese || english || ""
}
