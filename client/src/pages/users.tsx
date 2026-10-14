"use client"

import { useState } from "react"
import { useInfiniteQuery, useQueryClient } from "@tanstack/react-query"
import { api, formatDate, type ListResponse } from "@/lib/api"
import { useInfiniteScroll } from "@/hooks/use-infinite-scroll"
import { useToast } from "@/components/ui/use-toast"
import { PageHeader } from "@/components/layout/page-header"
import { Card } from "@/components/ui/card"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table"
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogDescription, DialogFooter } from "@/components/ui/dialog"
import { Loader2, UserPlus, RotateCcw, ShieldOff, PauseCircle, PlayCircle, Trash2 } from "lucide-react"

interface User {
  id: number
  email: string
  name: string | null
  role: string
  is_active: boolean
  is_superuser: boolean
  last_login_at: string | null
  created_at: string
}

const ROLES = ["admin", "reviewer", "enumerator", "analyst", "user"]
const ROLE_COLORS: Record<string, string> = {
  admin: "bg-[#1b4d3e]/15 text-[var(--success)]",
  reviewer: "bg-primary/10 text-primary",
  enumerator: "bg-chart-4/15 text-chart-4",
  analyst: "bg-warning/15 text-[var(--warning)]",
  user: "bg-muted text-muted-foreground",
}

export function UsersPage() {
  const qc = useQueryClient()
  const { toast } = useToast()
  const [createOpen, setCreateOpen] = useState(false)
  const [resetTarget, setResetTarget] = useState<User | null>(null)
  const [submitting, setSubmitting] = useState(false)

  const {
    data: users,
    isLoading,
    isFetchingNextPage,
    hasNextPage,
    fetchNextPage,
  } = useInfiniteQuery<ListResponse<User>>({
    queryKey: ["users"],
    queryFn: ({ pageParam }) =>
      api.get<ListResponse<User>>(`/api/v1/users?page=${pageParam}&page_size=25`),
    initialPageParam: 1,
    getNextPageParam: (last) => (last.page < last.pages ? last.page + 1 : undefined),
    retry: 1,
  })

  const rows = users?.pages.flatMap((p) => p.items) ?? []
  const total = users?.pages[0]?.total ?? 0

  const sentinelRef = useInfiniteScroll(
    () => { if (hasNextPage && !isFetchingNextPage) fetchNextPage() },
    Boolean(hasNextPage) && !isFetchingNextPage,
  )

  // create form
  const [form, setForm] = useState({ email: "", name: "", password: "", role: "enumerator" })
  const [resetPw, setResetPw] = useState("")

  const refresh = () => qc.invalidateQueries({ queryKey: ["users"] })

  const createUser = async () => {
    setSubmitting(true)
    try {
      await api.post("/api/v1/users", form)
      setCreateOpen(false)
      setForm({ email: "", name: "", password: "", role: "enumerator" })
      refresh()
      toast({ title: "User created", description: `${form.email} can now sign in.`, variant: "success" })
    } catch (err) {
      toast({ title: "Could not create user", description: err instanceof Error ? err.message : "Try again.", variant: "destructive" })
    } finally {
      setSubmitting(false)
    }
  }

  const toggleActive = async (u: User) => {
    try {
      await api.patch(`/api/v1/users/${u.id}`, { is_active: !u.is_active })
      toast({ title: "Account updated", description: `${u.email} is now ${!u.is_active ? "active" : "inactive"}.`, variant: "success" })
      refresh()
    } catch (err) {
      toast({ title: "Update failed", description: err instanceof Error ? err.message : "Try again.", variant: "destructive" })
    }
  }

  const changeRole = async (u: User) => {
    const next = window.prompt(`Set role for ${u.email} (admin, reviewer, enumerator, analyst, user):`, u.role)
    if (!next || !ROLES.includes(next)) return
    try {
      await api.patch(`/api/v1/users/${u.id}`, { role: next })
      toast({ title: "Role updated", description: `${u.email} is now a ${next}.`, variant: "success" })
      refresh()
    } catch (err) {
      toast({ title: "Update failed", description: err instanceof Error ? err.message : "Try again.", variant: "destructive" })
    }
  }

  const revokeSessions = async (u: User) => {
    try {
      await api.post(`/api/v1/users/${u.id}/revoke-sessions`)
      toast({ title: "Sessions revoked", description: `${u.email} must sign in again on every device.`, variant: "success" })
      refresh()
    } catch (err) {
      toast({ title: "Action failed", description: err instanceof Error ? err.message : "Try again.", variant: "destructive" })
    }
  }

  const doResetPassword = async () => {
    if (!resetTarget || resetPw.length < 8) {
      toast({ title: "Invalid password", description: "Use at least 8 characters.", variant: "destructive" })
      return
    }
    setSubmitting(true)
    try {
      await api.post(`/api/v1/users/${resetTarget.id}/reset-password`, { new_password: resetPw })
      toast({ title: "Password reset", description: `${resetTarget.email} can now sign in with the new password.`, variant: "success" })
      setResetTarget(null)
      setResetPw("")
      refresh()
    } catch (err) {
      toast({ title: "Reset failed", description: err instanceof Error ? err.message : "Try again.", variant: "destructive" })
    } finally {
      setSubmitting(false)
    }
  }

  const deactivateUser = async (u: User) => {
    if (!window.confirm(`Deactivate ${u.email}? Their sessions will be revoked.`)) return
    try {
      await api.delete(`/api/v1/users/${u.id}`)
      toast({ title: "User deactivated", description: `${u.email} can no longer sign in.`, variant: "success" })
      refresh()
    } catch (err) {
      toast({ title: "Action failed", description: err instanceof Error ? err.message : "Try again.", variant: "destructive" })
    }
  }

  return (
    <main className="w-full">
      <PageHeader
        title="Users &amp; Roles"
        description="Create and manage accounts, assign roles, reset passwords, and revoke sessions — every change is audit-logged."
        actions={
          <Button className="rounded-xl" onClick={() => setCreateOpen(true)}>
            <UserPlus className="h-4 w-4" /> Add user
          </Button>
        }
      />

      <Card data-reveal className="overflow-hidden border-border/80 bg-card">
        <div className="overflow-x-auto">
          <Table>
            <TableHeader className="bg-muted/40">
              <TableRow className="hover:bg-transparent">
                <TableHead>User</TableHead>
                <TableHead>Role</TableHead>
                <TableHead>Status</TableHead>
                <TableHead>Last login</TableHead>
                <TableHead>Created</TableHead>
                <TableHead className="text-right">Actions</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {isLoading && (
                <TableRow>
                  <TableCell colSpan={6} className="h-28 text-center text-muted-foreground">
                    <Loader2 className="mx-auto h-5 w-5 animate-spin" />
                  </TableCell>
                </TableRow>
              )}
              {rows.map((u) => (
                <TableRow key={u.id} className="group">
                  <TableCell>
                    <div className="flex items-center gap-3">
                      <span className="grid h-9 w-9 shrink-0 place-items-center rounded-full bg-gradient-to-br from-[#2c6b51] to-[#123626] font-display text-sm font-bold text-white">
                        {(u.name || u.email).slice(0, 1).toUpperCase()}
                      </span>
                      <div className="min-w-0">
                        <p className="truncate font-semibold text-foreground">{u.name || "—"}</p>
                        <p className="truncate text-[0.78rem] text-muted-foreground">{u.email}</p>
                      </div>
                    </div>
                  </TableCell>
                  <TableCell>
                    <Badge variant="outline" className={`border-transparent font-semibold capitalize ${ROLE_COLORS[u.role] ?? "bg-muted"} ${u.is_superuser ? "ring-1 ring-[#e67e22]/50" : ""}`}>
                      {u.role}{u.is_superuser ? " · super" : ""}
                    </Badge>
                  </TableCell>
                  <TableCell>
                    <span className={`inline-flex items-center gap-1.5 text-[0.8rem] font-semibold ${u.is_active ? "text-[var(--success)]" : "text-muted-foreground"}`}>
                      <span className={`h-2 w-2 rounded-full ${u.is_active ? "bg-[#3cb973]" : "bg-muted-foreground/50"}`} />
                      {u.is_active ? "Active" : "Inactive"}
                    </span>
                  </TableCell>
                  <TableCell className="whitespace-nowrap text-[0.8rem] text-muted-foreground">{formatDate(u.last_login_at)}</TableCell>
                  <TableCell className="whitespace-nowrap text-[0.8rem] text-muted-foreground">{formatDate(u.created_at)}</TableCell>
                  <TableCell>
                    <div className="flex justify-end gap-1.5">
                      <Button variant="ghost" size="sm" className="h-8 rounded-lg text-muted-foreground hover:text-primary" title="Change role" onClick={() => changeRole(u)}>
                        Change role
                      </Button>
                      <Button variant="ghost" size="sm" className="h-8 rounded-lg text-muted-foreground" title="Reset password" onClick={() => { setResetTarget(u); setResetPw("") }}>
                        <RotateCcw className="h-3.5 w-3.5" />
                      </Button>
                      <Button variant="ghost" size="sm" className="h-8 rounded-lg text-muted-foreground" title="Revoke sessions" onClick={() => revokeSessions(u)}>
                        <ShieldOff className="h-3.5 w-3.5" />
                      </Button>
                      <Button variant="ghost" size="sm" className="h-8 rounded-lg text-muted-foreground" title={u.is_active ? "Deactivate" : "Activate"} onClick={() => (u.is_active ? deactivateUser(u) : toggleActive(u))}>
                        {u.is_active ? <PauseCircle className="h-3.5 w-3.5" /> : <PlayCircle className="h-3.5 w-3.5" />}
                      </Button>
                      {!u.is_active && (
                        <Button variant="ghost" size="sm" className="h-8 rounded-lg text-destructive" title="Delete row" onClick={() => toggleActive(u)}>
                          <Trash2 className="h-3.5 w-3.5" />
                        </Button>
                      )}
                    </div>
                  </TableCell>
                </TableRow>
              ))}
            </TableBody>
          </Table>
        </div>

        {/* Infinite scroll: fetches the next page as this sentinel enters view */}
        <div ref={sentinelRef} className="flex items-center justify-center border-t border-border/70 px-4 py-4 text-[0.78rem] text-muted-foreground">
          {isFetchingNextPage ? (
            <span className="inline-flex items-center gap-2"><Loader2 className="h-3.5 w-3.5 animate-spin" /> Loading more…</span>
          ) : hasNextPage ? (
            <span>Scroll for more · {rows.length} of {total} loaded</span>
          ) : rows.length > 0 ? (
            <span>{total} user{total === 1 ? "" : "s"}</span>
          ) : null}
        </div>
      </Card>

      {/* Create user */}
      <Dialog open={createOpen} onOpenChange={setCreateOpen}>
        <DialogContent className="sm:max-w-md">
          <DialogHeader>
            <DialogTitle>Add a user</DialogTitle>
            <DialogDescription>Passwords are hashed with Argon2id and never stored in plain text.</DialogDescription>
          </DialogHeader>
          <div className="space-y-4">
            <div className="grid grid-cols-1 gap-4">
              <div className="space-y-1.5">
                <Label htmlFor="u-name">Full name</Label>
                <Input id="u-name" value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} placeholder="U Min Khant" className="rounded-xl" />
              </div>
              <div className="space-y-1.5">
                <Label htmlFor="u-email">Email</Label>
                <Input id="u-email" type="email" value={form.email} onChange={(e) => setForm({ ...form, email: e.target.value })} placeholder="user@moali.gov.mm" className="rounded-xl" />
              </div>
              <div className="space-y-1.5">
                <Label htmlFor="u-pw">Temporary password</Label>
                <Input id="u-pw" type="password" value={form.password} onChange={(e) => setForm({ ...form, password: e.target.value })} placeholder="At least 8 characters" className="rounded-xl" />
              </div>
              <div className="space-y-1.5">
                <Label htmlFor="u-role">Role</Label>
                <select
                  id="u-role"
                  value={form.role}
                  onChange={(e) => setForm({ ...form, role: e.target.value })}
                  className="h-10 w-full rounded-xl border border-input bg-card px-3 text-[0.85rem] text-foreground focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring"
                >
                  {ROLES.map((r) => <option key={r} value={r}>{r}</option>)}
                </select>
              </div>
            </div>
          </div>
          <DialogFooter>
            <Button variant="outline" className="rounded-xl border-border bg-card" onClick={() => setCreateOpen(false)}>Cancel</Button>
            <Button className="rounded-xl" onClick={createUser} disabled={submitting || !form.email || !form.password || form.password.length < 8}>
              {submitting ? <Loader2 className="h-4 w-4 animate-spin" /> : <UserPlus className="h-4 w-4" />} Create user
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* Reset password */}
      <Dialog open={resetTarget != null} onOpenChange={(o) => { if (!o) setResetTarget(null) }}>
        <DialogContent className="sm:max-w-md">
          <DialogHeader>
            <DialogTitle>Reset password</DialogTitle>
            <DialogDescription>
              {resetTarget?.email} will need to sign in again everywhere. This is recorded in the audit log.
            </DialogDescription>
          </DialogHeader>
          <div className="space-y-1.5">
            <Label htmlFor="reset-pw">New password</Label>
            <Input id="reset-pw" type="password" value={resetPw} onChange={(e) => setResetPw(e.target.value)} placeholder="At least 8 characters" className="rounded-xl" />
          </div>
          <DialogFooter>
            <Button variant="outline" className="rounded-xl border-border bg-card" onClick={() => setResetTarget(null)}>Cancel</Button>
            <Button className="rounded-xl" onClick={doResetPassword} disabled={submitting}>
              {submitting ? <Loader2 className="h-4 w-4 animate-spin" /> : <RotateCcw className="h-4 w-4" />} Reset password
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </main>
  )
}