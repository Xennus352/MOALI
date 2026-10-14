"use client"

import { useState } from "react"
import { useQuery } from "@tanstack/react-query"
import { api } from "@/lib/api"
import { PageHeader } from "@/components/layout/page-header"
import { Card } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { Table, TableHeader, TableBody, TableRow, TableHead, TableCell } from "@/components/ui/table"
import { Input } from "@/components/ui/input"
import { LoadingBlock } from "@/components/layout/loading-block"
import { ShieldAlert, Loader2 } from "lucide-react"

export function SecurityPage() {
  const [action, setAction] = useState("")

  const {
    data,
    isLoading,
    isError,
  } = useQuery<{ items?: unknown[]; total?: number }>({
    queryKey: ["audit-logs"],
    queryFn: () => api.get(`/api/v1/users/audit-logs`),
    staleTime: 60_000,
  })

  const rows = (data?.items as Array<{ action: string; id: number }> | undefined) ?? []
  const total = data?.total ?? 0

  // Filter by action if specified
  const filter = ""
  const filteredRows = rows.filter((e: { action: string; id: number }) => !filter || e.action === filter)

  return (
    <main className="w-full">
      <PageHeader title="Security & Audit" description="Administrator activity log" />

      <div className="mb-4 flex flex-col sm:flex-row gap-2">
        <Input
          value={action}
          onChange={(e) => setAction(e.target.value)}
          placeholder="Filter by action..."
          className="flex-1 h-10 rounded-xl border border-input bg-muted/40 pl-3 text-[0.85rem] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary/15"
        />
        <Button
          variant="outline"
          size="sm"
          onClick={() => setAction("")}
          className="h-9 rounded-xl px-3 text-[0.72rem] font-medium text-primary hover:bg-muted"
          disabled={action === ""}
        >
          Show all
        </Button>
        <Button
          variant="outline"
          size="sm"
          onClick={() => setAction("user.register")}
          className="h-9 rounded-xl px-3 text-[0.72rem] font-medium text-primary hover:bg-muted"
          disabled={action === "user.register"}
        >
          User register
        </Button>
        <Button
          variant="outline"
          size="sm"
          onClick={() => setAction("user.login")}
          className="h-9 rounded-xl px-3 text-[0.72rem] font-medium text-primary hover:bg-muted"
          disabled={action === "user.login"}
        >
          User login
        </Button>
        <Button
          variant="outline"
          size="sm"
          onClick={() => setAction("user.logout")}
          className="h-9 rounded-xl px-3 text-[0.72rem] font-medium text-primary hover:bg-muted"
          disabled={action === "user.logout"}
        >
          User logout
        </Button>
      </div>

      {isLoading && <LoadingBlock />}

      {isError && !data && (
        <Card className="border-border/80 bg-card p-8">
          <div className="flex flex-col items-center gap-3 py-6 text-center">
            <ShieldAlert className="h-8 w-8 text-warning" />
            <p>You may not have permission</p>
          </div>
        </Card>
      )}

      {data && (
        <Card data-reveal className="overflow-hidden border-border/80 bg-card">
          <div className="p-4 sm:p-6">
            <div className="mb-4">
              <p className="text-[0.78rem] text-muted-foreground/60">
                Events total:
                <span className="font-medium text-foreground">{total}</span>
              </p>
              <p className="text-[0.72rem] text-muted-foreground/50">
                Filtered events:
                <span className="font-medium text-foreground">{filteredRows.length}</span>
              </p>
            </div>

            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>When</TableHead>
                  <TableHead>Event</TableHead>
                  <TableHead>By</TableHead>
                  <TableHead>Details</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {filteredRows.map((e: any) => (
                  <TableRow key={e.id} className="border-b border-border/60 py-3">
                    <TableCell className="text-[0.76rem] text-muted-foreground">
                      Registered
                    </TableCell>
                    <TableCell className="font-semibold text-foreground">
                      User register
                    </TableCell>
                    <TableCell className="text-[0.82rem] text-muted-foreground">
                      {e.actor_id != null ? `User #${e.actor_id}` : "System"}
                    </TableCell>
                    <TableCell className="text-[0.78rem] text-muted-foreground">
                      {e.entity_type}{e.entity_id != null ? ` #${e.entity_id}` : ""}
                    </TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          </div>

          {data && rows.length === 0 && (
            <Card className="border-border/80 bg-card p-6 text-center text-muted-foreground">
              <Loader2 className="mx-auto mb-3 h-6 w-6 opacity-40" />
              <p>No matching events</p>
            </Card>
          )}
        </Card>
      )}
    </main>
  )
}