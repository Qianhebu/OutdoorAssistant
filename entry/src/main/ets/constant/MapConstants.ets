import { mapCommon } from '@kit.MapKit';

/** 地图默认中心点坐标（宁波附近） */
export const DEFAULT_LOCATION: mapCommon.LatLng = { latitude: 29.87, longitude: 121.55 };
/** 2D 模式倾斜角 */
export const MAP_2D_TILT: number = 0;
/** 3D 模式倾斜角 */
export const MAP_3D_TILT: number = 60;
/** 3D 模式最低缩放级别，低于此值会自动提升 */
export const MAP_3D_MIN_ZOOM: number = 17;
/** 自定义地图控件按钮尺寸 (vp) */
export const MAP_CONTROL_SIZE: number = 40;
/** 控件距屏幕右侧间距 (vp) */
export const MAP_CONTROL_RIGHT_MARGIN: number = 12;
/** 同类控件之间的间距 (vp) */
export const MAP_CONTROL_GAP: number = 8;
/** 单按钮控件数量（3D、图层） */
export const MAP_CONTROL_SINGLE_BUTTON_COUNT: number = 2;
/** 系统缩放控件高度，用于让自定义控件位于系统缩放上方 (vp) */
export const MAP_SYSTEM_ZOOM_CONTROL_HEIGHT: number = MAP_CONTROL_SIZE * 2 + 1;
/** 系统我的定位控件高度 (vp) */
export const MAP_SYSTEM_LOCATION_CONTROL_HEIGHT: number = MAP_CONTROL_SIZE;
/** 地图底部 padding 与系统控件之间的间距 (vp) */
export const MAP_SYSTEM_CONTROL_PADDING_GAP: number = 12;
/** 标题栏高度，用于放置系统指南针 (vp) */
export const MAP_TITLE_BAR_HEIGHT: number = 56;
/** 系统指南针与标题栏底部的间距 (vp) */
export const MAP_COMPASS_TOP_GAP: number = 8;
/** 开始运动按钮宽度和高度 (vp) */
export const MAP_START_BUTTON_WIDTH_AND_HEIGHT: number = 80;
/** 底部按钮行间距 (vp) */
export const MAP_BUTTON_ROW_SPACE: number = 28;
/** 长按结束进度刷新间隔 (ms) */
export const STOP_PROGRESS_INTERVAL: number = 30;
/** 长按结束进度每次递增值 */
export const STOP_PROGRESS_STEP: number = 2;
/** 长按结束进度满格后回弹动画时长 (ms) */
export const STOP_PROGRESS_RESET_DURATION: number = 450;
/** 结束按钮按下时的缩放比例 */
export const STOP_BUTTON_PRESSED_SCALE: number = 0.9;
/** 暂停态播放/结束两个大按钮中心点的水平偏移 (vp) */
export const PAUSED_ACTION_BUTTON_OFFSET: number = (MAP_START_BUTTON_WIDTH_AND_HEIGHT + MAP_BUTTON_ROW_SPACE) / 2;
/** 暂停态播放/结束两个大按钮合并动画容器宽度 (vp) */
export const PAUSED_ACTION_BUTTON_STACK_WIDTH: number = MAP_START_BUTTON_WIDTH_AND_HEIGHT * 2 + MAP_BUTTON_ROW_SPACE;
/** 运动面板收起后刷新 MapKit 系统控件的延迟 (ms) */
export const MAP_SYSTEM_CONTROL_REFRESH_DELAY: number = 420;
/** 运动数据面板高度兜底值 (vp)，实测高度未就绪时使用 */
export const WORKOUT_PANEL_HEIGHT: number = 300;
/** 运动数据面板展开后距左右边缘的间距 (vp) */
export const WORKOUT_PANEL_SIDE_GAP: number = 12;
/** 图层选择半模态高度 (vp)，与 detents 一致 */
export const MAP_LAYER_SHEET_HEIGHT: number = 300;
/** 地图 Logo 高度估算 (vp) */
export const MAP_LOGO_HEIGHT: number = 28;
/** 地图 Logo 距地图底部间距 (vp)，与 setLogoPadding 一致 */
export const MAP_LOGO_BOTTOM_GAP: number = 12;
/** 卫星图层叠加路网的最小缩放级别，缩小到该级别以下时切换为混合地图以显示道路 */
export const MAP_SATELLITE_ROAD_ZOOM_THRESHOLD: number = 15;
/** 天气预警定时刷新间隔 (ms)，每 10 分钟轮询一次 */
export const WEATHER_REFRESH_INTERVAL: number = 10 * 60 * 1000;
/** 天气预警按距离刷新阈值 (米)，移动超过 5km 时刷新预警 */
export const WEATHER_REFRESH_DISTANCE: number = 5000;
/** 轨迹点精度过滤阈值 (米)，超过此精度的点直接丢弃 */
export const TRACK_ACCURACY_THRESHOLD: number = 30;
/** 轨迹点速度过滤阈值 (米/秒)，超过此速度的点视为漂移丢弃 */
export const TRACK_SPEED_THRESHOLD: number = 10;
/** 轨迹点最小距离阈值 (米)，与上一点距离小于此值视为重复 */
export const TRACK_MIN_DISTANCE: number = 2;
/** 轨迹覆盖物线宽 (vp) */
export const TRACE_OVERLAY_WIDTH: number = 10;
/** 轨迹覆盖物颜色 (ARGB) */
export const TRACE_OVERLAY_COLOR: number = 0xFF00A991;
/** 轨迹视频帧间隔 (ms)，控制动画回放速度 */
export const TRACE_VIDEO_FRAME_INTERVAL: number = 200;
/** 真实运动检测：GPS 有速度但步数未增长的连续检查次数阈值，超过则判定为非真实运动 */
export const FAKE_MOTION_NO_STEP_THRESHOLD: number = 6;
/** 真实运动检测：GPS 最低速度阈值 (m/s)，高于此值认为设备在位移 */
export const FAKE_MOTION_GPS_SPEED_MIN: number = 1.0;
/** 真实运动检测：每次虚假运动警告的最小间隔 (ms)，避免频繁弹窗 */
export const FAKE_MOTION_WARNING_INTERVAL: number = 60 * 1000;
/** 真实运动检测：虚假运动最大警告次数，超过后不再提示 */
export const FAKE_MOTION_MAX_WARNINGS: number = 3;
/** 真实运动检测：延迟启动检测的运动时长 (秒)，运动前 120 秒内不检测，避免短暂真实运动误判 */
export const FAKE_MOTION_GRACE_DURATION: number = 120;
/** 真实运动检测：延迟启动检测的运动距离 (米)，运动不足 200 米时不检测，避免起步/热身阶段误判 */
export const FAKE_MOTION_GRACE_DISTANCE: number = 200;
