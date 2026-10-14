"use client"

import { Loader2 } from "lucide-react"

export function LoadingBlock({ label = "Loading…" }: { label?: string }) {
  return (
    <div className="grid min-h-[16rem] place-items-center rounded-2xl border border-dashed border-border/60 bg-card/40 text-muted-foreground">
      <div className="flex flex-col items-center gap-3">
        <Loader2 className="h-6 w-6 animate-spin text-primary" />
        <span className="text-[0.85rem]">{label}</span>
      </div>
    </div>
  )
}