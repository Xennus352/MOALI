"use client"

import { useState } from "react"
import { useAuth } from "@/context/auth-context"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Checkbox } from "@/components/ui/checkbox"
import { Link, Navigate } from "react-router-dom"
import { useToast } from "@/components/ui/use-toast"
import { Logo, LogoMark } from "@/components/logo"
import moaliLogo from "@/assets/moali-logo.png"
import { Mail, Lock, MapPinned, ShieldCheck, Database, Eye, EyeOff, ArrowRight, Loader2 } from "lucide-react"

export function LoginPage() {
  const [email, setEmail] = useState("")
  const [password, setPassword] = useState("")
  const [showPassword, setShowPassword] = useState(false)
  const [isSubmitting, setIsSubmitting] = useState(false)
  const { login, status } = useAuth()
  const { toast } = useToast()

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!email || !password) {
      toast({
        title: "Missing details",
        description: "Please enter both your email and password.",
        variant: "destructive",
      })
      return
    }
    setIsSubmitting(true)
    try {
      await login(email, password)
      toast({ title: "Welcome back", description: "Session started successfully.", variant: "success" })
    } catch (err) {
      toast({
        title: "Login failed",
        description: err instanceof Error ? err.message : "Please check your credentials and try again.",
        variant: "destructive",
      })
    } finally {
      setIsSubmitting(false)
    }
  }

  if (status === "authenticated") {
    return <Navigate to="/dashboard" replace />
  }

  return (
    <div className="flex min-h-screen w-full bg-background">
      {/* ---- Cinematic brand panel ---- */}
      <aside className="relative hidden w-[52%] overflow-hidden bg-[#0c2218] lg:flex lg:flex-col">
        {/* Ambient art */}
        <div aria-hidden="true" className="absolute inset-0">
          <div className="absolute -left-40 -top-40 h-[34rem] w-[34rem] rounded-full bg-[#1b4d3e] blur-3xl" />
          <div className="absolute -bottom-48 right-[-8rem] h-[30rem] w-[30rem] rounded-full bg-[#e67e22]/20 blur-3xl" />
          <div
            className="grain absolute inset-0"
            style={{ backgroundSize: "26px 26px" }}
          />
          {/* dotted field grid */}
          <div
            className="absolute inset-0 opacity-[0.16]"
            style={{
              backgroundImage: "radial-gradient(circle, rgba(255,255,255,.6) 1px, transparent 1px)",
              backgroundSize: "26px 26px",
            }}
          />
          {/* dotted field grid */}
          <div
            className="absolute inset-0 opacity-[0.16]"
            style={{
              backgroundImage: "radial-gradient(circle, rgba(255,255,255,.6) 1px, transparent 1px)",
              backgroundSize: "26px 26px",
            }}
          />
        </div>

        <div className="relative flex flex-1 flex-col p-14 xl:p-20">
          <div className="inline-flex items-center rounded-2xl bg-white/95 p-2.5 pr-5 shadow-[0_18px_50px_-22px_rgb(0_0_0/0.7)] ring-1 ring-white/25 backdrop-blur-md">
            <Logo src={moaliLogo} />
          </div>

          {/* Cinematic left offset headline */}
          <div className="mt-auto max-w-xl">
            <h1 className="font-display text-[clamp(2.2rem,3.6vw,3.6rem)] font-black leading-[1.05] tracking-tight text-white text-balance">
              The national livestock census,{" "}
              <span className="text-[#e67e22]">in one console.</span>
            </h1>
            <p className="mt-5 max-w-md text-[0.95rem] leading-relaxed text-white/60">
              MOALI gives the Department of Livestock a single operational view of every
              household, animal, and region — from the first interview to final validation.
            </p>

            <div className="mt-10 flex flex-wrap gap-3">
              {[
                { icon: MapPinned, label: "15 states & regions" },
                { icon: ShieldCheck, label: "Validated fieldwork" },
                { icon: Database, label: "One source of truth" },
              ].map((f) => (
                <span
                  key={f.label}
                  className="inline-flex items-center gap-2 rounded-full border border-white/10 bg-white/[0.06] px-4 py-2 text-[0.8rem] font-medium text-white/80 backdrop-blur"
                >
                  <f.icon className="h-4 w-4 text-[#e67e22]" />
                  {f.label}
                </span>
              ))}
            </div>
          </div>

          {/* footer quote */}
          <div className="mt-14 border-l-2 border-[#e67e22]/60 pl-4">
            <p className="max-w-sm text-[0.82rem] italic leading-relaxed text-white/55">
              “Every number on this board is a farm, a family, and a future in Burmese
              agriculture.”
            </p>
            <p className="mt-2 text-[0.7rem] font-semibold uppercase tracking-[0.2em] text-white/35">
              LBVD Data Directorate
            </p>
          </div>
        </div>
      </aside>

      {/* ---- Form panel ---- */}
      <main className="relative flex w-full flex-1 items-center justify-center px-6 py-12 sm:px-10">
        <div
          aria-hidden="true"
          className="pointer-events-none absolute inset-0 mesh-green opacity-60 dark:mesh-green-dark"
        />

        <div className="relative w-full max-w-[26rem]">
          {/* Mobile brand */}
          <div className="mb-10 flex justify-center lg:hidden">
            <Logo src={moaliLogo} />
          </div>

          <div className="mb-8 text-center lg:text-left">
            <p className="text-[0.7rem] font-bold uppercase tracking-[0.24em] text-primary">
              Secure admin access
            </p>
            <h2 className="mt-2 font-display text-[2rem] font-black leading-tight tracking-tight text-foreground">
              Welcome back
            </h2>
            <p className="mt-2 text-sm text-muted-foreground">
              Sign in to your administration workspace to continue.
            </p>
          </div>

          <form onSubmit={handleSubmit} className="space-y-5">
            <div className="space-y-2">
              <Label htmlFor="login-email" className="text-[0.8rem] font-semibold text-foreground">
                Email address
              </Label>
              <div className="relative">
                <Mail className="pointer-events-none absolute left-3.5 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground" />
                <Input
                  id="login-email"
                  type="email"
                  autoComplete="email"
                  placeholder="you@moali.gov.mm"
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  className="h-12 rounded-xl border-input bg-card pl-11 text-[0.92rem] shadow-[0_1px_2px_rgb(17_34_15/0.04)] focus-visible:ring-4 focus-visible:ring-primary/15"
                  required
                />
              </div>
            </div>

            <div className="space-y-2">
              <div className="flex items-center justify-between">
                <Label htmlFor="login-password" className="text-[0.8rem] font-semibold text-foreground">
                  Password
                </Label>
                <a
                  href="#"
                  onClick={(e) => e.preventDefault()}
                  className="text-[0.78rem] font-medium text-primary hover:underline"
                >
                  Forgot password?
                </a>
              </div>
              <div className="relative">
                <Lock className="pointer-events-none absolute left-3.5 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground" />
                <Input
                  id="login-password"
                  type={showPassword ? "text" : "password"}
                  autoComplete="current-password"
                  placeholder="••••••••••"
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  className="h-12 rounded-xl border-input bg-card pl-11 pr-11 text-[0.92rem] shadow-[0_1px_2px_rgb(17_34_15/0.04)] focus-visible:ring-4 focus-visible:ring-primary/15"
                  required
                />
                <button
                  type="button"
                  onClick={() => setShowPassword((v) => !v)}
                  className="absolute right-3.5 top-1/2 -translate-y-1/2 rounded-md p-1 text-muted-foreground transition-colors hover:text-foreground"
                  aria-label={showPassword ? "Hide password" : "Show password"}
                >
                  {showPassword ? <EyeOff className="h-4 w-4" /> : <Eye className="h-4 w-4" />}
                </button>
              </div>
            </div>

            <div className="flex items-center justify-between pt-1">
              <label className="flex cursor-pointer items-center gap-2.5 text-[0.82rem] font-medium text-muted-foreground">
                <Checkbox defaultChecked /> Remember me
              </label>
              <span className="inline-flex items-center gap-1.5 text-[0.72rem] font-semibold text-success dark:text-[var(--success)]">
                <span className="h-1.5 w-1.5 rounded-full bg-success dark:bg-[var(--success)]" />
                Secure session
              </span>
            </div>

            <Button
              type="submit"
              disabled={isSubmitting}
              className="h-12 w-full rounded-xl text-[0.95rem] font-bold shadow-[0_14px_32px_-14px_rgb(27_77_62/0.75)] transition-all hover:shadow-[0_18px_40px_-14px_rgb(27_77_62/0.85)] disabled:opacity-70"
            >
              {isSubmitting ? (
                <>
                  <Loader2 className="h-4 w-4 animate-spin" /> Signing you in…
                </>
              ) : (
                <>
                  Sign in <ArrowRight className="h-4 w-4" />
                </>
              )}
            </Button>
          </form>

          <p className="mt-8 text-center text-[0.82rem] text-muted-foreground">
            New to the workspace?{" "}
            <Link to="/register" className="font-semibold text-primary hover:underline">
              Create an account
            </Link>
          </p>

          <div className="mt-6 flex items-center justify-center gap-2 text-[0.68rem] text-muted-foreground/80">
            <LogoMark size={16} src={moaliLogo} />
            <span>MOALI · LBVD Livestock Census Administration · v1.0</span>
          </div>
        </div>
      </main>
    </div>
  )
}