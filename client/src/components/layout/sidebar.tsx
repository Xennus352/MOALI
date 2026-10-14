"use client"

import { Link, useLocation, useNavigate } from "react-router-dom"
import { cn } from "@/lib/utils"
import { Button } from "@/components/ui/button"
import { Separator } from "@/components/ui/separator"
import {
  LayoutDashboard,
  FileText,
  MenuSquare,
  BarChart3,
  LineChart,
  Users,
  MessageSquare,
  Shield,
  Database,
  Settings,
  LogOut,
  ChevronLeft,
  ChevronRight,
  Sparkles,
} from "lucide-react"
import { LogoMark } from "@/components/logo"
import moaliLogo from "@/assets/moali-logo.png"
import { useAuth } from "@/context/auth-context"
import { useI18n } from "@/lib/i18n"

type IconType = typeof LayoutDashboard

interface NavItem {
  /** i18n key for the label (also used as the React key). */
  labelKey: string
  href: string
  icon: IconType
}

/**
 * Regrouped, task-oriented navigation. Labels are localized at render time so
 * switching language updates them in place.
 */
const NAV_GROUPS: { labelKey: string; items: NavItem[] }[] = [
  {
    labelKey: "nav.main",
    items: [
      { labelKey: "nav.dashboard", href: "/dashboard", icon: LayoutDashboard },
      { labelKey: "nav.censusForms", href: "/form-builder", icon: MenuSquare },
      { labelKey: "nav.masterData", href: "/database", icon: Database },
      { labelKey: "nav.submissions", href: "/census-responses", icon: FileText },
      { labelKey: "nav.analytics", href: "/analytics", icon: BarChart3 },
      { labelKey: "nav.reports", href: "/reports", icon: LineChart },
    ],
  },
  {
    labelKey: "nav.management",
    items: [
      { labelKey: "nav.users", href: "/users", icon: Users },
      { labelKey: "nav.messages", href: "/messages", icon: MessageSquare },
      { labelKey: "nav.security", href: "/security", icon: Shield },
      { labelKey: "nav.settings", href: "/settings", icon: Settings },
    ],
  },
]

export function Sidebar({
  collapsed = false,
  onToggle,
}: {
  collapsed?: boolean
  onToggle: () => void
}) {
  const location = useLocation()
  const navigate = useNavigate()
  const { user, logout } = useAuth()
  const { t } = useI18n()

  const handleLogout = async () => {
    await logout()
    navigate("/login", { replace: true })
  }

  return (
    <aside
      className={cn(
        "fixed inset-y-0 left-0 z-40 flex flex-col border-r border-[#e4e3d6]/70 bg-[#fbfaf4] text-[#11220f] transition-all duration-300 dark:border-transparent dark:bg-[#08150d] dark:text-white",
        collapsed ? "w-[76px]" : "w-[264px]"
      )}
    >
      {/* Ambient glow */}
      <div
        aria-hidden="true"
        className="pointer-events-none absolute inset-0 overflow-hidden"
      >
        <div className="absolute -left-24 top-[-6rem] h-72 w-72 rounded-full bg-[#1b4d3e]/10 blur-3xl dark:bg-[#1b4d3e]/60" />
        <div className="absolute -right-28 bottom-[-8rem] h-80 w-80 rounded-full bg-[#e67e22]/10 blur-3xl" />
      </div>

      {/* Brand */}
      <div
        className={cn(
          "relative flex h-[72px] shrink-0 items-center border-b border-[#e4e3d6]/70 dark:border-white/10",
          collapsed ? "justify-center px-3" : "justify-between gap-2 px-5"
        )}
      >
        {collapsed ? (
          <LogoMark
            size={38}
            src={moaliLogo}
            className="drop-shadow-[0_6px_16px_rgb(0_0_0/0.12)] dark:drop-shadow-[0_6px_16px_rgb(0_0_0/0.4)]"
          />
        ) : (
          <>
            <span className="flex items-center gap-3">
              <LogoMark
                size={38}
                src={moaliLogo}
                className="drop-shadow-[0_6px_16px_rgb(0_0_0/0.12)] dark:drop-shadow-[0_6px_16px_rgb(0_0_0/0.4)]"
              />
              <span className="flex flex-col leading-none">
                <span className="font-display text-[1.1rem] font-black tracking-[0.16em] text-[#11220f] dark:text-white">
                  MOALI
                </span>
                <span className="mt-1 text-[0.58rem] font-semibold uppercase tracking-[0.28em] text-[#8b9186] dark:text-white/50">
                  {t("app.censusAdmin")}
                </span>
              </span>
            </span>
            <Button
              variant="ghost"
              size="icon"
              onClick={onToggle}
              className="h-7 w-7 rounded-md text-[#5c6b5c] hover:bg-black/[0.06] hover:text-[#11220f] dark:text-white/60 dark:hover:bg-white/10 dark:hover:text-white"
              aria-label={t("nav.collapse")}
            >
              <ChevronLeft className="h-4 w-4" />
            </Button>
          </>
        )}
        {collapsed && (
          <Button
            variant="ghost"
            size="icon"
            onClick={onToggle}
            className="absolute -right-3 top-[18px] z-10 h-6 w-6 rounded-full border border-[#dcdad0] bg-[#fbfaf4] text-[#3a4a3a] hover:text-[#11220f] dark:border-white/10 dark:bg-[#0d241a] dark:text-white/70 dark:hover:text-white"
            aria-label={t("nav.expand")}
          >
            <ChevronRight className="h-3.5 w-3.5" />
          </Button>
        )}
      </div>

      {/* Navigation */}
      <nav className="relative flex-1 space-y-6 overflow-y-auto px-3 py-5" aria-label={t("nav.main_navigation")}>
        <div className="px-1.5 text-[0.6rem] font-bold uppercase tracking-[0.24em] text-[#8b9186] dark:text-white/35">
          {collapsed ? "·" : t("nav.workspace")}
        </div>
        {NAV_GROUPS.map((group) => (
          <div key={group.labelKey} className="space-y-1">
            {!collapsed && (
              <p className="px-3 pb-1 text-[0.6rem] font-bold uppercase tracking-[0.24em] text-[#8b9186] dark:text-white/35">
                {t(group.labelKey)}
              </p>
            )}
            <ul className="space-y-1" role="list">
              {group.items.map((item) => {
                const label = t(item.labelKey)
                const isActive =
                  location.pathname === item.href ||
                  location.pathname.startsWith(`${item.href}/`)
                return (
                  <li key={item.labelKey}>
                    <Link
                      to={item.href}
                      className={cn(
                        "group relative flex items-center gap-3 rounded-xl px-3 py-2.5 text-[0.85rem] font-medium transition-all duration-200",
                        collapsed && "justify-center px-0",
                        isActive
                          ? "bg-[#1b4d3e] text-white shadow-[0_10px_24px_-10px_rgb(17_34_15/0.35)] dark:bg-white dark:text-[#123626] dark:shadow-[0_8px_24px_-8px_rgb(0_0_0/0.5)]"
                          : "text-[#4c5a4c] hover:bg-black/[0.05] hover:text-[#11220f] dark:text-white/60 dark:hover:bg-white/[0.07] dark:hover:text-white"
                      )}
                      title={collapsed ? label : undefined}
                    >
                      <item.icon className="h-[1.05rem] w-[1.05rem] shrink-0" aria-hidden="true" />
                      {!collapsed && <span className="truncate">{label}</span>}
                      {isActive && !collapsed && (
                        <span className="ml-auto h-1.5 w-1.5 rounded-full bg-[#e67e22]" />
                      )}
                    </Link>
                  </li>
                )
              })}
            </ul>
          </div>
        ))}
      </nav>

      {/* Footer */}
      <div className="relative shrink-0 border-t border-[#e4e3d6]/70 p-3 dark:border-white/10">
        <div
          className={cn(
            "flex items-center gap-3 rounded-xl px-2 py-2",
            collapsed && "justify-center px-0"
          )}
        >
          <div className="relative h-9 w-9 shrink-0 rounded-full bg-gradient-to-br from-[#2c6b51] to-[#123626] ring-2 ring-[#d8ddd2] flex items-center justify-center dark:ring-white/15">
            <span className="font-display text-sm font-bold text-white">
              {(user?.name || "U").slice(0, 1).toUpperCase()}
            </span>
            <span className="absolute -bottom-0.5 -right-0.5 h-2.5 w-2.5 rounded-full border-2 border-[#fbfaf4] bg-[#3cb973] dark:border-[#0d241a]" />
          </div>
          {!collapsed && (
            <div className="min-w-0 flex-1">
              <p className="truncate text-[0.82rem] font-semibold text-[#11220f] dark:text-white">
                {user?.name || "Admin User"}
              </p>
              <p className="truncate text-[0.7rem] text-[#6d7668] dark:text-white/45">
                {user?.email || "Synchronized"}
              </p>
            </div>
          )}
          {!collapsed && (
            <Button
              variant="ghost"
              size="icon"
              onClick={handleLogout}
              className="h-8 w-8 rounded-lg text-[#7a847a] hover:bg-black/[0.06] hover:text-[#11220f] dark:text-white/50 dark:hover:bg-white/10 dark:hover:text-white"
              aria-label={t("header.logout")}
              title={t("header.logout")}
            >
              <LogOut className="h-4 w-4" />
            </Button>
          )}
        </div>

        <Separator className="my-2 bg-[#e4e3d6]/80 dark:bg-white/10" />
        <div
          className={cn(
            "flex items-center gap-2 px-2 py-1 text-[0.72rem] text-[#6d7668] dark:text-white/45",
            collapsed && "justify-center px-0"
          )}
        >
          <Sparkles className="h-3.5 w-3.5 text-[#e67e22] dark:text-[#f08a2e]" aria-hidden="true" />
          {!collapsed && <span>{t("nav.footer")}</span>}
        </div>
      </div>
    </aside>
  )
}