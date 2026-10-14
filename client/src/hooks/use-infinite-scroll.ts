"use client"

import { useEffect, useRef } from "react"

/**
 * Drives "load more" pagination as an infinite scroll.
 *
 * Attach the returned ref to a sentinel element placed at the end of a list;
 * whenever that element scrolls into view (with a lead-in margin so the next
 * page starts loading before the user actually reaches the bottom),
 * `onIntersect` is invoked. Callers pass `enabled = hasNextPage &&
 * !isFetchingNextPage`, so the observer is only active while another page can
 * be fetched — this is what prevents runaway loops.
 */
export function useInfiniteScroll(onIntersect: () => void, enabled: boolean) {
  const sentinelRef = useRef<HTMLDivElement | null>(null)
  const callbackRef = useRef(onIntersect)

  // Keep the latest callback without re-subscribing the observer each render.
  useEffect(() => {
    callbackRef.current = onIntersect
  }, [onIntersect])

  useEffect(() => {
    const node = sentinelRef.current
    if (!node || !enabled) return

    const observer = new IntersectionObserver(
      (entries) => {
        if (entries[0]?.isIntersecting) callbackRef.current()
      },
      { rootMargin: "400px 0px" },
    )
    observer.observe(node)
    return () => observer.disconnect()
  }, [enabled])

  return sentinelRef
}
