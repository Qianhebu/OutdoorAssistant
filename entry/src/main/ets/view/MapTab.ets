import { map, mapCommon, MapComponent } from '@kit.MapKit';
import { geoLocationManager } from '@kit.LocationKit';
import { sensor } from '@kit.SensorServiceKit';
import {
  CapsuleSegmentButtonV2,
  ColorMetrics,
  curves,
  LengthMetrics,
  promptAction,
  SegmentButtonV2Items
} from '@kit.ArkUI';
import { AsyncCallback, BusinessError } from '@kit.BasicServicesKit';
import { abilityAccessCtrl, common, PermissionRequestResult, Permissions, Want } from '@kit.AbilityKit';
import { hdsMaterial, HdsNavDestination, HdsNavDestinationTitleMode, ScrollEffectType } from '@kit.UIDesignKit';
import { saveCurrentLocation } from '../utils/LocationStore';
import { WorkoutTaskService } from '../utils/WorkoutTaskService';
import { WorkoutVoice } from '../utils/WorkoutVoice';
import {
  formatCalories,
  formatCoordsTitle,
  formatDistanceKm,
  formatDuration,
  formatLocationSubTitle,
  formatPace,
  formatSteps,
  haversineDistance,
  KalmanFilter,
  KalmanPoint
} from '../utils/WorkoutFormat';
import { OutdoorTabType } from '../model/TabBarModel';
import { WeatherWarning, WeatherWarningLevel } from '../model/WeatherModel';
import { fetchWeatherWarnings } from '../utils/WeatherService';
import {
  MAP_LAYER_OPTIONS,
  MapLayerOption,
  MAX_METRIC_COUNT,
  METRIC_DEFS,
  MetricDef,
  MetricKey,
  SPORT_DEFAULT_METRICS,
  SPORT_TYPE_OPTIONS
} from '../model/WorkoutModels';
import {
  DEFAULT_LOCATION,
  FAKE_MOTION_GPS_SPEED_MIN,
  FAKE_MOTION_GRACE_DISTANCE,
  FAKE_MOTION_GRACE_DURATION,
  FAKE_MOTION_MAX_WARNINGS,
  FAKE_MOTION_NO_STEP_THRESHOLD,
  FAKE_MOTION_WARNING_INTERVAL,
  MAP_2D_TILT,
  MAP_3D_MIN_ZOOM,
  MAP_3D_TILT,
  MAP_BUTTON_ROW_SPACE,
  MAP_CONTROL_GAP,
  MAP_CONTROL_RIGHT_MARGIN,
  MAP_CONTROL_SINGLE_BUTTON_COUNT,
  MAP_CONTROL_SIZE,
  MAP_LAYER_SHEET_HEIGHT,
  MAP_LOGO_BOTTOM_GAP,
  MAP_LOGO_HEIGHT,
  MAP_SATELLITE_ROAD_ZOOM_THRESHOLD,
  MAP_START_BUTTON_WIDTH_AND_HEIGHT,
  MAP_SYSTEM_CONTROL_PADDING_GAP,
  MAP_SYSTEM_CONTROL_REFRESH_DELAY,
  MAP_SYSTEM_LOCATION_CONTROL_HEIGHT,
  MAP_SYSTEM_ZOOM_CONTROL_HEIGHT,
  MAP_TITLE_BAR_HEIGHT,
  PAUSED_ACTION_BUTTON_OFFSET,
  PAUSED_ACTION_BUTTON_STACK_WIDTH,
  STOP_BUTTON_PRESSED_SCALE,
  STOP_PROGRESS_INTERVAL,
  STOP_PROGRESS_STEP,
  TRACE_OVERLAY_COLOR,
  TRACE_OVERLAY_WIDTH,
  TRACE_VIDEO_FRAME_INTERVAL,
  TRACK_ACCURACY_THRESHOLD,
  TRACK_MIN_DISTANCE,
  TRACK_SPEED_THRESHOLD,
  WEATHER_REFRESH_DISTANCE,
  WEATHER_REFRESH_INTERVAL,
  WORKOUT_PANEL_HEIGHT,
  WORKOUT_PANEL_SIDE_GAP
} from '../constant/MapConstants';
import { AppStorageKeys } from '../constant/AppStorageKeys';

enum ReplayState {
  IDLE,
  PLAYING,
  FINISHED
}

@Component({ freezeWhenInactive: true })
export struct MapTab {
  /** 地图初始化参数，为 undefined 时尚未初始化 */
  @State mapOptions?: mapCommon.MapOptions = undefined;
  /** 当前定位坐标（WGS84），初始值为 DEFAULT_LOCATION */
  @State currentLocation: mapCommon.LatLng = DEFAULT_LOCATION;
  /** 标题栏坐标文本，如 "北 29°54'8.59"N 东121°33'4.16"E" */
  @State titleText: string = '';
  /** 标题栏副文本，如 "海拔22m 定位误差4.9m" */
  @State subTitleText: string = '';
  /** 是否已获取到 GPS 定位 */
  @State isGpsLocked: boolean = false;
  /** 当前可见卫星数量 */
  @State satelliteCount: number = 0;
  /** GNSS 信号等级：0=未定位, 1=弱, 2=中, 3=强 */
  @State gnssSignalLevel: number = 0;
  /** 坐标信息半模态是否展开 */
  @State isShowSheet: boolean = false;
  /** 坐标信息半模态当前高度 (vp)，用于计算地图 padding 避让 */
  @State sheetHeightVp: number = 0;
  /** 图层选择半模态是否展开 */
  @State isLayerSheetShown: boolean = false;
  /** 运动数据面板实测高度 (vp)，用于地图控件避让 */
  @State workoutPanelHeightVp: number = 0;
  /** 当前选中的运动类型索引 */
  @State @Watch('onSportIndexChanged') selectedSportIndex: number = 0;
  /** 切换运动类型时暂存目标索引，确认结束后再应用 */
  @State pendingSportIndex: number = -1;
  /** 上一次确认的运动类型索引，用于弹框取消时回滚 selectedSportIndex */
  private previousSportIndex: number = 0;
  /** 是否正在应用已确认的运动类型切换，避免 Watcher 二次弹框 */
  private isApplyingConfirmedSportIndex: boolean = false;
  /** 当前展示的运动数据指标 */
  @State displayMetricKeys: MetricKey[] = SPORT_DEFAULT_METRICS[0];
  /** 指标配置半模态是否展开 */
  @State isMetricConfigShown: boolean = false;
  /** 指标开关被拒绝时的刷新计数，用于强制开关复位 */
  @State metricConfigVersion: number = 0;
  /** 当前天气警示（无警示为 undefined） */
  @State weatherWarning?: WeatherWarning = undefined;
  /** 当前心率（bpm），暂无心率数据时保持 0 */
  @State heartRate: number = 0;
  /** 是否正在记录轨迹 */
  @State isTracking: boolean = false;
  /** 是否已进入本次运动面板，暂停时仍保持 true */
  @State isWorkoutStarted: boolean = false;
  /** 切换运动类型并确认结束当前运动后，保留面板但只显示播放按钮 */
  @State isSportSwitchReady: boolean = false;
  /** 控制按钮是否锁定 */
  @State isControlLocked: boolean = false;
  /** 是否开启运动语音提示 */
  @State isVoiceEnabled: boolean = true;
  /** 结束按钮长按进度（0~100），进度满后弹出结束确认 */
  @State stopProgress: number = 0;
  /** 结束按钮上方"长按结束"提示是否显示 */
  @State isStopTooltipShown: boolean = false;
  /** 结束按钮是否处于按压态 */
  @State isStopButtonPressed: boolean = false;
  /** 本轮长按是否已经完成，避免抬手事件再次清零打断动画 */
  @State isStopLongPressCompleted: boolean = false;
  /** 记录时长（秒） */
  @State trackingDuration: number = 0;
  /** 记录距离（米） */
  @State trackingDistance: number = 0;
  /** 累计上升（米），当前暂无海拔轨迹时保持 0 */
  @State trackingAscent: number = 0;
  /** 累计下降（米），当前暂无海拔轨迹时保持 0 */
  @State trackingDescent: number = 0;
  /** 是否处于 3D 倾斜模式 */
  @State isMap3DMode: boolean = false;
  /** 当前选中的地图图层类型 */
  @State selectedMapType: mapCommon.MapType = mapCommon.MapType.STANDARD;
  /** 当前地图朝向角 (bearing)，正北为 0，用于自定义指南针旋转 */
  @State compassBearing: number = 0;
  /** 当前地图缩放级别，由 cameraMove 事件实时更新 */
  @State mapZoom: number = 15;
  @State pageReady: boolean = false;
  /** 当前选中的 Tab 索引，切换时激活/停用地图页面 */
  @Prop @Watch('onCurrentTabChanged') currentTab: number = OutdoorTabType.RECORD;
  /** 顶部安全区高度 (vp) */
  @StorageLink(AppStorageKeys.TOP_INSET) @Watch('onSafeAreaChanged') topInset: number = 0;
  /** 底部安全区高度 (vp) */
  @StorageLink(AppStorageKeys.BOTTOM_INSET) @Watch('onSafeAreaChanged') bottomInset: number = 0;
  /** 关闭地图页面的回调 */
  onClose?: () => void = undefined;
  /** 地图容器宽度 (vp) */
  @State containerWidthVp: number = 0;
  /** 地图容器高度 (vp) */
  @State containerHeightVp: number = 0;
  /** 地图控制器，初始化回调中赋值 */
  private mapController?: map.MapComponentController = undefined;
  /** 地图初始化回调 */
  private mapCallback?: AsyncCallback<map.MapComponentController> = undefined;
  /** 需要申请的定位权限列表（前台定位，后台定位权限单独申请） */
  private locationPermissions: Array<Permissions> =
    ['ohos.permission.APPROXIMATELY_LOCATION', 'ohos.permission.LOCATION'];
  /** 地图页面是否处于激活状态（当前 Tab） */
  private isMapActive: boolean = false;
  /** 定位权限是否已授予 */
  private isPermissionGranted: boolean = false;
  /** 连续定位追踪是否已启动 */
  private isLocationTrackingStarted: boolean = false;
  /** 卫星状态监听是否已启动 */
  private isSatelliteTrackingStarted: boolean = false;
  /** 首次定位后是否已将地图中心移到当前位置 */
  private hasCenteredOnLocation: boolean = false;
  /** 半模态布局后延迟居中定位的定时器 ID */
  private sheetCenterTimer?: number = undefined;
  /** 记录轨迹的坐标点列表（WGS84） */
  private routePoints: mapCommon.LatLng[] = [];
  /** 已绘制的轨迹覆盖物对象（运动中增量绘制） */
  private traceOverlay?: map.TraceOverlay = undefined;
  /** 已绘制的轨迹折线对象（运动结束/地图切换后全量绘制，支持圆角连接） */
  private routePolyline?: map.MapPolyline = undefined;
  /** 路线起点标记（开始时的人物图标） */
  private startMarker?: map.Marker = undefined;
  /** 计时器 ID */
  private durationTimer?: number = undefined;
  /** 结束按钮长按进度定时器 ID */
  private stopProgressTimer?: number = undefined;
  /** 上一次定位坐标（用于计算距离增量） */
  private lastTrackingLocation?: mapCommon.LatLng = undefined;
  /** 上一次定位海拔（用于计算上升/下降增量） */
  private lastAltitude?: number = undefined;
  /** 天气预警定时刷新定时器 ID */
  private weatherRefreshTimer?: number = undefined;
  /** 上一次天气预警刷新时的定位坐标（用于按距离刷新） */
  private lastWeatherLocation?: mapCommon.LatLng = undefined;
  /** 卡尔曼滤波器，用于平滑 GPS 轨迹坐标去噪 */
  private kalmanFilter: KalmanFilter = new KalmanFilter();
  /** 运动真实性检测：计步器订阅是否已启动 */
  private isPedometerStarted: boolean = false;
  /** 运动真实性检测：运动开始时的计步器步数 */
  private startSteps: number = -1;
  /** 运动真实性检测：最新一次计步器回调的步数 */
  private currentSteps: number = 0;
  /** 运动真实性检测：连续无步数增长但 GPS 有速度的检查次数 */
  private noStepGpsMovingCount: number = 0;
  /** 运动真实性检测：已提示过的虚假运动警告次数 */
  private fakeMotionWarningCount: number = 0;
  /** 运动真实性检测：上一次虚假运动警告的时间戳 (ms)，用于限流 */
  private lastFakeMotionWarningTime: number = 0;
  /** 轨迹回放状态：IDLE=未开始, PLAYING=播放中, FINISHED=已结束 */
  private replayState: ReplayState = ReplayState.IDLE;
  /** 轨迹回放动画覆盖物 */
  private replayTraceOverlay?: map.TraceOverlay = undefined;
  /** 轨迹回放终点标记 */
  private endMarker?: map.Marker = undefined;
  /** 地图容器组件 id，用于 ComponentSnapshot 截图 */
  private mapContainerId: string = 'mapContainer';
  /** 运动类型分段按钮选项（仅图标） */
  private segmentSportItems: SegmentButtonV2Items = new SegmentButtonV2Items([
    { symbol: $r('sys.symbol.figure_hiking') },
    { symbol: $r('sys.symbol.figure_run') },
    { symbol: $r('sys.symbol.figure_walk') }
  ]);

  /** Tab 切换时激活或停用地图页面 */
  private onCurrentTabChanged(): void {
    if (this.currentTab === OutdoorTabType.RECORD) {
      this.activateMapPage();
    } else {
      this.deactivateMapPage();
    }
  }

  /** 安全区变化后重新调整系统控件和自定义控件位置 */
  private onSafeAreaChanged(): void {
    this.applySheetLayout();
  }

  /** 激活地图页面：显示半模态、启动定位与卫星追踪 */
  private activateMapPage(): void {
    if (this.isMapActive) {
      this.isShowSheet = false;
      this.applySheetLayout();
      return;
    }
    this.isMapActive = true;
    this.isShowSheet = false;
    this.hasCenteredOnLocation = false;
    this.applySheetLayout();
    this.startWeatherRefresh();
    if (this.isPermissionGranted) {
      this.startLocationTracking();
      this.startSatelliteTracking();
    } else {
      this.requestLocationPermission();
    }
  }

  /** 停用地图页面：隐藏半模态、停止定位与卫星追踪 */
  private deactivateMapPage(): void {
    this.isMapActive = false;
    this.isShowSheet = false;
    this.isLayerSheetShown = false;
    this.clearSheetCenterTimer();
    this.stopWeatherRefresh();
    this.applySheetLayout();
    this.stopTracking();
    this.stopLocationTracking();
    this.stopSatelliteTracking();
    this.stopPedometer();
  }

  /** 请求定位权限，授权后启动定位追踪 */
  private async requestLocationPermission(): Promise<void> {
    if (!this.isMapActive) {
      return;
    }
    try {
      const atManager: abilityAccessCtrl.AtManager = abilityAccessCtrl.createAtManager();
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const result: PermissionRequestResult =
        await atManager.requestPermissionsFromUser(context, this.locationPermissions);
      console.info(`MapTab requestPermission result=${JSON.stringify(result)}`);
      const granted = result.authResults.every((status: number) => status === 0);
      this.isPermissionGranted = granted;
      if (granted && this.isMapActive) {
        this.startLocationTracking();
        this.startSatelliteTracking();
        this.requestBackgroundLocationPermission();
      }
    } catch (err) {
      console.error(`MapTab request location permission failed: ${JSON.stringify(err)}`);
    }
  }

  /** 申请后台定位权限（长时任务需要），失败不影响前台定位 */
  private requestBackgroundLocationPermission(): void {
    const atManager: abilityAccessCtrl.AtManager = abilityAccessCtrl.createAtManager();
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    atManager.requestPermissionsFromUser(context, ['ohos.permission.LOCATION_IN_BACKGROUND'])
      .then((result: PermissionRequestResult) => {
        console.info(`MapTab background permission result=${JSON.stringify(result)}`);
      }).catch((err: BusinessError) => {
      console.info(`MapTab background permission skipped: ${err.code} ${err.message}`);
    });
  }

  /** 申请活动识别权限（计步器需要），授权后启动计步器 */
  private requestActivityMotionPermission(): void {
    const atManager: abilityAccessCtrl.AtManager = abilityAccessCtrl.createAtManager();
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    atManager.requestPermissionsFromUser(context, ['ohos.permission.ACTIVITY_MOTION'])
      .then((result: PermissionRequestResult) => {
        const granted: boolean = result.authResults.length > 0 && result.authResults[0] === 0;
        console.info(`MapTab ACTIVITY_MOTION permission result=${JSON.stringify(result)}`);
        if (granted) {
          this.startPedometer();
        }
      }).catch((err: BusinessError) => {
      console.info(`MapTab ACTIVITY_MOTION permission skipped: ${err.code} ${err.message}`);
    });
  }

  /** 启动定位追踪：启用地图定位图层 + 注册连续定位监听 + 立即获取一次定位 */
  private startLocationTracking(): void {
    if (!this.isMapActive || !this.isPermissionGranted || this.isLocationTrackingStarted) {
      return;
    }
    this.isLocationTrackingStarted = true;
    this.enableMyLocationLayer();
    // 地图控制器可能尚未就绪，延迟重试启用定位图层
    setTimeout(() => {
      this.enableMyLocationLayer();
    }, 800);
    let locationRequest: geoLocationManager.ContinuousLocationRequest = {
      interval: 1,
      locationScenario: 0x401
    };
    try {
      geoLocationManager.on('locationChange', locationRequest, this.locationChangeCb);
    } catch (error) {
      this.isLocationTrackingStarted = false;
      console.error(`MapTab locationChange failed: ${(error as BusinessError).message}`);
      return;
    }
    this.requestCurrentLocation();
  }

  /** 停止定位追踪 */
  private stopLocationTracking(): void {
    if (!this.isLocationTrackingStarted) {
      return;
    }
    this.isLocationTrackingStarted = false;
    try {
      geoLocationManager.off('locationChange', this.locationChangeCb);
    } catch (err) {
      console.info(`MapTab off locationChange: ${JSON.stringify(err)}`);
    }
  }

  /** 启动计步器订阅，用于运动真实性检测 */
  private startPedometer(): void {
    if (this.isPedometerStarted) {
      return;
    }
    try {
      sensor.on(sensor.SensorId.PEDOMETER, (data: sensor.PedometerResponse) => {
        this.onPedometerUpdate(data.steps);
      });
      this.isPedometerStarted = true;
      console.info(`MapTab pedometer started`);
    } catch (err) {
      console.error(`MapTab pedometer start failed: ${(err as BusinessError).message}`);
    }
  }

  /** 停止计步器订阅 */
  private stopPedometer(): void {
    if (!this.isPedometerStarted) {
      return;
    }
    try {
      sensor.off(sensor.SensorId.PEDOMETER);
    } catch (err) {
      console.error(`MapTab pedometer stop failed: ${(err as BusinessError).message}`);
    }
    this.isPedometerStarted = false;
    this.startSteps = -1;
    this.currentSteps = 0;
    this.noStepGpsMovingCount = 0;
    this.fakeMotionWarningCount = 0;
    this.lastFakeMotionWarningTime = 0;
  }

  /** 计步器回调：记录运动开始后的步数增量 */
  private onPedometerUpdate(steps: number): void {
    if (!this.isTracking) {
      return;
    }
    if (this.startSteps < 0) {
      this.startSteps = steps;
      this.currentSteps = steps;
      return;
    }
    this.currentSteps = steps;
    if (steps > this.startSteps) {
      this.noStepGpsMovingCount = 0;
    }
  }

  /** 真实运动检测：运动超过宽限期后，GPS 有速度但步数无增长则判定为非真实运动 */
  private checkFakeMotion(gpsSpeed: number): void {
    if (!this.isTracking) {
      return;
    }
    if (this.trackingDuration < FAKE_MOTION_GRACE_DURATION) {
      return;
    }
    if (this.trackingDistance < FAKE_MOTION_GRACE_DISTANCE) {
      return;
    }
    if (this.fakeMotionWarningCount >= FAKE_MOTION_MAX_WARNINGS) {
      return;
    }
    if (gpsSpeed < FAKE_MOTION_GPS_SPEED_MIN) {
      this.noStepGpsMovingCount = 0;
      return;
    }
    if (this.startSteps < 0) {
      return;
    }
    const stepsIncreased: boolean = this.currentSteps > this.startSteps;
    if (stepsIncreased) {
      this.noStepGpsMovingCount = 0;
      return;
    }
    this.noStepGpsMovingCount++;
    if (this.noStepGpsMovingCount >= FAKE_MOTION_NO_STEP_THRESHOLD) {
      const now: number = Date.now();
      if (now - this.lastFakeMotionWarningTime < FAKE_MOTION_WARNING_INTERVAL) {
        return;
      }
      this.lastFakeMotionWarningTime = now;
      this.fakeMotionWarningCount++;
      this.noStepGpsMovingCount = 0;
      promptAction.showToast({
        message: this.resString($r('app.string.fake_motion_warning')),
        duration: 4000
      });
    }
  }

  /** 立即获取一次当前定位，更新蓝点并写入共享定位 */
  private requestCurrentLocation(): void {
    if (!this.isMapActive) {
      return;
    }
    const request: geoLocationManager.SingleLocationRequest = {
      locatingPriority: 0x502,
      locatingTimeoutMs: 10000
    };
    geoLocationManager.getCurrentLocation(request).then((location: geoLocationManager.Location) => {
      this.onLocationUpdate(location);
    }).catch((err: BusinessError) => {
      console.error(`MapTab get current location failed: ${JSON.stringify(err)}`);
    });
  }

  /** 统一处理一次定位结果：更新地图蓝点、标题坐标、GPS 状态并写入共享定位 */
  private onLocationUpdate(location: geoLocationManager.Location): void {
    if (!this.isMapActive) {
      return;
    }
    this.currentLocation = { latitude: location.latitude, longitude: location.longitude };
    this.mapController?.setMyLocation(location);
    saveCurrentLocation(location.latitude, location.longitude);
    this.isGpsLocked = true;
    this.titleText = formatCoordsTitle(location.latitude, location.longitude);
    this.subTitleText = formatLocationSubTitle(location);
    if (this.isTracking) {
      this.updateAltitudeDelta(location.altitude);
      if (this.isValidTrackPoint(location)) {
        this.addRoutePoint(this.currentLocation);
      }
      this.checkFakeMotion(location.speed);
    }
    this.maybeRefreshWeather(this.currentLocation);
    this.scheduleCenterAfterSheetLayout();
  }

  /** 根据相邻两次定位的海拔差累计上升/下降，忽略 1m 内的噪声波动 */
  private updateAltitudeDelta(altitude: number): void {
    if (this.lastAltitude === undefined) {
      this.lastAltitude = altitude;
      return;
    }
    const diff: number = altitude - this.lastAltitude;
    this.lastAltitude = altitude;
    if (diff > 1) {
      this.trackingAscent += diff;
    } else if (diff < -1) {
      this.trackingDescent += -diff;
    }
  }

  /** 按当前定位刷新天气警示 */
  private async refreshWeatherWarning(): Promise<void> {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    if (context === undefined) {
      return;
    }
    const warning: WeatherWarning | undefined =
      await fetchWeatherWarnings(context, this.currentLocation.latitude, this.currentLocation.longitude);
    this.weatherWarning = warning;
  }

  /** 启动天气预警定时刷新：立即刷新一次，之后按 WEATHER_REFRESH_INTERVAL 间隔轮询 */
  private startWeatherRefresh(): void {
    this.stopWeatherRefresh();
    this.refreshWeatherWarning();
    this.weatherRefreshTimer = setInterval(() => {
      this.refreshWeatherWarning();
    }, WEATHER_REFRESH_INTERVAL);
  }

  /** 停止天气预警定时刷新 */
  private stopWeatherRefresh(): void {
    if (this.weatherRefreshTimer !== undefined) {
      clearInterval(this.weatherRefreshTimer);
      this.weatherRefreshTimer = undefined;
    }
  }

  /** 位置变化超过 WEATHER_REFRESH_DISTANCE 时刷新天气预警，避免区域变化后预警不同步 */
  private maybeRefreshWeather(latLng: mapCommon.LatLng): void {
    if (this.lastWeatherLocation !== undefined) {
      const dist: number = haversineDistance(
        this.lastWeatherLocation.latitude, this.lastWeatherLocation.longitude,
        latLng.latitude, latLng.longitude
      );
      if (dist < WEATHER_REFRESH_DISTANCE) {
        return;
      }
    }
    this.lastWeatherLocation = latLng;
    this.refreshWeatherWarning();
  }

  /** 开始记录轨迹 */
  private startTracking(): void {
    if (this.isTracking) {
      return;
    }
    if (!geoLocationManager.isLocationEnabled()) {
      promptAction.showToast({ message: this.resString($r('app.string.location_disabled')) });
      return;
    }
    if (this.isSportSwitchReady) {
      this.startSwitchedWorkout();
      return;
    }
    if (this.isWorkoutStarted) {
      this.resumeTracking();
      return;
    }
    this.isWorkoutStarted = true;
    this.isControlLocked = false;
    this.isTracking = true;
    this.previousSportIndex = this.selectedSportIndex;
    this.trackingDuration = 0;
    this.trackingDistance = 0;
    this.trackingAscent = 0;
    this.trackingDescent = 0;
    this.routePoints = [];
    this.lastTrackingLocation = undefined;
    this.lastAltitude = undefined;
    this.startSteps = -1;
    this.currentSteps = 0;
    this.noStepGpsMovingCount = 0;
    this.fakeMotionWarningCount = 0;
    this.lastFakeMotionWarningTime = 0;
    if (this.isGpsLocked) {
      this.addRoutePoint(this.currentLocation);
    }
    this.startDurationTimer();
    this.startWorkoutBackgroundService();
    this.requestActivityMotionPermission();
    this.speakWorkoutVoice(
      `${SPORT_TYPE_OPTIONS[this.selectedSportIndex].label}${this.resString($r('app.string.voice_started'))}`);
  }

  /** 切换运动类型确认结束后，从保留面板的播放按钮开始新运动 */
  private startSwitchedWorkout(): void {
    if (!geoLocationManager.isLocationEnabled()) {
      promptAction.showToast({ message: this.resString($r('app.string.location_disabled')) });
      return;
    }
    this.resetWorkoutData();
    this.isSportSwitchReady = false;
    this.isWorkoutStarted = true;
    this.isControlLocked = false;
    this.isTracking = true;
    this.previousSportIndex = this.selectedSportIndex;
    this.startSteps = -1;
    this.currentSteps = 0;
    this.noStepGpsMovingCount = 0;
    this.fakeMotionWarningCount = 0;
    this.lastFakeMotionWarningTime = 0;
    if (this.isGpsLocked) {
      this.addRoutePoint(this.currentLocation);
    }
    this.startDurationTimer();
    this.startWorkoutBackgroundService();
    this.requestActivityMotionPermission();
    this.speakWorkoutVoice(
      `${SPORT_TYPE_OPTIONS[this.selectedSportIndex].label}${this.resString($r('app.string.voice_started'))}`);
  }

  /** 继续记录轨迹：不重置运动数据 */
  private resumeTracking(): void {
    if (this.isTracking) {
      return;
    }
    this.isTracking = true;
    this.startDurationTimer();
    this.speakWorkoutVoice(
      `${SPORT_TYPE_OPTIONS[this.selectedSportIndex].label}${this.resString($r('app.string.voice_resumed'))}`);
  }

  /** 暂停记录轨迹：保留本次运动面板和已累计数据 */
  private pauseTracking(): void {
    if (!this.isTracking) {
      return;
    }
    this.isTracking = false;
    this.clearDurationTimer();
    this.speakWorkoutVoice(
      `${SPORT_TYPE_OPTIONS[this.selectedSportIndex].label}${this.resString($r('app.string.voice_paused'))}`);
  }

  /** 启动运动计时器 */
  private startDurationTimer(): void {
    this.clearDurationTimer();
    this.durationTimer = setInterval(() => {
      this.trackingDuration++;
      this.updateWorkoutNotification();
    }, 1000);
  }

  /** 清理运动计时器 */
  private clearDurationTimer(): void {
    if (this.durationTimer !== undefined) {
      clearInterval(this.durationTimer);
      this.durationTimer = undefined;
    }
  }

  /** 启动运动长时任务：关闭应用后后台继续记录，状态栏显示运动通知 */
  private startWorkoutBackgroundService(): void {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    if (context === undefined) {
      return;
    }
    WorkoutTaskService.start(context).then((success: boolean) => {
      if (success) {
        this.updateWorkoutNotification();
      }
    });
  }

  /** 停止运动长时任务并移除状态栏通知 */
  private stopWorkoutBackgroundService(): void {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    if (context === undefined) {
      return;
    }
    WorkoutTaskService.stop(context);
  }

  /** 更新状态栏运动通知内容 */
  private updateWorkoutNotification(): void {
    if (!WorkoutTaskService.isRunning()) {
      return;
    }
    const sportLabel: string = SPORT_TYPE_OPTIONS[this.selectedSportIndex].label;
    const title: string =
      `${sportLabel}${this.resString($r('app.string.notify_workout_ing'))}${formatDuration(this.trackingDuration,
        true)}`;
    const text: string =
      `距离 ${formatDistanceKm(this.trackingDistance)} km · 热量 ${formatCalories(this.trackingDistance)} 千卡`;
    WorkoutTaskService.update(title, text);
  }

  /** 播报当前运动状态语音（语音提示关闭时自动忽略） */
  private speakWorkoutVoice(text: string): void {
    WorkoutVoice.speak(text, this.isVoiceEnabled);
  }

  /** 读取字符串资源，供需要 string 类型的位置使用 */
  private resString(res: Resource): string {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) {
      return '';
    }
    return context.resourceManager.getStringSync(res.id);
  }

  /** 读取带占位符的字符串资源，如 %d/%s */
  private resStringArgs(res: Resource, ...args: Array<string | number>): string {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) {
      return '';
    }
    return context.resourceManager.getStringSync(res.id, ...args);
  }

  /** 停止记录轨迹 */
  private stopTracking(): void {
    if (!this.isWorkoutStarted && !this.isTracking) {
      return;
    }
    this.isTracking = false;
    this.isWorkoutStarted = false;
    this.isSportSwitchReady = false;
    this.isControlLocked = false;
    this.workoutPanelHeightVp = 0;
    this.cancelStopProgress();
    this.clearDurationTimer();
    this.stopWorkoutBackgroundService();
    this.stopPedometer();
    this.clearReplayOverlay();
    this.showFullRoute();
    this.applySheetLayout();
    setTimeout(() => {
      this.applySheetLayout();
    }, MAP_SYSTEM_CONTROL_REFRESH_DELAY);
  }

  /** 切换运动类型时结束当前运动：保留数据面板，只显示 play_circle_fill 按钮 */
  private prepareSportSwitchWorkout(): void {
    this.isTracking = false;
    this.isWorkoutStarted = true;
    this.isSportSwitchReady = true;
    this.isControlLocked = false;
    this.cancelStopProgress();
    this.clearDurationTimer();
    this.resetWorkoutData();
    this.applySheetLayout();
  }

  /** 清除本次运动数据与地图轨迹 */
  private resetWorkoutData(): void {
    this.trackingDuration = 0;
    this.trackingDistance = 0;
    this.trackingAscent = 0;
    this.trackingDescent = 0;
    this.routePoints = [];
    this.lastTrackingLocation = undefined;
    this.lastAltitude = undefined;
    this.kalmanFilter.reset();
    this.removeRouteStartMarker();
    this.removeTraceOverlay();
    this.removeRoutePolyline();
    this.clearReplayOverlay();
  }

  /** 开始结束按钮长按进度，进度满后立即弹出结束确认框 */
  private startStopProgress(): void {
    this.cancelStopProgress();
    this.isStopLongPressCompleted = false;
    this.stopProgress = 0;
    this.stopProgressTimer = setInterval(() => {
      this.stopProgress += STOP_PROGRESS_STEP;
      if (this.stopProgress >= 100) {
        this.stopProgress = 100;
        this.isStopLongPressCompleted = true;
        this.clearStopProgressTimer();
        this.onStopProgressCompleted();
      }
    }, STOP_PROGRESS_INTERVAL);
  }

  /** 进度条满 100% 时：保持满格显示并弹出确认框，等待松手后再隐藏进度 */
  private onStopProgressCompleted(): void {
    this.showEndWorkoutDialog();
  }

  /** 完成结束按钮长按：弹窗已在进度满时触发，松手后隐藏进度和提示 */
  private finishStopProgress(): void {
    this.clearStopProgressTimer();
    this.isStopButtonPressed = false;
    this.isStopTooltipShown = false;
    this.isStopLongPressCompleted = false;
    this.stopProgress = 0;
  }

  /** 取消结束按钮长按进度并复位 */
  private cancelStopProgress(): void {
    this.clearStopProgressTimer();
    this.isStopButtonPressed = false;
    this.isStopLongPressCompleted = false;
    this.stopProgress = 0;
  }

  /** 清除结束按钮长按进度定时器 */
  private clearStopProgressTimer(): void {
    if (this.stopProgressTimer !== undefined) {
      clearInterval(this.stopProgressTimer);
      this.stopProgressTimer = undefined;
    }
  }

  /** 弹出结束运动确认框 */
  private showEndWorkoutDialog(): void {
    this.getUIContext().showAlertDialog({
      title: $r('app.string.end_workout'),
      message: $r('app.string.short_distance_confirm'),
      autoCancel: false,
      alignment: DialogAlignment.Center,
      primaryButton: {
        value: $r('app.string.continue_workout'),
        action: () => {
          this.finishStopProgress();
        }
      },
      secondaryButton: {
        value: $r('app.string.end_workout'),
        fontColor: $r('app.color.action_red'),
        action: () => {
          this.getUIContext().animateTo({ duration: 400, curve: Curve.EaseOut }, () => {
            this.stopTracking();
          });
        }
      }
    });
  }

  /** 轨迹点过滤：精度和速度不合格则丢弃 */
  private isValidTrackPoint(location: geoLocationManager.Location): boolean {
    if (location.accuracy > TRACK_ACCURACY_THRESHOLD) {
      return false;
    }
    if (location.speed > TRACK_SPEED_THRESHOLD) {
      return false;
    }
    return true;
  }

  /** 添加轨迹点并增量绘制轨迹覆盖物（经卡尔曼滤波平滑后） */
  private addRoutePoint(latLng: mapCommon.LatLng): void {
    const smoothed: KalmanPoint = this.kalmanFilter.filter(latLng.latitude, latLng.longitude);
    const smoothLatLng: mapCommon.LatLng = { latitude: smoothed.latitude, longitude: smoothed.longitude };
    if (this.lastTrackingLocation !== undefined) {
      const dist: number = haversineDistance(this.lastTrackingLocation.latitude,
        this.lastTrackingLocation.longitude, smoothLatLng.latitude, smoothLatLng.longitude);
      if (dist < TRACK_MIN_DISTANCE) {
        return;
      }
      this.trackingDistance += dist;
    }
    this.lastTrackingLocation = smoothLatLng;
    this.routePoints.push(smoothLatLng);
    if (this.routePoints.length === 1) {
      this.addRouteStartMarker(smoothLatLng);
    }
    this.drawTraceSegment();
    this.animateCameraToCurrentLocation();
  }

  /** 在路线起点添加运动起点标记 */
  private addRouteStartMarker(latLng: mapCommon.LatLng): void {
    const controller = this.mapController;
    if (!controller || this.startMarker !== undefined) {
      return;
    }
    const options: mapCommon.MarkerOptions = {
      position: this.convertToMapCoordinate(latLng),
      icon: $r('app.media.local_and_figure_run_leave'),
      anchorU: 0.5,
      anchorV: 1,
      visible: true,
      zIndex: 3
    };
    try {
      controller.addMarker(options).then((marker: map.Marker) => {
        this.startMarker = marker;
      }).catch((err: BusinessError) => {
        console.error(`MapTab add start marker failed: ${JSON.stringify(err)}`);
      });
    } catch (err) {
      console.error(`MapTab add start marker sync failed: ${JSON.stringify(err)}`);
    }
  }

  /** 移除路线起点标记 */
  private removeRouteStartMarker(): void {
    if (this.startMarker !== undefined) {
      try {
        this.startMarker.remove();
      } catch (err) {
        console.error(`MapTab remove start marker failed: ${JSON.stringify(err)}`);
      }
      this.startMarker = undefined;
    }
  }

  /** 移除地图上的轨迹覆盖物 */
  private removeTraceOverlay(): void {
    if (this.traceOverlay !== undefined) {
      try {
        this.traceOverlay.remove();
      } catch (err) {
        console.error(`MapTab remove trace overlay failed: ${JSON.stringify(err)}`);
      }
      this.traceOverlay = undefined;
    }
  }

  /** 移除地图上的轨迹折线 */
  private removeRoutePolyline(): void {
    if (this.routePolyline !== undefined) {
      try {
        this.routePolyline.remove();
      } catch (err) {
        console.error(`MapTab remove route polyline failed: ${JSON.stringify(err)}`);
      }
      this.routePolyline = undefined;
    }
  }

  /** 增量绘制最新一段轨迹：传 3 点（前段末点重叠），确保段间无断痕 */
  private drawTraceSegment(): void {
    const controller = this.mapController;
    if (!controller || this.routePoints.length < 2) {
      return;
    }
    const tracePoints: mapCommon.LatLng[] = [];
    if (this.routePoints.length >= 3) {
      tracePoints.push(this.convertToMapCoordinate(this.routePoints[this.routePoints.length - 3]));
    }
    tracePoints.push(this.convertToMapCoordinate(this.routePoints[this.routePoints.length - 2]));
    tracePoints.push(this.convertToMapCoordinate(this.routePoints[this.routePoints.length - 1]));
    const traceOptions: mapCommon.TraceOverlayParams = {
      points: tracePoints,
      width: TRACE_OVERLAY_WIDTH,
      color: TRACE_OVERLAY_COLOR
    };
    try {
      controller.addTraceOverlay(traceOptions).then((overlay: map.TraceOverlay) => {
        this.traceOverlay = overlay;
      }).catch((err: BusinessError) => {
        console.error(`MapTab addTraceOverlay failed: ${JSON.stringify(err)}`);
      });
    } catch (err) {
      console.error(`MapTab addTraceOverlay sync failed: ${JSON.stringify(err)}`);
    }
  }

  /** 全量重建轨迹折线（地图类型切换后渲染层重建），使用 addPolyline 支持圆角连接消除断痕 */
  private rebuildTraceOverlay(): void {
    const controller = this.mapController;
    if (!controller || this.routePoints.length < 2) {
      return;
    }
    this.removeTraceOverlay();
    this.removeRoutePolyline();
    const gcjPoints: mapCommon.LatLng[] = [];
    for (let i = 0; i < this.routePoints.length; i++) {
      gcjPoints.push(this.convertToMapCoordinate(this.routePoints[i]));
    }
    const polylineOptions: mapCommon.MapPolylineOptions = {
      points: gcjPoints,
      width: TRACE_OVERLAY_WIDTH,
      color: TRACE_OVERLAY_COLOR,
      jointType: mapCommon.JointType.ROUND,
      startCap: mapCommon.CapStyle.ROUND,
      endCap: mapCommon.CapStyle.ROUND,
      visible: true,
      zIndex: 2
    };
    try {
      controller.addPolyline(polylineOptions).then((polyline: map.MapPolyline) => {
        this.routePolyline = polyline;
      }).catch((err: BusinessError) => {
        console.error(`MapTab rebuildTraceOverlay addPolyline failed: ${JSON.stringify(err)}`);
      });
    } catch (err) {
      console.error(`MapTab rebuildTraceOverlay sync failed: ${JSON.stringify(err)}`);
    }
  }

  /** 运动中相机跟随当前位置 */
  private animateCameraToCurrentLocation(): void {
    const controller = this.mapController;
    if (!controller || !this.isGpsLocked) {
      return;
    }
    const mapLatLng: mapCommon.LatLng = this.convertToMapCoordinate(this.currentLocation);
    try {
      controller.animateCamera(map.newLatLng(mapLatLng, this.mapZoom), 300);
    } catch (err) {
      console.error(`MapTab animate camera to location failed: ${JSON.stringify(err)}`);
    }
  }

  /** 运动结束后：移除增量轨迹覆盖物，用 addPolyline 全量绘制圆角折线，再调整地图视角 */
  private showFullRoute(): void {
    const controller = this.mapController;
    if (!controller || this.routePoints.length < 2) {
      return;
    }
    this.removeTraceOverlay();
    this.removeRoutePolyline();
    const gcjPoints: mapCommon.LatLng[] = [];
    for (let i = 0; i < this.routePoints.length; i++) {
      gcjPoints.push(this.convertToMapCoordinate(this.routePoints[i]));
    }
    const polylineOptions: mapCommon.MapPolylineOptions = {
      points: gcjPoints,
      width: TRACE_OVERLAY_WIDTH,
      color: TRACE_OVERLAY_COLOR,
      jointType: mapCommon.JointType.ROUND,
      startCap: mapCommon.CapStyle.ROUND,
      endCap: mapCommon.CapStyle.ROUND,
      visible: true,
      zIndex: 2
    };
    try {
      controller.addPolyline(polylineOptions).then((polyline: map.MapPolyline) => {
        this.routePolyline = polyline;
      }).catch((err: BusinessError) => {
        console.error(`MapTab showFullRoute addPolyline failed: ${JSON.stringify(err)}`);
      });
    } catch (err) {
      console.error(`MapTab showFullRoute sync failed: ${JSON.stringify(err)}`);
    }
    let minLat: number = 90;
    let maxLat: number = -90;
    let minLng: number = 180;
    let maxLng: number = -180;
    for (let i = 0; i < this.routePoints.length; i++) {
      const p: mapCommon.LatLng = this.routePoints[i];
      if (p.latitude < minLat) {
        minLat = p.latitude;
      }
      if (p.latitude > maxLat) {
        maxLat = p.latitude;
      }
      if (p.longitude < minLng) {
        minLng = p.longitude;
      }
      if (p.longitude > maxLng) {
        maxLng = p.longitude;
      }
    }
    const ne: mapCommon.LatLng = this.convertToMapCoordinate({ latitude: maxLat, longitude: maxLng });
    const sw: mapCommon.LatLng = this.convertToMapCoordinate({ latitude: minLat, longitude: minLng });
    const latLngBounds: mapCommon.LatLngBounds = {
      northeast: ne,
      southwest: sw
    };
    try {
      const cameraUpdate: map.CameraUpdate = map.newLatLngBounds(latLngBounds, 200);
      controller.moveCamera(cameraUpdate);
    } catch (err) {
      console.error(`MapTab showFullRoute failed: ${JSON.stringify(err)}`);
    }
    this.replayState = ReplayState.IDLE;
  }

  /** 启动轨迹回放动画：利用 TraceOverlay 内置动画能力，逐段绘制轨迹 + 相机跟随飞行 */
  private startTraceReplay(): void {
    const controller = this.mapController;
    if (!controller || this.routePoints.length < 2) {
      return;
    }
    if (this.replayState === ReplayState.PLAYING) {
      return;
    }
    this.clearReplayOverlay();
    this.removeRoutePolyline();
    this.replayState = ReplayState.PLAYING;
    const gcjPoints: mapCommon.LatLng[] = [];
    for (let i = 0; i < this.routePoints.length; i++) {
      gcjPoints.push(this.convertToMapCoordinate(this.routePoints[i]));
    }
    const totalPoints: number = gcjPoints.length;
    const animationDuration: number = Math.max(3000, Math.min(totalPoints * TRACE_VIDEO_FRAME_INTERVAL, 15000));
    const traceOptions: mapCommon.TraceOverlayParams = {
      points: gcjPoints,
      animationDuration: animationDuration,
      isMapMoving: true,
      width: TRACE_OVERLAY_WIDTH,
      color: TRACE_OVERLAY_COLOR,
      animationCallback: (pointIndex: number): void => {
        if (pointIndex === 0) {
          this.onReplayStartPoint();
        }
        if (pointIndex === totalPoints - 1) {
          this.onReplayEndPoint();
        }
      }
    };
    try {
      controller.addTraceOverlay(traceOptions).then((overlay: map.TraceOverlay) => {
        this.replayTraceOverlay = overlay;
      }).catch((err: BusinessError) => {
        console.error(`MapTab replay addTraceOverlay failed: ${JSON.stringify(err)}`);
        this.replayState = ReplayState.IDLE;
      });
    } catch (err) {
      console.error(`MapTab replay sync failed: ${JSON.stringify(err)}`);
      this.replayState = ReplayState.IDLE;
    }
  }

  /** 回放动画到达起点时回调：确保起点标记可见 */
  private onReplayStartPoint(): void {
    console.info(`MapTab replay reached start point`);
  }

  /** 回放动画到达终点时回调：添加终点标记，结束回放状态 */
  private onReplayEndPoint(): void {
    this.replayState = ReplayState.FINISHED;
    this.addEndMarker();
    this.speakWorkoutVoice('轨迹回放已完成');
  }

  /** 添加终点标记 */
  private addEndMarker(): void {
    const controller = this.mapController;
    if (!controller || this.routePoints.length < 2) {
      return;
    }
    const endPoint: mapCommon.LatLng = this.convertToMapCoordinate(this.routePoints[this.routePoints.length - 1]);
    const markerOptions: mapCommon.MarkerOptions = {
      position: endPoint,
      icon: $r('app.media.local_and_figure_run_leave'),
      anchorU: 0.5,
      anchorV: 1,
      visible: true,
      zIndex: 3
    };
    try {
      controller.addMarker(markerOptions).then((marker: map.Marker) => {
        this.endMarker = marker;
      }).catch((err: BusinessError) => {
        console.error(`MapTab add end marker failed: ${JSON.stringify(err)}`);
      });
    } catch (err) {
      console.error(`MapTab add end marker sync failed: ${JSON.stringify(err)}`);
    }
  }

  /** 移除终点标记 */
  private removeEndMarker(): void {
    if (this.endMarker !== undefined) {
      try {
        this.endMarker.remove();
      } catch (err) {
        console.error(`MapTab remove end marker failed: ${JSON.stringify(err)}`);
      }
      this.endMarker = undefined;
    }
  }

  /** 清除回放动画覆盖物 */
  private clearReplayOverlay(): void {
    if (this.replayTraceOverlay !== undefined) {
      try {
        this.replayTraceOverlay.remove();
      } catch (err) {
        console.error(`MapTab remove replay overlay failed: ${JSON.stringify(err)}`);
      }
      this.replayTraceOverlay = undefined;
    }
    this.removeEndMarker();
  }

  /** 重新播放轨迹回放：清除旧动画，重新开始 */
  private replayAgain(): void {
    this.clearReplayOverlay();
    this.replayState = ReplayState.IDLE;
    this.startTraceReplay();
  }

  /** 标题栏坐标文本：两者都为空时显示定位等待提示 */
  private coordinateChipText(): Resource | string {
    const combined: string = `${this.titleText}${this.subTitleText}`;
    if (combined.trim().length > 0) {
      return combined;
    }
    return $r('app.string.locating');
  }

  /** 启用地图定位图层（需权限已授予且地图控制器就绪） */
  private enableMyLocationLayer(): void {
    if (!this.isPermissionGranted || this.mapController === undefined) {
      return;
    }
    try {
      this.mapController.setMyLocationEnabled(true);
    } catch (err) {
      console.error(`MapTab enable my location failed: ${JSON.stringify(err)}`);
    }
  }

  /** 连续定位回调，统一转发给 onLocationUpdate 处理 */
  private locationChangeCb: (location: geoLocationManager.Location) => void =
    (location: geoLocationManager.Location) => {
      this.onLocationUpdate(location);
    };

  /** 启动卫星状态监听，更新卫星数量和信号等级 */
  private startSatelliteTracking(): void {
    if (!this.isMapActive || this.isSatelliteTrackingStarted) {
      return;
    }
    this.isSatelliteTrackingStarted = true;
    try {
      geoLocationManager.on('satelliteStatusChange', this.satelliteStatusCb);
    } catch (err) {
      this.isSatelliteTrackingStarted = false;
      console.error(`MapTab satelliteStatusChange failed: ${JSON.stringify(err)}`);
    }
  }

  /** 停止卫星状态监听 */
  private stopSatelliteTracking(): void {
    if (!this.isSatelliteTrackingStarted) {
      return;
    }
    this.isSatelliteTrackingStarted = false;
    try {
      geoLocationManager.off('satelliteStatusChange', this.satelliteStatusCb);
    } catch (err) {
      console.info(`MapTab off satelliteStatusChange: ${JSON.stringify(err)}`);
    }
  }

  /** 卫星状态回调：根据强信号卫星占比计算 gnssSignalLevel (1~3) */
  private satelliteStatusCb: (status: geoLocationManager.SatelliteStatusInfo) => void =
    (status: geoLocationManager.SatelliteStatusInfo) => {
      this.satelliteCount = status.satellitesNumber;
      if (status.carrierToNoiseDensitys && status.carrierToNoiseDensitys.length > 0) {
        let strongCount: number = 0;
        for (let i = 0; i < status.carrierToNoiseDensitys.length; i++) {
          if (status.carrierToNoiseDensitys[i] >= 25) {
            strongCount++;
          }
        }
        const ratio: number = strongCount / status.carrierToNoiseDensitys.length;
        if (ratio >= 0.6) {
          this.gnssSignalLevel = 3;
        } else if (ratio >= 0.3) {
          this.gnssSignalLevel = 2;
        } else {
          this.gnssSignalLevel = 1;
        }
      }
    };

  /** 将地图相机动画移动到指定坐标（WGS84→GCJ02 转换后），zoom=15 */
  private centerCameraOnLocation(latLng: mapCommon.LatLng): boolean {
    const controller = this.mapController;
    if (!controller) {
      return false;
    }
    const mapLatLng = this.convertToMapCoordinate(latLng);
    try {
      controller.animateCamera(map.newLatLng(mapLatLng, 15), 500);
      return true;
    } catch (err) {
      console.error(`MapTab center camera failed: ${JSON.stringify(err)}`);
      return false;
    }
  }

  /** WGS84 坐标转换为 GCJ02（国测局坐标），MapKit 使用 GCJ02 */
  private convertToMapCoordinate(latLng: mapCommon.LatLng): mapCommon.LatLng {
    try {
      return map.convertCoordinateSync(
        mapCommon.CoordinateType.WGS84,
        mapCommon.CoordinateType.GCJ02,
        latLng
      );
    } catch (err) {
      console.error(`MapTab convert coordinate failed: ${JSON.stringify(err)}`);
      return latLng;
    }
  }

  /** 半模态布局稳定后延迟居中到当前位置，避免动画冲突 */
  private scheduleCenterAfterSheetLayout(): void {
    this.clearSheetCenterTimer();
    if (!this.isMapActive || !this.isGpsLocked || this.hasCenteredOnLocation || !this.mapController) {
      return;
    }
    if (this.isShowSheet && this.sheetHeightVp <= 0) {
      return;
    }
    this.sheetCenterTimer = setTimeout(() => {
      this.hasCenteredOnLocation = this.centerCameraOnLocation(this.currentLocation);
      this.sheetCenterTimer = undefined;
    }, 120);
  }

  /** 清除半模态居中定时器 */
  private clearSheetCenterTimer(): void {
    if (this.sheetCenterTimer !== undefined) {
      clearTimeout(this.sheetCenterTimer);
      this.sheetCenterTimer = undefined;
    }
  }

  /** 切换 3D/2D 模式，更新蓝点样式和相机倾斜角 */
  private toggleMap3DMode(): void {
    this.isMap3DMode = !this.isMap3DMode;
    this.applyMyLocationStyle();
    this.animateToCurrentLocationWithMode();
  }

  /** 根据当前 3D/2D 模式动画移动相机，3D 模式下 tilt=60 且 zoom 不低于 17 */
  private animateToCurrentLocationWithMode(): void {
    const controller = this.mapController;
    if (!controller) {
      return;
    }
    const currentPosition: mapCommon.CameraPosition = controller.getCameraPosition();
    const targetZoom: number =
      this.isMap3DMode && currentPosition.zoom < MAP_3D_MIN_ZOOM ? MAP_3D_MIN_ZOOM : currentPosition.zoom;
    const cameraPosition: mapCommon.CameraPosition = {
      target: this.isGpsLocked ? this.convertToMapCoordinate(this.currentLocation) : currentPosition.target,
      zoom: targetZoom,
      tilt: this.isMap3DMode ? MAP_3D_TILT : MAP_2D_TILT,
      bearing: currentPosition.bearing ?? 0
    };
    try {
      controller.animateCamera(map.newCameraPosition(cameraPosition), 500);
    } catch (err) {
      console.error(`MapTab animate camera mode failed: ${JSON.stringify(err)}`);
    }
  }

  /** 设置蓝点样式：半透明圆 + 跟随设备旋转 */
  private async applyMyLocationStyle(): Promise<void> {
    const controller = this.mapController;
    if (!controller) {
      return;
    }
    let myLocationStyle: mapCommon.MyLocationStyle = {
      anchorU: 0.5,
      anchorV: 0.5,
      radiusFillColor: 0x407570FF,
      displayType: mapCommon.MyLocationDisplayType.TRACK_ROTATE
    };
    try {
      await controller.setMyLocationStyle(myLocationStyle);
    } catch (styleErr) {
      console.error(`MapTab setMyLocationStyle failed: ${JSON.stringify(styleErr)}`);
    }
  }

  /** 关闭坐标半模态，打开图层选择半模态 */
  private openLayerSheet(): void {
    this.isShowSheet = false;
    this.isLayerSheetShown = true;
    this.applySheetLayout();
  }

  /** 从持久化存储恢复上次选中的地图图层，无记录时返回标准地图 */
  private loadPersistedMapType(): mapCommon.MapType {
    const saved: number | undefined = AppStorage.get<number>(AppStorageKeys.MAP_TYPE);
    for (let i = 0; i < MAP_LAYER_OPTIONS.length; i++) {
      if (MAP_LAYER_OPTIONS[i].mapType === saved) {
        return MAP_LAYER_OPTIONS[i].mapType;
      }
    }
    return mapCommon.MapType.STANDARD;
  }

  /** 切换地图图层：仅在不同模式下切换地图类型并关闭图层半模态 */
  private selectMapLayer(option: MapLayerOption): void {
    if (option.mapType === this.selectedMapType) {
      return;
    }
    this.selectedMapType = option.mapType;
    this.mapController?.setMapType(option.mapType);
    this.applySatelliteRoadOverlay();
    AppStorage.setOrCreate(AppStorageKeys.MAP_TYPE, option.mapType);
    // 切换地图类型后部分渲染层会重建，重新绘制轨迹覆盖物确保线路可见
    if (this.routePoints.length >= 2) {
      this.rebuildTraceOverlay();
    }
    // 非标准地图不支持 3D 模式，切换时退出 3D 回到 2D 俯视
    if (this.isMap3DMode && option.mapType !== mapCommon.MapType.STANDARD) {
      this.isMap3DMode = false;
      this.applyMyLocationStyle();
      this.animateToCurrentLocationWithMode();
    }
    this.isLayerSheetShown = false;
    this.applySheetLayout();
  }

  /** 卫星图层缩小到阈值以下时叠加路网（切换为混合地图），放大后恢复纯卫星图 */
  private applySatelliteRoadOverlay(): void {
    const controller = this.mapController;
    if (!controller || this.selectedMapType !== mapCommon.MapType.SATELLITE) {
      return;
    }
    if (this.mapZoom < MAP_SATELLITE_ROAD_ZOOM_THRESHOLD) {
      controller.setMapType(mapCommon.MapType.HYBRID);
    } else {
      controller.setMapType(mapCommon.MapType.SATELLITE);
    }
  }

  /** 计算系统控件随悬浮面板或半模态上移的底部 padding：仅运动面板会抬高控件 */
  private mapSystemBottomPaddingVp(): number {
    if (this.isWorkoutStarted) {
      const panelHeight: number =
        this.workoutPanelHeightVp > 0 ? this.workoutPanelHeightVp : WORKOUT_PANEL_HEIGHT;
      return panelHeight + this.bottomInset + MAP_SYSTEM_CONTROL_PADDING_GAP;
    }
    return this.bottomInset;
  }

  /** 计算控件组底部边距：贴着系统我的定位控件和缩放控件上方，并跟随地图 padding 上移 */
  private mapControlsBottomMargin(): number {
    return this.mapSystemBottomPaddingVp() +
      MAP_SYSTEM_ZOOM_CONTROL_HEIGHT +
      MAP_CONTROL_GAP +
      MAP_SYSTEM_LOCATION_CONTROL_HEIGHT +
      MAP_CONTROL_GAP;
  }

  /** 计算控件组 X 坐标：右对齐，距右边 MAP_CONTROL_RIGHT_MARGIN */
  private mapControlsX(): number {
    return Math.max(0, this.containerWidthVp - MAP_CONTROL_RIGHT_MARGIN - MAP_CONTROL_SIZE);
  }

  /** 当前右侧地图控件的可见按钮数量：标准地图显示 3D + 图层，其他图层仅显示图层 */
  private mapControlVisibleCount(): number {
    return this.selectedMapType === mapCommon.MapType.STANDARD ? MAP_CONTROL_SINGLE_BUTTON_COUNT : 1;
  }

  /** 计算控件组 Y 坐标：底部对齐，向上留出所有可见控件高度 */
  private mapControlsY(): number {
    const controlGroupCount: number = this.mapControlVisibleCount();
    const controlsHeight: number =
      MAP_CONTROL_SIZE * controlGroupCount +
        MAP_CONTROL_GAP * (controlGroupCount - 1);
    return Math.max(0, this.containerHeightVp - this.mapControlsBottomMargin() - controlsHeight);
  }

  /** 指标配置按钮 Y 坐标：基于地图底部避让量定位，位于 Logo/面板上方，随面板展开同步上移 */
  private metricConfigButtonY(): number {
    const bottomMargin: number = this.mapSystemBottomPaddingVp()
      + MAP_LOGO_BOTTOM_GAP + MAP_LOGO_HEIGHT + MAP_CONTROL_GAP;
    return Math.max(0, this.containerHeightVp - bottomMargin - MAP_CONTROL_SIZE);
  }

  /** 调整系统控件位置：指南针右上、比例尺左上同高、Logo 移到左下角 */
  private applySystemControlPositions(): void {
    const controller = this.mapController;
    if (!controller || this.containerWidthVp <= 0) {
      return;
    }
    const uiContext = this.getUIContext();
    const titleY: number = uiContext.vp2px(this.topInset + MAP_TITLE_BAR_HEIGHT);
    const compassPoint: mapCommon.MapPoint = {
      positionX: uiContext.vp2px(this.containerWidthVp - MAP_CONTROL_RIGHT_MARGIN - MAP_CONTROL_SIZE),
      positionY: titleY
    };
    try {
      controller.setCompassPosition(compassPoint);
    } catch (err) {
      console.error(`MapTab set compass position failed: ${JSON.stringify(err)}`);
    }
    const scalePoint: mapCommon.MapPoint = {
      positionX: uiContext.vp2px(MAP_CONTROL_RIGHT_MARGIN),
      positionY: titleY
    };
    try {
      controller.setScalePosition(scalePoint);
    } catch (err) {
      console.error(`MapTab set scale position failed: ${JSON.stringify(err)}`);
    }
    try {
      controller.setLogoAlignment(mapCommon.LogoAlignment.BOTTOM_START);
      controller.setLogoPadding({
        left: uiContext.vp2px(12),
        bottom: uiContext.vp2px(this.mapSystemBottomPaddingVp())
      });
    } catch (err) {
      console.error(`MapTab set logo position failed: ${JSON.stringify(err)}`);
    }
  }

  /** 初始化地图参数和回调，关闭系统内置控件，注册相机移动事件监听 */
  private initMap(): void {
    // bearing 设为 1 度（非正北），使自定义指南针初始可见
    this.mapOptions = {
      mapType: this.selectedMapType,
      position: {
        target: this.currentLocation,
        zoom: 15,
        tilt: 0,
        bearing: 0
      },
      rotateGesturesEnabled: true,
      scrollGesturesEnabled: true,
      zoomGesturesEnabled: true,
      tiltGesturesEnabled: true,
      // 缩放控件
      zoomControlsEnabled: true,
      // 我的定位控件
      myLocationControlsEnabled: true,
      // 指南针控件
      compassControlsEnabled: true,
      // 比例尺控件
      scaleControlsEnabled: true,
      dayNightMode: mapCommon.DayNightMode.AUTO,
      sphereEnabled: true
    };
    this.mapCallback = async (err: BusinessError | undefined, controller: map.MapComponentController) => {
      if (err) {
        console.error(`MapTab map init failed: ${err.message}`);
        return;
      }
      this.mapController = controller;
      await this.applyMyLocationStyle();
      this.enableMyLocationLayer();
      // 启用系统指南针、缩放和定位控件
      this.mapController.setCompassControlsEnabled(true);
      this.mapController.setZoomControlsEnabled(true);
      this.mapController.setMyLocationControlsEnabled(true);
      this.mapController.setScaleControlsEnabled(true);
      this.mapController.setAlwaysShowScaleEnabled(true);
      this.mapController.setBuildingEnabled(true);
      this.applySystemControlPositions();
      // 监听相机移动事件，实时更新指南针朝向角和缩放级别
      const eventManager: map.MapEventManager = this.mapController.getEventManager();
      eventManager.on('cameraMove', () => {
        const ctrl: map.MapComponentController | undefined = this.mapController;
        if (ctrl) {
          const pos: mapCommon.CameraPosition = ctrl.getCameraPosition();
          this.compassBearing = pos.bearing ?? 0;
          this.mapZoom = pos.zoom;
          this.applySatelliteRoadOverlay();
        }
      });
      this.mapController.setTrafficEnabled(false);
      this.applySheetLayout();
      this.applySatelliteRoadOverlay();
      if (this.isMapActive && this.isPermissionGranted) {
        this.startLocationTracking();
        this.startSatelliteTracking();
      }
    };
  }

  /** 重置指南针：将地图旋转回正北（bearing=0），取消倾斜（tilt=0） */
  private resetCompassToNorth(): void {
    const controller = this.mapController;
    if (!controller) {
      return;
    }
    const currentPos: mapCommon.CameraPosition = controller.getCameraPosition();
    const cameraPosition: mapCommon.CameraPosition = {
      target: currentPos.target,
      zoom: currentPos.zoom,
      tilt: 0,
      bearing: 0
    };
    try {
      controller.animateCamera(map.newCameraPosition(cameraPosition), 300);
    } catch (err) {
      console.error(`MapTab reset compass failed: ${JSON.stringify(err)}`);
    }
  }

  /** 定位按钮：将地图中心移动到当前 GPS 位置 */
  private centerOnMyLocation(): void {
    if (this.isGpsLocked) {
      this.centerCameraOnLocation(this.currentLocation);
    }
  }

  /** 图层选择半模态配置：固定高度、带关闭按钮、禁止下拉关闭 */
  private buildLayerSheetOptions(): SheetOptions {
    return {
      detents: [MAP_LAYER_SHEET_HEIGHT],
      preferType: SheetType.BOTTOM,
      dragBar: true,
      showClose: true,
      enableOutsideInteractive: true,
      title: { title: $r('app.string.layer_sheet_title'), subtitle: '' },
      onWillDismiss: (action: DismissSheetAction) => {
        if (action.reason === DismissReason.SLIDE_DOWN) {
          return;
        }
        this.isLayerSheetShown = false;
        action.dismiss();
      },
      onWillSpringBackWhenDismiss: (action: SpringBackAction) => {
        action.springBack();
      }
    };
  }

  /** 半模态出现时：地图全屏，用 padding 把系统控件顶到半模态上方 */
  private applySheetLayout(): void {
    const controller = this.mapController;
    if (!controller || this.containerHeightVp <= 0) {
      return;
    }
    const uiContext = this.getUIContext();
    const bottomPaddingPx: number = uiContext.vp2px(this.mapSystemBottomPaddingVp());
    controller.setPadding({ bottom: bottomPaddingPx });
    if (this.isShowSheet && this.sheetHeightVp > 0) {
      this.scheduleCenterAfterSheetLayout();
    }
    this.applySystemControlPositions();
  }

  aboutToAppear(): void {
    PersistentStorage.persistProp(AppStorageKeys.MAP_TYPE, mapCommon.MapType.STANDARD);
    this.selectedMapType = this.loadPersistedMapType();
    this.initMap();
    WorkoutVoice.preload();
    this.refreshWeatherWarning();
    if (this.currentTab === OutdoorTabType.RECORD) {
      this.activateMapPage();
    }
    setTimeout(() => {
      this.pageReady = true;
    }, 100);
  }

  aboutToDisappear(): void {
    this.deactivateMapPage();
  }

  build() {
    HdsNavDestination() {
      Stack({ alignContent: Alignment.Bottom }) {
        // 地图组件
        if (this.mapOptions && this.mapCallback) {
          MapComponent({ mapOptions: this.mapOptions, mapCallback: this.mapCallback })
            .width('100%')
            .height('100%')
        }
        // 自定义地图控件（覆盖在地图上方）
        this.buildMapControls()

        // 左侧数据指标配置按钮
        this.buildMetricConfigButton()

        // 开始运动按钮 / 运动中数据面板
        this.buildStartWorkoutButton()

        // // 运动结束后的轨迹视频生成按钮
        // this.buildTraceVideoButton()
      }
      .id(this.mapContainerId)
      .width('100%')
      .height('100%')
      // 图层选择半模态绑定在整个 Stack 上
      .bindSheet(this.isLayerSheetShown, this.buildLayerSheetContent(), this.buildLayerSheetOptions())
      .onAreaChange((oldValue: Area, newValue: Area) => {
        const width: number = newValue.width as number;
        const height: number = newValue.height as number;
        if (width > 0) {
          this.containerWidthVp = width;
          this.applySystemControlPositions();
        }
        if (height > 0) {
          this.containerHeightVp = height;
          this.applySheetLayout();
        }
      })
    }
    .titleBar({
      avoidLayoutSafeArea: true,
      content: {
        title: { mainTitle: '' },
        // 标题栏自定义内容：有天气警示时显示滚动警示，否则显示坐标 + GNSS
        stackBuilder: (): void => this.buildTitleBarContent(),
        backIcon: {
          action: () => {
            this.onClose?.();
          }
        }
      },
      style: {
        // 沉浸式毛玻璃效果
        systemMaterialEffect: {
          materialType: hdsMaterial.MaterialType.IMMERSIVE,
          materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
        },
        scrollEffectOpts: {
          enableScrollEffect: true,
          scrollEffectType: ScrollEffectType.IMMERSIVE_GRADIENT_BLUR
        },
        originalStyle: {
          contentStyle: {
            titleStyle: {
              mainTitleColor: $r('sys.color.ohos_id_color_text_primary')
            },
            menuStyle: {
              backgroundColor: $r('sys.color.comp_background_tertiary'),
              iconColor: $r('sys.color.icon_primary')
            },
            backIconStyle: {
              backgroundColor: $r('sys.color.comp_background_tertiary'),
              iconColor: $r('sys.color.icon_primary')
            }
          }
        },
        scrollEffectStyle: {
          backgroundStyle: {
            backgroundColor: $r('app.color.start_window_background'),
            maskExtraHeight: 32,
            blurRadius: 18
          },
          contentStyle: {
            titleStyle: {
              mainTitleColor: $r('sys.color.ohos_id_color_text_primary')
            },
            menuStyle: {
              backgroundColor: $r('sys.color.comp_background_tertiary'),
              iconColor: $r('sys.color.icon_primary')
            },
            backIconStyle: {
              backgroundColor: $r('sys.color.comp_background_tertiary'),
              iconColor: $r('sys.color.icon_primary')
            }
          }
        }
      },
    })
    .titleMode(HdsNavDestinationTitleMode.MINI)
    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
    .backgroundColor($r('sys.color.background_secondary'))
    .width('100%')
    .height('100%')
    .onBackPressed(() => {
      this.onClose?.();
      return true;
    })
  }

  /** 标题栏内容：有警示时显示滚动警示横幅，否则显示坐标 + GNSS */
  @Builder
  buildTitleBarContent() {
    if (this.weatherWarning !== undefined) {
      this.buildWeatherWarningBanner()
    } else {
      this.buildStackBuilder()
    }
  }

  /** 天气警示横幅：替换标题栏内容，带颜色框，Marquee 横向滚动，点击跳系统天气应用 */
  @Builder
  buildWeatherWarningBanner() {
    Row() {
      Row({ space: 8 }) {
        SymbolGlyph($r('sys.symbol.exclamationmark_triangle_fill'))
          .fontSize(18)
          .fontColor([$r('app.color.white')])
        Marquee({
          start: true,
          src: `${this.weatherWarning?.title}：${this.lastSentence(this.weatherWarning?.message ?? '')}`,
          step: 5,
          loop: -1,
          fromStart: true
        })
          .layoutWeight(1)
          .fontSize(13)
          .fontColor($r('app.color.white'))
          .fontWeight(FontWeight.Medium)
        SymbolGlyph($r('sys.symbol.xmark'))
          .fontSize(15)
          .fontColor([$r('app.color.white')])
          .hitTestBehavior(HitTestMode.Block)
          .onClick(() => {
            this.weatherWarning = undefined;
          })
      }
      .height(40)
      .padding({ left: 12, right: 12 })
      .borderRadius(20)
      .border({
        width: 1,
        color: this.weatherWarning?.level === WeatherWarningLevel.WARNING ?
          $r('app.color.warning_red') : $r('app.color.warning_orange')
      })
      .backgroundColor(this.weatherWarning?.level === WeatherWarningLevel.WARNING ?
        $r('app.color.warning_red') : $r('app.color.warning_orange'))
      .backgroundBlurStyle(BlurStyle.Thin, { colorMode: ThemeColorMode.SYSTEM })
      .alignItems(VerticalAlign.Center)
      .onClick(() => {
        this.openWeatherApp();
      })
    }
    .width('100%')
    .height(56)
    .padding({ left: 64, right: 12 })
    .alignItems(VerticalAlign.Center)
  }

  /** 标题栏自定义布局：左侧坐标文本 + 右侧 GNSS 卫星状态芯片 */
  @Builder
  buildStackBuilder() {
    Flex({ justifyContent: FlexAlign.SpaceBetween, alignItems: ItemAlign.Center }) {
      Row() {
        Text(this.coordinateChipText())
          .fontSize(10)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.ohos_id_color_text_primary'))
          .textAlign(TextAlign.Center)
          .maxLines(2)
      }
      .padding({
        left: 10,
        right: 10,
        top: 8,
        bottom: 8
      })
      .borderRadius(20)
      .border({ width: 1, color: $r('sys.color.indicator_border_color') })
      .backgroundBlurStyle(BlurStyle.Thin, { colorMode: ThemeColorMode.SYSTEM })
      .alignItems(VerticalAlign.Center)

      this.buildGnssChip()
    }
    .width('100%')
    .height(56)
    .padding({ left: 64, right: 12 })
  }

  /** GNSS 卫星状态芯片：显示卫星数量，未定位时显示"正在搜索..." */
  @Builder
  buildGnssChip() {
    Row({ space: 2 }) {
      Text('GNSS')
        .fontSize(10)
        .fontColor($r('sys.color.ohos_id_color_text_primary'))
        .fontWeight(FontWeight.Medium)

      if (!this.isGpsLocked) {
        Text($r('app.string.searching_gnss'))
          .fontSize(10)
          .fontColor($r('sys.color.ohos_id_color_text_primary'))
      } else {
        if (this.satelliteCount > 0) {
          Text(`${this.satelliteCount}`)
            .fontSize(10)
            .fontColor($r('app.color.brand_green'))
            .fontWeight(FontWeight.Medium)
        }
      }
    }
    .padding({
      left: 10,
      right: 10,
      top: 8,
      bottom: 8
    })
    .margin({ left: 8 })
    .borderRadius(20)
    .backgroundBlurStyle(BlurStyle.Thin, { colorMode: ThemeColorMode.SYSTEM })
    .border({ width: 1, color: $r('sys.color.indicator_border_color') })
    .alignItems(VerticalAlign.Center)
  }

  /** 取文本最后一句话（按句号/感叹号/问号切分） */
  private lastSentence(text: string): string {
    const segments: string[] = text.split(/[。！？!?]/);
    for (let i = segments.length - 1; i >= 0; i--) {
      const segment: string = segments[i].trim();
      if (segment.length > 0) {
        return segment;
      }
    }
    return text;
  }

  /** 跳转系统天气应用 */
  private openWeatherApp(): void {
    console.info(`MapTab openWeatherApp clicked`);
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    if (context === undefined) {
      return;
    }
    const want: Want = {
      bundleName: 'com.huawei.hmsapp.totemweather',
      moduleName: 'product',
      abilityName: 'com.huawei.hmsapp.totemweather.MainAbility'
    };
    context.startAbility(want).then(() => {
      console.info(`MapTab openWeatherApp success`);
    }).catch((err: BusinessError) => {
      console.error(`MapTab open weather app failed: ${err.code} ${err.message}`);
    });
  }

  /** 3D 模式切换按钮：仅标准地图显示，其他图层不支持 3D */
  @Builder
  buildMapControls() {
    if (this.containerHeightVp > 0 && this.pageReady) {
      Column({ space: MAP_CONTROL_GAP }) {
        if (this.selectedMapType === mapCommon.MapType.STANDARD) {
          Stack({ alignContent: Alignment.Center }) {
            Text(this.isMap3DMode ? '2D' : '3D')
              .fontSize(18)
              .fontWeight(FontWeight.Bolder)
              .fontFamily('SmileySans')
              .fontColor($r('sys.color.ohos_id_color_text_primary'))
          }
          .width(MAP_CONTROL_SIZE)
          .height(MAP_CONTROL_SIZE)
          .borderRadius(24)
          .border({ width: 1, color: $r('sys.color.indicator_border_color') })
          .backgroundBlurStyle(BlurStyle.Thin, { colorMode: ThemeColorMode.SYSTEM })
          .onClick(() => {
            this.toggleMap3DMode();
          })
        }

        this.buildMapControlButton($r('sys.symbol.satellite_map_fill'), undefined, this.isLayerSheetShown, () => {
          this.openLayerSheet();
        })
      }
      .width(MAP_CONTROL_SIZE)
      .position({ x: this.mapControlsX(), y: this.mapControlsY() })
      .animation({ duration: 300, curve: Curve.EaseOut })
      .zIndex(2)
    }
  }

  /** 通用地图控件按钮：毛玻璃背景 + 边框，选中时绿底白图标/文字 */
  @Builder
  buildMapControlButton(icon: Resource | undefined, label: string | undefined, selected: boolean, action: () => void) {
    Stack({ alignContent: Alignment.Center }) {
      if (icon !== undefined) {
        SymbolGlyph(icon)
          .fontSize(24)
          .fontColor([selected ? Color.White : $r('sys.color.ohos_id_color_text_primary')])
      } else if (label !== undefined) {
        Text(label)
          .fontSize(18)
          .fontWeight(FontWeight.Bolder)
          .fontFamily('SmileySans')
          .fontColor(selected ? Color.White : $r('sys.color.ohos_id_color_text_primary'))
      }
    }
    .width(MAP_CONTROL_SIZE)
    .height(MAP_CONTROL_SIZE)
    .borderRadius(24)
    .border({ width: 1, color: $r('sys.color.indicator_border_color') })
    .backgroundBlurStyle(BlurStyle.Thin, { colorMode: ThemeColorMode.SYSTEM })
    .onClick(() => {
      action();
    })
  }

  /** 左侧数据指标配置按钮：打开指标显示配置半模态 */
  @Builder
  buildMetricConfigButton() {
    Stack({ alignContent: Alignment.Center }) {
      SymbolGlyph($r('sys.symbol.gearshape'))
        .fontSize(24)
        .fontColor([$r('sys.color.ohos_id_color_text_primary')])
    }
    .width(MAP_CONTROL_SIZE)
    .height(MAP_CONTROL_SIZE)
    .borderRadius(24)
    .border({ width: 1, color: $r('sys.color.indicator_border_color') })
    .backgroundBlurStyle(BlurStyle.Thin, { colorMode: ThemeColorMode.SYSTEM })
    .position({ x: MAP_CONTROL_RIGHT_MARGIN, y: this.metricConfigButtonY() })
    .zIndex(2)
    .onClick(() => {
      this.isMetricConfigShown = true;
    })
    .bindSheet(this.isMetricConfigShown, this.buildMetricConfigContent(), this.buildMetricConfigOptions())
  }

  /** 数据指标配置半模态：各指标开关，最多选择 MAX_METRIC_COUNT 项 */
  @Builder
  buildMetricConfigContent() {
    Column({ space: 4 }) {
      Text(`最多选择 ${MAX_METRIC_COUNT} 项，运动类型切换时自动恢复默认`)
        .fontSize(12)
        .fontColor($r('sys.color.ohos_id_color_text_secondary'))
        .width('100%')
        .padding({ left: 4, bottom: 8 })

      ForEach(METRIC_DEFS, (def: MetricDef) => {
        Row({ space: 12 }) {
          SymbolGlyph(def.icon)
            .fontSize(22)
            .fontColor([$r('sys.color.ohos_id_color_text_primary')])

          Text(def.label)
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.ohos_id_color_text_primary'))
            .layoutWeight(1)

          Text(def.unit)
            .fontSize(12)
            .fontColor($r('sys.color.ohos_id_color_text_secondary'))

          Toggle({ type: ToggleType.Switch, isOn: this.isMetricSelected(def.key) })
            .onChange((isOn: boolean) => {
              this.toggleMetric(def.key);
            })
        }
        .width('100%')
        .padding({
          left: 4,
          right: 4,
          top: 8,
          bottom: 8
        })
      }, (def: MetricDef) => `${def.key}_${this.metricConfigVersion}`)
    }
    .width('100%')
    .padding({
      left: 16,
      right: 16,
      top: 12,
      bottom: 24
    })
  }

  /** 数据指标配置半模态配置：固定高度、带关闭按钮、禁止下拉关闭 */
  private buildMetricConfigOptions(): SheetOptions {
    return {
      detents: [SheetSize.MEDIUM],
      preferType: SheetType.BOTTOM,
      dragBar: true,
      showClose: true,
      enableOutsideInteractive: true,
      title: { title: $r('app.string.metric_sheet_title'), subtitle: '' },
      onWillDismiss: (action: DismissSheetAction) => {
        if (action.reason === DismissReason.SLIDE_DOWN) {
          return;
        }
        this.isMetricConfigShown = false;
        action.dismiss();
      },
      onWillSpringBackWhenDismiss: (action: SpringBackAction) => {
        action.springBack();
      }
    };
  }

  /** 运动结束后的轨迹回放控制：播放/重新播放/回放中 */
  @Builder
  buildTraceVideoButton() {
    if (!this.isWorkoutStarted && !this.isTracking && this.routePoints.length >= 2
      && this.containerHeightVp > 0 && this.pageReady) {
      Column({ space: 4 }) {
        if (this.replayState === ReplayState.PLAYING) {
          SymbolGlyph($r('sys.symbol.pause'))
            .fontSize(20)
            .fontColor([$r('sys.color.ohos_id_color_text_secondary')])
          Text($r('app.string.replaying'))
            .fontSize(10)
            .fontColor($r('sys.color.ohos_id_color_text_secondary'))
        } else if (this.replayState === ReplayState.FINISHED) {
          SymbolGlyph($r('sys.symbol.arrow_counterclockwise'))
            .fontSize(20)
            .fontColor([$r('app.color.brand_green')])
          Text($r('app.string.replay_again'))
            .fontSize(10)
            .fontColor($r('sys.color.ohos_id_color_text_primary'))
            .fontWeight(FontWeight.Medium)
        } else {
          SymbolGlyph($r('sys.symbol.play_circle'))
            .fontSize(20)
            .fontColor([$r('app.color.brand_green')])
          Text($r('app.string.generate_video'))
            .fontSize(10)
            .fontColor($r('sys.color.ohos_id_color_text_primary'))
            .fontWeight(FontWeight.Medium)
        }
      }
      .width(72)
      .padding({ top: 6, bottom: 6 })
      .borderRadius(20)
      .border({ width: 1, color: $r('sys.color.indicator_border_color') })
      .backgroundBlurStyle(BlurStyle.Thin, { colorMode: ThemeColorMode.SYSTEM })
      .alignItems(HorizontalAlign.Center)
      .position({ x: MAP_CONTROL_RIGHT_MARGIN, y: this.metricConfigButtonY() - MAP_CONTROL_SIZE - MAP_CONTROL_GAP })
      .zIndex(2)
      .enabled(this.replayState !== ReplayState.PLAYING)
      .onClick(() => {
        if (this.replayState === ReplayState.FINISHED) {
          this.replayAgain();
        } else {
          this.startTraceReplay();
        }
      })
    }
  }

  /** 开始运动按钮：点击播放后背景块带动画扩大，内容自适应高度，开始按钮位于下方 */
  @Builder
  buildStartWorkoutButton() {
    if (this.containerHeightVp > 0 && this.pageReady) {
      if (!this.isWorkoutStarted) {
        Column({ space: 16 }) {
          this.buildSportTypeSegmented()

          SymbolGlyph($r('sys.symbol.play_circle_fill'))
            .fontSize(80)
            .renderingStrategy(SymbolRenderingStrategy.MULTIPLE_COLOR)
            .fontColor([$r('app.color.action_green'), $r('app.color.white')])
            .width(MAP_START_BUTTON_WIDTH_AND_HEIGHT)
            .height(MAP_START_BUTTON_WIDTH_AND_HEIGHT)
            .onClick(() => {
              this.startTracking();
              this.applySheetLayout();
            })
        }
        .alignItems(HorizontalAlign.Center)
        .margin({ bottom: this.bottomInset })
        .transition(
          TransitionEffect.asymmetric(
            TransitionEffect.OPACITY
              .combine(TransitionEffect.scale({ x: 1, y: 1 }))
              .animation({ duration: 220, curve: Curve.EaseOut }),
            TransitionEffect.OPACITY
              .combine(TransitionEffect.scale({ x: 0.92, y: 0.92 }))
              .animation({ duration: 180, curve: Curve.EaseIn })
          )
        )
      } else {
        Column({ space: 16 }) {
          this.buildSportTypeSegmented()

          this.buildWorkoutMetrics()

          Row({ space: MAP_BUTTON_ROW_SPACE }) {
            // 锁
            Stack({ alignContent: Alignment.Center }) {
              SymbolGlyph(this.isControlLocked ? $r('sys.symbol.lock_fill') : $r('sys.symbol.lock'))
                .fontSize(24)
                .fontColor([$r('sys.color.icon_secondary')])
            }
            .width(50)
            .height(50)
            .borderRadius(25)
            .backgroundColor($r('sys.color.comp_background_tertiary'))
            .onClick(() => {
              this.isControlLocked = !this.isControlLocked;
            })

            // 播放/暂停 + 结束运动：视频同款从中心合并/拆分，红色结束按钮在上层
            Stack({ alignContent: Alignment.Center }) {
              SymbolGlyph(this.isTracking ? $r('sys.symbol.pause_circle_fill') : $r('sys.symbol.play_circle_fill'))
                .fontSize(80)
                .renderingStrategy(SymbolRenderingStrategy.MULTIPLE_COLOR)
                .fontColor(
                  [this.isTracking ? $r('app.color.action_red') : $r('app.color.action_green'), $r('app.color.white')])
                .width(MAP_START_BUTTON_WIDTH_AND_HEIGHT)
                .height(MAP_START_BUTTON_WIDTH_AND_HEIGHT)
                .translate({
                  x: (this.isWorkoutStarted && !this.isTracking && !this.isSportSwitchReady) ?
                    -PAUSED_ACTION_BUTTON_OFFSET : 0,
                  y: 0
                })
                .animation({ duration: 320, curve: curves.springMotion(0.35, 0.78) })
                .zIndex((this.isWorkoutStarted && !this.isTracking && !this.isSportSwitchReady) ? 1 : 3)
                .onClick(() => {
                  if (this.isControlLocked) {
                    return;
                  }
                  if (this.isTracking) {
                    this.pauseTracking();
                  } else {
                    this.startTracking();
                  }
                  this.applySheetLayout();
                })

              if (this.isWorkoutStarted && !this.isSportSwitchReady) {
                Stack({ alignContent: Alignment.Center }) {
                  Progress({ value: this.stopProgress, total: 100, type: ProgressType.Ring })
                    .width(82)
                    .height(82)
                    .style({ strokeWidth: 3 })
                    .color($r('app.color.action_red'))
                    .backgroundColor(Color.Transparent)
                    .opacity((this.isStopButtonPressed || this.stopProgress > 0) ? 1 : 0)
                  SymbolGlyph($r('sys.symbol.stop_circle_fill'))
                    .fontSize(80)
                    .renderingStrategy(SymbolRenderingStrategy.MULTIPLE_COLOR)
                    .fontColor([$r('app.color.action_red'), $r('app.color.white')])
                    .width(80)
                    .height(80)
                }
                .width(90)
                .height(90)
                .opacity(this.isTracking ? 0 : 1)
                .translate({
                  x: this.isTracking ? 0 : PAUSED_ACTION_BUTTON_OFFSET,
                  y: 0
                })
                .animation({ duration: 320, curve: curves.springMotion(0.35, 0.78) })
                .scale({
                  x: this.isStopButtonPressed ? STOP_BUTTON_PRESSED_SCALE : 1,
                  y: this.isStopButtonPressed ? STOP_BUTTON_PRESSED_SCALE : 1
                })
                .animation({ duration: 160, curve: Curve.EaseOut })
                .zIndex(2)
                .enabled(!this.isTracking)
                .onTouch((event: TouchEvent) => {
                  if (event.type === TouchType.Down) {
                    this.isStopButtonPressed = true;
                    this.isStopTooltipShown = true;
                    this.startStopProgress();
                  } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
                    if (this.isStopLongPressCompleted) {
                      this.finishStopProgress();
                    } else {
                      this.isStopTooltipShown = false;
                      this.isStopButtonPressed = false;
                      this.cancelStopProgress();
                    }
                  }
                })
                .bindPopup(this.isStopTooltipShown, {
                  message: this.resString($r('app.string.long_press_end')),
                  placement: Placement.Top,
                  offset: { x: 0, y: -8 }
                })
              }
            }
            .width((this.isWorkoutStarted && !this.isSportSwitchReady) ?
              PAUSED_ACTION_BUTTON_STACK_WIDTH : MAP_START_BUTTON_WIDTH_AND_HEIGHT)
            .height(90)
            .animation({ duration: 320, curve: curves.springMotion(0.35, 0.78) })

            // 声音
            Stack({ alignContent: Alignment.Center }) {
              SymbolGlyph(
                this.isVoiceEnabled ? $r('sys.symbol.speaker_wave_3_fill') : $r('sys.symbol.speaker_slash_fill'))
                .fontSize(24)
                .fontColor([$r('sys.color.icon_secondary')])
            }
            .width(50)
            .height(50)
            .borderRadius(25)
            .backgroundColor($r('sys.color.comp_background_tertiary'))
            .onClick(() => {
              this.isVoiceEnabled = !this.isVoiceEnabled;
              if (!this.isVoiceEnabled) {
                WorkoutVoice.stop();
              }
            })
          }
          .alignItems(VerticalAlign.Center)
        }
        .width(this.isWorkoutStarted ? this.containerWidthVp - WORKOUT_PANEL_SIDE_GAP * 2 : 'auto')
        .alignItems(HorizontalAlign.Center)
        .margin({ bottom: this.bottomInset })
        .padding({
          left: 12,
          right: 12,
          top: 12,
          bottom: 12
        })
        .borderRadius(36)
        .clip(true)
        .border({ width: 1, color: $r('sys.color.indicator_border_color') })
        .backgroundBlurStyle(BlurStyle.Thin, { colorMode: ThemeColorMode.SYSTEM })
        .transition(
          TransitionEffect.asymmetric(
            TransitionEffect.OPACITY
              .combine(TransitionEffect.translate({ x: 0, y: 20 }))
              .combine(TransitionEffect.scale({ x: 0.92, y: 0.92 }))
              .animation({ duration: 420, curve: curves.springMotion(0.35, 0.78) }),
            TransitionEffect.OPACITY
              .combine(TransitionEffect.translate({ x: 0, y: 16 }))
              .combine(TransitionEffect.scale({ x: 0.96, y: 0.96 }))
              .animation({ duration: 240, curve: Curve.EaseIn })
          )
        )
        .onClick(() => {
        })
        .gesture(GestureGroup(GestureMode.Parallel,
          PanGesture().onActionStart(() => {
          }),
          TapGesture({ count: 2 }).onAction(() => {
          })
        ))
        .animation({ duration: 400, curve: Curve.EaseOut })
        .onAreaChange((oldValue: Area, newValue: Area) => {
          if (this.isWorkoutStarted) {
            const h: number = newValue.height as number;
            if (h > 0 && h !== this.workoutPanelHeightVp) {
              this.workoutPanelHeightVp = h;
              this.applySheetLayout();
            }
          }
        })
      }
    }
  }

  /** 指标项宽度：4 项按 2 列、其余按 3 列（flexBasis 不支持百分比，故用 width） */
  private metricItemWidth(): string {
    return this.displayMetricKeys.length === 4 ? '48%' : '31%';
  }

  /** 运动数据：按当前运动类型与展示配置动态渲染（Flex 换行，每项 flex=1 等宽） */
  @Builder
  buildWorkoutMetrics() {
    Flex({
      wrap: FlexWrap.Wrap,
      justifyContent: FlexAlign.Center,
      alignItems: ItemAlign.Center,
      space: { main: LengthMetrics.vp(MAP_CONTROL_GAP), cross: LengthMetrics.vp(12) }
    }) {
      ForEach(this.displayMetricKeys, (key: MetricKey) => {
        this.buildPanelMetric(this.getMetricDef(key))
      }, (key: MetricKey) => `${key}`)
    }
    .width('100%')
  }

  /** 面板单项运动数据：图标 + 数值 + 单位，flex=1 等宽排列 */
  @Builder
  buildPanelMetric(def: MetricDef | undefined) {
    if (def !== undefined) {
      Column({ space: 2 }) {
        Row({ space: 3 }) {
          SymbolGlyph(def.icon)
            .fontSize(18)
            .fontColor([$r('sys.color.ohos_id_color_text_secondary')])
          Text(this.metricValue(def))
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .fontFamily('SmileySans')
            .fontColor($r('sys.color.ohos_id_color_text_primary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          if (def.unit.length > 0) {
            Text(def.unit)
              .fontSize(10)
              .fontWeight(FontWeight.Medium)
              .fontFamily('SmileySans')
              .fontColor($r('sys.color.ohos_id_color_text_secondary'))
              .maxLines(1)
          }
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)
      }
      .width(this.metricItemWidth())
      .flexGrow(1)
      .flexShrink(1)
      .alignItems(HorizontalAlign.Center)
    }
  }

  /** 运动类型分段按钮：使用原生分段按钮组件，仅展示 SPORT_TYPE_OPTIONS 图标 */
  @Builder
  buildSportTypeSegmented() {
    Row() {
      CapsuleSegmentButtonV2({
        items: this.segmentSportItems,
        selectedIndex: this.selectedSportIndex,
        $selectedIndex: (index: number) => {
          this.selectedSportIndex = index;
        },
        itemSymbolFontSize: LengthMetrics.vp(26),
        itemSymbolFontColor: ColorMetrics.resourceColor($r('app.color.icon_gray')),
        itemSelectedSymbolFontColor: ColorMetrics.resourceColor($r('app.color.brand_green')),
        itemSelectedBackgroundColor: ColorMetrics.rgba(0, 169, 145, 0.25),
        buttonBackgroundColor: ColorMetrics.rgba(255, 255, 255, 0.4),
        buttonBackgroundBlurStyle: BlurStyle.Thin,
        itemSpace: LengthMetrics.vp(4),
        itemMinHeight: LengthMetrics.vp(40),
        itemBorderRadius: LengthMetrics.vp(20),
        buttonBorderRadius: LengthMetrics.vp(22),
        buttonPadding: LengthMetrics.vp(2)
      })
    }
    .width(132)
    .height(44)
  }

  /** 图层选择半模态内容：三列网格，选中项图片加边框 */
  @Builder
  buildLayerSheetContent() {
    Grid() {
      ForEach(MAP_LAYER_OPTIONS, (option: MapLayerOption) => {
        GridItem() {
          Column({ space: 8 }) {
            Image(option.thumbnail)
              .width(80)
              .height(80)
              .borderRadius(16)
              .objectFit(ImageFit.Cover)
              .border({
                width: this.selectedMapType === option.mapType ? 3 : 0,
                color: $r('app.color.brand_green')
              })
              .onClick(() => {
                this.selectMapLayer(option);
              })
            Text(option.title)
              .fontSize(12)
              .fontColor($r('sys.color.ohos_id_color_text_secondary'))
          }
        }
      }, (option: MapLayerOption) => option.title)
    }
    .columnsTemplate('1fr 1fr 1fr')
    .columnsGap(12)
    .rowsGap(12)
    .width('100%')
    .padding({
      left: 16,
      right: 16,
      top: 12,
      bottom: 20
    })
  }

  /** 运动类型切换时，若有正在进行的运动则弹确认框，否则直接切换 */
  private onSportIndexChanged(): void {
    if (this.isApplyingConfirmedSportIndex) {
      this.isApplyingConfirmedSportIndex = false;
      this.previousSportIndex = this.selectedSportIndex;
      this.displayMetricKeys = SPORT_DEFAULT_METRICS[this.selectedSportIndex].slice();
      return;
    }
    if (this.isWorkoutStarted && !this.isSportSwitchReady) {
      if (this.pendingSportIndex >= 0) {
        return;
      }
      this.pendingSportIndex = this.selectedSportIndex;
      this.selectedSportIndex = this.previousSportIndex;
      const currentLabel: string = SPORT_TYPE_OPTIONS[this.previousSportIndex].label;
      this.getUIContext().showAlertDialog({
        title: $r('app.string.switch_sport'),
        message: `${currentLabel}正在进行中，是否结束当前运动？`,
        autoCancel: false,
        alignment: DialogAlignment.Center,
        primaryButton: {
          value: $r('app.string.continue_workout'),
          action: () => {
            this.pendingSportIndex = -1;
          }
        },
        secondaryButton: {
          value: $r('app.string.end_workout'),
          fontColor: $r('app.color.action_red'),
          action: () => {
            const targetIndex: number = this.pendingSportIndex;
            this.pendingSportIndex = -1;
            this.prepareSportSwitchWorkout();
            this.isApplyingConfirmedSportIndex = true;
            this.selectedSportIndex = targetIndex;
          }
        }
      });
      return;
    }
    this.previousSportIndex = this.selectedSportIndex;
    this.displayMetricKeys = SPORT_DEFAULT_METRICS[this.selectedSportIndex].slice();
  }

  /** 根据指标键获取定义 */
  private getMetricDef(key: MetricKey): MetricDef | undefined {
    for (let i = 0; i < METRIC_DEFS.length; i++) {
      if (METRIC_DEFS[i].key === key) {
        return METRIC_DEFS[i];
      }
    }
    return undefined;
  }

  /** 获取指标当前值 */
  private metricValue(def: MetricDef): string {
    switch (def.key) {
      case MetricKey.TIME:
        return formatDuration(this.trackingDuration, true);
      case MetricKey.DISTANCE:
        return formatDistanceKm(this.trackingDistance);
      case MetricKey.ASCENT:
        return `${Math.round(this.trackingAscent)}`;
      case MetricKey.DESCENT:
        return `${Math.round(this.trackingDescent)}`;
      case MetricKey.PACE:
        return formatPace(this.trackingDuration, this.trackingDistance);
      case MetricKey.HEART_RATE:
        return `${this.heartRate}`;
      case MetricKey.STEPS:
        return `${formatSteps(this.trackingDistance)}`;
      case MetricKey.CALORIES:
        return `${formatCalories(this.trackingDistance)}`;
      case MetricKey.CLIMB:
        return `${Math.round(this.trackingAscent)}`;
      default:
        return '';
    }
  }

  /** 指标是否已选中展示 */
  private isMetricSelected(key: MetricKey): boolean {
    return this.displayMetricKeys.indexOf(key) >= 0;
  }

  /** 切换指标展示状态，最多展示 MAX_METRIC_COUNT 项，超出时提示需先关闭其他指标 */
  private toggleMetric(key: MetricKey): void {
    const index: number = this.displayMetricKeys.indexOf(key);
    if (index >= 0) {
      const next: MetricKey[] = [];
      for (let i = 0; i < this.displayMetricKeys.length; i++) {
        if (this.displayMetricKeys[i] !== key) {
          next.push(this.displayMetricKeys[i]);
        }
      }
      this.displayMetricKeys = next;
    } else {
      if (this.displayMetricKeys.length >= MAX_METRIC_COUNT) {
        promptAction.showToast({
          message: this.resStringArgs($r('app.string.metric_max_warning'), MAX_METRIC_COUNT)
        });
        // 强制刷新列表，使被点击的开关复位到关闭态
        this.metricConfigVersion++;
        return;
      }
      this.displayMetricKeys = [...this.displayMetricKeys, key];
    }
  }
}
