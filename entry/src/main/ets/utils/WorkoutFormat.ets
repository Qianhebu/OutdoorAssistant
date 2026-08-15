import { geoLocationManager } from '@kit.LocationKit';

/** 使用 Haversine 公式计算两点间距离（米） */
export function haversineDistance(fromLat: number, fromLng: number, toLat: number, toLng: number): number {
  const R: number = 6371000;
  const dLat: number = (toLat - fromLat) * Math.PI / 180;
  const dLon: number = (toLng - fromLng) * Math.PI / 180;
  const a: number = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(fromLat * Math.PI / 180) * Math.cos(toLat * Math.PI / 180) *
      Math.sin(dLon / 2) * Math.sin(dLon / 2);
  const c: number = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c;
}

/** 格式化时长，可强制显示小时 */
export function formatDuration(seconds: number, alwaysShowHour: boolean = false): string {
  const h: number = Math.floor(seconds / 3600);
  const m: number = Math.floor((seconds % 3600) / 60);
  const s: number = seconds % 60;
  const mStr: string = m < 10 ? `0${m}` : `${m}`;
  const sStr: string = s < 10 ? `0${s}` : `${s}`;
  if (h > 0 || alwaysShowHour) {
    const hStr: string = h < 10 ? `0${h}` : `${h}`;
    return `${hStr}:${mStr}:${sStr}`;
  }
  return `${mStr}:${sStr}`;
}

/** 格式化配速（分/公里） */
export function formatPace(durationSec: number, distanceMeters: number): string {
  if (distanceMeters < 100 || durationSec === 0) {
    return "--'--\"";
  }
  const minutesPerKm: number = (durationSec / 60) / (distanceMeters / 1000);
  const paceMin: number = Math.floor(minutesPerKm);
  const paceSec: number = Math.round((minutesPerKm - paceMin) * 60);
  return `${paceMin}'${paceSec < 10 ? '0' : ''}${paceSec}"`;
}

/** 格式化公里数，仅显示数值 */
export function formatDistanceKm(distanceMeters: number): string {
  return (distanceMeters / 1000).toFixed(2);
}

/** 估算热量消耗，缺少体重数据时使用距离近似 */
export function formatCalories(distanceMeters: number): number {
  return Math.round(distanceMeters * 0.06);
}

/** 估算步数，缺少计步传感器数据时按平均步长换算 */
export function formatSteps(distanceMeters: number): number {
  return Math.round(distanceMeters / 0.75);
}

/** 仅用坐标生成标题：北 29°54'8.59"N 东121°33'4.16"E */
export function formatCoordsTitle(latitude: number, longitude: number): string {
  const latDir: string = latitude >= 0 ? '北' : '南';
  const lonDir: string = longitude >= 0 ? '东' : '西';
  const latSuffix: string = latitude >= 0 ? 'N' : 'S';
  const lonSuffix: string = longitude >= 0 ? 'E' : 'W';
  const latDms: string = toDms(Math.abs(latitude));
  const lonDms: string = toDms(Math.abs(longitude));
  return `${latDir} ${latDms}"${latSuffix} ${lonDir}${lonDms}"${lonSuffix}`;
}

/** 十进制度数转换为度分秒字符串，如 29.9024 → 29°54'8.64 */
export function toDms(value: number): string {
  const degree: number = Math.floor(value);
  const minuteFloat: number = (value - degree) * 60;
  const minute: number = Math.floor(minuteFloat);
  const second: number = (minuteFloat - minute) * 60;
  return `${degree}°${minute}'${second.toFixed(2)}`;
}

/** 生成副标题：海拔22m 定位误差4.9m */
export function formatLocationSubTitle(location: geoLocationManager.Location): string {
  return `海拔${Math.round(location.altitude)}m 定位误差${location.accuracy.toFixed(1)}m`;
}

/** 卡尔曼滤波器：对 GPS 轨迹坐标进行平滑去噪 */
export class KalmanFilter {
  private processNoise: number = 0.0001;
  private measurementNoise: number = 0.01;
  private estimatedLat: number = 0;
  private estimatedLng: number = 0;
  private errorCovLat: number = 1;
  private errorCovLng: number = 1;
  private initialized: boolean = false;

  /** 重置滤波器状态 */
  reset(): void {
    this.estimatedLat = 0;
    this.estimatedLng = 0;
    this.errorCovLat = 1;
    this.errorCovLng = 1;
    this.initialized = false;
  }

  /** 输入原始坐标，输出滤波后的平滑坐标 */
  filter(latitude: number, longitude: number): KalmanPoint {
    if (!this.initialized) {
      this.estimatedLat = latitude;
      this.estimatedLng = longitude;
      this.errorCovLat = 1;
      this.errorCovLng = 1;
      this.initialized = true;
      return { latitude: latitude, longitude: longitude };
    }
    const kLat: number = this.errorCovLat / (this.errorCovLat + this.measurementNoise);
    const kLng: number = this.errorCovLng / (this.errorCovLng + this.measurementNoise);
    this.estimatedLat = this.estimatedLat + kLat * (latitude - this.estimatedLat);
    this.estimatedLng = this.estimatedLng + kLng * (longitude - this.estimatedLng);
    this.errorCovLat = (1 - kLat) * this.errorCovLat + this.processNoise;
    this.errorCovLng = (1 - kLng) * this.errorCovLng + this.processNoise;
    return { latitude: this.estimatedLat, longitude: this.estimatedLng };
  }
}

/** 卡尔曼滤波输出点 */
export interface KalmanPoint {
  latitude: number;
  longitude: number;
}
