import { AsyncCallback, BusinessError } from '@kit.BasicServicesKit';
import { map, mapCommon } from '@kit.MapKit';
import { UIContext } from '@kit.ArkUI';
import { HikingRouteItem, TrackPoint } from '@ohos/common';

/** 标题栏高度，地图顶部适配时预留 */
export const ROUTE_TITLE_BAR_HEIGHT: number = 56;
const METERS_PER_DEGREE: number = 111320;
const GROUND_RESOLUTION_ZOOM0: number = 156543.03392;

/** 路线在地图上的几何数据（墨卡托近似投影 + 旋转后的外接矩形） */
export interface RouteGeometry {
  gcjPoints: mapCommon.LatLng[];
  bearingRad: number;
  refLat: number;
  refLng: number;
  uMin: number;
  uMax: number;
  vMin: number;
  vMax: number;
}

/** 方向箭头：在路线绘制到 thresholdIndex 时显示 */
interface ArrowPlan {
  thresholdIndex: number;
  options: mapCommon.MarkerOptions;
}

/**
 * 路线详情页的地图逻辑封装：地图初始化、相机适配（适配到 bindSheet 上方区域）、
 * 路线逐段绘制动画、方向箭头与起终点标记的渐进显示。
 */
export class RouteMapHelper {
  private controller?: map.MapComponentController;
  private route?: HikingRouteItem;
  private uiContext: UIContext;
  private topInset: number = 0;
  private deviceHeightVp: number = 0;
  private deviceWidthVp: number = 0;
  private sheetHeightVp: number = 0;
  private routeGeom?: RouteGeometry;
  private isRouteTraceAdded: boolean = false;
  private isEndMarkerAdded: boolean = false;
  private arrowPlan: ArrowPlan[] = [];
  private arrowCursor: number = 0;

  constructor(uiContext: UIContext) {
    this.uiContext = uiContext;
  }

  /** 页面级配置：路线数据与屏幕尺寸，进入页面时调用一次 */
  configure(route: HikingRouteItem, topInset: number, deviceHeightVp: number, deviceWidthVp: number): void {
    this.route = route;
    this.topInset = topInset;
    this.deviceHeightVp = deviceHeightVp;
    this.deviceWidthVp = deviceWidthVp;
  }

  /** 构建地图初始化参数，初始相机对准路线包围盒中心 */
  buildMapOptions(): mapCommon.MapOptions {
    const track: TrackPoint[] = this.route?.trackPath ?? [];
    let center: mapCommon.LatLng = { latitude: 29.87, longitude: 121.55 };
    if (track.length >= 2) {
      let minLat: number = 90;
      let maxLat: number = -90;
      let minLng: number = 180;
      let maxLng: number = -180;
      for (let i = 0; i < track.length; i++) {
        const p: TrackPoint = track[i];
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
      center = this.convertToMapCoordinate({
        latitude: (minLat + maxLat) / 2,
        longitude: (minLng + maxLng) / 2
      });
    }
    return {
      mapType: mapCommon.MapType.STANDARD,
      position: {
        target: center,
        zoom: 13,
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
      dayNightMode: mapCommon.DayNightMode.AUTO,
      sphereEnabled: false
    };
  }

  /** 构建地图就绪回调：就绪后计算路线几何并适配相机、开始绘制 */
  buildMapCallback(): AsyncCallback<map.MapComponentController> {
    return (err: BusinessError | undefined, controller: map.MapComponentController) => {
      if (err) {
        console.error(`RouteDetailPage map init failed: ${err.message}`);
        return;
      }
      this.controller = controller;
      this.prepareRouteGeometry();
      this.fitCamera();
    };
  }

  /** bindSheet 高度变化时重新适配相机 */
  onSheetHeightChanged(sheetHeightVp: number): void {
    this.sheetHeightVp = sheetHeightVp;
    this.fitCamera();
  }

  private convertToMapCoordinate(latLng: TrackPoint): mapCommon.LatLng {
    const source: mapCommon.LatLng = {
      latitude: latLng.latitude,
      longitude: latLng.longitude
    };
    try {
      return map.convertCoordinateSync(
        mapCommon.CoordinateType.WGS84,
        mapCommon.CoordinateType.GCJ02,
        source
      );
    } catch (err) {
      console.error(`RouteDetailPage convert coordinate failed: ${JSON.stringify(err)}`);
      return source;
    }
  }

  /** 预处理路线几何：GCJ02 点集 + 米制外接矩形，供相机适配与绘制使用 */
  private prepareRouteGeometry(): void {
    const track: TrackPoint[] = this.route?.trackPath ?? [];
    if (track.length < 2) {
      return;
    }
    const gcjPoints: mapCommon.LatLng[] = [];
    let minLat: number = 90;
    let maxLat: number = -90;
    let minLng: number = 180;
    let maxLng: number = -180;
    for (let i = 0; i < track.length; i++) {
      const g: mapCommon.LatLng = this.convertToMapCoordinate(track[i]);
      gcjPoints.push(g);
      if (g.latitude < minLat) {
        minLat = g.latitude;
      }
      if (g.latitude > maxLat) {
        maxLat = g.latitude;
      }
      if (g.longitude < minLng) {
        minLng = g.longitude;
      }
      if (g.longitude > maxLng) {
        maxLng = g.longitude;
      }
    }
    const refLat: number = (minLat + maxLat) / 2;
    const refLng: number = (minLng + maxLng) / 2;
    const cosRefLat: number = Math.cos(refLat * Math.PI / 180);
    const sinB: number = 0;
    const cosB: number = 1;
    let uMin: number = 1e12;
    let uMax: number = -1e12;
    let vMin: number = 1e12;
    let vMax: number = -1e12;
    for (let i = 0; i < gcjPoints.length; i++) {
      const p: mapCommon.LatLng = gcjPoints[i];
      const x: number = (p.longitude - refLng) * METERS_PER_DEGREE * cosRefLat;
      const y: number = (p.latitude - refLat) * METERS_PER_DEGREE;
      const u: number = x * sinB + y * cosB;
      const v: number = x * cosB - y * sinB;
      if (u < uMin) {
        uMin = u;
      }
      if (u > uMax) {
        uMax = u;
      }
      if (v < vMin) {
        vMin = v;
      }
      if (v > vMax) {
        vMax = v;
      }
    }
    this.routeGeom = {
      gcjPoints: gcjPoints,
      bearingRad: 0,
      refLat: refLat,
      refLng: refLng,
      uMin: uMin,
      uMax: uMax,
      vMin: vMin,
      vMax: vMax
    };
  }

  /** 把路线适配进 bindSheet 上方可见区域，然后开始动画绘制 */
  private fitCamera(): void {
    const controller = this.controller;
    const geom = this.routeGeom;
    if (!controller || !geom || geom.gcjPoints.length < 2 || this.sheetHeightVp <= 0) {
      return;
    }
    const uiContext = this.uiContext;
    const edgePx: number = uiContext.vp2px(12);
    const sidePx: number = uiContext.vp2px(24);
    const topOffsetPx: number = uiContext.vp2px(this.topInset + ROUTE_TITLE_BAR_HEIGHT + 12);
    const sheetHeightPx: number = uiContext.vp2px(this.sheetHeightVp);
    const mapHPx: number = uiContext.vp2px(this.deviceHeightVp);
    const mapWPx: number = uiContext.vp2px(this.deviceWidthVp);
    const minMapStripPx: number = uiContext.vp2px(this.deviceHeightVp * 0.2);
    const maxSheetHeightPx: number = mapHPx - topOffsetPx - minMapStripPx;
    const bottomOffsetPx: number = Math.min(sheetHeightPx + edgePx, maxSheetHeightPx);
    const fitWPx: number = mapWPx - 2 * sidePx;
    const fitHPx: number = mapHPx - topOffsetPx - bottomOffsetPx;
    const widthM: number = geom.vMax - geom.vMin;
    const heightM: number = geom.uMax - geom.uMin;
    const resMPerPx: number = Math.max(widthM / fitWPx, heightM / fitHPx);
    const density: number = uiContext.vp2px(1);
    const groundRes: number = GROUND_RESOLUTION_ZOOM0 * Math.cos(geom.refLat * Math.PI / 180);
    const zoom: number = Math.min(Math.max(Math.log2(groundRes / (resMPerPx * density)), 10), 17);
    const shiftPx: number = (bottomOffsetPx - topOffsetPx) / 2;
    const uCenter: number = (geom.uMin + geom.uMax) / 2;
    const vCenter: number = (geom.vMin + geom.vMax) / 2;
    const uTarget: number = uCenter - shiftPx * resMPerPx;
    const vTarget: number = vCenter;
    const sinB: number = Math.sin(geom.bearingRad);
    const cosB: number = Math.cos(geom.bearingRad);
    const xTarget: number = uTarget * sinB + vTarget * cosB;
    const yTarget: number = uTarget * cosB - vTarget * sinB;
    const cosRef: number = Math.cos(geom.refLat * Math.PI / 180);
    const target: mapCommon.LatLng = {
      latitude: geom.refLat + yTarget / METERS_PER_DEGREE,
      longitude: geom.refLng + xTarget / (METERS_PER_DEGREE * cosRef)
    };
    const camBearing: number = (geom.bearingRad * 180 / Math.PI + 360) % 360;
    const camPos: mapCommon.CameraPosition = {
      target: target,
      zoom: zoom,
      tilt: 0,
      bearing: camBearing
    };
    try {
      const fitUpdate: map.CameraUpdate = map.newCameraPosition(camPos);
      controller.moveCamera(fitUpdate);
      this.drawAnimatedRoute();
    } catch (err) {
      console.error(`RouteDetailPage fitTrackToSheetArea failed: ${JSON.stringify(err)}`);
    }
  }

  /** 用 TraceOverlay 从起点向终点逐段绘制路线，箭头与终点标记跟随绘制进度出现 */
  private drawAnimatedRoute(): void {
    const controller = this.controller;
    const geom = this.routeGeom;
    if (!controller || this.isRouteTraceAdded || !geom || geom.gcjPoints.length < 2) {
      return;
    }
    this.prepareArrowPlan();
    this.addStartMarker();
    const distanceKm: number = this.route?.distanceKm ?? 0;
    const duration: number = Math.min(4000, Math.max(1500, distanceKm * 180));
    const traceOptions: mapCommon.TraceOverlayParams = {
      points: geom.gcjPoints,
      animationDuration: duration,
      width: 12,
      color: 0xFF00A991,
      isMapMoving: false,
      animationCallback: (pointIndex: number) => {
        this.onTraceProgress(pointIndex);
      }
    };
    try {
      controller.addTraceOverlay(traceOptions).then(() => {
        this.isRouteTraceAdded = true;
      }).catch((err: BusinessError) => {
        console.error(`RouteDetailPage addTraceOverlay failed: ${JSON.stringify(err)}`);
        this.fallbackDrawPolyline();
      });
    } catch (err) {
      console.error(`RouteDetailPage addTraceOverlay sync failed: ${JSON.stringify(err)}`);
      this.fallbackDrawPolyline();
    }
  }

  /** 路线绘制进度回调：按当前已绘制的点索引补箭头，绘制完成后显示终点 */
  private onTraceProgress(pointIndex: number): void {
    this.addArrowsUpTo(pointIndex);
    const geom = this.routeGeom;
    if (geom && !this.isEndMarkerAdded && pointIndex >= geom.gcjPoints.length - 1) {
      this.addEndMarker();
    }
  }

  /** 预计算箭头：沿路线每 500m 一个，记录每个箭头对应的点索引 */
  private prepareArrowPlan(): void {
    const geom = this.routeGeom;
    if (!geom || geom.gcjPoints.length < 2) {
      return;
    }
    const gcjPoints: mapCommon.LatLng[] = geom.gcjPoints;
    const plan: ArrowPlan[] = [];
    const INTERVAL_METERS: number = 500;
    let accumulated: number = 0;
    let nextThreshold: number = INTERVAL_METERS;
    for (let i = 1; i < gcjPoints.length; i++) {
      const prev: mapCommon.LatLng = gcjPoints[i - 1];
      const curr: mapCommon.LatLng = gcjPoints[i];
      const dLat: number = curr.latitude - prev.latitude;
      const dLng: number = curr.longitude - prev.longitude;
      const segmentDist: number = Math.sqrt(dLat * dLat + dLng * dLng) * 111320;
      accumulated += segmentDist;
      if (accumulated >= nextThreshold) {
        const bearing: number = Math.atan2(dLng, dLat) * (180 / Math.PI);
        const rotation: number = bearing < 0 ? bearing + 360 : bearing;
        const arrowOptions: mapCommon.MarkerOptions = {
          position: curr,
          icon: 'icon/arrow_direction.svg',
          anchorU: 0.5,
          anchorV: 0.5,
          rotation: rotation,
          visible: true,
          alpha: 0.8,
          flat: true,
          zIndex: 2
        };
        plan.push({ thresholdIndex: i, options: arrowOptions });
        nextThreshold += INTERVAL_METERS;
      }
    }
    this.arrowPlan = plan;
    this.arrowCursor = 0;
  }

  /** 把已绘制到 pointIndex 之前应出现的箭头补上 */
  private addArrowsUpTo(pointIndex: number): void {
    const controller = this.controller;
    if (!controller) {
      return;
    }
    while (this.arrowCursor < this.arrowPlan.length) {
      const plan: ArrowPlan = this.arrowPlan[this.arrowCursor];
      if (plan.thresholdIndex > pointIndex) {
        break;
      }
      try {
        controller.addMarker(plan.options);
      } catch (err) {
        console.error(`RouteDetailPage add arrow marker failed: ${JSON.stringify(err)}`);
      }
      this.arrowCursor++;
    }
  }

  /** TraceOverlay 不可用时的兜底：直接绘制静态折线 + 全部箭头 + 起终点标记 */
  private fallbackDrawPolyline(): void {
    const controller = this.controller;
    const geom = this.routeGeom;
    if (!controller || this.isRouteTraceAdded || !geom || geom.gcjPoints.length < 2) {
      return;
    }
    const polylineOptions: mapCommon.MapPolylineOptions = {
      points: geom.gcjPoints,
      width: 12,
      color: 0xFF00A991,
      jointType: mapCommon.JointType.ROUND,
      startCap: mapCommon.CapStyle.ROUND,
      endCap: mapCommon.CapStyle.ROUND,
      visible: true,
      zIndex: 2
    };
    try {
      controller.addPolyline(polylineOptions).then(() => {
        this.isRouteTraceAdded = true;
      }).catch((err: BusinessError) => {
        console.error(`RouteDetailPage addPolyline failed: ${JSON.stringify(err)}`);
      });
    } catch (err) {
      console.error(`RouteDetailPage addPolyline sync failed: ${JSON.stringify(err)}`);
    }
    this.addStartMarker();
    this.addEndMarker();
    this.addArrowsUpTo(geom.gcjPoints.length);
  }

  private addStartMarker(): void {
    const controller = this.controller;
    const geom = this.routeGeom;
    if (!controller || !geom || geom.gcjPoints.length < 1) {
      return;
    }
    const startOptions: mapCommon.MarkerOptions = {
      position: geom.gcjPoints[0],
      icon: $r('app.media.route_start_marker'),
      anchorU: 0.5,
      anchorV: 1,
      visible: true,
      zIndex: 3
    };
    try {
      controller.addMarker(startOptions);
    } catch (err) {
      console.error(`RouteDetailPage add start marker failed: ${JSON.stringify(err)}`);
    }
  }

  private addEndMarker(): void {
    const controller = this.controller;
    const geom = this.routeGeom;
    if (!controller || this.isEndMarkerAdded || !geom || geom.gcjPoints.length < 2) {
      return;
    }
    const endOptions: mapCommon.MarkerOptions = {
      position: geom.gcjPoints[geom.gcjPoints.length - 1],
      icon: $r('app.media.route_end_marker'),
      anchorU: 0.5,
      anchorV: 1,
      visible: true,
      zIndex: 3
    };
    try {
      controller.addMarker(endOptions).then(() => {
        this.isEndMarkerAdded = true;
      }).catch((err: BusinessError) => {
        console.error(`RouteDetailPage add end marker failed: ${JSON.stringify(err)}`);
      });
    } catch (err) {
      console.error(`RouteDetailPage add end marker sync failed: ${JSON.stringify(err)}`);
    }
  }
}
