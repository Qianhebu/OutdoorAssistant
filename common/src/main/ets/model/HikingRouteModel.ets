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

export function getCardAccentColor(route: HikingRouteItem): Resource {
  if (route.difficulty === '简单') {
    return $r('app.color.accent_easy')
  }
  if (route.difficulty === '中等') {
    return $r('app.color.accent_medium')
  }
  if (route.difficulty === '较难') {
    return $r('app.color.accent_hard')
  }
  if (route.difficulty === '困难') {
    return $r('app.color.accent_veryhard')
  }
  return $r('app.color.accent_default')
}

export function getCardSubColor(route: HikingRouteItem): Resource {
  if (route.difficulty === '简单') {
    return $r('app.color.sub_easy')
  }
  if (route.difficulty === '中等') {
    return $r('app.color.sub_medium')
  }
  if (route.difficulty === '较难') {
    return $r('app.color.sub_hard')
  }
  if (route.difficulty === '困难') {
    return $r('app.color.sub_veryhard')
  }
  return $r('app.color.sub_default')
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

export function getDifficultyColor(difficulty: string): Resource {
  if (difficulty === '简单') {
    return $r('app.color.difficulty_easy')
  }
  if (difficulty === '中等') {
    return $r('sys.color.ohos_id_color_palette10')
  }
  if (difficulty === '较难') {
    return $r('app.color.difficulty_hard')
  }
  if (difficulty === '困难') {
    return $r('app.color.difficulty_veryhard')
  }
  return $r('app.color.difficulty_unknown')
}
