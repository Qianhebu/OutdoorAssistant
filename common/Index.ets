// 基础共享模块统一导出入口

// ===== constant =====
export { AppStorageKeys } from './src/main/ets/constant/AppStorageKeys';
export { PageEnum } from './src/main/ets/constant/PageEnum';
export { StorageKey } from './src/main/ets/constant/StorageKey';

// ===== model =====
export type { HikingRouteItem, HikingRouteResponse, TrackPoint, ElevationPoint, KmPaceItem } from './src/main/ets/model/HikingRouteModel';
export { getCardAccentColor, getCardSubColor, getDifficultyColor } from './src/main/ets/model/HikingRouteModel';
export {
  RECORD_METRIC_STORE_KEY,
  DEFAULT_VISIBLE_METRIC_KEYS,
  ALL_RECORD_METRICS
} from './src/main/ets/model/RecordMetricModel';
export type { RecordMetric } from './src/main/ets/model/RecordMetricModel';
export { RecordMetricStore, getRecordMetricStore } from './src/main/ets/model/RecordMetricModel';
export { OutdoorTabType } from './src/main/ets/model/TabBarModel';
export type { OutdoorTabData } from './src/main/ets/model/TabBarModel';
export { OUTDOOR_TABS_LIST } from './src/main/ets/model/TabBarModel';
export { WeatherWarningLevel } from './src/main/ets/model/WeatherModel';
export type { WeatherWarning } from './src/main/ets/model/WeatherModel';
export { SportType, MetricKey, SPORT_TYPE_OPTIONS, METRIC_DEFS, SPORT_DEFAULT_METRICS, MAX_METRIC_COUNT, MAP_LAYER_OPTIONS } from './src/main/ets/model/WorkoutModels';
export type { SportTypeOption, MetricDef, MapLayerOption } from './src/main/ets/model/WorkoutModels';

// ===== util =====
export type { StoredLocation } from './src/main/ets/util/LocationStore';
export { saveCurrentLocation, getStoredLocation } from './src/main/ets/util/LocationStore';
export type { SafeAreaInfo } from './src/main/ets/util/SafeAreaManager';
export { SafeAreaManager } from './src/main/ets/util/SafeAreaManager';
export { updateStatusBarContentColor } from './src/main/ets/util/SystemBarHelper';
export { getStringSync } from './src/main/ets/util/ResourceUtils';
export {
  haversineDistance,
  formatDuration,
  formatPace,
  formatDistanceKm,
  formatCalories,
  formatSteps,
  formatCoordsTitle,
  toDms,
  formatLocationSubTitle,
  KalmanFilter
} from './src/main/ets/util/WorkoutFormat';
export type { KalmanPoint } from './src/main/ets/util/WorkoutFormat';

// ===== service =====
export { fetchWeatherWarnings } from './src/main/ets/service/WeatherService';
export { WorkoutTaskService } from './src/main/ets/service/WorkoutTaskService';
export { WorkoutVoice } from './src/main/ets/service/WorkoutVoice';

// ===== api =====
export type { ApiResponse } from './src/main/ets/api/MockApi';
export { mockRequest, getAbilityContext, readRawFileText } from './src/main/ets/api/MockApi';
export type { HikingRoutePageData } from './src/main/ets/api/HikingRouteApi';
export { fetchHikingRoutes, fetchRouteDetail } from './src/main/ets/api/HikingRouteApi';
export type { HomeBanner } from './src/main/ets/api/HomeApi';
export { fetchHomeBanners } from './src/main/ets/api/HomeApi';
export type { CityGroup, CityListData } from './src/main/ets/api/CityApi';
export { fetchCityList, searchCities } from './src/main/ets/api/CityApi';
export type { HotSearchItem, SearchResultItem } from './src/main/ets/api/SearchApi';
export { fetchHotSearches, searchRoutes } from './src/main/ets/api/SearchApi';

// ===== router =====
export type { RouterParam } from './src/main/ets/router/PageContext';
export { PageContext } from './src/main/ets/router/PageContext';

// ===== component =====
export { VideoPlayerView } from './src/main/ets/component/VideoPlayerView';
