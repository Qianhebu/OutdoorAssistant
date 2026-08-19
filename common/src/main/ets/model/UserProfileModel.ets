export interface UserProfileData {
  userId: string
  nickname: string
  avatar: string
  account: string
  gender: string
  age: number
  city: string
  bio: string
  totalHikes: number
  totalDistanceKm: number
  totalElevationM: number
  joinDate: string
  level: string
  badges: string[]
}

export interface UserProfileResponse {
  code: number
  message: string
  data: UserProfileData
}
