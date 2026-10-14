"use client"

import { Outlet } from "react-router-dom"
import { cn } from "@/lib/utils"
import { Sidebar } from "./sidebar"
import { Header } from "./header"
import { useState } from "react"

export function AdminLayout() {
  const [sidebarCollapsed, setSidebarCollapsed] = useState(false)
  const [mobileSidebarOpen, setMobileSidebarOpen] = useState(false)

  return (
    <div className="min-h-screen bg-background">
      <Sidebar
        collapsed={sidebarCollapsed}
        onToggle={() => setSidebarCollapsed(!sidebarCollapsed)}
      />

      <div
        className={cn(
          "transition-[padding] duration-300",
          sidebarCollapsed ? "lg:pl-[76px]" : "lg:pl-[264px]"
        )}
      >
        <Header onMenuClick={() => setMobileSidebarOpen((open) => !open)} />

        <main className="mx-auto min-h-[calc(100vh-68px)] w-full max-w-[1600px] px-4 py-6 lg:px-8 lg:py-8">
          <div className="relative">
            {/* Subtle ambient wash behind page content */}
            <div
              aria-hidden="true"
              className="pointer-events-none absolute inset-x-0 -top-24 -z-10 h-64 opacity-70 mesh-green dark:mesh-green-dark"
            />
            <Outlet />
          </div>
        </main>
      </div>

      {mobileSidebarOpen && (
        <div
          className="fixed inset-0 z-30 bg-black/60 backdrop-blur-sm lg:hidden"
          onClick={() => setMobileSidebarOpen(false)}
          aria-hidden="true"
        />
      )}
    </div>
  )
}