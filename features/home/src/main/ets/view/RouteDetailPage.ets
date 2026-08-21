import {
  hdsMaterial, HdsNavDestination, HdsNavDestinationTitleMode, HdsNavigationMenuItemOptions, IconStyleMode, ScrollEffectType
} from '@kit.UIDesignKit';
import { curves, display, promptAction } from '@kit.ArkUI';
import { map, mapCommon, MapComponent } from '@kit.MapKit';
import { AsyncCallback } from '@kit.BasicServicesKit';
import { AppStorageKeys, HikingRouteItem } from '@ohos/common';
import { RouteMapHelper } from './RouteMapHelper';
import { RouteDetailSheet } from './RouteDetailSheet';

export interface RouteDetailParam {
  route: HikingRouteItem;
  heroHeight?: number;
}

function createDefaultRouteDetailParam(): RouteDetailParam {
  const defaultRoute: HikingRouteItem = {
    id: '',
    name: '',
    district: '',
    address: '',
    trackType: '',
    difficulty: '',
    distanceKm: 0,
    durationDisplay: '',
    elevationGainMeters: 0,
    elevationLossMeters: 0,
    maxAltitudeMeters: 0,
    minAltitudeMeters: 0,
    altitudeRange: '',
    avgPaceMinPerKm: 0,
    noticeTips: '',
    photos: [],
    videoUrl: '',
    waypointCount: 0
  };
  return { route: defaultRoute };
}

@Component
struct RouteDetailPage {
  @StorageLink(AppStorageKeys.TOP_INSET) topInset: number = 0;
  @State params: RouteDetailParam = createDefaultRouteDetailParam();
  @State pageInfos: NavPathStack = new NavPathStack();
  @State mapOptions: mapCommon.MapOptions | undefined = undefined;
  @State isDetailSheetShown: boolean = true;
  @State sheetHeightVp: number = 0;
  private mapCallback?: AsyncCallback<map.MapComponentController>;
  private routeMapHelper?: RouteMapHelper;
  private deviceHeight: number = 0;
  private deviceWidthVp: number = 0;
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
    this.deviceWidthVp = uiContext.px2vp(displayInfo.width);
    this.routeMapHelper = new RouteMapHelper(uiContext);
  }

  private initRouteMap(): void {
    if (!this.routeMapHelper || !this.params.route.id) {
      return;
    }
    this.routeMapHelper.configure(
      this.params.route,
      this.topInset,
      this.deviceHeight,
      this.deviceWidthVp
    );
    this.mapOptions = this.routeMapHelper.buildMapOptions();
    this.mapCallback = this.routeMapHelper.buildMapCallback();
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
      backgroundColor: $r('sys.color.background_secondary'),
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
    this.routeMapHelper?.onSheetHeightChanged(this.sheetHeightVp);
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

        if (this.isDetailSheetShown && this.sheetHeightVp > 0) {
          Column()
            .width('100%')
            .height(this.sheetHeightVp)
            .hitTestBehavior(HitTestMode.Block)
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
      RouteDetailSheet({ route: this.params.route })
    }
    .width('100%')
    .padding({ left: 16, right: 16 })
  }
}

@Builder
export function RouteDetailPageBuilder() {
  RouteDetailPage();
}
