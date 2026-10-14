"use client"

import { useState } from "react"
import { useAuth } from "@/context/auth-context"
import { api } from "@/lib/api"
import { useToast } from "@/components/ui/use-toast"
import { PageHeader } from "@/components/layout/page-header"
import { Card, CardHeader, CardTitle, CardDescription } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Badge } from "@/components/ui/badge"
import { formatDate } from "@/lib/api"
import { useNavigate } from "react-router-dom"
import { Loader2, KeyRound, Globe, Lock } from "lucide-react"

export function SettingsPage() {
  const { user, logout } = useAuth()
  const { toast } = useToast()
  const navigate = useNavigate()

  const [current, setCurrent] = useState("")
  const [next, setNext] = useState("")
  const [confirm, setConfirm] = useState("")
  const [submitting, setSubmitting] = useState(false)

  const changePassword = async () => {
    if (next.length < 8) {
      toast({ title: "Password too short", description: "Use at least 8 characters.", variant: "destructive" })
      return
    }
    if (next !== confirm) {
      toast({ title: "Passwords do not match", description: "Please confirm the new password.", variant: "destructive" })
      return
    }
    setSubmitting(true)
    try {
      await api.post("/api/v1/auth/change-password", { current_password: current, new_password: next })
      toast({ title: "Password updated", description: "All sessions were revoked — please sign in again.", variant: "success" })
      await logout()
      navigate("/login", { replace: true })
    } catch (err) {
      toast({
        title: "Could not update password",
        description: err instanceof Error ? err.message : "Check your current password and try again.",
        variant: "destructive",
      })
    } finally {
      setSubmitting(false)
    }
  }

  return (
    <main className="w-full">
      <PageHeader
        title="Settings"
        description="Your account details and security preferences."
      />

      <div className="grid grid-flow-dense grid-cols-1 gap-5 xl:grid-cols-3">
        <Card data-reveal className="border-border/80 bg-card">
          <CardHeader className="pb-2">
            <Globe className="mb-2 h-5 w-5 text-primary" />
            <CardTitle className="text-[1rem]">Profile</CardTitle>
            <CardDescription>How you appear in the workspace</CardDescription>
          </CardHeader>
          <div className="space-y-4 px-6 pb-6">
            <div className="flex items-center gap-3">
              <span className="grid h-12 w-12 place-items-center rounded-full bg-gradient-to-br from-[#2c6b51] to-[#123626] font-display text-lg font-bold text-white">
                {(user?.name || "U").slice(0, 1).toUpperCase()}
              </span>
              <div>
                <p className="font-semibold text-foreground">{user?.name || "—"}</p>
                <p className="text-[0.8rem] text-muted-foreground">{user?.email || "—"}</p>
              </div>
            </div>
            <div className="grid grid-cols-2 gap-3">
              <div className="rounded-xl border border-border/60 bg-muted/30 p-3">
                <p className="text-[0.66rem] font-semibold uppercase tracking-wider text-muted-foreground">Role</p>
                <p className="mt-1 text-[0.9rem] font-semibold capitalize text-foreground">{user?.role || "user"}</p>
              </div>
              <div className="rounded-xl border border-border/60 bg-muted/30 p-3">
                <p className="text-[0.66rem] font-semibold uppercase tracking-wider text-muted-foreground">Session</p>
                <p className="mt-1 text-[0.9rem] font-semibold text-foreground">HttpOnly cookie</p>
              </div>
            </div>
            <div className="flex flex-wrap gap-2">
              <Badge variant="outline" className="border-transparent bg-success/10 font-semibold text-[var(--success)]">
                Secure channel
              </Badge>
              <Badge variant="outline" className="border-transparent bg-muted text-muted-foreground">
                {user?.role}
              </Badge>
            </div>
            <p className="text-[0.72rem] text-muted-foreground">
              Last profile load: {formatDate(new Date().toISOString())}
            </p>
          </div>
        </Card>

        <Card data-reveal className="border-border/80 bg-card xl:col-span-2">
          <CardHeader className="pb-2">
            <KeyRound className="mb-2 h-5 w-5 text-primary" />
            <CardTitle className="text-[1rem]">Change password</CardTitle>
            <CardDescription>
              Changing your password revokes every active session immediately (session version bump).
            </CardDescription>
          </CardHeader>
          <div className="grid grid-cols-1 gap-4 px-6 pb-6 sm:grid-cols-3">
            <div className="space-y-1.5">
              <Label htmlFor="cur-pw" className="text-[0.8rem] font-semibold">Current password</Label>
              <Input id="cur-pw" type="password" value={current} onChange={(e) => setCurrent(e.target.value)} className="rounded-xl" />
            </div>
            <div className="space-y-1.5">
              <Label htmlFor="new-pw" className="text-[0.8rem] font-semibold">New password</Label>
              <Input id="new-pw" type="password" value={next} onChange={(e) => setNext(e.target.value)} className="rounded-xl" />
            </div>
            <div className="space-y-1.5">
              <Label htmlFor="cf-pw" className="text-[0.8rem] font-semibold">Confirm new password</Label>
              <Input id="cf-pw" type="password" value={confirm} onChange={(e) => setConfirm(e.target.value)} className="rounded-xl" />
            </div>
            <div className="flex items-end sm:col-span-3">
              <Button className="rounded-xl" onClick={changePassword} disabled={submitting}>
                {submitting ? <Loader2 className="h-4 w-4 animate-spin" /> : <Lock className="h-4 w-4" />} Update password
              </Button>
            </div>
          </div>
        </Card>
      </div>
    </main>
  )
}