"use client"

import { useEffect, useRef } from "react"
import gsap from "gsap"

/**
 * Animated numeric counter. Spins from 0 to `value` on mount.
 */
export function Counter({
  value,
  className,
  prefix = "",
  suffix = "",
  duration = 1.6,
}: {
  value: number
  className?: string
  prefix?: string
  suffix?: string
  duration?: number
}) {
  const ref = useRef<HTMLSpanElement>(null)
  const displayRef = useRef<HTMLSpanElement>(null)

  useEffect(() => {
    const el = ref.current
    const out = displayRef.current
    if (!el || !out) return

    const obj = { n: 0 }
    const tween = gsap.to(obj, {
      n: value,
      duration,
      ease: "power2.out",
      onUpdate: () => {
        out.textContent = `${prefix}${Math.round(obj.n).toLocaleString()}${suffix}`
      },
    })
    return () => {
      tween.kill()
    }
  }, [value, prefix, suffix, duration])

  return (
    <span ref={ref} className={className}>
      <span ref={displayRef}>{`${prefix}0${suffix}`}</span>
    </span>
  )
}