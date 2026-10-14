"use client"

/**
 * Centralised API client for the MOALI / LBVD census backend.
 *
 * Every call is authenticated with the HttpOnly session cookie (`credentials:
 * "include"`). Errors are unwrapped from FastAPI's `{ "detail": ... }` payload
 * so the UI can render them directly.
 */

import { translate, type Lang } from "@/lib/i18n/dictionaries"

export class ApiError extends Error {
  status: number
  detail: unknown

  constructor(status: number, detail: unknown) {
    const message =
      typeof detail === "string"
        ? detail
        : detail && typeof detail === "object"
          ? JSON.stringify(detail)
          : `Request failed (${status})`
    super(message)
    this.name = "ApiError"
    this.status = status
    this.detail = detail
  }
}

async function request<T>(path: string, options: RequestInit = {}): Promise<T> {
  // Only FormData uploads manage their own Content-Type (the browser sets the
  // multipart boundary). Every JSON body — api.post/patch/put stringify before
  // calling — must be labelled application/json, otherwise `fetch` falls back to
  // text/plain and FastAPI cannot parse the body (422/500).
  const isFormData = options.body instanceof FormData
  const hasBody = options.body !== undefined && options.body !== null

  const headers = new Headers(options.headers)
  if (!isFormData && hasBody && !headers.has("Content-Type")) {
    headers.set("Content-Type", "application/json")
  }

  const res = await fetch(path, { ...options, headers, credentials: "include" })

  const text = await res.text()
  let data: unknown = null
  if (text) {
    try {
      data = JSON.parse(text)
    } catch {
      data = text
    }
  }

  if (!res.ok) {
    const detail =
      (data as { detail?: unknown } | undefined)?.detail ??
      (data as { message?: unknown } | undefined)?.message
    throw new ApiError(res.status, detail ?? `HTTP ${res.status}`)
  }

  return data as T
}

export interface ListResponse<T> {
  items: T[]
  total: number
  page: number
  page_size: number
  pages: number
}

export const api = {
  get<T>(path: string): Promise<T> {
    return request<T>(path)
  },
  post<T>(path: string, body?: unknown): Promise<T> {
    return request<T>(path, {
      method: "POST",
      body: body === undefined ? null : JSON.stringify(body),
    })
  },
  patch<T>(path: string, body?: unknown): Promise<T> {
    return request<T>(path, {
      method: "PATCH",
      body: body === undefined ? null : JSON.stringify(body),
    })
  },
  put<T>(path: string, body?: unknown): Promise<T> {
    return request<T>(path, {
      method: "PUT",
      body: body === undefined ? null : JSON.stringify(body),
    })
  },
  delete<T>(path: string): Promise<T> {
    return request<T>(path, { method: "DELETE" })
  },
}

/** Open a server-side CSV download in the current tab (authenticated cookie). */
export function downloadCsv(path: string) {
  window.open(path, "_self")
}

/**
 * The active UI language, read straight from the same localStorage key the
 * i18n provider writes. Reading it here lets every existing `timeAgo(...)` /
 * `formatDate(...)` call become localized without threading `lang` through
 * dozens of call sites; components re-render when the provider's language
 * changes, so the value is always fresh at render time.
 */
function activeLang(): Lang {
  if (typeof window === "undefined") return "my"
  try {
    const stored = window.localStorage.getItem("moali_lang")
    if (stored === "en" || stored === "my") return stored
  } catch {
    // localStorage may be unavailable; fall through to the default.
  }
  return "my"
}

/** Small, localized relative-time label for audit/submission timestamps. */
export function timeAgo(iso?: string | null, lang: Lang = activeLang()): string {
  if (!iso) return "—"
  const then = new Date(iso).getTime()
  if (Number.isNaN(then)) return "—"
  const diffSec = Math.max(0, Math.floor((Date.now() - then) / 1000))
  if (diffSec < 45) return translate(lang, "time.now")
  if (diffSec < 3600) return translate(lang, "time.minutesAgo", { n: Math.round(diffSec / 60) })
  if (diffSec < 86400) return translate(lang, "time.hoursAgo", { n: Math.round(diffSec / 3600) })
  if (diffSec < 2592000) return translate(lang, "time.daysAgo", { n: Math.round(diffSec / 86400) })
  if (diffSec < 31536000) return translate(lang, "time.monthsAgo", { n: Math.round(diffSec / 2592000) })
  return translate(lang, "time.yearsAgo", { n: Math.round(diffSec / 31536000) })
}

/** Localized short date (Myanmar numerals are not used by ICU for `my-MM`). */
export function formatDate(iso?: string | null, lang: Lang = activeLang()): string {
  if (!iso) return "—"
  const d = new Date(iso)
  if (Number.isNaN(d.getTime())) return iso
  return d.toLocaleDateString(lang === "en" ? "en-GB" : "my-MM", {
    day: "2-digit",
    month: "short",
    year: "numeric",
  })
}