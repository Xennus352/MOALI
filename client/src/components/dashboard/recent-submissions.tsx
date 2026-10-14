"use client"

import { Link } from "react-router-dom"
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table"
import { Card, CardHeader, CardTitle, CardDescription } from "@/components/ui/card"
import { Badge } from "@/components/ui/badge"
import { Calendar, ArrowUpRight } from "lucide-react"
import { cn } from "@/lib/utils"

export interface RecentSubmission {
  id: number
  household_no?: string | null
  respondent_name_burmese?: string | null
  township?: string | null
  state_region?: string | null
  collection_status?: string | null
  interview_date?: string | null
  created_at?: string | null
}

const statusMap: Record<string, { label: string; className: string }> = {
  pending: { label: "Pending", className: "bg-warning/15 text-[var(--warning)]" },
  approved: { label: "Approved", className: "bg-success/15 text-[var(--success)]" },
  rejected: { label: "Rejected", className: "bg-destructive/10 text-[var(--destructive)]" },
  under_review: { label: "Under review", className: "bg-primary/10 text-primary" },
  submitted: { label: "Submitted", className: "bg-chart-4/15 text-chart-4" },
  completed: { label: "Completed", className: "bg-success/15 text-[var(--success)]" },
}

export function RecentSubmissions({ submissions }: { submissions: RecentSubmission[] }) {
  const rows = submissions.slice(0, 5)

  return (
    <Card
      data-reveal
      className="overflow-hidden border-border/80 bg-card shadow-[0_1px_2px_rgb(17_34_15/0.04),0_8px_24px_-8px_rgb(17_34_15/0.06)]"
    >
      <CardHeader className="flex flex-row items-start justify-between border-b border-border/60">
        <div>
          <CardTitle className="text-base">Recent Submissions</CardTitle>
          <CardDescription className="mt-0.5">Latest census responses coming in</CardDescription>
        </div>
        <Link
          to="/census-responses"
          className="inline-flex items-center gap-1 rounded-lg px-2.5 py-1.5 text-[0.8rem] font-semibold text-primary transition-colors hover:bg-primary/10"
        >
          View all <ArrowUpRight className="h-3.5 w-3.5" />
        </Link>
      </CardHeader>

      <div className="overflow-x-auto">
        <Table>
          <TableHeader className="bg-muted/40">
            <TableRow className="hover:bg-transparent">
              <TableHead className="text-[0.72rem] uppercase tracking-wider text-muted-foreground">Household</TableHead>
              <TableHead className="text-[0.72rem] uppercase tracking-wider text-muted-foreground">Township</TableHead>
              <TableHead className="text-[0.72rem] uppercase tracking-wider text-muted-foreground">Region</TableHead>
              <TableHead className="text-[0.72rem] uppercase tracking-wider text-muted-foreground">Status</TableHead>
              <TableHead className="text-[0.72rem] uppercase tracking-wider text-muted-foreground">Interview date</TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {rows.map((sub) => {
              const status = statusMap[sub.collection_status ?? ""] || {
                label: sub.collection_status?.replace("_", " ") || "N/A",
                className: "bg-muted text-muted-foreground",
              }
              return (
                <TableRow key={sub.id} className="group">
                  <TableCell className="font-semibold text-foreground">{sub.household_no || "—"}</TableCell>
                  <TableCell className="text-muted-foreground">{sub.township || "—"}</TableCell>
                  <TableCell className="text-muted-foreground">{sub.state_region || "—"}</TableCell>
                  <TableCell>
                    <Badge
                      variant="outline"
                      className={cn("border-transparent font-semibold capitalize", status.className)}
                    >
                      {status.label}
                    </Badge>
                  </TableCell>
                  <TableCell className="whitespace-nowrap text-muted-foreground">
                    <span className="inline-flex items-center gap-1.5">
                      <Calendar className="h-3.5 w-3.5 text-muted-foreground/60" />
                      {sub.interview_date?.split("T")[0] || "—"}
                    </span>
                  </TableCell>
                </TableRow>
              )
            })}
            {rows.length === 0 && (
              <TableRow>
                <TableCell colSpan={5} className="py-10 text-center text-muted-foreground">
                  No submissions yet — incoming responses will appear here.
                </TableCell>
              </TableRow>
            )}
          </TableBody>
        </Table>
      </div>
    </Card>
  )
}
