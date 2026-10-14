"use client"

export function EmptyState({
  icon,
  title,
  description,
  action,
}: {
  icon: React.ReactNode
  title: string
  description: string
  action?: React.ReactNode
}) {
  return (
    <div
      data-reveal
      className="flex flex-col items-center rounded-2xl border border-dashed border-border/70 bg-card/50 px-6 py-14 text-center"
    >
      <div className="relative mb-5">
        <div className="grid h-16 w-16 place-items-center rounded-2xl bg-primary/10 text-primary">
          {icon}
        </div>
        <span className="absolute -right-1 -top-1 h-3.5 w-3.5 rounded-full border-2 border-card bg-[#e67e22]" />
      </div>
      <h3 className="font-display text-lg font-bold text-foreground">{title}</h3>
      <p className="mt-1.5 max-w-sm text-sm text-muted-foreground">{description}</p>
      {action && <div className="mt-5">{action}</div>}
    </div>
  )
}