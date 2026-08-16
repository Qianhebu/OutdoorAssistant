import {
  hdsMaterial,
  HdsNavDestination,
  HdsNavDestinationTitleMode,
  HdsNavigationMenuItemOptions,
  IconStyleMode,
  ScrollEffectType
} from '@kit.UIDesignKit';
import { AppStorageKeys } from '@ohos/common';
import { PageEnum } from '@ohos/common';
import { StorageKey } from '@ohos/common';
import { PageContext } from '@ohos/common';
import { Chip, ChipSize, curves, display, LengthMetrics, promptAction, SymbolGlyphModifier } from '@kit.ArkUI';
import { image } from '@kit.ImageKit';
import { abilityAccessCtrl, common, PermissionRequestResult, Permissions } from '@kit.AbilityKit';
import { geoLocationManager } from '@kit.LocationKit';
import {
  getCardAccentColor,
  getCardSubColor,
  getDifficultyColor,
  HikingRouteItem
} from '@ohos/common';
import { BusinessError } from '@kit.BasicServicesKit';
import { fetchHikingRoutes } from '@ohos/common';
import { fetchHomeBanners, HomeBanner } from '@ohos/common';
import { RouteDetailParam } from './RouteDetailPage';
import { BannerDetailParam } from './BannerDetailPage';
import { updateStatusBarContentColor } from '@ohos/common';
import { saveCurrentLocation } from '@ohos/common';

/** 城市选择页面传参 */
interface CitySelectParam {
  currentCity: string;
}

/** 状态栏内容颜色切换阈值：滚动偏移小于此值时使用白色（banner 区域），否则黑色 */
const STATUS_BAR_LIGHT_THRESHOLD: number = 140;
/** Banner 进度条最大值，对应自动切换间隔 */
const BANNER_PROGRESS_VALUE_MAX: number = 2300;
/** Banner 进度条帧间隔（30fps） */
const BANNER_PROGRESS_FRAME_TIME: number = 1000 / 30;
/** 触摸结束后延迟恢复轮播的时间 */
const BANNER_PROGRESS_RESTART_DELAY: number = 50;
/** Banner 内容文字区域高度，用于计算导航栏模糊效果偏移 */
const BANNER_CONTENT_HEIGHT: number = 160;
/** 导航栏高度 */
const NAVIGATION_HEIGHT: number = 56;
/** Banner 下拉弹性拉伸缩放因子 */
const BANNER_SCALE_FACTOR: number = 2;

@Component
struct HomeListView {
  // ===== 全局安全区域 =====
  /** 顶部安全区高度（状态栏） */
  @StorageLink(AppStorageKeys.TOP_INSET) topInset: number = 0;
  /** 底部安全区高度（Home 指示条） */
  @StorageLink(AppStorageKeys.BOTTOM_INSET) bottomInset: number = 0;
  // ===== 页面路由 =====
  /** 首页 Navigation 上下文，用于页面跳转 */
  @StorageLink(StorageKey.HOME_PAGE_CONTEXT) appPageContext: PageContext =
    AppStorage.get<PageContext>(StorageKey.HOME_PAGE_CONTEXT) ?? new PageContext();
  /** 城市选择页回传的选中城市，@Watch 监听后更新 currentCity */
  @StorageLink('selectedCity') @Watch('onCitySelected') selectedCity: string = '';
  // ===== 城市定位 =====
  /** 当前显示的城市名 */
  @State currentCity: string = '定位中...';
  // ===== Banner 轮播 =====
  /** 当前轮播索引 */
  @State currentBannerIndex: number = 0;
  /** 当前轮播进度值，驱动底部进度条动画 */
  @State currentProgressValue: number = 0;
  /** Banner 当前高度（受下拉拉伸影响） */
  @State bannerHeight: number = 0;
  /** Banner 列表数据（通过接口加载） */
  @State banners: HomeBanner[] = [];
  // ===== 徒步路线列表 =====
  /** 当前已展示的路线数据（分页追加） */
  @State displayedRoutes: HikingRouteItem[] = [];
  /** 是否正在加载更多 */
  @State routesLoadingMore: boolean = false;
  /** 是否已全部加载 */
  @State routesAllLoaded: boolean = false;
  /** 路线卡片图片高度（根据屏幕宽度计算） */
  @State cardImageHeight: number = 0;
  // ===== 私有辅助属性 =====
  /** 路线列表每页加载条数 */
  private routesPageSize: number = 8;
  /** 路线列表当前页码 */
  private routesCurrentPage: number = 0;
  /** 路线列表加载更多防抖定时器 */
  private routesLoadingTimer: number = -1;
  /** Banner 原始高度（下拉拉伸恢复基准） */
  private originBannerHeight: number = 0;
  /** 当前滚动状态，用于判断下拉拉伸/回弹 */
  private currentScrollState: ScrollState = ScrollState.Idle;
  /** 是否正在执行 Banner 回弹动画 */
  private isBannerSpringing: boolean = false;
  /** Swiper 控制器 */
  private bannerController: SwiperController = new SwiperController();
  /** 轮播进度定时器 ID */
  private bannerProgressIntervalId: number = -1;
  /** 延迟恢复轮播定时器 */
  private bannerProgressTimer?: number;
  /** 定位权限列表 */
  private locationPermissions: Array<Permissions> =
    ['ohos.permission.APPROXIMATELY_LOCATION', 'ohos.permission.LOCATION'];
  /** HDS 导航栏菜单项（搜索 + 更多） */
  private hdsMenuItems: HdsNavigationMenuItemOptions[] = [
    {
      content: {
        icon: $r('sys.symbol.magnifyingglass'),
        type: IconStyleMode.NORMAL,
        isEnabled: true,
        label: 'search',
        action: () => {
          this.navigateToSearch();
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
          promptAction.showToast({ message: '更多功能' });
        }
      }
    }
  ];
  /** 主列表滚动控制器 */
  scroller: Scroller = new Scroller();

  /** 跳转到搜索页 */
  private navigateToSearch(): void {
    this.appPageContext.openPage({ routerName: PageEnum.SEARCH_PAGE });
  }

  /** 城市选择页回传监听：更新当前城市 */
  private onCitySelected(): void {
    if (this.selectedCity && this.selectedCity.length > 0) {
      this.currentCity = this.selectedCity;
      this.selectedCity = '';
    }
  }

  /** 请求定位权限，授权后定位当前城市 */
  private async requestLocationPermission(): Promise<void> {
    try {
      const atManager: abilityAccessCtrl.AtManager = abilityAccessCtrl.createAtManager();
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const result: PermissionRequestResult =
        await atManager.requestPermissionsFromUser(context, this.locationPermissions);
      const granted = result.authResults.every((status: number) => status === 0);
      if (granted) {
        this.locateCurrentCity();
      } else {
        this.currentCity = '定位失败';
      }
    } catch (err) {
      this.currentCity = '定位失败';
      console.error(`Request location permission failed: ${JSON.stringify(err)}`);
    }
  }

  /** 定位当前城市：先读缓存，再请求实时位置 */
  private locateCurrentCity(): void {
    this.tryCachedLocation();
    this.requestFreshLocation();
  }

  /** 尝试使用缓存位置 */
  private tryCachedLocation(): void {
    try {
      const location = geoLocationManager.getLastLocation();
      if (location) {
        saveCurrentLocation(location.latitude, location.longitude);
        this.reverseGeocode(location.latitude, location.longitude);
      }
    } catch (err) {
      console.info(`No cached location: ${JSON.stringify(err)}`);
    }
  }

  /** 请求实时位置并逆地理编码 */
  private requestFreshLocation(): void {
    const request: geoLocationManager.SingleLocationRequest = {
      locatingPriority: 0x502,
      locatingTimeoutMs: 10000
    };
    geoLocationManager.getCurrentLocation(request).then((location: geoLocationManager.Location) => {
      saveCurrentLocation(location.latitude, location.longitude);
      this.reverseGeocode(location.latitude, location.longitude);
    }).catch((err: BusinessError) => {
      if (this.currentCity === '定位中...') {
        this.currentCity = '定位失败';
      }
      console.error(`Get current location failed: ${JSON.stringify(err)}`);
    });
  }

  /** 逆地理编码：经纬度 → 城市名 */
  private reverseGeocode(latitude: number, longitude: number): void {
    const reverseRequest: geoLocationManager.ReverseGeoCodeRequest = {
      latitude: latitude,
      longitude: longitude,
      maxItems: 1
    };
    geoLocationManager.getAddressesFromLocation(reverseRequest).then((data: geoLocationManager.GeoAddress[]) => {
      if (data && data.length > 0 && data[0].locality && data[0].locality.length > 0) {
        this.currentCity = this.stripCitySuffix(data[0].locality!);
      } else if (this.currentCity === '定位中...') {
        this.currentCity = '定位失败';
      }
    }).catch((err: BusinessError) => {
      if (this.currentCity === '定位中...') {
        this.currentCity = '定位失败';
      }
      console.error(`Reverse geocode failed: ${JSON.stringify(err)}`);
    });
  }

  /** 去除城市名后缀（市、自治区等），只保留简短名称 */
  private stripCitySuffix(city: string): string {
    return city.replace(/(市|自治区|特别行政区|自治州|地区|盟)$/, '');
  }

  /** 初始化 Banner 高度和卡片图片高度（根据屏幕尺寸） */
  private initBannerHeight(): void {
    const uiContext: UIContext = this.getUIContext();
    const displayInfo = display.getDefaultDisplaySync();
    const deviceWidth = uiContext.px2vp(displayInfo.width);
    this.bannerHeight = deviceWidth * 1.28;
    this.originBannerHeight = this.bannerHeight;
    this.cardImageHeight = (deviceWidth - 24) / 1.5;
  }

  /** 滚动时处理：切换状态栏颜色（回弹由 calculateBannerHeight/onScrollStop 触发） */
  private handleHomeScroll(): void {
    const offset = this.scroller.currentOffset();
    const yOffset = offset?.yOffset ?? 0;
    updateStatusBarContentColor(yOffset < STATUS_BAR_LIGHT_THRESHOLD);
  }

  /**
   * 计算下拉拉伸时 Banner 高度变化
   *
   * 在 onScrollFrameBegin 中调用，返回 true 表示消费了本次滚动（offsetRemain=0）
   * - 下拉时：Banner 高度按 BANNER_SCALE_FACTOR 缩放增加
   * - 上滑且 Banner 超过原始高度时：逐步恢复
   * - 回弹时：弹簧动画恢复原始高度
   */
  private calculateBannerHeight(offset: number, state: ScrollState, yOffset: number): boolean {
    if (yOffset > 0) {
      return false;
    }
    if (state === ScrollState.Scroll && offset !== 0) {
      this.currentScrollState = ScrollState.Scroll;
      this.isBannerSpringing = false;
      const currentBannerHeight: number = this.bannerHeight - offset;
      if (currentBannerHeight < this.originBannerHeight) {
        this.bannerHeight = this.originBannerHeight;
        return false;
      }
      const bannerOffset: number = -(offset / BANNER_SCALE_FACTOR);
      this.bannerHeight += bannerOffset;
      return true;
    } else if (this.currentScrollState === ScrollState.Scroll &&
      (state === ScrollState.Fling || state === ScrollState.Idle) &&
      !this.isBannerSpringing) {
      this.bannerSpringBack();
      return true;
    }
    return false;
  }

  /** Banner 高度弹簧回弹到原始高度 */
  private bannerSpringBack(): void {
    this.currentScrollState = ScrollState.Fling;
    this.isBannerSpringing = true;
    this.getUIContext().animateTo({
      curve: Curve.EaseOut,
      duration: 250,
      onFinish: () => {
        this.isBannerSpringing = false;
        this.currentScrollState = ScrollState.Idle;
      }
    }, () => {
      this.bannerHeight = this.originBannerHeight;
    });
    // 回弹动画完成后回到 Banner 顶部区域，同步状态栏为白色
    updateStatusBarContentColor(true);
  }

  /** 根据滚动位置切换状态栏文字颜色（Banner 区域白色，列表区域按主题色） */

  // ==================== Banner 轮播进度 ====================

  /** 重启轮播进度条：清零并开始计时，达到最大值后自动切换下一张 */
  private restartBannerProgress(): void {
    this.currentProgressValue = 0;
    clearInterval(this.bannerProgressIntervalId);
    this.bannerProgressIntervalId = setInterval(() => {
      this.currentProgressValue += BANNER_PROGRESS_FRAME_TIME;
      if (this.currentProgressValue >= BANNER_PROGRESS_VALUE_MAX) {
        clearInterval(this.bannerProgressIntervalId);
      }
    }, BANNER_PROGRESS_FRAME_TIME);
  }

  /** 停止轮播进度条（用户触摸时调用） */
  private stopBannerProgress(): void {
    clearInterval(this.bannerProgressIntervalId);
  }

  /** 延迟恢复轮播进度条（用户手指抬起后延迟调用，避免触摸和自动切换冲突） */
  private delayRestartBannerProgress(): void {
    if (this.bannerProgressTimer) {
      clearTimeout(this.bannerProgressTimer);
    }
    this.bannerProgressTimer = setTimeout(() => {
      this.restartBannerProgress();
    }, BANNER_PROGRESS_RESTART_DELAY);
  }

  /** 跳转 Banner 详情页 */
  private navigateToBannerDetail(banner: HomeBanner): void {
    const param: BannerDetailParam = {
      id: banner.id,
      title: banner.title,
      subTitle: banner.subTitle,
      desc: banner.desc,
      themeColor: banner.themeColor,
      mediaUrl: banner.mediaUrl,
      content: banner.content
    };
    this.appPageContext.navPathStack.pushPath(new NavPathInfo(PageEnum.BANNER_DETAIL, param), false);
  }

  /** 跳转路线详情页，使用弹簧曲线转场动画 */
  private async navigateToRouteDetail(route: HikingRouteItem): Promise<void> {
    let heroHeight: number = 0;
    if (route.photos.length > 0) {
      heroHeight = await this.resolvePhotoHeroHeight(route.photos[0]);
    }
    const param: RouteDetailParam = {
      route: route,
      heroHeight: heroHeight
    };
    this.getUIContext().animateTo({
      duration: 500,
      curve: curves.interpolatingSpring(0, 1, 273, 33)
    }, () => {
      this.appPageContext.navPathStack.pushPath(new NavPathInfo(PageEnum.ROUTE_DETAIL, param), false);
    });
  }

  /** 解析首图真实宽高比对应的全屏高度（vp），供详情页 hero 在转场开始时即锁定目标帧 */
  private async resolvePhotoHeroHeight(photoPath: string): Promise<number> {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    let source: image.ImageSource | undefined = undefined;
    try {
      const rawContent = context.resourceManager.getRawFileContentSync(photoPath);
      const buffer: ArrayBuffer = rawContent.buffer.slice(rawContent.byteOffset,
        rawContent.byteOffset + rawContent.byteLength);
      source = image.createImageSource(buffer);
      const info: image.ImageInfo = await source.getImageInfo();
      if (!info || !info.size || info.size.width <= 0 || info.size.height <= 0) {
        return 0;
      }
      const displayInfo = display.getDefaultDisplaySync();
      const uiContext = this.getUIContext();
      const deviceWidthVp: number = uiContext.px2vp(displayInfo.width);
      return deviceWidthVp * info.size.height / info.size.width;
    } catch (err) {
      return 0;
    } finally {
      if (source !== undefined) {
        try {
          await source.release();
        } catch (err) {
        }
      }
    }
  }

  /** 通过接口分页加载更多路线数据 */
  private loadMoreRoutes(): void {
    if (this.routesAllLoaded || this.routesLoadingMore) {
      return
    }
    this.routesLoadingMore = true
    const nextPage = this.routesCurrentPage + 1
    fetchHikingRoutes(nextPage, this.routesPageSize).then((response) => {
      if (response.code === 0 && response.data && response.data.routes) {
        this.displayedRoutes.push(...response.data.routes)
        this.routesCurrentPage = nextPage
        if (this.routesCurrentPage * this.routesPageSize >= response.data.total) {
          this.routesAllLoaded = true
        }
      }
      this.routesLoadingMore = false
    }).catch((err: BusinessError) => {
      console.error(`[HomeListView] load routes failed: ${JSON.stringify(err)}`)
      this.routesLoadingMore = false
    })
  }

  /** 通过接口加载首页 Banner 数据 */
  private loadBanners(): void {
    fetchHomeBanners().then((response) => {
      if (response.code === 0 && response.data) {
        this.banners = response.data
      }
    }).catch((err: BusinessError) => {
      console.error(`[HomeListView] load banners failed: ${JSON.stringify(err)}`)
    })
  }

  /** 组件初始化：初始化尺寸、启动轮播、请求定位、加载路线 */
  aboutToAppear(): void {
    this.initBannerHeight();
    this.restartBannerProgress();
    this.requestLocationPermission();
    this.loadMoreRoutes();
    this.loadBanners();
    AppStorage.setOrCreate(AppStorageKeys.IS_FOREGROUND, true);
  }

  /** 组件销毁：清理定时器 */
  aboutToDisappear(): void {
    clearInterval(this.bannerProgressIntervalId);
    if (this.bannerProgressTimer) {
      clearTimeout(this.bannerProgressTimer);
      this.bannerProgressTimer = undefined;
    }
  }

  build() {
    HdsNavDestination() {
      WaterFlow({ scroller: this.scroller }) {
        FlowItem() {
          this.buildBannerCard()
        }
        .height(this.bannerHeight)
        .width('100%')

        ForEach(this.displayedRoutes, (route: HikingRouteItem) => {
          FlowItem() {
            this.buildHikingRouteCard(route)
          }
          .width('100%')
          .height(this.cardImageHeight + 116)
          .margin({ top: 12 })
          .padding({ left: 12, right: 12 })
        }, (route: HikingRouteItem) => route.id)


        if (this.routesLoadingMore) {
          FlowItem() {
            Row({ space: 8 }) {
              LoadingProgress()
                .width(20)
                .height(20)
                .color($r('app.color.brand_green'))
              Text('加载更多路线...')
                .fontSize(13)
                .fontColor($r('sys.color.font_secondary'))
            }
            .width('100%')
            .justifyContent(FlexAlign.Center)
            .padding({ top: 12, bottom: 12 })
          }
          .width('100%')
        }


        if (this.routesAllLoaded && this.displayedRoutes.length > 0) {
          FlowItem() {
            Row({ space: 6 }) {
              Divider()
                .width(40)
                .color($r('sys.color.comp_background_tertiary'))
              Text('已到最底部')
                .fontSize(12)
                .fontColor($r('sys.color.font_tertiary'))
              Divider()
                .width(40)
                .color($r('sys.color.comp_background_tertiary'))
            }
            .width('100%')
            .justifyContent(FlexAlign.Center)
            .padding({ top: 16, bottom: 8 })
          }
          .width('100%')
        }

        // --- 底部安全区占位 ---
        FlowItem() {
          Column().width('100%').height(this.bottomInset + 68)
        }
        .width('100%')
      }
      .columnsTemplate('1fr')
      .rowsGap(0)
      .columnsGap(0)
      .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: false, effectEdge: EffectEdge.END })
      .scrollBar(BarState.Off)
      .backgroundColor($r('sys.color.background_secondary'))
      .width('100%')
      .height('100%')
      // 滚动帧回调：计算 Banner 下拉拉伸高度
      .onScrollFrameBegin((offset: number, state: ScrollState) => {
        const yOffset: number = this.scroller.currentOffset()?.yOffset ?? 0;
        const bannerHeightChange: boolean = this.calculateBannerHeight(offset, state, yOffset);
        if (bannerHeightChange) {
          return { offsetRemain: 0 };
        }
        return { offsetRemain: offset };
      })
      // 滚动回调：回弹检测 + 状态栏颜色切换
      .onDidScroll(() => {
        this.handleHomeScroll();
      })
      // 滚动停止（含回弹动画结束）：同步状态栏颜色 + 兜底触发 Banner 回弹
      .onScrollStop(() => {
        const yOffset: number = this.scroller.currentOffset()?.yOffset ?? 0;
        if (yOffset <= 0 && this.bannerHeight > this.originBannerHeight && !this.isBannerSpringing) {
          this.bannerSpringBack();
        }
        updateStatusBarContentColor(yOffset < STATUS_BAR_LIGHT_THRESHOLD);
      })
      // 滚动到底部：延迟加载更多路线
      .onReachEnd(() => {
        if (this.routesLoadingTimer !== -1) {
          clearTimeout(this.routesLoadingTimer)
        }
        this.routesLoadingTimer = setTimeout(() => {
          this.loadMoreRoutes()
        }, 200)
      })
    }
    // HDS Navigation 绑定滚动容器
    .bindToScrollable([this.scroller])
    .hideBackButton(true)
    .titleMode(HdsNavDestinationTitleMode.MINI)
    // 导航栏配置：城市选择器 + 搜索/更多菜单 + 滚动模糊效果
    .titleBar({
      avoidLayoutSafeArea: true,
      content: {
        title: { mainTitle: '' },
        stackBuilder: (): void => this.buildTopOperationBar(),
        menu: {
          value: this.hdsMenuItems
        }
      },
      style: {
        // 滚动时导航栏背景模糊效果参数（基于 Banner 原始高度，避免拉伸/回弹时标题栏闪烁）
        scrollEffectOpts: {
          enableScrollEffect: true,
          scrollEffectType: ScrollEffectType.IMMERSIVE_GRADIENT_BLUR,
          blurEffectiveStartOffset: LengthMetrics.vp(this.originBannerHeight - BANNER_CONTENT_HEIGHT - this.topInset),
          blurEffectiveEndOffset: LengthMetrics.vp(this.originBannerHeight - this.topInset - NAVIGATION_HEIGHT)
        },
        // 未滚动时导航栏样式
        originalStyle: {
          contentStyle: {
            menuStyle: {
              backgroundColor: $r('sys.color.comp_background_tertiary'),
              iconColor: $r('sys.color.icon_primary')
            }
          }
        },
        // 滚动后导航栏样式
        scrollEffectStyle: {
          contentStyle: {
            menuStyle: {
              backgroundColor: $r('sys.color.comp_background_tertiary'),
              iconColor: $r('sys.color.icon_primary')
            }
          }
        },
        systemMaterialEffect: {
          materialType: hdsMaterial.MaterialType.IMMERSIVE,
          materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
        }
      }
    })
    .hideTitleBar(false)
    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
    .width('100%')
    .height('100%')
  }

  /** 顶部操作栏：城市选择 Chip */
  @Builder
  buildTopOperationBar() {
    Row() {
      this.buildLocationSelector()
    }
    .width('100%')
    .height(this.topInset + 56)
    .padding({ left: 16 })
    .alignItems(VerticalAlign.Center)
    .backgroundColor(Color.Transparent)
  }

  /** 城市选择 Chip 组件 */
  @Builder
  buildLocationSelector() {
    Chip({
      label: {
        text: this.currentCity,
        fontSize: 16,
        fontColor: $r('sys.color.ohos_id_color_text_primary')
      },
      suffixSymbol: {
        normal: new SymbolGlyphModifier($r('sys.symbol.arrowtriangle_down_fill')),
        activated: new SymbolGlyphModifier($r('sys.symbol.arrowtriangle_down_fill'))
      },
      size: ChipSize.NORMAL,
      borderRadius: 20,
      onClicked: () => {
        const navParam: CitySelectParam = { currentCity: this.currentCity };
        this.appPageContext.openPage({ routerName: PageEnum.CITY_SELECT, param: navParam });
      }
    })
  }

  /** Banner 轮播卡片 */
  @Builder
  buildBannerCard() {
    Stack({ alignContent: Alignment.Bottom }) {
      Swiper(this.bannerController) {
        ForEach(this.banners, (banner: HomeBanner) => {
          this.buildBannerItem(banner);
        }, (banner: HomeBanner) => banner.id.toString())
      }
      .loop(true)
      .autoPlay(this.banners.length > 1)
      .indicator(false)
      .effectMode(EdgeEffect.None)
      .width('100%')
      .height('100%')
      .onChange((index: number) => {
        this.currentBannerIndex = index;
      })
      .onAnimationStart((index: number, targetIndex: number) => {
        if (index === targetIndex) {
          this.restartBannerProgress();
        } else {
          this.currentBannerIndex = targetIndex;
          this.restartBannerProgress();
        }
      })
      // 触摸时暂停轮播进度，抬起后延迟恢复
      .onTouch((event: TouchEvent) => {
        if (event.type === TouchType.Down) {
          this.stopBannerProgress();
        } else if (event.type === TouchType.Up) {
          this.delayRestartBannerProgress();
        }
      })

      // 底部进度指示条
      Row({ space: 6 }) {
        ForEach(this.banners, (_banner: HomeBanner, index: number) => {
          Progress({
            value: index === this.currentBannerIndex ? this.currentProgressValue :
              (index < this.currentBannerIndex ? BANNER_PROGRESS_VALUE_MAX : 0),
            total: BANNER_PROGRESS_VALUE_MAX,
            type: ProgressType.Linear
          })
            .color('rgba(255,255,255,0.94)')
            .backgroundColor('rgba(255,255,255,0.32)')
            .style({
              strokeWidth: 2,
              enableSmoothEffect: false
            })
            .layoutWeight(1)
        }, (_banner: HomeBanner, index: number) => index.toString())
      }
      .width('100%')
      .padding({
        left: 16,
        right: 16,
        bottom: 20
      })
      .transition(TransitionEffect.OPACITY)
    }
    .width('100%')
    .height('100%')
  }

  /**
   * 单个 Banner 项
   *
   * - 背景图 + 标题/副标题/描述文字
   * - geometryTransition 绑定 banner_hero_{id}，与详情页 Banner 区域配对实现一镜到底
   * - renderGroup 优化转场渲染性能
   * - transition 配置出现/消失透明度过渡
   * - onClick 触发 navigateToBannerDetail
   */
  @Builder
  buildBannerItem(banner: HomeBanner) {
    Stack({ alignContent: Alignment.BottomStart }) {
      Image(banner.mediaUrl)
        .objectFit(ImageFit.Cover)
        .width('100%')
        .height('100%')
        .backgroundColor(banner.themeColor)

      Column() {
        Text(banner.title)
          .fontColor($r('sys.color.font_on_primary'))
          .fontSize($r('sys.float.Subtitle_L'))
          .fontWeight(FontWeight.Bold)

        Text(banner.subTitle)
          .margin({
            top: $r('sys.float.padding_level3'),
            bottom: $r('sys.float.padding_level2')
          })
          .fontColor($r('sys.color.font_on_primary'))
          .fontSize($r('sys.float.Body_S'))
          .fontWeight(FontWeight.Medium)

        Text(banner.desc)
          .fontColor($r('sys.color.font_on_secondary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .fontSize($r('sys.float.Body_S'))
          .fontWeight(FontWeight.Medium)
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.End)
      .alignItems(HorizontalAlign.Start)
      .padding({
        top: this.topInset + 56,
        left: 16,
        right: 16,
        bottom: 44
      })
      .transition(TransitionEffect.OPACITY)
    }
    .width('100%')
    .height('100%')
    .renderGroup(true)
    .onClick(() => {
      this.navigateToBannerDetail(banner);
    })
  }

  /** 徒步路线卡片 */
  @Builder
  buildHikingRouteCard(route: HikingRouteItem) {
    Column() {
      Stack({ alignContent: Alignment.TopEnd }) {
        // 图片轮播
        if (route.photos.length > 0) {
          Swiper() {
            ForEach(route.photos, (photo: string) => {
              Image($rawfile(photo))
                .objectFit(ImageFit.Cover)
                .width('100%')
                .height(this.cardImageHeight)
            }, (photo: string, index: number) => `${route.id}_${index}`)
          }
          .autoPlay(route.photos.length > 1)
          .indicator(
            Indicator.dot()
              .itemWidth(30)
              .itemHeight(2)
              .selectedItemWidth(40)
              .selectedItemHeight(2)
              .color('rgba(255,255,255,0.40)')
              .selectedColor('rgba(255,255,255,0.94)')
          )
          .duration(800)
          .itemSpace(0)
          .width('100%')
          .height(this.cardImageHeight)
          .borderRadius({ topLeft: 20, topRight: 20 })
        } else {
          // 渐变占位图（当前版本不展示视频）
          Column() {
            SymbolGlyph($r('sys.symbol.mountain_2_fill'))
              .fontSize(40)
              .fontColor([$r('app.color.white')])
          }
          .width('100%')
          .height(this.cardImageHeight)
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
          .linearGradient({
            direction: GradientDirection.RightBottom,
            colors: [[getCardAccentColor(route), 0], [getCardSubColor(route), 1]]
          })
          .borderRadius({ topLeft: 20, topRight: 20 })
        }
      }
      .width('100%')
      .height(this.cardImageHeight)
      .borderRadius({ topLeft: 20, topRight: 20 })
      .clip(true)
      .renderGroup(true)
      .geometryTransition(`route_hero_${route.id}`, { follow: true })

      // 路线信息区
      Column({ space: 10 }) {
        Row({ space: 8 }) {
          Text(route.name)
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('sys.color.font_primary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)

          // 难度标签
          Text(route.difficulty)
            .fontSize(12)
            .fontColor($r('sys.color.font_on_primary'))
            .fontWeight(FontWeight.Bold)
            .padding({
              left: 12,
              right: 12,
              top: 6,
              bottom: 6
            })
            .borderRadius(16)
            .border({ width: 1, color: getDifficultyColor(route.difficulty) })
            .backgroundColor(getDifficultyColor(route.difficulty))
            .backgroundBlurStyle(BlurStyle.Thin, { colorMode: ThemeColorMode.SYSTEM })
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        Text(route.district + ' · ' + route.trackType)
          .fontSize(13)
          .fontColor($r('sys.color.font_secondary'))
          .fontWeight(FontWeight.Medium)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        // 距离 / 时长 / 爬升
        Row({ space: 16 }) {
          Row({ space: 5 }) {
            SymbolGlyph($r('sys.symbol.start_to_end_distance_fill'))
              .fontSize(15)
              .fontColor([$r('sys.color.icon_secondary')])
            Text(`${route.distanceKm}km`)
              .fontSize(14)
              .fontColor($r('sys.color.font_secondary'))
              .fontWeight(FontWeight.Medium)
          }

          Row({ space: 5 }) {
            SymbolGlyph($r('sys.symbol.clock_fill'))
              .fontSize(15)
              .fontColor([$r('sys.color.icon_secondary')])
            Text(route.durationDisplay)
              .fontSize(14)
              .fontColor($r('sys.color.font_secondary'))
              .fontWeight(FontWeight.Medium)
          }

          Row({ space: 5 }) {
            SymbolGlyph($r('sys.symbol.max_slope'))
              .fontSize(15)
              .fontColor([$r('sys.color.icon_secondary')])
            Text(`${route.elevationGainMeters}m`)
              .fontSize(14)
              .fontColor($r('sys.color.font_secondary'))
              .fontWeight(FontWeight.Medium)
          }
        }
      }
      .width('100%')
      .padding({
        left: 16,
        right: 16,
        top: 14,
        bottom: 16
      })
      .alignItems(HorizontalAlign.Start)
      .backgroundColor($r('sys.color.comp_background_primary'))
    }
    .width('100%')
    .borderRadius(20)
    .clip(true)
    .onClick(() => {
      this.navigateToRouteDetail(route);
    })
  }
}

/** HomeListView Builder 导出函数，供路由注册使用 */
@Builder
export function HomeListViewBuilder() {
  HomeListView()
}

export { HomeListView };
