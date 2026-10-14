"use client"

import { Navigate, useLocation } from "react-router-dom"
import { Logo } from "@/components/logo"
import moaliLogo from "@/assets/moali-logo.png"
import { useAuth } from "@/context/auth-context"
import { Lottie } from "lottie-react"
import lottieJson from "@/assets/lottie-loader.json"

/** Gate for authenticated areas: never renders protected content until the
 *  session has been confirmed by the server (the httpOnly cookie). */
export function RequireAuth({ children }: { children: React.ReactNode }) {
  const { status } = useAuth()
  const location = useLocation()

  if (status === "loading") {
    return (
      <div className="flex min-h-screen flex-col items-center justify-center p-8">
        <Logo compact src={moaliLogo} markSize={56} className="mb-8" />
        <Lottie src={lottieJson} loop autoplay className="h-28 w-28" />
        <p className="mt-4 animate-pulse-slow text-sm text-muted-foreground">
          Verifying your session…
        </p>
      </div>
    )
  }

  if (status === "unauthenticated") {
    return <Navigate to="/login" replace state={{ from: location.pathname }} />
  }

  return <>{children}</>
}
