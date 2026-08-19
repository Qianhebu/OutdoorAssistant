import { UserProfileData, UserProfileResponse } from '../model/UserProfileModel';
import { ApiResponse, mockRequest, readRawFileText } from './MockApi';

let profileCache: UserProfileData | undefined = undefined;

function loadProfile(): UserProfileData {
  if (profileCache !== undefined) {
    return profileCache;
  }
  try {
    const jsonStr = readRawFileText('user_profile.json');
    const response: UserProfileResponse = JSON.parse(jsonStr) as UserProfileResponse;
    profileCache = (response.code === 0 && response.data) ? response.data : getDefaultProfile();
  } catch (err) {
    console.error(`[UserProfileApi] load profile failed: ${JSON.stringify(err)}`);
    profileCache = getDefaultProfile();
  }
  return profileCache;
}

function getDefaultProfile(): UserProfileData {
  return {
    userId: '',
    nickname: '户外探索者',
    avatar: '',
    account: '',
    gender: '',
    age: 0,
    city: '',
    bio: '',
    totalHikes: 0,
    totalDistanceKm: 0,
    totalElevationM: 0,
    joinDate: '',
    level: '',
    badges: []
  };
}

export function fetchUserProfile(): Promise<ApiResponse<UserProfileData>> {
  const profile = loadProfile();
  return mockRequest<UserProfileData>(profile, 100);
}
