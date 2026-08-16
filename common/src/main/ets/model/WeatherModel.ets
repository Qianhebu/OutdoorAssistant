/** 天气警示等级 */
export enum WeatherWarningLevel {
  NONE = 0,
  CAUTION = 1,
  WARNING = 2
}

/** 天气警示 */
export interface WeatherWarning {
  level: WeatherWarningLevel;
  title: string;
  message: string;
}
