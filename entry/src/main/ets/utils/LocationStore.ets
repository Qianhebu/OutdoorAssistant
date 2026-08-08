import { AppStorageKeys } from '../constant/AppStorageKeys';

/** 共享定位坐标 */
export interface StoredLocation {
  latitude: number;
  longitude: number;
}

/** 将当前定位坐标写入 AppStorage，供各页面共享 */
export function saveCurrentLocation(latitude: number, longitude: number): void {
  if (latitude !== 0 && longitude !== 0) {
    AppStorage.setOrCreate(AppStorageKeys.CURRENT_LATITUDE, latitude);
    AppStorage.setOrCreate(AppStorageKeys.CURRENT_LONGITUDE, longitude);
  }
}

/** 从 AppStorage 读取已共享的定位坐标，无有效值返回 undefined */
export function getStoredLocation(): StoredLocation | undefined {
  const latitude: number | undefined = AppStorage.get<number>(AppStorageKeys.CURRENT_LATITUDE);
  const longitude: number | undefined = AppStorage.get<number>(AppStorageKeys.CURRENT_LONGITUDE);
  if (latitude === undefined || longitude === undefined) {
    return undefined;
  }
  return { latitude: latitude, longitude: longitude };
}
