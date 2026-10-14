"use client"

/**
 * Lightweight, dependency-free SVG charts used across the dashboard, analytics
 * and reports pages. They are driven purely by real backend aggregates and
 * respect light/dark theme tokens via CSS variables.
 */

import { useMemo, useId } from "react"

export interface ChartDatum {
  label: string
  value: number
}

const PALETTE = [
  "var(--chart-1)",
  "var(--chart-2)",
  "var(--chart-3)",
  "var(--chart-4)",
  "#e67e22",
  "var(--warning)",
]

/* ------------------------------------------------------------------ utils */

function niceMax(values: number[]): number {
  const m = Math.max(1, ...values)
  const order = 10 ** Math.floor(Math.log10(m))
  return Math.ceil(m / order) * order
}

const fmt = (n: number) =>
  n >= 1_000_000 ? `${(n / 1_000_000).toFixed(1)}M` : n >= 1000 ? `${(n / 1000).toFixed(1)}k` : `${Math.round(n)}`

/* ------------------------------------------------------------ area chart */

export function AreaChart({
  data,
  height = 170,
  color = "var(--chart-1)",
  label = "count",
}: {
  data: ChartDatum[]
  height?: number
  color?: string
  label?: string
}) {
  const gid = useId().replace(/[:]/g, "")
  const width = 640

  const view = useMemo(() => {
    const values = data.map((d) => d.value)
    const max = niceMax(values)
    const pts = data.map((d, i) => ({
      x: (i / Math.max(1, data.length - 1)) * width,
      y: height - (d.value / max) * (height - 14) - 6,
    }))
    return { pts, max }
  }, [data, height])

  if (data.length === 0) return null

  const line = view.pts.map((p) => `${p.x},${p.y}`).join(" ")
  const area = `0,${height} ${line} ${width},${height}`

  // x tick positions: a handful of evenly spaced dates
  const tickEvery = Math.max(1, Math.floor(data.length / 6))
  const ticks = data
    .map((d, i) => ({ d, i }))
    .filter((_, i) => i % tickEvery === 0 || i === data.length - 1)

  return (
    <div className="w-full">
      <svg viewBox={`0 0 ${width} ${height}`} className="h-[170px] w-full" preserveAspectRatio="none" role="img">
        <defs>
          <linearGradient id={`area-${gid}`} x1="0" y1="0" x2="0" y2="1">
            <stop offset="0%" stopColor={color} stopOpacity="0.32" />
            <stop offset="100%" stopColor={color} stopOpacity="0.02" />
          </linearGradient>
        </defs>
        {[0.25, 0.5, 0.75].map((f) => (
          <line
            key={f}
            x1="0"
            x2={width}
            y1={height - f * (height - 20) - 6}
            y2={height - f * (height - 20) - 6}
            stroke="var(--border)"
            strokeWidth="1"
            strokeDasharray="3 5"
          />
        ))}
        <polygon points={area} fill={`url(#area-${gid})`} />
        <polyline
          points={line}
          fill="none"
          stroke={color}
          strokeWidth="2.5"
          strokeLinecap="round"
          strokeLinejoin="round"
          vectorEffect="non-scaling-stroke"
        />
        {view.pts[view.pts.length - 1] && (
          <circle
            cx={view.pts[view.pts.length - 1].x}
            cy={view.pts[view.pts.length - 1].y}
            r="3.5"
            fill={color}
            stroke="var(--card)"
            strokeWidth="1.5"
          />
        )}
      </svg>
      <div className="mt-1 flex justify-between text-[0.62rem] text-muted-foreground">
        {ticks.map(({ d, i }) => (
          <span key={i} title={`${d.label}: ${d.value}`}>
            {d.label.length > 10 ? d.label.slice(0, 6) : d.label}
          </span>
        ))}
      </div>
      <div className="sr-only" aria-label={`${label} chart`}>
        {data.map((d) => `${d.label}: ${d.value}`).join(", ")}
      </div>
    </div>
  )
}

/* ------------------------------------------------------------ bar chart */

export function BarChart({
  data,
  height = 170,
  color = "var(--chart-2)",
}: {
  data: ChartDatum[]
  height?: number
  color?: string
}) {
  const width = 640
  const max = niceMax(data.map((d) => d.value))
  const barW = Math.max(6, (width / Math.max(1, data.length)) * 0.58)

  if (data.length === 0) return null

  return (
    <div className="w-full">
      <svg viewBox={`0 0 ${width} ${height}`} className="h-[170px] w-full" preserveAspectRatio="none" role="img">
        {data.map((d, i) => {
          const h = Math.max(2, (d.value / max) * (height - 24))
          const x = (i + 0.21) * (width / Math.max(1, data.length))
          return (
            <g key={d.label}>
              <rect
                x={x}
                y={height - h}
                width={barW}
                height={h}
                rx="4"
                fill={color}
                opacity={0.85}
              >
                <title>{`${d.label}: ${d.value}`}</title>
              </rect>
            </g>
          )
        })}
      </svg>
      <div className="mt-1 flex flex-wrap justify-between gap-x-2 text-[0.62rem] text-muted-foreground">
        {data.map((d) => (
          <span key={d.label} title={`${d.label}: ${d.value}`} className="max-w-[80px] truncate">
            {d.label}
          </span>
        ))}
      </div>
    </div>
  )
}

/* --------------------------------------------------------- horizontal bar */

export function HBarChart({
  data,
  color = "var(--chart-3)",
}: {
  data: ChartDatum[]
  color?: string
}) {
  const max = niceMax(data.map((d) => d.value))

  if (data.length === 0) return null

  return (
    <div className="flex flex-col gap-2.5">
      {data.slice(0, 8).map((d) => (
        <div key={d.label} className="group flex items-center gap-3">
          <span className="w-[104px] shrink-0 truncate text-[0.72rem] font-medium text-muted-foreground">
            {d.label}
          </span>
          <div className="relative h-[14px] flex-1 overflow-hidden rounded-full bg-muted/70">
            <div
              className="h-full rounded-full"
              style={{ width: `${Math.max(2, (d.value / max) * 100)}%`, backgroundColor: color }}
            >
              <title>{`${d.label}: ${d.value}`}</title>
            </div>
          </div>
          <span className="w-10 shrink-0 text-right font-display text-sm font-bold text-foreground">
            {fmt(d.value)}
          </span>
        </div>
      ))}
    </div>
  )
}

/* ------------------------------------------------------------- donut chart */

export function DonutChart({
  data = [],
  size = 150,
  thickness = 22,
}: {
  data?: ChartDatum[]
  size?: number
  thickness?: number
}) {
  const total = data.reduce((s, d) => s + d.value, 0)
  if (total <= 0) return null

  const r = (size - thickness) / 2
  const c = 2 * Math.PI * r

  // Pure-functional segment geometry — no mutable accumulator during render.
  const fracs = data.map((d) => d.value / total)
  const cumulative = fracs.reduce<number[]>(
    (acc, f) => [...acc, (acc[acc.length - 1] ?? 0) + f],
    []
  )
  const segments = data.map((d, i) => ({
    ...d,
    dash: Math.max(0.5, fracs[i] * c - 3),
    offset: -(cumulative[i] - fracs[i]) * c,
    color: PALETTE[i % PALETTE.length],
  }))

  return (
    <div className="flex items-center justify-center gap-5">
      <div className="relative" style={{ width: size, height: size }}>
        <svg width={size} height={size} role="img" className="-rotate-90">
          <circle cx={size / 2} cy={size / 2} r={r} fill="none" stroke="var(--muted)" strokeWidth={thickness} />
          {segments.map((d) => (
            <circle
              key={d.label}
              cx={size / 2}
              cy={size / 2}
              r={r}
              fill="none"
              stroke={d.color}
              strokeWidth={thickness}
              strokeDasharray={`${d.dash} ${c - d.dash}`}
              strokeDashoffset={d.offset}
              strokeLinecap="butt"
            >
              <title>{`${d.label}: ${d.value}`}</title>
            </circle>
          ))}
        </svg>
        <div className="absolute inset-0 grid place-items-center">
          <div className="text-center">
            <div className="font-display text-2xl font-black text-foreground">{fmt(total)}</div>
            <div className="text-[0.62rem] uppercase tracking-wider text-muted-foreground">total</div>
          </div>
        </div>
      </div>
      <div className="flex flex-col gap-1.5">
        {data.map((d, i) => (
          <div key={d.label} className="flex items-center gap-2 text-[0.72rem]">
            <span
              className="h-2.5 w-2.5 shrink-0 rounded-[4px]"
              style={{ backgroundColor: PALETTE[i % PALETTE.length] }}
            />
            <span className="max-w-[130px] truncate text-muted-foreground">{d.label}</span>
            <span className="ml-auto pl-2 font-semibold text-foreground">{fmt(d.value)}</span>
          </div>
        ))}
      </div>
    </div>
  )
}

/* ------------------------------------------------------------- legend/text */

export function MiniStat({
  label,
  value,
  hint,
  color = "var(--chart-1)",
}: {
  label: string
  value: string | number
  hint?: string
  color?: string
}) {
  return (
    <div className="rounded-xl border border-border/70 bg-card/60 px-3.5 py-3">
      <div className="flex items-center gap-1.5 text-[0.68rem] font-semibold uppercase tracking-wider text-muted-foreground">
        <span className="h-2 w-2 rounded-full" style={{ backgroundColor: color }} />
        {label}
      </div>
      <div className="mt-1 font-display text-xl font-bold text-foreground">{value}</div>
      {hint && <div className="text-[0.68rem] text-muted-foreground">{hint}</div>}
    </div>
  )
}