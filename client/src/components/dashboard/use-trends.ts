"use client"

import { useQuery } from "@tanstack/react-query"
import { api } from "@/lib/api"

export interface TrendsData {
  submissionsOverTime: { date: string; count: number }[]
  submissionsByRegion: { region: string; count: number }[]
  submissionsByTownship: { township: string; count: number }[]
  submissionsByStatus: { status: string; count: number }[]
  animalsByType: { animalType: string; count: number }[]
  animalsByGender: { gender: string; count: number }[]
  breedingByCategory: { category: string; count: number }[]
}

/** Live trend series from /api/v1/dashboard/trends — reused by dashboard + analytics. */
export function useTrends(days = 30) {
  return useQuery({
    queryKey: ["dashboard-trends", days],
    queryFn: () => api.get<TrendsData>(`/api/v1/dashboard/trends?days=${days}`),
  })
}