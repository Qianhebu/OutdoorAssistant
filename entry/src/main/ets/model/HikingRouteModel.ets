export interface HikingRouteItem {
  id: string
  name: string
  district: string
  address: string
  trackType: string
  difficulty: string
  distanceKm: number
  durationDisplay: string
  elevationGainMeters: number
  elevationLossMeters: number
  maxAltitudeMeters: number
  minAltitudeMeters: number
  altitudeRange: string
  avgPaceMinPerKm: number
  noticeTips: string
  photos: string[]
  videoUrl: string
  waypointCount: number
}

export function getCardAccentColor(route: HikingRouteItem): string {
  if (route.difficulty === '简单') {
    return '#2E7D32'
  }
  if (route.difficulty === '中等') {
    return '#E65100'
  }
  if (route.difficulty === '较难') {
    return '#C62828'
  }
  if (route.difficulty === '困难') {
    return '#6A1B9A'
  }
  return '#424242'
}

export function getCardSubColor(route: HikingRouteItem): string {
  if (route.difficulty === '简单') {
    return '#C8E6C9'
  }
  if (route.difficulty === '中等') {
    return '#FFE0B2'
  }
  if (route.difficulty === '较难') {
    return '#FFCDD2'
  }
  if (route.difficulty === '困难') {
    return '#E1BEE7'
  }
  return '#EEEEEE'
}

interface HikingRouteListData {
  total: number
  routes: HikingRouteItem[]
}

export interface HikingRouteResponse {
  code: number
  message: string
  data: HikingRouteListData
}

export function getDifficultyColor(difficulty: string): string {
  if (difficulty === '简单') {
    return '#4CAF50'
  }
  if (difficulty === '中等') {
    return '#FF9800'
  }
  if (difficulty === '较难') {
    return '#F44336'
  }
  if (difficulty === '困难') {
    return '#9C27B0'
  }
  return '#9E9E9E'
}
