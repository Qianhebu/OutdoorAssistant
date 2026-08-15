import { mapCommon } from '@kit.MapKit';

/** 运动类型枚举 */
export enum SportType {
  HIKING = 0,
  RUNNING = 1,
  WALKING = 2
}

/** 运动类型选项数据结构 */
export interface SportTypeOption {
  type: SportType;
  label: string;
  icon: Resource;
  desc: string;
}

/** 可选运动类型列表 */
export const SPORT_TYPE_OPTIONS: SportTypeOption[] = [
  {
    type: SportType.HIKING,
    label: '爬山',
    icon: $r('sys.symbol.figure_hiking'),
    desc: '挑战山峰，登顶俯瞰群山'
  },
  {
    type: SportType.RUNNING,
    label: '跑步',
    icon: $r('sys.symbol.figure_run'),
    desc: '城市路跑，迈出健康节奏'
  },
  {
    type: SportType.WALKING,
    label: '徒步',
    icon: $r('sys.symbol.figure_walk'),
    desc: '轻装徒步，慢享自然风光'
  }
];

/** 运动数据指标键 */
export enum MetricKey {
  TIME = 0,
  DISTANCE = 1,
  ASCENT = 2,
  DESCENT = 3,
  PACE = 4,
  HEART_RATE = 5,
  STEPS = 6,
  CALORIES = 7,
  CLIMB = 8
}

/** 运动数据指标定义 */
export interface MetricDef {
  key: MetricKey;
  label: string;
  unit: string;
  icon: Resource;
}

/** 全部可选运动数据指标 */
export const METRIC_DEFS: MetricDef[] = [
  { key: MetricKey.TIME, label: '时间', unit: '', icon: $r('sys.symbol.clock_fill') },
  { key: MetricKey.DISTANCE, label: '距离', unit: 'km', icon: $r('sys.symbol.start_to_end_distance_fill') },
  { key: MetricKey.STEPS, label: '步数', unit: '步', icon: $r('sys.symbol.steps_fill') },
  { key: MetricKey.ASCENT, label: '上升', unit: 'm', icon: $r('sys.symbol.elevation_gain_fill') },
  { key: MetricKey.DESCENT, label: '下降', unit: 'm', icon: $r('sys.symbol.total_descent_fill') },
  { key: MetricKey.PACE, label: '配速', unit: '', icon: $r('sys.symbol.average_pace_fill') },
  { key: MetricKey.HEART_RATE, label: '心率', unit: 'bpm', icon: $r('sys.symbol.heart_fill') },
  { key: MetricKey.CALORIES, label: '热量', unit: '千卡', icon: $r('sys.symbol.flame_fill_1') },
  { key: MetricKey.CLIMB, label: '爬升', unit: 'm', icon: $r('sys.symbol.max_slope') }
];

/** 各运动类型默认展示指标（爬山带上升/下降；跑步/徒步带配速/心率） */
export const SPORT_DEFAULT_METRICS: MetricKey[][] = [
  [MetricKey.TIME, MetricKey.DISTANCE, MetricKey.ASCENT, MetricKey.DESCENT, MetricKey.STEPS, MetricKey.CALORIES],
  [MetricKey.TIME, MetricKey.DISTANCE, MetricKey.PACE, MetricKey.HEART_RATE, MetricKey.STEPS, MetricKey.CALORIES],
  [MetricKey.TIME, MetricKey.DISTANCE, MetricKey.PACE, MetricKey.HEART_RATE, MetricKey.STEPS, MetricKey.CALORIES]
];

/** 最多展示指标数量 */
export const MAX_METRIC_COUNT: number = 6;

/** 地图图层选项数据结构 */
export interface MapLayerOption {
  title: string;
  subtitle: string;
  mapType: mapCommon.MapType;
  thumbnail: Resource;
}

/** 可选地图图层列表 */
export const MAP_LAYER_OPTIONS: MapLayerOption[] = [
  {
    title: '标准地图',
    subtitle: '道路、建筑、绿地等基础地图',
    mapType: mapCommon.MapType.STANDARD,
    thumbnail: $r('app.media.map_layer_default_light')
  },
  {
    title: '地形地图',
    subtitle: '在标准地图上叠加地形信息',
    mapType: mapCommon.MapType.TERRAIN,
    thumbnail: $r('app.media.map_layer_terrain_light')
  },
  {
    title: '卫星地图',
    subtitle: '卫星影像地图',
    mapType: mapCommon.MapType.SATELLITE,
    thumbnail: $r('app.media.map_layer_satellite_light')
  }
];
