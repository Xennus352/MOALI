"use client"

import { cn } from "@/lib/utils"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { TrendingUp, TrendingDown } from "lucide-react"
import { Counter } from "@/components/ui/counter"

export interface StatCardProps {
  title: string
  value: string
  icon: React.ReactNode
  description?: string
  /** Real change, e.g. "+3 vs yesterday". Only shown when passed. */
  delta?: string
  deltaType?: "increase" | "decrease"
  /** Extra class for the icon chip */
  accent?: string
}

export function StatCard({
  title,
  value,
  icon,
  description,
  delta,
  deltaType = "increase",
  accent,
}: StatCardProps) {
  const numeric = Number.parseFloat(value)
  const up = deltaType === "increase"
  const hasDelta = delta !== undefined && delta !== null && delta !== ""

  return (
    <Card
      data-reveal
      className="group relative overflow-hidden border-border/80 bg-card shadow-[0_1px_2px_rgb(17_34_15/0.04),0_8px_24px_-8px_rgb(17_34_15/0.06)] transition-all duration-300 hover:-translate-y-0.5 hover:shadow-[0_2px_4px_rgb(17_34_15/0.05),0_18px_44px_-16px_rgb(17_34_15/0.16)]"
    >
      <div className="absolute inset-x-4 top-0 h-px bg-gradient-to-r from-transparent via-primary/40 to-transparent" />

      <CardHeader className="flex flex-row items-start justify-between space-y-0 pb-1 pt-5">
        <CardTitle className="text-[0.82rem] font-semibold text-muted-foreground">{title}</CardTitle>
        <div
          className={cn(
            "flex h-10 w-10 items-center justify-center rounded-xl bg-muted text-primary transition-transform duration-300 group-hover:scale-110",
            accent
          )}
        >
          {icon}
        </div>
      </CardHeader>

      <CardContent className="pb-5">
        <div className="font-display text-[1.9rem] font-bold leading-none tracking-tight text-foreground">
          {Number.isFinite(numeric) ? <Counter value={numeric} /> : <span>{value}</span>}
        </div>
        <div className="mt-2 flex flex-wrap items-center gap-x-2 gap-y-0.5">
          {hasDelta && (
            <span
              className={cn(
                "inline-flex items-center gap-1 rounded-full px-2 py-0.5 text-[0.72rem] font-semibold",
                up ? "bg-success/10 text-[var(--success)]" : "bg-warning/15 text-[var(--warning)]"
              )}
            >
              {up ? <TrendingUp className="h-3 w-3" /> : <TrendingDown className="h-3 w-3" />}
              <span>{delta}</span>
            </span>
          )}
          {description && (
            <span className="text-[0.72rem] font-normal text-muted-foreground">{description}</span>
          )}
        </div>
      </CardContent>
    </Card>
  )
}