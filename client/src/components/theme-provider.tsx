"use client"

import * as React from "react"
import { useEffect, useState, useMemo } from "react"
import { ThemeContext } from "./theme-context"

type Theme = "light" | "dark" | "system"

function getInitialTheme(defaultTheme: Theme): Theme {
  if (typeof window !== "undefined") {
    const stored = localStorage.getItem("theme") as Theme | null
    if (stored) return stored
  }
  return defaultTheme
}

function getResolvedTheme(theme: Theme, enableSystem: boolean): "light" | "dark" {
  if (theme === "system" && enableSystem && typeof window !== "undefined") {
    return window.matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light"
  }
  return theme === "dark" ? "dark" : "light"
}

export function ThemeProvider({
  children,
  defaultTheme = "system",
  enableSystem = true,
}: {
  children: React.ReactNode
  defaultTheme?: Theme
  enableSystem?: boolean
  attribute?: "class" | "data-theme"
}) {
  const [theme, setTheme] = useState<Theme>(() => getInitialTheme(defaultTheme))

  const resolvedTheme = useMemo(
    () => getResolvedTheme(theme, enableSystem),
    [theme, enableSystem]
  )

  useEffect(() => {
    const root = document.documentElement
    root.classList.remove("light", "dark")
    root.classList.add(resolvedTheme)
    localStorage.setItem("theme", theme)
  }, [theme, resolvedTheme])

  useEffect(() => {
    if (!enableSystem || theme !== "system") return

    const mediaQuery = window.matchMedia("(prefers-color-scheme: dark)")
    const handleChange = () => {
      const resolved = mediaQuery.matches ? "dark" : "light"
      const root = document.documentElement
      root.classList.remove("light", "dark")
      root.classList.add(resolved)
    }

    mediaQuery.addEventListener("change", handleChange)
    return () => mediaQuery.removeEventListener("change", handleChange)
  }, [enableSystem, theme])

  return (
    <ThemeContext.Provider value={{ theme, setTheme, resolvedTheme }}>
      {children}
    </ThemeContext.Provider>
  )
}