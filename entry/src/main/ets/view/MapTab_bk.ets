import { map, mapCommon, MapComponent } from '@kit.MapKit';
import { geoLocationManager } from '@kit.LocationKit';
import { AsyncCallback, BusinessError } from '@kit.BasicServicesKit';
import { AppStorageKeys } from '../constant/AppStorageKeys';
import { StorageKey } from '../constant/StorageKey';
import { PageEnum } from '../constant/PageEnum';
import { PageContext } from '../router/PageContext';
import { LengthMetrics, promptAction } from '@kit.ArkUI';
import {
  ALL_RECORD_METRICS,
  RecordMetric,
  RecordMetricStore,
  getRecordMetricStore
} from '../model/RecordMetricModel';

/** 记录状态 */
enum RecordPhase {
  IDLE = 0,
  RECORDING = 1,
  PAUSED = 2
}

/** GNSS 定位状态 */
enum GnssPhase {
  SEARCHING = 0,
  LOCKED = 1
}

/** 模拟步频（步/分钟），用于步频指标展示 */
const SIMULATED_CADENCE: number = 120;
/** 模拟海拔（米） */
const SIMULATED_ALTITUDE: number = 12;
/** 每秒钟模拟行进距离（公里，约 5.8km/h 步行速度） */
const DISTANCE_PER_SECOND: number = 0.0016;
/** 每秒钟模拟步数 */
const STEPS_PER_SECOND: number = 2;
/** 每秒钟模拟消耗热量（千卡） */
const CALORIES_PER_SECOND: number = 0.06;
/** GNSS 定位兜底锁定时间（毫秒） */
const GNSS_LOCK_FALLBACK_MS: number = 4000;

@ComponentV2({ freezeWhenInactive: true })
export struct MapTab {
  // ===== 地图 =====
  @Local mapOptions?: mapCommon.MapOptions = undefined;
  @Local currentLocation: mapCommon.LatLng = { latitude: 29.87, longitude: 121.55 };
  // ===== 记录数据 =====
  @Local metricStore: RecordMetricStore = getRecordMetricStore();
  @Local recordPhase: RecordPhase = RecordPhase.IDLE;
  @Local elapsedSeconds: number = 0;
  @Local distanceKm: number = 0;
  @Local stepCount: number = 0;
  @Local calorieCount: number = 0;
  @Local heartRate: number = 0;
  // ===== GNSS 状态 =====
  @Local gnssPhase: GnssPhase = GnssPhase.SEARCHING;
  // ===== 安全区 =====
  topInset: number = AppStorage.get<number>(AppStorageKeys.TOP_INSET) ?? 0;
  bottomInset: number = AppStorage.get<number>(AppStorageKeys.BOTTOM_INSET) ?? 0;
  // ===== 路由与控制器 =====
  private appPageContext: PageContext =
    AppStorage.get<PageContext>(StorageKey.HOME_PAGE_CONTEXT) ?? new PageContext();
  private mapController?: map.MapComponentController = undefined;
  private mapCallback?: AsyncCallback<map.MapComponentController> = undefined;
  private recordTimer: number = -1;
  private gnssLockTimer: number = -1;
  private locationChangeCb: (location: geoLocationManager.Location) => void =
    (location: geoLocationManager.Location) => {
      this.mapController?.setMyLocation(location);
      if (this.gnssPhase !== GnssPhase.LOCKED) {
        this.gnssPhase = GnssPhase.LOCKED;
      }
    };

  aboutToAppear(): void {
    this.initMap();
    this.startGnssLockTimer();
  }

  aboutToDisappear(): void {
    this.stopRecordTimer();
    if (this.gnssLockTimer !== -1) {
      clearTimeout(this.gnssLockTimer);
      this.gnssLockTimer = -1;
    }
    try {
      geoLocationManager.off('locationChange');
    } catch (err) {
      console.info(`MapTab off locationChange: ${JSON.stringify(err)}`);
    }
  }

  /** 初始化地图与定位监听 */
  private initMap(): void {
    this.mapOptions = {
      mapType: mapCommon.MapType.STANDARD,
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
      zoomControlsEnabled: false,
      myLocationControlsEnabled: false,
      compassControlsEnabled: false,
      scaleControlsEnabled: false,
      dayNightMode: mapCommon.DayNightMode.AUTO
    };
    this.mapCallback = async (err: BusinessError | undefined, controller: map.MapComponentController) => {
      if (err) {
        console.error(`MapTab map init failed: ${err.message}`);
        return;
      }
      this.mapController = controller;
      let myLocationStyle: mapCommon.MyLocationStyle = {
        anchorU: 0.5,
        anchorV: 0.5,
        radiusFillColor: 0x00000000,
        displayType: mapCommon.MyLocationDisplayType.FOLLOW
      };
      await this.mapController.setMyLocationStyle(myLocationStyle);
      try {
        this.mapController.setMyLocationEnabled(true);
      } catch (enableErr) {
        console.error(`MapTab setMyLocationEnabled failed: ${JSON.stringify(enableErr)}`);
      }
      this.mapController.setBuildingEnabled(true);
      this.mapController.setTrafficEnabled(false);

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
        console.error(`MapTab locationChange failed: ${(error as BusinessError).message}`);
      }
    };
  }

  /** GNSS 定位兜底：超时仍未定位则视为已锁定 */
  private startGnssLockTimer(): void {
    if (this.gnssLockTimer !== -1) {
      clearTimeout(this.gnssLockTimer);
    }
    this.gnssLockTimer = setTimeout(() => {
      if (this.gnssPhase !== GnssPhase.LOCKED) {
        this.gnssPhase = GnssPhase.LOCKED;
      }
    }, GNSS_LOCK_FALLBACK_MS);
  }

  // ==================== 记录控制 ====================

  private handleRecordButton(): void {
    if (this.recordPhase === RecordPhase.IDLE) {
      this.startRecord();
    } else if (this.recordPhase === RecordPhase.RECORDING) {
      this.pauseRecord();
    } else {
      this.resumeRecord();
    }
  }

  private startRecord(): void {
    this.elapsedSeconds = 0;
    this.distanceKm = 0;
    this.stepCount = 0;
    this.calorieCount = 0;
    this.heartRate = 0;
    this.recordPhase = RecordPhase.RECORDING;
    this.startRecordTimer();
    promptAction.showToast({ message: '开始记录' });
  }

  private pauseRecord(): void {
    this.stopRecordTimer();
    this.recordPhase = RecordPhase.PAUSED;
  }

  private resumeRecord(): void {
    this.recordPhase = RecordPhase.RECORDING;
    this.startRecordTimer();
  }

  private finishRecord(): void {
    this.stopRecordTimer();
    const summary: string = `已结束记录：${this.formatDuration()} · ${this.distanceKm.toFixed(2)}km · ${this.stepCount}步`;
    this.recordPhase = RecordPhase.IDLE;
    this.elapsedSeconds = 0;
    this.distanceKm = 0;
    this.stepCount = 0;
    this.calorieCount = 0;
    this.heartRate = 0;
    promptAction.showToast({ message: summary });
  }

  private startRecordTimer(): void {
    this.stopRecordTimer();
    this.recordTimer = setInterval(() => {
      this.onRecordTick();
    }, 1000);
  }

  private stopRecordTimer(): void {
    if (this.recordTimer !== -1) {
      clearInterval(this.recordTimer);
      this.recordTimer = -1;
    }
  }

  /** 每秒更新模拟运动数据 */
  private onRecordTick(): void {
    this.elapsedSeconds++;
    this.distanceKm += DISTANCE_PER_SECOND;
    this.stepCount += STEPS_PER_SECOND;
    this.calorieCount += CALORIES_PER_SECOND;
    this.heartRate = 70 + Math.floor(Math.random() * 9);
  }

  // ==================== 数据格式化 ====================

  private padNumber(value: number): string {
    return value < 10 ? `0${value}` : `${value}`;
  }

  private formatDuration(): string {
    const hours: number = Math.floor(this.elapsedSeconds / 3600);
    const minutes: number = Math.floor((this.elapsedSeconds % 3600) / 60);
    const seconds: number = this.elapsedSeconds % 60;
    if (hours > 0) {
      return `${this.padNumber(hours)}:${this.padNumber(minutes)}:${this.padNumber(seconds)}`;
    }
    return `${this.padNumber(minutes)}:${this.padNumber(seconds)}`;
  }

  private formatPace(): string {
    if (this.distanceKm <= 0) {
      return "--'";
    }
    const secPerKm: number = this.elapsedSeconds / 60 / this.distanceKm;
    const minutes: number = Math.floor(secPerKm / 60);
    const seconds: number = Math.floor(secPerKm % 60);
    return `${minutes}'${this.padNumber(seconds)}"`;
  }

  /** 根据指标 key 返回当前值（模拟数据） */
  private metricValue(key: string): string {
    switch (key) {
      case 'distance':
        return this.distanceKm.toFixed(2);
      case 'time':
        return this.formatDuration();
      case 'steps':
        return `${this.stepCount}`;
      case 'calories':
        return `${Math.floor(this.calorieCount)}`;
      case 'activeCalories':
        return `${Math.floor(this.calorieCount)}`;
      case 'pace':
        return this.formatPace();
      case 'heartRate':
        return this.recordPhase === RecordPhase.IDLE ? '--' : `${this.heartRate}`;
      case 'speed':
        if (this.elapsedSeconds <= 0) {
          return '0.0';
        }
        return (this.distanceKm / this.elapsedSeconds * 3600).toFixed(1);
      case 'cadence':
        return this.recordPhase === RecordPhase.IDLE ? '0' : `${SIMULATED_CADENCE}`;
      case 'descent':
        return '0';
      case 'altitude':
        return `${SIMULATED_ALTITUDE}`;
      case 'groundContactTime':
        return '220';
      case 'eversion':
        return '0';
      case 'impact':
        return '0';
      case 'swingAngle':
        return '0';
      case 'flightRatio':
        return '0';
      default:
        return '0';
    }
  }

  private isMetricVisible(key: string): boolean {
    return this.metricStore.visibleKeys.indexOf(key) >= 0;
  }

  /** 除距离外的可见指标（距离作为主展示区） */
  private visibleSecondaryMetrics(): RecordMetric[] {
    return ALL_RECORD_METRICS.filter((metric: RecordMetric) =>
      metric.key !== 'distance' && this.metricStore.visibleKeys.indexOf(metric.key) >= 0);
  }

  private openEditMetricsPage(): void {
    this.appPageContext.openPage({ routerName: PageEnum.RECORD_METRICS_EDIT });
  }

  build() {
    Stack() {
      // ===== 地图 =====
      if (this.mapOptions && this.mapCallback) {
        MapComponent({ mapOptions: this.mapOptions, mapCallback: this.mapCallback })
          .width('100%')
          .height('100%')
      }

      // ===== 顶部：GNSS 状态 + 指标编辑入口 =====
      Row() {
        this.buildGnssChip()
        Blank()
        this.buildEditButton()
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: this.topInset + 8 })
      .alignItems(VerticalAlign.Center)
      .align(Alignment.Top)

      // ===== 底部：数据面板 + 记录控制 =====
      Column({ space: 16 }) {
        this.buildStatsPanel()
        this.buildRecordControls()
      }
      .width('100%')
      .align(Alignment.Bottom)
      .padding({
        left: 16,
        right: 16,
        bottom: this.bottomInset + 104
      })
    }
    .width('100%')
    .height('100%')
  }

  /** GNSS 状态指示 */
  @Builder
  buildGnssChip() {
    Row({ space: 6 }) {
      Circle({ width: 8, height: 8 })
        .fill(this.gnssPhase === GnssPhase.LOCKED ? '#00A991' : '#E6A23C')
      Text(this.gnssPhase === GnssPhase.LOCKED ? 'GNSS 已定位' : 'GNSS 正在搜索')
        .fontSize(12)
        .fontColor(this.gnssPhase === GnssPhase.LOCKED ? '#00A991' : '#B8860B')
        .fontWeight(FontWeight.Medium)
    }
    .padding({ left: 12, right: 12, top: 6, bottom: 6 })
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(16)
    .shadow({ radius: 8, color: 'rgba(0,0,0,0.10)', offsetY: 2 })
  }

  /** 指标编辑入口按钮 */
  @Builder
  buildEditButton() {
    Column() {
      SymbolGlyph($r('sys.symbol.dot_grid_2x2'))
        .fontSize(20)
        .fontColor(['#1A1A1A'])
    }
    .width(36)
    .height(36)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(18)
    .shadow({ radius: 8, color: 'rgba(0,0,0,0.10)', offsetY: 2 })
    .onClick(() => {
      this.openEditMetricsPage();
    })
  }

  /** 实时数据面板 */
  @Builder
  buildStatsPanel() {
    Column() {
      if (this.isMetricVisible('distance')) {
        Column({ space: 2 }) {
          Text(this.metricValue('distance'))
            .fontSize(44)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('sys.color.font_primary'))
          Text('距离（公里）')
            .fontSize(12)
            .fontColor($r('sys.color.font_secondary'))
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)

        Divider()
          .color($r('sys.color.comp_background_tertiary'))
          .margin({ top: 12, bottom: 12 })
      }

      if (this.visibleSecondaryMetrics().length > 0) {
        Flex({ wrap: FlexWrap.Wrap, space: { main: LengthMetrics.vp(20), cross: LengthMetrics.vp(16) } }) {
          ForEach(this.visibleSecondaryMetrics(), (metric: RecordMetric) => {
            this.buildMetricCell(metric)
          }, (metric: RecordMetric) => metric.key)
        }
        .width('100%')
      }
    }
    .width('100%')
    .padding(16)
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(24)
    .shadow({ radius: 16, color: 'rgba(0,0,0,0.12)', offsetY: 4 })
  }

  /** 单个指标展示单元 */
  @Builder
  buildMetricCell(metric: RecordMetric) {
    Column({ space: 3 }) {
      Text(this.metricValue(metric.key))
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('sys.color.font_primary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      Text(metric.unit.length > 0 ? `${metric.title}（${metric.unit}）` : metric.title)
        .fontSize(11)
        .fontColor($r('sys.color.font_secondary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width(96)
    .alignItems(HorizontalAlign.Start)
  }

  /** 记录控制：开始/暂停/继续 + 结束 */
  @Builder
  buildRecordControls() {
    Row({ space: 16 }) {
      if (this.recordPhase !== RecordPhase.IDLE) {
        Button('结束')
          .type(ButtonType.Capsule)
          .height(44)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(Color.White)
          .backgroundColor('#E84026')
          .padding({ left: 28, right: 28 })
          .onClick(() => {
            this.finishRecord();
          })
      }

      Button() {
        if (this.recordPhase === RecordPhase.IDLE) {
          Text('开始')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
        } else if (this.recordPhase === RecordPhase.RECORDING) {
          Row({ space: 5 }) {
            Column()
              .width(6)
              .height(20)
              .backgroundColor(Color.White)
              .borderRadius(3)
            Column()
              .width(6)
              .height(20)
              .backgroundColor(Color.White)
              .borderRadius(3)
          }
        } else {
          Path()
            .commands('M 6 3 L 6 21 L 20 12 Z')
            .width(26)
            .height(26)
            .fill(Color.White)
        }
      }
      .type(ButtonType.Circle)
      .width(76)
      .height(76)
      .backgroundColor(this.recordPhase === RecordPhase.RECORDING ? '#E84026' : '#00A991')
      .shadow({ radius: 12, color: 'rgba(0,0,0,0.20)', offsetY: 4 })
      .onClick(() => {
        this.handleRecordButton();
      })
    }
    .width('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
  }
}
