"use client"

import { createContext, useContext } from "react"

export type AuthStatus = "unauthenticated" | "authenticated" | "loading"

export interface AuthUser {
  id: string
  name: string
  email: string
  role: string
}

export interface AuthContextType {
  status: AuthStatus
  user: AuthUser | null
  login: (email: string, password: string) => Promise<void>
  register: (name: string, email: string, password: string) => Promise<void>
  logout: () => Promise<void>
  refresh: () => Promise<void>
}

export const AuthContext = createContext<AuthContextType | null>(null)

export function useAuth(): AuthContextType {
  const ctx = useContext(AuthContext)
  if (!ctx) {
    throw new Error("useAuth must be used within an AuthProvider")
  }
  return ctx
}