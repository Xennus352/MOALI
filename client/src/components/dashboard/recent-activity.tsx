"use client"

import { Card, CardHeader, CardTitle, CardDescription } from "@/components/ui/card"
import { Link } from "react-router-dom"
import { ArrowUpRight, ScrollText } from "lucide-react"
import { timeAgo } from "@/lib/api"

export interface ActivityEntry {
  id: number
  actor_id?: string | null
  action?: string
  entity_type?: string
  entity_id?: number | null
  created_at?: string | null
}

const ACTION_LABEL: Record<string, string> = {
  // dot-style actions actually recorded by the backend
  "auth.login": "signed in",
  "auth.logout": "signed out",
  "auth.register": "registered an account",
  "auth.change_password": "changed their password",
  "submission.create": "created a submission",
  "submission.update": "updated a submission",
  "submission.submit": "submitted a record",
  "submission.start_review": "started reviewing a submission",
  "submission.approve": "approved a submission",
  "submission.reject": "rejected a submission",
  "submission.return": "returned a submission",
  "submission.reopen": "reopened a submission",
  "submissions.export": "exported submissions",
  "user.create": "created a user account",
  "user.update": "updated a user account",
  "user.reset_password": "reset a user password",
  "user.revoke_sessions": "revoked a user's sessions",
  "user.deactivate": "deactivated a user account",
  "master.create": "added reference data",
  "master.update": "updated reference data",
  "master.deactivate": "deactivated reference data",
  "form.publish": "published a form version",
  // legacy / older action spellings
  submission_created: "recorded a census submission",
  submission_updated: "updated a census submission",
  submission_reviewed: "reviewed a submission",
  submission_approved: "approved a submission",
  submission_rejected: "rejected a submission",
  submission_returned: "returned a submission",
  user_created: "created a user account",
  user_updated: "updated a user account",
  user_deactivated: "deactivated a user account",
  user_activated: "reactivated a user account",
  user_password_reset: "reset a user password",
  user_role_changed: "changed a user role",
  form_created: "created a form",
  form_version_published: "published a form version",
  form_version_draft: "saved a form version",
  auth_login: "logged in",
  auth_logout: "logged out",
  auth_register: "registered an account",
  auth_password_change: "changed their password",
  master_updated: "updated reference data",
  master_created: "added reference data",
  master_deactivated: "deactivated reference data",
}

const ENTITY_LABEL: Record<string, string> = {
  submission: "submission",
  user: "user",
  form: "form",
  form_version: "form version",
  gender: "gender",
  animal_type: "animal type",
  animal_category: "animal category",
  species: "species",
  breed: "breed",
  age_group: "age group",
  breeding_category: "breeding category",
  state_region: "state/region",
  district: "district",
  township: "township",
}

export function RecentActivity({ activity }: { activity?: ActivityEntry[] }) {
  return (
    <Card data-reveal className="border-border/80 bg-card">
      <CardHeader className="flex flex-row items-center justify-between gap-3 pb-2 pt-5">
        <div>
          <CardTitle className="text-[1.05rem] font-bold tracking-tight">Recent activity</CardTitle>
          <CardDescription className="text-[0.78rem]">Audit trail across the system</CardDescription>
        </div>
        <Link
          to="/security"
          className="inline-flex items-center gap-1 text-[0.78rem] font-semibold text-primary hover:underline"
        >
          Audit log <ArrowUpRight className="h-3.5 w-3.5" />
        </Link>
      </CardHeader>

      {!activity || activity.length === 0 ? (
        <div className="flex flex-col items-center gap-2 px-6 py-10 text-center text-sm text-muted-foreground">
          <ScrollText className="h-8 w-8 opacity-50" />
          No activity recorded yet.
        </div>
      ) : (
        <ol className="space-y-0 px-5 py-2">
          {activity.slice(0, 7).map((a) => {
            const verb = ACTION_LABEL[a.action ?? ""] ?? `${a.action ?? "performed an action"}`
            const entity = ENTITY_LABEL[a.entity_type ?? ""]
            return (
              <li key={a.id} className="relative flex gap-3 border-l-2 border-border/70 py-2.5 pl-4">
                <span className="absolute -left-[5px] top-[1.15rem] h-2 w-2 rounded-full bg-primary ring-2 ring-card" />
                <div className="min-w-0 flex-1">
                  <p className="text-[0.8rem] leading-snug text-foreground">
                    <span className="font-semibold">{a.actor_id ? `User #${a.actor_id}` : "System"}</span>{" "}
                    {verb}
                    {entity ? (
                      <>
                        {" "}
                        <span className="font-medium text-primary">{entity}</span>
                        {a.entity_id != null && <span className="text-muted-foreground"> #{a.entity_id}</span>}
                      </>
                    ) : null}
                  </p>
                  <p className="mt-0.5 text-[0.68rem] text-muted-foreground">{timeAgo(a.created_at)}</p>
                </div>
              </li>
            )
          })}
        </ol>
      )}
    </Card>
  )
}