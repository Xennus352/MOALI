"use client"

import { useEffect, useRef } from "react"
import type { DependencyList, RefObject } from "react"
import gsap from "gsap"
import { ScrollTrigger } from "gsap/ScrollTrigger"

if (typeof window !== "undefined") {
  gsap.registerPlugin(ScrollTrigger)
}

/**
 * Staggered fade-up reveal for any `[data-reveal]` elements inside the ref.
 * Runs on mount (pass deps that change when content arrives) — used for
 * dashboard cards that mount once the API data resolves.
 */
export function useReveal<T extends HTMLElement>(deps: DependencyList = []): RefObject<T | null> {
  const ref = useRef<T>(null)

  useEffect(() => {
    const el = ref.current
    if (!el) return

    const items = el.querySelectorAll<HTMLElement>("[data-reveal]")
    if (items.length === 0) return

    const ctx = gsap.context(() => {
      gsap.fromTo(
        items,
        { autoAlpha: 0, y: 26 },
        {
          autoAlpha: 1,
          y: 0,
          duration: 0.7,
          stagger: 0.08,
          ease: "power3.out",
          overwrite: "auto",
          delay: 0.05,
        }
      )
    }, el)

    return () => ctx.revert()
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, deps)

  return ref
}

/**
 * Scroll-triggered fade-up for `[data-reveal]` children as they enter the viewport.
 */
export function useScrollReveal<T extends HTMLElement>(): RefObject<T | null> {
  const ref = useRef<T>(null)

  useEffect(() => {
    const el = ref.current
    if (!el) return

    const items = el.querySelectorAll<HTMLElement>("[data-reveal]")
    if (items.length === 0) return

    const ctx = gsap.context(() => {
      gsap.set(items, { autoAlpha: 0, y: 26 })
      items.forEach((item) => {
        ScrollTrigger.create({
          trigger: item,
          start: "top 92%",
          once: true,
          onEnter: () => {
            gsap.to(item, { autoAlpha: 1, y: 0, duration: 0.7, ease: "power3.out" })
          },
        })
      })
    }, el)

    return () => ctx.revert()
  }, [])

  return ref
}