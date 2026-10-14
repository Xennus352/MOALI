"use client"

import { useCallback, useEffect, useState } from "react"
import { AuthContext, type AuthStatus, type AuthUser } from "./auth-context"

/** Resolve the current session from the backend via the httpOnly cookie. */
async function fetchMe(): Promise<AuthUser | null> {
  try {
    const res = await fetch("/api/v1/auth/me", { credentials: "same-origin" })
    if (!res.ok) return null
    const data = await res.json()
    return {
      id: String(data.id),
      name: data.name || data.email.split("@")[0],
      email: data.email,
      role: data.role || "user",
    }
  } catch {
    return null
  }
}

async function parseError(res: Response): Promise<string> {
  try {
    const data = await res.json()
    return data?.detail || "Request failed"
  } catch {
    return "Request failed"
  }
}

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const [status, setStatus] = useState<AuthStatus>("loading")
  const [user, setUser] = useState<AuthUser | null>(null)

  // Resolve session on mount via the true session source (the httpOnly cookie)
  useEffect(() => {
    let cancelled = false
    ;(async () => {
      const me = await fetchMe()
      if (cancelled) return
      setUser(me)
      setStatus(me ? "authenticated" : "unauthenticated")
    })()
    return () => {
      cancelled = true
    }
  }, [])

  const login = useCallback(async (email: string, password: string) => {
    const res = await fetch("/api/v1/auth/login/cookie", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ email, password }),
      credentials: "same-origin",
    })
    if (!res.ok) throw new Error(await parseError(res))

    const me = await fetchMe()
    setUser(me)
    setStatus(me ? "authenticated" : "unauthenticated")
  }, [])

  const register = useCallback(
    async (name: string, email: string, password: string) => {
      const res = await fetch("/api/v1/auth/register", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ name, email, password, role: "user" }),
        credentials: "same-origin",
      })
      if (!res.ok) throw new Error(await parseError(res))
      // Auto-login after successful registration
      await login(email, password)
    },
    [login]
  )

  const logout = useCallback(async () => {
    try {
      await fetch("/api/v1/auth/logout", { method: "POST", credentials: "same-origin" })
    } catch {
      // Ignore network errors; still clear local session state
    } finally {
      setUser(null)
      setStatus("unauthenticated")
    }
  }, [])

  const refresh = useCallback(async () => {
    const me = await fetchMe()
    setUser(me)
    setStatus(me ? "authenticated" : "unauthenticated")
  }, [])

  return (
    <AuthContext.Provider value={{ status, user, login, register, logout, refresh }}>
      {children}
    </AuthContext.Provider>
  )
}

export default AuthProvider