"use client"

import { useState } from "react"
import { useAuth } from "@/context/auth-context"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Link, Navigate, useNavigate } from "react-router-dom"
import { useToast } from "@/components/ui/use-toast"
import { Logo } from "@/components/logo"
import moaliLogo from "@/assets/moali-logo.png"
import { Mail, Lock, User, ArrowRight, Loader2, Eye, EyeOff } from "lucide-react"

export function RegisterPage() {
  const [name, setName] = useState("")
  const [email, setEmail] = useState("")
  const [password, setPassword] = useState("")
  const [confirm, setConfirm] = useState("")
  const [showPassword, setShowPassword] = useState(false)
  const [isSubmitting, setIsSubmitting] = useState(false)
  const { register, status } = useAuth()
  const navigate = useNavigate()
  const { toast } = useToast()

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    if (password.length < 8) {
      toast({
        title: "Password too short",
        description: "Use at least 8 characters for your password.",
        variant: "destructive",
      })
      return
    }
    if (password !== confirm) {
      toast({
        title: "Passwords do not match",
        description: "Please re-enter the same password in both fields.",
        variant: "destructive",
      })
      return
    }
    setIsSubmitting(true)
    try {
      await register(name, email, password)
      toast({ title: "Account created", description: "Welcome aboard — your session has started.", variant: "success" })
      navigate("/dashboard", { replace: true })
    } catch (err) {
      toast({
        title: "Registration failed",
        description:
          err instanceof Error ? err.message : "Please check your details and try again.",
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
    <div className="flex min-h-screen w-full items-center justify-center bg-background px-6 py-12">
      <div
        aria-hidden="true"
        className="pointer-events-none fixed inset-0 mesh-green opacity-70 dark:mesh-green-dark"
      />

      <div className="relative w-full max-w-[26rem]">
        <div className="mb-10 flex justify-center lg:hidden">
          <Logo src={moaliLogo} />
        </div>

        <div className="mb-8 text-center">
          <p className="text-[0.7rem] font-bold uppercase tracking-[0.24em] text-primary">
            Join the workspace
          </p>
          <h2 className="mt-2 font-display text-[2rem] font-black leading-tight tracking-tight">
            Create your account
          </h2>
          <p className="mt-2 text-sm text-muted-foreground">
            Collectors and admins sign up below. Your administrator can adjust roles after
            approval.
          </p>
        </div>

        <form onSubmit={handleSubmit} className="space-y-5">
          <div className="space-y-2">
            <Label htmlFor="reg-name" className="text-[0.8rem] font-semibold">
              Full name
            </Label>
            <div className="relative">
              <User className="pointer-events-none absolute left-3.5 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground" />
              <Input
                id="reg-name"
                type="text"
                autoComplete="name"
                placeholder="e.g. Daw Khin Mar"
                value={name}
                onChange={(e) => setName(e.target.value)}
                className="h-12 rounded-xl border-input bg-card pl-11 shadow-[0_1px_2px_rgb(17_34_15/0.04)] focus-visible:ring-4 focus-visible:ring-primary/15"
              />
            </div>
          </div>

          <div className="space-y-2">
            <Label htmlFor="reg-email" className="text-[0.8rem] font-semibold">
              Email address
            </Label>
            <div className="relative">
              <Mail className="pointer-events-none absolute left-3.5 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground" />
              <Input
                id="reg-email"
                type="email"
                autoComplete="email"
                placeholder="you@moali.gov.mm"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                className="h-12 rounded-xl border-input bg-card pl-11 shadow-[0_1px_2px_rgb(17_34_15/0.04)] focus-visible:ring-4 focus-visible:ring-primary/15"
                required
              />
            </div>
          </div>

          <div className="space-y-2">
            <Label htmlFor="reg-password" className="text-[0.8rem] font-semibold">
              Password
            </Label>
            <div className="relative">
              <Lock className="pointer-events-none absolute left-3.5 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground" />
              <Input
                id="reg-password"
                type={showPassword ? "text" : "password"}
                autoComplete="new-password"
                placeholder="At least 8 characters"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                className="h-12 rounded-xl border-input bg-card pl-11 pr-11 shadow-[0_1px_2px_rgb(17_34_15/0.04)] focus-visible:ring-4 focus-visible:ring-primary/15"
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

          <div className="space-y-2">
            <Label htmlFor="reg-confirm" className="text-[0.8rem] font-semibold">
              Confirm password
            </Label>
            <div className="relative">
              <Lock className="pointer-events-none absolute left-3.5 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground" />
              <Input
                id="reg-confirm"
                type={showPassword ? "text" : "password"}
                autoComplete="new-password"
                placeholder="Repeat your password"
                value={confirm}
                onChange={(e) => setConfirm(e.target.value)}
                className="h-12 rounded-xl border-input bg-card pl-11 shadow-[0_1px_2px_rgb(17_34_15/0.04)] focus-visible:ring-4 focus-visible:ring-primary/15"
                required
              />
            </div>
          </div>

          <Button
            type="submit"
            disabled={isSubmitting}
            className="h-12 w-full rounded-xl text-[0.95rem] font-bold shadow-[0_14px_32px_-14px_rgb(27_77_62/0.75)] disabled:opacity-70"
          >
            {isSubmitting ? (
              <>
                <Loader2 className="h-4 w-4 animate-spin" /> Creating your account…
              </>
            ) : (
              <>
                Create account <ArrowRight className="h-4 w-4" />
              </>
            )}
          </Button>
        </form>

        <p className="mt-8 text-center text-[0.82rem] text-muted-foreground">
          Already have an account?{" "}
          <Link to="/login" className="font-semibold text-primary hover:underline">
            Sign in instead
          </Link>
        </p>
      </div>
    </div>
  )
}