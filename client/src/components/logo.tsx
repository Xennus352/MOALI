"use client"

import { useId } from "react"
import { cn } from "@/lib/utils"

/* Original brand mark for MOALI / LBVD Livestock Census.
   A twin-peak "M" monogram standing in for a census form / cattle horns,
   struck through with an amber sun-disc accent. */

export function LogoMark({
  className,
  size = 40,
  src,
}: {
  className?: string
  size?: number
  /** Optional raster/vector mark (e.g. official ministry seal) that replaces the built-in SVG mark */
  src?: string
}) {
  const id = useId()

  if (src) {
    return (
      <img
        src={src}
        alt="MOALI"
        width={size}
        height={size}
        style={{ width: size, height: size }}
        className={cn("shrink-0 object-contain", className)}
      />
    )
  }

  return (
    <svg
      width={size}
      height={size}
      viewBox="0 0 48 48"
      fill="none"
      xmlns="http://www.w3.org/2000/svg"
      className={className}
      aria-hidden="true"
    >
      <defs>
        <linearGradient id={`${id}-g`} x1="0" y1="0" x2="1" y2="1">
          <stop offset="0%" stopColor="#2c6b51" />
          <stop offset="60%" stopColor="#1b4d3e" />
          <stop offset="100%" stopColor="#0f2f26" />
        </linearGradient>
      </defs>
      <rect x="2.5" y="2.5" width="43" height="43" rx="13.5" fill={`url(#${id}-g)`} />
      <rect
        x="3.5"
        y="3.5"
        width="41"
        height="41"
        rx="12.5"
        stroke="white"
        strokeOpacity="0.14"
        strokeWidth="1.5"
      />
      <path
        d="M13.5 33.5V17.5L24 27.5L34.5 17.5V33.5"
        stroke="white"
        strokeWidth="4.4"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
      <circle cx="34.2" cy="15.8" r="4.6" fill="#e67e22" />
      <circle cx="34.2" cy="15.8" r="1.7" fill="white" fillOpacity="0.85" />
    </svg>
  )
}

export function Logo({
  className,
  markSize = 38,
  compact = false,
  on = "light",
  src,
}: {
  className?: string
  markSize?: number
  /** Icon + wordmark only, no subline */
  compact?: boolean
  /** `light` = for light surfaces, `dark` = for dark surfaces */
  on?: "light" | "dark"
  /** Optional raster/vector mark (e.g. official ministry seal) that replaces the built-in SVG mark */
  src?: string
}) {
  const sub = on === "dark"

  return (
    <span className={cn("inline-flex select-none items-center gap-3", className)}>
      {src ? (
        <LogoMark
          size={markSize}
          src={src}
          className="shrink-0 object-contain drop-shadow-[0_6px_14px_rgb(27_77_62/0.25)]"
        />
      ) : (
        <LogoMark size={markSize} className="drop-shadow-[0_6px_14px_rgb(27_77_62/0.35)]" />
      )}
      {!compact && (
        <span className="flex flex-col leading-none">
          <span
            className={cn(
              "font-display text-[1.35rem] font-black tracking-[0.14em]",
              sub ? "text-white" : "text-foreground"
            )}
          >
            MOALI
          </span>
          <span
            className={cn(
              "mt-1.5 text-[0.62rem] font-semibold uppercase tracking-[0.3em]",
              sub ? "text-white/55" : "text-muted-foreground"
            )}
          >
            Livestock Census
          </span>
        </span>
      )}
    </span>
  )
}