import { AppStorageV2 } from '@kit.ArkUI';

/** 记录指标存储的 AppStorageV2 key（默认使用类名） */
export const RECORD_METRIC_STORE_KEY: string = 'RecordMetricStore';

/** 记录数据指标定义 */
export interface RecordMetric {
  key: string;
  title: string;
  unit: string;
  icon: Resource;
}

/** 默认展示的指标 key */
export const DEFAULT_VISIBLE_METRIC_KEYS: string[] =
  ['distance', 'time', 'calories', 'pace', 'steps', 'heartRate'];

/** 全部可选指标（顺序即展示顺序） */
export const ALL_RECORD_METRICS: RecordMetric[] = [
  { key: 'distance', title: '距离', unit: '公里', icon: $r('sys.symbol.start_to_end_distance_fill') },
  { key: 'time', title: '时间', unit: '', icon: $r('sys.symbol.clock_fill') },
  { key: 'calories', title: '总消耗热量', unit: '千卡', icon: $r('sys.symbol.leaf_2_fill') },
  { key: 'pace', title: '配速', unit: '分/公里', icon: $r('sys.symbol.outward_curvature_fill') },
  { key: 'activeCalories', title: '活动热量', unit: '千卡', icon: $r('sys.symbol.leaf_2_fill') },
  { key: 'steps', title: '步数', unit: '步', icon: $r('sys.symbol.mountain_2_fill') },
  { key: 'speed', title: '速度', unit: '公里/时', icon: $r('sys.symbol.soaring_time_fill') },
  { key: 'cadence', title: '步频', unit: '步/分', icon: $r('sys.symbol.outward_curvature_fill') },
  { key: 'descent', title: '累计下降', unit: '米', icon: $r('sys.symbol.mountain_2_fill') },
  { key: 'altitude', title: '海拔', unit: '米', icon: $r('sys.symbol.soaring_time_fill') },
  { key: 'heartRate', title: '心率', unit: 'bpm', icon: $r('sys.symbol.info_circle') },
  { key: 'groundContactTime', title: '触地时间', unit: '毫秒', icon: $r('sys.symbol.clock_fill') },
  { key: 'eversion', title: '外翻幅度', unit: '度', icon: $r('sys.symbol.arrowtriangle_down_fill') },
  { key: 'impact', title: '着地冲击', unit: 'G', icon: $r('sys.symbol.leaf_2_fill') },
  { key: 'swingAngle', title: '摆动角度', unit: '度', icon: $r('sys.symbol.arrowtriangle_down_fill') },
  { key: 'flightRatio', title: '触地腾空比', unit: '%', icon: $r('sys.symbol.mountain_2_fill') }
];

/** 应用全局共享的记录指标可见性存储 */
@ObservedV2
export class RecordMetricStore {
  @Trace visibleKeys: string[] = DEFAULT_VISIBLE_METRIC_KEYS.slice();
}

/** 获取全局共享的记录指标存储实例 */
export function getRecordMetricStore(): RecordMetricStore {
  const store: RecordMetricStore | undefined =
    AppStorageV2.connect<RecordMetricStore>(RecordMetricStore, () => new RecordMetricStore());
  return store ?? new RecordMetricStore();
}
