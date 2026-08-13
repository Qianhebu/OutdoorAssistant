import { map, mapCommon, MapComponent } from '@kit.MapKit';
import { geoLocationManager } from '@kit.LocationKit';
import { CapsuleSegmentButtonV2, ColorMetrics, LengthMetrics, SegmentButtonV2Items } from '@kit.ArkUI';
import { AsyncCallback, BusinessError } from '@kit.BasicServicesKit';
import { abilityAccessCtrl, common, PermissionRequestResult, Permissions } from '@kit.AbilityKit';
import { saveCurrentLocation } from '../utils/LocationStore';
import { OutdoorTabType } from '../model/TabBarModel';
import { AppStorageKeys } from '../constant/AppStorageKeys';

/** 地图默认中心点坐标（宁波附近） */
const DEFAULT_LOCATION: mapCommon.LatLng = { latitude: 29.87, longitude: 121.55 };
/** 2D 模式倾斜角 */
const MAP_2D_TILT: number = 0;
/** 3D 模式倾斜角 */
const MAP_3D_TILT: number = 60;
/** 3D 模式最低缩放级别，低于此值会自动提升 */
const MAP_3D_MIN_ZOOM: number = 17;
/** 自定义地图控件按钮尺寸 (vp) */
const MAP_CONTROL_SIZE: number = 40;
/** 控件距屏幕右侧间距 (vp) */
const MAP_CONTROL_RIGHT_MARGIN: number = 12;
/** 控件距屏幕底部间距（无半模态时）(vp) */
const MAP_CONTROL_BOTTOM_MARGIN: number = 24;
/** 同类控件之间的间距 (vp) */
const MAP_CONTROL_GAP: number = 8;
/** 单按钮控件数量（3D、图层） */
const MAP_CONTROL_SINGLE_BUTTON_COUNT: number = 2;
/** 系统缩放控件高度，用于让自定义控件位于系统缩放上方 (vp) */
const MAP_SYSTEM_ZOOM_CONTROL_HEIGHT: number = MAP_CONTROL_SIZE * 2 + 1;
/** 系统我的定位控件高度 (vp) */
const MAP_SYSTEM_LOCATION_CONTROL_HEIGHT: number = MAP_CONTROL_SIZE;
/** 地图底部 padding 与系统控件之间的间距 (vp) */
const MAP_SYSTEM_CONTROL_PADDING_GAP: number = 12;
/** 标题栏高度，用于放置系统指南针 (vp) */
const MAP_TITLE_BAR_HEIGHT: number = 56;
/** 系统指南针与标题栏底部的间距 (vp) */
const MAP_COMPASS_TOP_GAP: number = 8;
/** 底部悬浮 Tab 栏高度 (vp) */
const MAP_TAB_BAR_HEIGHT: number = 64;
/** 悬浮 Tab 栏距底部间距 (vp) */
const MAP_TAB_BAR_BOTTOM_MARGIN: number = 28;
/** 开始运动按钮距 Tab 栏上方间距 (vp) */
const MAP_START_BUTTON_BOTTOM_GAP: number = 16;
/** 开始运动按钮宽度和高度 (vp) */
const MAP_START_BUTTON_WIDTH_AND_HEIGHT: number = 80;
/** 图层选择半模态高度 (vp)，与 detents 一致 */
const MAP_LAYER_SHEET_HEIGHT: number = 280;
/** 开始运动面板展开后的高度 (vp) */
const WORKOUT_PANEL_HEIGHT: number = 260;
/** 开始运动面板展开后距左右边缘的间距 (vp) */
const WORKOUT_PANEL_SIDE_GAP: number = 12;
/** 卫星图层叠加路网的最小缩放级别，缩小到该级别以下时切换为混合地图以显示道路 */
const MAP_SATELLITE_ROAD_ZOOM_THRESHOLD: number = 15;

/** 运动类型枚举 */
enum SportType {
  HIKING = 0,
  RUNNING = 1,
  WALKING = 2
}

/** 运动类型选项数据结构 */
interface SportTypeOption {
  type: SportType;
  label: string;
  icon: Resource;
  desc: string;
}

/** 可选运动类型列表 */
const SPORT_TYPE_OPTIONS: SportTypeOption[] = [
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

/** 地图图层选项数据结构 */
interface MapLayerOption {
  title: string;
  subtitle: string;
  mapType: mapCommon.MapType;
  thumbnail: Resource;
}

/** 可选地图图层列表 */
const MAP_LAYER_OPTIONS: MapLayerOption[] = [
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
  /** 当前选中的运动类型索引 */
  @State selectedSportIndex: number = 0;
  /** 是否正在记录轨迹 */
  @State isTracking: boolean = false;
  /** 是否已进入本次运动面板，暂停时仍保持 true */
  @State isWorkoutStarted: boolean = false;
  /** 控制按钮是否锁定 */
  @State isControlLocked: boolean = false;
  /** 是否开启运动语音提示 */
  @State isVoiceEnabled: boolean = true;
  /** 记录时长（秒） */
  @State trackingDuration: number = 0;
  /** 记录距离（米） */
  @State trackingDistance: number = 0;
  /** 累计爬升（米），当前暂无海拔轨迹时保持 0 */
  @State trackingClimb: number = 0;
  /** 是否处于 3D 倾斜模式 */
  @State isMap3DMode: boolean = false;
  /** 当前选中的地图图层类型 */
  @State selectedMapType: mapCommon.MapType = mapCommon.MapType.STANDARD;
  /** 当前地图朝向角 (bearing)，正北为 0，用于自定义指南针旋转 */
  @State compassBearing: number = 0;
  /** 当前地图缩放级别，由 cameraMove 事件实时更新 */
  @State mapZoom: number = 15;
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
  /** 需要申请的定位权限列表 */
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
  /** 已绘制的折线对象 */
  private routePolyline?: map.MapPolyline = undefined;
  /** 计时器 ID */
  private durationTimer?: number = undefined;
  /** 上一次定位坐标（用于计算距离增量） */
  private lastTrackingLocation?: mapCommon.LatLng = undefined;

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
    this.applySheetLayout();
    this.stopTracking();
    this.stopLocationTracking();
    this.stopSatelliteTracking();
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
      const granted = result.authResults.every((status: number) => status === 0);
      this.isPermissionGranted = granted;
      if (granted && this.isMapActive) {
        this.startLocationTracking();
        this.startSatelliteTracking();
      }
    } catch (err) {
      console.error(`MapTab request location permission failed: ${JSON.stringify(err)}`);
    }
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
    let locationRequest: geoLocationManager.LocationRequest = {
      priority: geoLocationManager.LocationRequestPriority.FIRST_FIX,
      scenario: geoLocationManager.LocationRequestScenario.UNSET,
      timeInterval: 1,
      distanceInterval: 0,
      maxAccuracy: 0
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
    this.titleText = this.formatCoordsTitle(location.latitude, location.longitude);
    this.subTitleText = this.formatLocationSubTitle(location);
    if (this.isTracking) {
      this.addRoutePoint(this.currentLocation);
    }
    this.scheduleCenterAfterSheetLayout();
  }

  /** 开始记录轨迹 */
  private startTracking(): void {
    if (this.isTracking) {
      return;
    }
    if (this.isWorkoutStarted) {
      this.resumeTracking();
      return;
    }
    this.isWorkoutStarted = true;
    this.isControlLocked = false;
    this.isTracking = true;
    this.trackingDuration = 0;
    this.trackingDistance = 0;
    this.trackingClimb = 0;
    this.routePoints = [];
    this.lastTrackingLocation = undefined;
    if (this.isGpsLocked) {
      this.addRoutePoint(this.currentLocation);
    }
    this.startDurationTimer();
  }

  /** 继续记录轨迹：不重置运动数据 */
  private resumeTracking(): void {
    if (this.isTracking) {
      return;
    }
    this.isTracking = true;
    this.startDurationTimer();
  }

  /** 暂停记录轨迹：保留本次运动面板和已累计数据 */
  private pauseTracking(): void {
    if (!this.isTracking) {
      return;
    }
    this.isTracking = false;
    this.clearDurationTimer();
  }

  /** 启动运动计时器 */
  private startDurationTimer(): void {
    this.clearDurationTimer();
    this.durationTimer = setInterval(() => {
      this.trackingDuration++;
    }, 1000);
  }

  /** 清理运动计时器 */
  private clearDurationTimer(): void {
    if (this.durationTimer !== undefined) {
      clearInterval(this.durationTimer);
      this.durationTimer = undefined;
    }
  }

  /** 停止记录轨迹 */
  private stopTracking(): void {
    if (!this.isWorkoutStarted && !this.isTracking) {
      return;
    }
    this.isTracking = false;
    this.isWorkoutStarted = false;
    this.isControlLocked = false;
    this.clearDurationTimer();
  }

  /** 添加轨迹点并更新折线 */
  private addRoutePoint(latLng: mapCommon.LatLng): void {
    if (this.lastTrackingLocation !== undefined) {
      const dist: number = this.haversineDistance(this.lastTrackingLocation, latLng);
      if (dist < 2) {
        return;
      }
      this.trackingDistance += dist;
    }
    this.lastTrackingLocation = latLng;
    this.routePoints.push(latLng);
    this.updateRoutePolyline();
  }

  /** 使用 Haversine 公式计算两点间距离（米） */
  private haversineDistance(from: mapCommon.LatLng, to: mapCommon.LatLng): number {
    const R: number = 6371000;
    const dLat: number = (to.latitude - from.latitude) * Math.PI / 180;
    const dLon: number = (to.longitude - from.longitude) * Math.PI / 180;
    const a: number = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
      Math.cos(from.latitude * Math.PI / 180) * Math.cos(to.latitude * Math.PI / 180) *
        Math.sin(dLon / 2) * Math.sin(dLon / 2);
    const c: number = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    return R * c;
  }

  /** 更新地图上的路线折线 */
  private updateRoutePolyline(): void {
    const controller = this.mapController;
    if (!controller || this.routePoints.length < 2) {
      return;
    }
    const gcjPoints: mapCommon.LatLng[] = [];
    for (let i = 0; i < this.routePoints.length; i++) {
      gcjPoints.push(this.convertToMapCoordinate(this.routePoints[i]));
    }
    if (this.routePolyline !== undefined) {
      try {
        this.routePolyline.remove();
      } catch (err) {
        console.error(`MapTab remove polyline failed: ${JSON.stringify(err)}`);
      }
      this.routePolyline = undefined;
    }
    const polylineOptions: mapCommon.MapPolylineOptions = {
      points: gcjPoints,
      clickable: false,
      startCap: mapCommon.CapStyle.ROUND,
      endCap: mapCommon.CapStyle.ROUND,
      jointType: mapCommon.JointType.ROUND,
      visible: true,
      width: 8,
      zIndex: 2,
      gradient: false,
      color: 0xFF00A991
    };
    try {
      controller.addPolyline(polylineOptions).then((polyline: map.MapPolyline) => {
        this.routePolyline = polyline;
      }).catch((err: BusinessError) => {
        console.error(`MapTab addPolyline failed: ${JSON.stringify(err)}`);
      });
    } catch (err) {
      console.error(`MapTab addPolyline sync failed: ${JSON.stringify(err)}`);
    }
  }

  /** 生成副标题：海拔22m 定位误差4.9m */
  private formatLocationSubTitle(location: geoLocationManager.Location): string {
    return `海拔${Math.round(location.altitude)}m 定位误差${location.accuracy.toFixed(1)}m`;
  }

  /** 仅用坐标生成标题：北 29°54'8.59"N 东121°33'4.16"E */
  private formatCoordsTitle(latitude: number, longitude: number): string {
    const latDir: string = latitude >= 0 ? '北' : '南';
    const lonDir: string = longitude >= 0 ? '东' : '西';
    const latSuffix: string = latitude >= 0 ? 'N' : 'S';
    const lonSuffix: string = longitude >= 0 ? 'E' : 'W';
    const latDms: string = this.toDms(Math.abs(latitude));
    const lonDms: string = this.toDms(Math.abs(longitude));
    return `${latDir} ${latDms}"${latSuffix} ${lonDir}${lonDms}"${lonSuffix}`;
  }

  /** 十进制度数转换为度分秒字符串，如 29.9024 → 29°54'8.64 */
  private toDms(value: number): string {
    const degree: number = Math.floor(value);
    const minuteFloat: number = (value - degree) * 60;
    const minute: number = Math.floor(minuteFloat);
    const second: number = (minuteFloat - minute) * 60;
    return `${degree}°${minute}'${second.toFixed(2)}`;
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
    // 切换地图类型后部分渲染层会重建，重新绘制轨迹折线确保线路可见
    if (this.routePoints.length >= 2) {
      this.updateRoutePolyline();
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

  private tabBarOccupiedHeight(): number {
    return MAP_TAB_BAR_HEIGHT + MAP_SYSTEM_CONTROL_PADDING_GAP
  }

  /** 计算系统控件随半模态上移的底部 padding */
  private mapSystemBottomPaddingVp(): number {
    if (this.isShowSheet) {
      return WORKOUT_PANEL_HEIGHT + this.bottomInset + MAP_SYSTEM_CONTROL_PADDING_GAP;
    }
    if (this.isLayerSheetShown) {
      return MAP_LAYER_SHEET_HEIGHT + MAP_SYSTEM_CONTROL_PADDING_GAP;
    }
    return this.bottomInset + this.tabBarOccupiedHeight()
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

  /** 开始运动按钮 X 坐标：水平居中 */
  private startButtonX(): number {
    return Math.max(0, (this.containerWidthVp - MAP_START_BUTTON_WIDTH_AND_HEIGHT) / 2);
  }

  /** 开始运动按钮 Y 坐标：位于底部 Tab 栏上方 */
  private startButtonY(): number {
    return Math.max(0, this.containerHeightVp - this.bottomInset -
      this.tabBarOccupiedHeight() - MAP_START_BUTTON_WIDTH_AND_HEIGHT);
  }

  /** 调整系统指南针位置到标题栏下方 */
  private applySystemControlPositions(): void {
    const controller = this.mapController;
    if (!controller || this.containerWidthVp <= 0) {
      return;
    }
    const uiContext = this.getUIContext();
    const compassPoint: mapCommon.MapPoint = {
      positionX: uiContext.vp2px(this.containerWidthVp - MAP_CONTROL_RIGHT_MARGIN - MAP_CONTROL_SIZE),
      positionY: uiContext.vp2px(this.topInset + MAP_TITLE_BAR_HEIGHT)
    };
    try {
      controller.setCompassPosition(compassPoint);
    } catch (err) {
      console.error(`MapTab set compass position failed: ${JSON.stringify(err)}`);
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
      // 控制路况显示
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

  /** 坐标信息半模态配置：两档高度、可拖拽、背景可交互 */
  private buildSheetOptions(): SheetOptions {
    return {
      detents: [400],
      preferType: SheetType.BOTTOM,
      dragBar: true,
      showClose: false,
      enableOutsideInteractive: true,
      onWillDismiss: (action: DismissSheetAction) => {
      },
      onWillSpringBackWhenDismiss: (action: SpringBackAction) => {
        action.springBack();
      },
      onHeightDidChange: (height: number) => {
        this.sheetHeightVp = this.getUIContext().px2vp(height);
        this.applySheetLayout();
      },
      onAppear: () => {
        this.applySheetLayout();
      }
    };
  }

  /** 图层选择半模态配置：固定高度、带关闭按钮、禁止下拉关闭 */
  private buildLayerSheetOptions(): SheetOptions {
    return {
      detents: [280],
      preferType: SheetType.BOTTOM,
      dragBar: true,
      showClose: true,
      enableOutsideInteractive: true,
      // blurStyle: BlurStyle.Thin,
      title: { title: '地图图层类型', subtitle: '' },
      onWillDismiss: (action: DismissSheetAction) => {
        if (action.reason !== DismissReason.SLIDE_DOWN) {
          action.dismiss();
        }
      },
      onWillSpringBackWhenDismiss: (action: SpringBackAction) => {
        action.springBack();
      },
      onDisappear: () => {
        this.isLayerSheetShown = false;
        this.applySheetLayout();
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
    if (this.currentTab === OutdoorTabType.RECORD) {
      this.activateMapPage();
    }
  }

  aboutToDisappear(): void {
    this.deactivateMapPage();
  }

  build() {
    Stack({ alignContent: Alignment.Top }) {
      // 地图组件，绑定坐标信息半模态
      if (this.mapOptions && this.mapCallback) {
        MapComponent({ mapOptions: this.mapOptions, mapCallback: this.mapCallback })
          .width('100%')
          .height('100%')
        // .bindSheet(this.isShowSheet, this.buildSheetContent(), this.buildSheetOptions())
      }

      // 顶部自定义标题栏：坐标文本 + GNSS 芯片
      this.buildStackBuilder()

      // 自定义地图控件（覆盖在地图上方）
      this.buildMapControls()

      // 开始运动按钮（悬浮在底部 Tab 栏上方）
      this.buildStartWorkoutButton()

    }
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
    .backgroundColor($r('sys.color.background_secondary'))
  }

  /** 标题栏自定义布局：左侧坐标文本 + 右侧 GNSS 卫星状态芯片 */
  @Builder
  buildStackBuilder() {
    Column() {
      Flex({ justifyContent: FlexAlign.SpaceBetween, alignItems: ItemAlign.Center }) {
        Row() {
          Text(`${this.titleText}${this.subTitleText}`)
            .fontSize(11)
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
      .height(MAP_TITLE_BAR_HEIGHT)
      .padding({ left: 12, right: 12 })
    }
    .width('100%')
    .padding({ top: this.topInset })
  }

  /** 开始运动按钮：悬浮在底部 Tab 栏上方，水平居中，含运动类型分段切换 + 播放按钮 */
  @Builder
  buildStartWorkoutButton() {
    if (this.containerHeightVp > 0) {
      Column({ space: 16 }) {
        this.buildSportTypeSegmented()
        SymbolGlyph($r('sys.symbol.play_circle_fill'))
          .fontSize(80)
          .renderingStrategy(SymbolRenderingStrategy.MULTIPLE_COLOR)
          .fontColor(['#60C25A', '#FFFFFF'])
          .width(80)
          .height(80)
          .onClick(() => {
            this.isShowSheet = true;
            this.applySheetLayout();
          })
      }
      .width(this.isShowSheet ? this.containerWidthVp - WORKOUT_PANEL_SIDE_GAP * 2 : 'auto')
      .height(this.isShowSheet ? WORKOUT_PANEL_HEIGHT : 'auto')
      .alignItems(HorizontalAlign.Center)
      .position({
        x: this.containerWidthVp / 2,
        y: this.isShowSheet ? this.containerHeightVp - this.bottomInset - this.tabBarOccupiedHeight() :
          (this.startButtonY() + MAP_START_BUTTON_WIDTH_AND_HEIGHT)
      })
      .markAnchor({ x: '50%', y: '100%' })
      .zIndex(3)
      .borderRadius(36)
      .padding({
        left: 12,
        right: 12,
        top: 12,
        bottom: 12
      })
      .backgroundBlurStyle(BlurStyle.Thin, { colorMode: ThemeColorMode.SYSTEM })
      .border({ width: 1, color: $r('sys.color.indicator_border_color') })

      // .backgroundColor(Color.Orange)
    }
  }

  /** 运动类型分段按钮选项（仅图标） */
  private segmentSportItems: SegmentButtonV2Items = new SegmentButtonV2Items([
    { symbol: $r('sys.symbol.figure_hiking') },
    { symbol: $r('sys.symbol.figure_run') },
    { symbol: $r('sys.symbol.figure_walk') }
  ]);

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
        itemSymbolFontColor: ColorMetrics.resourceColor('#8B9499'),
        itemSelectedSymbolFontColor: ColorMetrics.resourceColor('#00A991'),
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

  /** GNSS 卫星状态芯片：显示卫星数量，未定位时显示"正在搜索..." */
  @Builder
  buildGnssChip() {
    Row({ space: 2 }) {
      // SymbolGlyph($r('sys.symbol.beidou_satellite_fill'))
      //   .fontSize(21)
      //   .fontColor([$r('sys.color.icon_secondary')])
      Text('GNSS')
        .fontSize(11)
        .fontColor($r('sys.color.ohos_id_color_text_primary'))
        .fontWeight(FontWeight.Medium)

      if (!this.isGpsLocked) {
        Text('正在搜索...')
          .fontSize(11)
          .fontColor($r('sys.color.ohos_id_color_text_primary'))
      } else {
        if (this.satelliteCount > 0) {
          Text(`${this.satelliteCount}`)
            .fontSize(11)
            .fontColor('#00A991')
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

  /** 3D 模式切换按钮：仅标准地图显示，其他图层不支持 3D */
  @Builder
  buildMapControls() {
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
                color: '#00A991'
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

  /** 坐标信息半模态内容：运动中显示数据面板 */
  @Builder
  buildSheetContent() {
    this.buildWorkoutSheetContent()
  }

  /** 运动中半模态：数据显示 + 锁定/继续/暂停/声音 */
  @Builder
  buildWorkoutSheetContent() {
    Column() {
      Row() {
        Column({ space: 6 }) {
          Text(this.formatDistanceKmValue())
            .fontSize(56)
            .fontWeight(FontWeight.Bold)
            .fontFamily('SmileySans')
            .fontColor('#F4F6F7')
          Text('距离 (公里)')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor('#9EA4A8')
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        this.buildSportGauge()
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Row({ space: 12 }) {
        Column() {
          this.buildMetricItem(this.formatElapsedTime(), '时间')
        }
        .layoutWeight(1)

        Column() {
          this.buildMetricItem(`${Math.round(this.trackingClimb)}`, '爬升 (米)')
        }
        .layoutWeight(1)

        Column() {
          this.buildMetricItem(`${this.formatSteps()}`, '步数')
        }
        .layoutWeight(1)
      }
      .width('100%')
      .margin({ top: 28 })

      Row({ space: 12 }) {
        Column() {
          this.buildMetricItem(`${this.formatCalories()}`, '总消耗热量 (千卡)')
        }
        .layoutWeight(1)

        Column() {
          this.buildMetricItem(this.formatPace(), '配速')
        }
        .layoutWeight(1)

        Blank()
          .layoutWeight(1)
      }
      .width('100%')
      .margin({ top: 22 })

      Blank()

      Row() {
        this.buildCircleActionButton(
          this.isControlLocked ? $r('sys.symbol.lock_fill') : $r('sys.symbol.lock'),
          '#2E3233',
          56,
          () => {
            this.isControlLocked = !this.isControlLocked;
          }
        )

        Blank()

        this.buildCircleActionButton(
          this.isTracking ? $r('sys.symbol.pause_circle_fill') : $r('sys.symbol.play_circle_fill'),
          this.isControlLocked ? '#496F45' : (this.isTracking ? '#F04F57' : '#60C25A'),
          72,
          () => {
            if (this.isControlLocked) {
              return;
            }
            if (this.isTracking) {
              this.pauseTracking();
            } else {
              this.resumeTracking();
            }
          }
        )

        Blank()

        this.buildCircleActionButton(
          this.isVoiceEnabled ? $r('sys.symbol.speaker_wave_3_fill') : $r('sys.symbol.speaker_slash_fill'),
          '#2E3233',
          56,
          () => {
            this.isVoiceEnabled = !this.isVoiceEnabled;
          }
        )
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      .margin({ bottom: 12 })
    }
    .width('100%')
    .height('100%')
    .padding({
      left: 24,
      right: 24,
      top: 34,
      bottom: this.bottomInset + 16
    })
  }

  /** 单项运动指标 */
  @Builder
  buildMetricItem(value: string, label: string) {
    Column({ space: 4 }) {
      Text(value)
        .fontSize(34)
        .fontWeight(FontWeight.Bold)
        .fontFamily('SmileySans')
        .fontColor('#F4F6F7')
        .maxLines(1)
      Text(label)
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor('#9EA4A8')
        .maxLines(1)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  /** 右上运动类型仪表盘 */
  @Builder
  buildSportGauge() {
    Swiper() {
      ForEach(SPORT_TYPE_OPTIONS, (option: SportTypeOption) => {
        Stack({ alignContent: Alignment.Center }) {
          Circle()
            .width(78)
            .height(78)
            .fill('#273033')

          Column({ space: 2 }) {
            SymbolGlyph(option.icon)
              .fontSize(25)
              .fontColor(['#8B9499'])
            Text(option.label)
              .fontSize(9)
              .fontWeight(FontWeight.Medium)
              .fontColor('#8B9499')
          }
          .width(48)
          .height(48)
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
        }
        .width(86)
        .height(86)
      }, (option: SportTypeOption, index?: number) => `${index}`)
    }
    .width(86)
    .height(86)
    .index(this.selectedSportIndex)
    .vertical(true)
    .loop(true)
    .indicator(false)
    .displayCount(1)
    .effectMode(EdgeEffect.None)
    .onChange((index: number) => {
      this.selectedSportIndex = index;
    })
  }

  /** 底部圆形控制按钮 */
  @Builder
  buildCircleActionButton(icon: Resource, backgroundColor: ResourceColor, size: number, action: () => void) {
    Stack({ alignContent: Alignment.Center }) {
      SymbolGlyph(icon)
        .fontSize(size >= 80 ? 40 : 25)
        .fontColor([Color.White])
    }
    .width(size)
    .height(size)
    .borderRadius(size / 2)
    .backgroundColor(backgroundColor)
    .shadow({
      radius: 16,
      color: 'rgba(0,0,0,0.18)',
      offsetX: 0,
      offsetY: 4
    })
    .onClick(() => {
      action();
    })
  }

  /** 格式化时长 hh:mm:ss */
  private formatElapsedTime(): string {
    return this.formatDuration(this.trackingDuration, true);
  }

  /** 格式化时长，可强制显示小时 */
  private formatDuration(seconds: number, alwaysShowHour: boolean = false): string {
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

  /** 格式化公里数，仅显示数值 */
  private formatDistanceKmValue(): string {
    return (this.trackingDistance / 1000).toFixed(2);
  }

  /** 估算热量消耗，缺少体重数据时使用距离近似 */
  private formatCalories(): number {
    return Math.round(this.trackingDistance * 0.06);
  }

  /** 估算步数，缺少计步传感器数据时按平均步长换算 */
  private formatSteps(): number {
    return Math.round(this.trackingDistance / 0.75);
  }

  /** 格式化距离 */
  private formatDistance(meters: number): string {
    if (meters >= 1000) {
      return `${(meters / 1000).toFixed(2)} km`;
    }
    return `${Math.round(meters)} m`;
  }

  /** 格式化配速 */
  private formatPace(): string {
    if (this.trackingDistance < 100 || this.trackingDuration === 0) {
      return "--'--\"";
    }
    const minutesPerKm: number = (this.trackingDuration / 60) / (this.trackingDistance / 1000);
    const paceMin: number = Math.floor(minutesPerKm);
    const paceSec: number = Math.round((minutesPerKm - paceMin) * 60);
    return `${paceMin}'${paceSec < 10 ? '0' : ''}${paceSec}"`;
  }
}
