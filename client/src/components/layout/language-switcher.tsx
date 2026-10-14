"use client"

import { Languages, Check } from "lucide-react"
import { Button } from "@/components/ui/button"
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuLabel,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu"
import { LANG_LABEL, SUPPORTED_LANGS, useI18n } from "@/lib/i18n"
import { cn } from "@/lib/utils"

/**
 * Language selector (Myanmar / English). Switching re-renders in place — there
 * is no page reload, so any unsaved form draft is preserved.
 */
export function LanguageSwitcher({ className }: { className?: string }) {
  const { lang, setLang, t } = useI18n()

  return (
    <DropdownMenu>
      <DropdownMenuTrigger asChild>
        <Button
          variant="ghost"
          size="sm"
          className={cn("gap-2 rounded-full px-2.5", className)}
          aria-label={t("header.language")}
          title={t("header.language")}
        >
          <Languages className="h-[1.1rem] w-[1.1rem]" aria-hidden="true" />
          <span className="text-xs font-semibold tracking-wide">{lang.toUpperCase()}</span>
        </Button>
      </DropdownMenuTrigger>
      <DropdownMenuContent align="end" className="w-44">
        <DropdownMenuLabel>{t("header.language")}</DropdownMenuLabel>
        <DropdownMenuSeparator />
        {SUPPORTED_LANGS.map((code) => (
          <DropdownMenuItem
            key={code}
            onClick={() => setLang(code)}
            className="justify-between"
          >
            <span className={cn(code === "my" && "font-[var(--font-myanmar)]")}>
              {LANG_LABEL[code]}
            </span>
            {lang === code && <Check className="h-4 w-4" aria-hidden="true" />}
          </DropdownMenuItem>
        ))}
      </DropdownMenuContent>
    </DropdownMenu>
  )
}
