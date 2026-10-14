import { BrowserRouter, Routes, Route, Navigate } from "react-router-dom"
import { Providers } from "./providers"
import { ThemeProvider } from "./components/theme-provider"
import { TooltipProvider } from "./components/ui/tooltip"
import { AdminLayout } from "./components/layout/admin-layout"
import { RequireAuth } from "./components/require-auth"
import { Toaster } from "./components/ui/use-toast"
import { DashboardPage } from "./pages/dashboard"
import { FormBuilderPage } from "./features/form-builder/form-builder-page"
import { SubmissionsPage } from "./pages/submissions"
import { CensusSubmitPage } from "./pages/census-submit"
import { UsersPage } from "./pages/users"
import { MasterDataPage } from "./pages/master-data"
import { AnalyticsPage } from "./pages/analytics"
import { ReportsPage } from "./pages/reports"
import { SecurityPage } from "./pages/security"
import { SettingsPage } from "./pages/settings"
import { MessagesPage } from "./pages/messages"
import { LoginPage } from "./pages/login"
import { RegisterPage } from "./pages/register"
import AuthProvider from "./context/auth-provider"
import { RealtimeProvider } from "./lib/realtime"
import { I18nProvider } from "./lib/i18n"

function App() {
  return (
    <AuthProvider>
      <I18nProvider>
        <Providers>
          <ThemeProvider attribute="class" defaultTheme="system" enableSystem>
            <TooltipProvider>
              <Toaster />
              <RealtimeProvider>
                <BrowserRouter>
                  <Routes>
                    <Route path="/login" element={<LoginPage />} />
                    <Route path="/register" element={<RegisterPage />} />
                    <Route
                      element={
                        <RequireAuth>
                          <AdminLayout />
                        </RequireAuth>
                      }
                    >
                      <Route path="/dashboard" element={<DashboardPage />} />
                      <Route path="/form-builder" element={<FormBuilderPage />} />
                      <Route path="/analytics" element={<AnalyticsPage />} />
                      <Route path="/census-responses" element={<SubmissionsPage />} />
                      <Route path="/census-responses/new" element={<CensusSubmitPage />} />
                      <Route path="/reports" element={<ReportsPage />} />
                      <Route path="/users" element={<UsersPage />} />
                      <Route path="/messages" element={<MessagesPage />} />
                      <Route path="/security" element={<SecurityPage />} />
                      <Route path="/database" element={<MasterDataPage />} />
                      <Route path="/settings" element={<SettingsPage />} />
                    </Route>
                    <Route path="/" element={<Navigate to="/dashboard" replace />} />
                    <Route path="*" element={<Navigate to="/login" replace />} />
                  </Routes>
                </BrowserRouter>
              </RealtimeProvider>
            </TooltipProvider>
          </ThemeProvider>
        </Providers>
      </I18nProvider>
    </AuthProvider>
  )
}

export default App