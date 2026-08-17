import {
  hdsMaterial,
  HdsNavDestination,
  HdsNavDestinationTitleMode,
  HdsNavigationMenuItemOptions,
  IconStyleMode,
  ScrollEffectType
} from '@kit.UIDesignKit';
import { curves, display, promptAction } from '@kit.ArkUI';
import { map, mapCommon, MapComponent } from '@kit.MapKit';
import { AsyncCallback, BusinessError } from '@kit.BasicServicesKit';
import {
  AppStorageKeys,
  ElevationPoint,
  getDifficultyColor,
  HikingRouteItem,
  KmPaceItem,
  TrackPoint
} from '@ohos/common';

export interface RouteDetailParam {
  route: HikingRouteItem;
  heroHeight?: number;
}

const ROUTE_TITLE_BAR_HEIGHT: number = 56;
const DETAIL_MAP_ZOOM: number = 13;

@Component
struct RouteDetailPage {
  @StorageLink(AppStorageKeys.TOP_INSET) topInset: number = 0;
  @State params: RouteDetailParam | null = null;
  @State pageInfos: NavPathStack = new NavPathStack();
  @State mapOptions?: mapCommon.MapOptions = undefined;
  @State isDetailSheetShown: boolean = true;
  @State sheetHeightVp: number = 0;
  private mapController?: map.MapComponentController = undefined;
  private mapCallback?: AsyncCallback<map.MapComponentController> = undefined;
  private mapReady: boolean = false;
  private isPolylineDrawn: boolean = false;
  private isMarkersAdded: boolean = false;
  private isArrowsAdded: boolean = false;
  private elevationCanvasCtx: CanvasRenderingContext2D =
    new CanvasRenderingContext2D(new RenderingContextSettings(true));
  private stepsCanvasCtx: CanvasRenderingContext2D = new CanvasRenderingContext2D(new RenderingContextSettings(true));
  private floorsCanvasCtx: CanvasRenderingContext2D = new CanvasRenderingContext2D(new RenderingContextSettings(true));
  private deviceHeight: number = 0;
  private trackCenter?: mapCommon.LatLng = undefined;
  private trackBounds?: mapCommon.LatLngBounds = undefined;
  private initialZoomFitted: boolean = false;
  private lastScrollOffsetPx: number = 0;
  private hdsMenuItems: HdsNavigationMenuItemOptions[] = [
    {
      content: {
        icon: $r('sys.symbol.share'),
        type: IconStyleMode.NORMAL,
        isEnabled: true,
        label: 'search',
        action: () => {
        }
      }
    },
    {
      content: {
        icon: $r('sys.symbol.dot_grid_2x2'),
        type: IconStyleMode.NORMAL,
        isEnabled: true,
        label: 'more',
        action: () => {
          promptAction.showToast({ message: $r('app.string.home_more_feature') });
        }
      }
    }
  ];

  aboutToAppear(): void {
    const displayInfo = display.getDefaultDisplaySync();
    const uiContext = this.getUIContext();
    this.deviceHeight = uiContext.px2vp(displayInfo.height);
  }

  private initRouteMap(): void {
    const track: TrackPoint[] = this.params?.route.trackPath ?? [];
    let center: mapCommon.LatLng = { latitude: 29.87, longitude: 121.55 };
    if (track.length >= 2) {
      center = this.convertToMapCoordinate({
        latitude: track[0].latitude,
        longitude: track[0].longitude
      });
    }
    this.mapOptions = {
      mapType: mapCommon.MapType.STANDARD,
      position: {
        target: center,
        zoom: 14,
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
    this.mapCallback = async (err: BusinessError | undefined, controller: map.MapComponentController) => {
      if (err) {
        console.error(`RouteDetailPage map init failed: ${err.message}`);
        return;
      }
      this.mapController = controller;
      this.mapReady = true;
      this.drawRoutePolyline();
      this.addRouteMarkers();
      this.addDirectionArrows();
    };
  }

  private drawRoutePolyline(): void {
    const controller = this.mapController;
    const track: TrackPoint[] = this.params?.route.trackPath ?? [];
    if (!controller || !this.mapReady || this.isPolylineDrawn || track.length < 2) {
      return;
    }
    const gcjPoints: mapCommon.LatLng[] = [];
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
      gcjPoints.push(this.convertToMapCoordinate(p));
    }
    const polylineOptions: mapCommon.MapPolylineOptions = {
      points: gcjPoints,
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
        this.isPolylineDrawn = true;
      }).catch((err: BusinessError) => {
        console.error(`RouteDetailPage addPolyline failed: ${JSON.stringify(err)}`);
      });
    } catch (err) {
      console.error(`RouteDetailPage addPolyline sync failed: ${JSON.stringify(err)}`);
    }
    const ne: mapCommon.LatLng = this.convertToMapCoordinate({ latitude: maxLat, longitude: maxLng });
    const sw: mapCommon.LatLng = this.convertToMapCoordinate({ latitude: minLat, longitude: minLng });
    const centerLat: number = (sw.latitude + ne.latitude) / 2;
    const centerLng: number = (sw.longitude + ne.longitude) / 2;
    this.trackCenter = { latitude: centerLat, longitude: centerLng };
    this.trackBounds = { northeast: ne, southwest: sw };
    this.fitTrackToSheetArea();
  }

  private addRouteMarkers(): void {
    const controller = this.mapController;
    const track: TrackPoint[] = this.params?.route.trackPath ?? [];
    if (!controller || !this.mapReady || this.isMarkersAdded || track.length < 2) {
      return;
    }
    const startPoint: mapCommon.LatLng = this.convertToMapCoordinate(track[0]);
    const endPoint: mapCommon.LatLng = this.convertToMapCoordinate(track[track.length - 1]);
    const startOptions: mapCommon.MarkerOptions = {
      position: startPoint,
      icon: $r('app.media.route_start_marker'),
      anchorU: 0.5,
      anchorV: 1,
      visible: true,
      zIndex: 3
    };
    const endOptions: mapCommon.MarkerOptions = {
      position: endPoint,
      icon: $r('app.media.route_end_marker'),
      anchorU: 0.5,
      anchorV: 1,
      visible: true,
      zIndex: 3
    };
    try {
      controller.addMarker(startOptions).then(() => {
      }).catch((err: BusinessError) => {
        console.error(`RouteDetailPage add start marker failed: ${JSON.stringify(err)}`);
      });
    } catch (err) {
      console.error(`RouteDetailPage add start marker sync failed: ${JSON.stringify(err)}`);
    }
    try {
      controller.addMarker(endOptions).then(() => {
        this.isMarkersAdded = true;
      }).catch((err: BusinessError) => {
        console.error(`RouteDetailPage add end marker failed: ${JSON.stringify(err)}`);
      });
    } catch (err) {
      console.error(`RouteDetailPage add end marker sync failed: ${JSON.stringify(err)}`);
    }
  }

  private addDirectionArrows(): void {
    const controller = this.mapController;
    const track: TrackPoint[] = this.params?.route.trackPath ?? [];
    if (!controller || !this.mapReady || this.isArrowsAdded || track.length < 2) {
      return;
    }
    const gcjPoints: mapCommon.LatLng[] = [];
    for (let i = 0; i < track.length; i++) {
      gcjPoints.push(this.convertToMapCoordinate(track[i]));
    }
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
        try {
          controller.addMarker(arrowOptions);
        } catch (err) {
          console.error(`RouteDetailPage add arrow marker failed: ${JSON.stringify(err)}`);
        }
        nextThreshold += INTERVAL_METERS;
      }
    }
    this.isArrowsAdded = true;
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

  private positionMapLogo(): void {
    const controller = this.mapController;
    if (!controller) {
      return;
    }
    const uiContext = this.getUIContext();
    try {
      controller.setLogoAlignment(mapCommon.LogoAlignment.BOTTOM_START);
      controller.setLogoPadding({
        left: uiContext.vp2px(12),
        bottom: 0
      });
    } catch (err) {
      console.error(`RouteDetailPage set logo position failed: ${JSON.stringify(err)}`);
    }
  }

  private buildDetailSheetOptions(): SheetOptions {
    const minHeight: number = Math.max(220, this.deviceHeight * 0.32);
    return {
      detents: [minHeight, SheetSize.MEDIUM, SheetSize.LARGE],
      detentSelection: SheetSize.MEDIUM,
      preferType: SheetType.BOTTOM,
      dragBar: true,
      showClose: false,
      enableOutsideInteractive: true,
      backgroundColor: $r('sys.color.comp_background_primary'),
      onWillDismiss: (action: DismissSheetAction) => {
        const reason: number = action.reason;
        if (reason === DismissReason.SLIDE || reason === DismissReason.PRESS_BACK) {
          this.pageInfos.pop(false);
          return;
        }
        return;
      },
      onDetentsDidChange: (heightPx: number) => {
        this.onSheetHeightChanged(heightPx);
      },
      onHeightDidChange: (heightPx: number) => {
        this.onSheetHeightChanged(heightPx);
      }
    };
  }

  private onSheetHeightChanged(heightPx: number): void {
    this.sheetHeightVp = this.getUIContext().px2vp(heightPx);
    if (!this.initialZoomFitted) {
      this.fitTrackToSheetArea();
    } else {
      this.updateMapPadding();
    }
  }

  private updateMapPadding(): void {
    const controller = this.mapController;
    if (!controller || !this.trackCenter) {
      return;
    }
    const uiContext = this.getUIContext();
    const topOffsetPx: number = uiContext.vp2px(this.topInset);
    const bottomOffsetPx: number = uiContext.vp2px(this.sheetHeightVp);
    const targetScrollPx: number = Math.floor((bottomOffsetPx - topOffsetPx) / 2);
    const deltaPx: number = targetScrollPx - this.lastScrollOffsetPx;
    if (deltaPx === 0) {
      return;
    }
    try {
      const cameraUpdate: map.CameraUpdate = map.scrollBy(0, deltaPx);
      controller.moveCamera(cameraUpdate);
      this.lastScrollOffsetPx = targetScrollPx;
    } catch (err) {
      console.error(`RouteDetailPage updateMapPadding failed: ${JSON.stringify(err)}`);
    }
  }

  private fitTrackToSheetArea(): void {
    const controller = this.mapController;
    if (!controller || !this.trackCenter) {
      return;
    }
    const uiContext = this.getUIContext();
    const topOffsetPx: number = uiContext.vp2px(this.topInset);
    const bottomOffsetPx: number = uiContext.vp2px(this.sheetHeightVp);
    try {
      const cameraUpdate: map.CameraUpdate = map.newLatLng(this.trackCenter, DETAIL_MAP_ZOOM);
      controller.moveCamera(cameraUpdate);
      const targetScrollPx: number = Math.floor((bottomOffsetPx - topOffsetPx) / 2);
      const scrollUpdate: map.CameraUpdate = map.scrollBy(0, targetScrollPx);
      controller.moveCamera(scrollUpdate);
      this.lastScrollOffsetPx = targetScrollPx;
      this.initialZoomFitted = true;
    } catch (err) {
      console.error(`RouteDetailPage fitTrackToSheetArea failed: ${JSON.stringify(err)}`);
    }
  }

  build() {
    HdsNavDestination() {
      Stack({ alignContent: Alignment.Bottom }) {
        if (this.mapOptions && this.mapCallback) {
          MapComponent({ mapOptions: this.mapOptions, mapCallback: this.mapCallback })
            .width('100%')
            .height('100%')
        } else {
          Column() {
            LoadingProgress()
              .width(32)
              .height(32)
              .color($r('app.color.brand_green'))
          }
          .width('100%')
          .height('100%')
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
          .backgroundColor($r('sys.color.background_secondary'))
        }
      }
      .width('100%')
      .height('100%')
      .bindSheet(this.isDetailSheetShown, this.buildDetailSheet(), this.buildDetailSheetOptions())
    }
    .titleBar({
      avoidLayoutSafeArea: false,
      content: {
        title: { mainTitle: '' },
        menu: { value: this.hdsMenuItems }
      },
      style: {
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
      }
    })
    .titleMode(HdsNavDestinationTitleMode.MINI)
    .hideTitleBar(false)
    .backgroundColor($r('app.color.start_window_background'))
    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
    .width('100%')
    .height('100%')
    .onReady((ctx: NavDestinationContext) => {
      this.pageInfos = ctx.pathStack;
      const param = ctx.pathInfo.param as RouteDetailParam;
      if (param) {
        this.params = param;
        this.sheetHeightVp = this.deviceHeight * 0.5;
        this.initRouteMap();
      }
    })
    .onBackPressed(() => {
      this.isDetailSheetShown = false;
      this.getUIContext().animateTo({
        duration: 300,
        curve: curves.interpolatingSpring(0, 1, 273, 33)
      }, () => {
        this.pageInfos.pop(false);
      });
      return true;
    })
  }

  @Builder
  buildDetailSheet() {
    Column({ space: 0 }) {
      if (this.params) {
        this.buildSheetHeader()
        this.buildRouteInfo()
        this.buildStatsRow()
        this.buildDetailContent()
        this.buildElevationProfile()
        this.buildStepsSection()
        this.buildKmPaceTable()
        this.buildTips()
      }
    }
    .width('100%')
  }

  @Builder
  buildSheetHeader() {
    Column() {
      Text(this.params!.route.name)
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('sys.color.font_primary'))
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
    }
    .width('100%')
    .padding({
      left: 20,
      right: 20,
      top: 8,
      bottom: 4
    })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  buildRouteInfo() {
    Row({ space: 8 }) {
      Text(this.params!.route.difficulty)
        .fontSize(13)
        .fontColor($r('sys.color.font_on_primary'))
        .fontWeight(FontWeight.Bold)
        .padding({
          left: 12,
          right: 12,
          top: 6,
          bottom: 6
        })
        .borderRadius(16)
        .border({ width: 1, color: getDifficultyColor(this.params!.route.difficulty) })
        .backgroundColor(getDifficultyColor(this.params!.route.difficulty))
        .backgroundBlurStyle(BlurStyle.Thin, { colorMode: ThemeColorMode.SYSTEM })

      Text(this.params!.route.altitudeRange)
        .fontSize(13)
        .fontColor($r('sys.color.font_secondary'))
        .fontWeight(FontWeight.Medium)
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 8 })
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  buildStatsRow() {
    Row({ space: 24 }) {
      Column({ space: 4 }) {
        SymbolGlyph($r('sys.symbol.route'))
          .fontSize(20)
          .fontColor([$r('sys.color.icon_secondary')])
        Text(`${this.params!.route.distanceKm}km`)
          .fontSize(16)
          .fontColor($r('sys.color.font_primary'))
          .fontWeight(FontWeight.Bold)
        Text($r('app.string.route_distance'))
          .fontSize(12)
          .fontColor($r('sys.color.font_tertiary'))
      }
      .alignItems(HorizontalAlign.Center)

      Column({ space: 4 }) {
        SymbolGlyph($r('sys.symbol.clock_fill'))
          .fontSize(20)
          .fontColor([$r('sys.color.icon_secondary')])
        Text(this.params!.route.durationDisplay)
          .fontSize(16)
          .fontColor($r('sys.color.font_primary'))
          .fontWeight(FontWeight.Bold)
        Text($r('app.string.route_duration'))
          .fontSize(12)
          .fontColor($r('sys.color.font_tertiary'))
      }
      .alignItems(HorizontalAlign.Center)

      Column({ space: 4 }) {
        SymbolGlyph($r('sys.symbol.arrow_up_circle_fill'))
          .fontSize(20)
          .fontColor([$r('sys.color.icon_secondary')])
        Text(`↑${this.params!.route.elevationGainMeters}m`)
          .fontSize(16)
          .fontColor($r('sys.color.font_primary'))
          .fontWeight(FontWeight.Bold)
        Text($r('app.string.route_climb'))
          .fontSize(12)
          .fontColor($r('sys.color.font_tertiary'))
      }
      .alignItems(HorizontalAlign.Center)

      Column({ space: 4 }) {
        SymbolGlyph($r('sys.symbol.arrow_down'))
          .fontSize(20)
          .fontColor([$r('sys.color.icon_secondary')])
        Text(`↓${this.params!.route.elevationLossMeters}m`)
          .fontSize(16)
          .fontColor($r('sys.color.font_primary'))
          .fontWeight(FontWeight.Bold)
        Text($r('app.string.route_descent'))
          .fontSize(12)
          .fontColor($r('sys.color.font_tertiary'))
      }
      .alignItems(HorizontalAlign.Center)
    }
    .width('100%')
    .justifyContent(FlexAlign.SpaceAround)
    .padding({
      left: 20,
      right: 20,
      top: 20,
      bottom: 16
    })
    .borderRadius(16)
    .backgroundColor($r('sys.color.comp_background_tertiary'))
    .margin({ left: 16, right: 16, top: 8 })
  }

  @Builder
  buildDetailContent() {
    Column({ space: 12 }) {
      Text($r('app.string.route_detail_title'))
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('sys.color.font_primary'))

      Row({ space: 12 }) {
        Row({ space: 6 }) {
          SymbolGlyph($r('sys.symbol.local_fill'))
            .fontSize(16)
            .fontColor([$r('sys.color.icon_secondary')])
          Text(this.params!.route.address)
            .fontSize(14)
            .fontColor($r('sys.color.font_secondary'))
            .layoutWeight(1)
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .width('100%')
        .alignItems(VerticalAlign.Top)
      }

      Row({ space: 12 }) {
        Row({ space: 6 }) {
          SymbolGlyph($r('sys.symbol.clock_fill'))
            .fontSize(16)
            .fontColor([$r('sys.color.icon_secondary')])
          Text(`平均配速 ${this.params!.route.avgPaceMinPerKm.toFixed(1)} 分钟/km`)
            .fontSize(14)
            .fontColor($r('sys.color.font_secondary'))
        }
      }

      Row({ space: 12 }) {
        Row({ space: 6 }) {
          SymbolGlyph($r('sys.symbol.flag_fill'))
            .fontSize(16)
            .fontColor([$r('sys.color.icon_secondary')])
          Text(`途经 ${this.params!.route.waypointCount} 个路点`)
            .fontSize(14)
            .fontColor($r('sys.color.font_secondary'))
        }
      }
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 20 })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  buildTips() {
    Column({ space: 12 }) {
      Text($r('app.string.route_tips'))
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('sys.color.font_primary'))

      Text(this.params!.route.noticeTips)
        .fontSize(14)
        .lineHeight(24)
        .fontColor($r('sys.color.font_secondary'))
        .width('100%')
    }
    .width('100%')
    .padding({
      left: 20,
      right: 20,
      top: 16,
      bottom: 40
    })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  buildElevationProfile() {
    if ((this.params!.route.elevationProfile ?? []).length >= 2) {
      Column({ space: 12 }) {
        Text($r('app.string.route_elevation_profile'))
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('sys.color.font_primary'))

        Canvas(this.elevationCanvasCtx)
          .width('100%')
          .height(120)
          .borderRadius(10)
          .onReady(() => {
            const profile = this.params!.route.elevationProfile!;
            const minAlt = this.params!.route.minAltitudeMeters;
            const maxAlt = this.params!.route.maxAltitudeMeters;
            const altRange = maxAlt - minAlt > 0 ? maxAlt - minAlt : 1;
            const totalDist = profile[profile.length - 1].distanceKm;
            this.drawElevationChart(profile, minAlt, altRange, totalDist);
          })

        Row() {
          Text(`${this.params!.route.minAltitudeMeters}m`)
            .fontSize(11)
            .fontColor($r('sys.color.font_tertiary'))
          Blank()
          Text(`最高 ${this.params!.route.maxAltitudeMeters}m`)
            .fontSize(11)
            .fontColor($r('sys.color.font_tertiary'))
        }
        .width('100%')
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 16 })
      .alignItems(HorizontalAlign.Start)
    }
  }

  private drawElevationChart(profile: ElevationPoint[], minAlt: number, altRange: number, totalDist: number): void {
    const ctx = this.elevationCanvasCtx;
    const w = ctx.width;
    const h = ctx.height;
    ctx.clearRect(0, 0, w, h);

    const toX = (d: number): number => (d / totalDist) * w;
    const toY = (a: number): number => h - ((a - minAlt) / altRange) * (h - 8) - 4;

    const grad = ctx.createLinearGradient(0, 0, 0, h);
    grad.addColorStop(0, 'rgba(52,199,89,0.45)');
    grad.addColorStop(1, 'rgba(52,199,89,0.04)');
    ctx.fillStyle = grad;
    ctx.beginPath();
    ctx.moveTo(toX(profile[0].distanceKm), toY(profile[0].altitudeMeters));
    for (let i = 1; i < profile.length; i++) {
      ctx.lineTo(toX(profile[i].distanceKm), toY(profile[i].altitudeMeters));
    }
    ctx.lineTo(toX(profile[profile.length - 1].distanceKm), h);
    ctx.lineTo(toX(profile[0].distanceKm), h);
    ctx.closePath();
    ctx.fill();

    ctx.strokeStyle = '#34C759';
    ctx.lineWidth = 2;
    ctx.beginPath();
    ctx.moveTo(toX(profile[0].distanceKm), toY(profile[0].altitudeMeters));
    for (let i = 1; i < profile.length; i++) {
      ctx.lineTo(toX(profile[i].distanceKm), toY(profile[i].altitudeMeters));
    }
    ctx.stroke();
  }

  @Builder
  buildStepsSection() {
    if ((this.params!.route.totalSteps ?? 0) > 0) {
      Column({ space: 12 }) {
        Text($r('app.string.route_steps_section'))
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('sys.color.font_primary'))

        Row({ space: 24 }) {
          Column({ space: 8 }) {
            Stack() {
              Canvas(this.stepsCanvasCtx)
                .width(96)
                .height(96)
                .onReady(() => {
                  this.drawStepsRing(this.stepsCanvasCtx, this.params!.route.totalSteps!, 15000);
                })
              Column({ space: 2 }) {
                Text(`${this.params!.route.totalSteps!}`)
                  .fontSize(18)
                  .fontWeight(FontWeight.Bold)
                  .fontColor($r('sys.color.font_primary'))
                Text($r('app.string.route_steps_unit'))
                  .fontSize(11)
                  .fontColor($r('sys.color.font_tertiary'))
              }
            }
            .width(96)
            .height(96)
            .alignContent(Alignment.Center)

            Text($r('app.string.route_steps_label'))
              .fontSize(13)
              .fontColor($r('sys.color.font_secondary'))
          }
          .alignItems(HorizontalAlign.Center)

          Column({ space: 8 }) {
            Stack() {
              Canvas(this.floorsCanvasCtx)
                .width(96)
                .height(96)
                .onReady(() => {
                  this.drawStepsRing(this.floorsCanvasCtx, this.params!.route.floorsClimbed ?? 0, 30);
                })
              Column({ space: 2 }) {
                Text(`${this.params!.route.floorsClimbed ?? 0}`)
                  .fontSize(18)
                  .fontWeight(FontWeight.Bold)
                  .fontColor($r('sys.color.font_primary'))
                Text($r('app.string.route_floors_unit'))
                  .fontSize(11)
                  .fontColor($r('sys.color.font_tertiary'))
              }
            }
            .width(96)
            .height(96)
            .alignContent(Alignment.Center)

            Text($r('app.string.route_floors_label'))
              .fontSize(13)
              .fontColor($r('sys.color.font_secondary'))
          }
          .alignItems(HorizontalAlign.Center)
        }
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 16 })
      .alignItems(HorizontalAlign.Start)
    }
  }

  private drawStepsRing(ctx: CanvasRenderingContext2D, value: number, max: number): void {
    const size = 96;
    const cx = size / 2;
    const cy = size / 2;
    const r = 38;
    const lw = 8;
    const ratio = Math.min(value / max, 1);

    ctx.clearRect(0, 0, size, size);

    ctx.strokeStyle = 'rgba(52,199,89,0.15)';
    ctx.lineWidth = lw;
    ctx.beginPath();
    ctx.arc(cx, cy, r, 0, Math.PI * 2);
    ctx.stroke();

    ctx.strokeStyle = '#34C759';
    ctx.lineWidth = lw;
    ctx.lineCap = 'round';
    ctx.beginPath();
    ctx.arc(cx, cy, r, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * ratio);
    ctx.stroke();
  }

  @Builder
  buildKmPaceTable() {
    if ((this.params!.route.kmPaceList ?? []).length > 0) {
      Column({ space: 12 }) {
        Text($r('app.string.route_km_pace'))
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('sys.color.font_primary'))

        Column({ space: 0 }) {
          Row() {
            Text($r('app.string.route_km_label'))
              .fontSize(12)
              .fontColor($r('sys.color.font_tertiary'))
              .width(48)
              .textAlign(TextAlign.Center)
            Text($r('app.string.route_pace_label'))
              .fontSize(12)
              .fontColor($r('sys.color.font_tertiary'))
              .layoutWeight(1)
              .textAlign(TextAlign.Center)
            Text('爬升')
              .fontSize(12)
              .fontColor($r('sys.color.font_tertiary'))
              .width(52)
              .textAlign(TextAlign.Center)
            Text('下降')
              .fontSize(12)
              .fontColor($r('sys.color.font_tertiary'))
              .width(52)
              .textAlign(TextAlign.Center)
          }
          .width('100%')
          .padding({
            top: 8,
            bottom: 8,
            left: 4,
            right: 4
          })
          .backgroundColor($r('sys.color.comp_background_tertiary'))
          .borderRadius({ topLeft: 10, topRight: 10 })

          ForEach(this.params!.route.kmPaceList!, (item: KmPaceItem, index: number) => {
            Row() {
              Text(`${item.km}`)
                .fontSize(14)
                .fontColor($r('sys.color.font_primary'))
                .fontWeight(FontWeight.Medium)
                .width(48)
                .textAlign(TextAlign.Center)

              Row({ space: 6 }) {
                Row()
                  .height(6)
                  .borderRadius(3)
                  .layoutWeight(item.paceMinPerKm / 25)
                  .backgroundColor('#34C759')
                Text(`${item.paceMinPerKm.toFixed(1)}'`)
                  .fontSize(13)
                  .fontColor($r('sys.color.font_secondary'))
              }
              .layoutWeight(1)
              .padding({ left: 8, right: 8 })
              .alignItems(VerticalAlign.Center)

              Text(`↑${item.elevationGainMeters}m`)
                .fontSize(13)
                .fontColor('#FF6B35')
                .width(52)
                .textAlign(TextAlign.Center)

              Text(`↓${item.elevationLossMeters}m`)
                .fontSize(13)
                .fontColor('#4A9EFF')
                .width(52)
                .textAlign(TextAlign.Center)
            }
            .width('100%')
            .padding({
              top: 10,
              bottom: 10,
              left: 4,
              right: 4
            })
            .backgroundColor(index % 2 === 0
              ? $r('app.color.start_window_background')
              : $r('sys.color.comp_background_tertiary'))
          }, (item: KmPaceItem) => `km_${item.km}`)
        }
        .width('100%')
        .borderRadius(10)
        .clip(true)
        .border({ width: 1, color: 'rgba(0,0,0,0.06)' })
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 16 })
      .alignItems(HorizontalAlign.Start)
    }
  }
}

@Builder
export function RouteDetailPageBuilder() {
  RouteDetailPage();
}
