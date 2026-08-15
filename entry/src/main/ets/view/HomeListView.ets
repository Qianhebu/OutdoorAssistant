import {
  hdsMaterial,
  HdsNavDestination,
  HdsNavDestinationTitleMode,
  HdsNavigationMenuItemOptions,
  IconStyleMode,
  ScrollEffectType
} from '@kit.UIDesignKit';
import { AppStorageKeys } from '../constant/AppStorageKeys';
import { PageEnum } from '../constant/PageEnum';
import { StorageKey } from '../constant/StorageKey';
import { PageContext } from '../router/PageContext';
import { Chip, ChipSize, curves, display, LengthMetrics, promptAction, SymbolGlyphModifier } from '@kit.ArkUI';
import { abilityAccessCtrl, common, PermissionRequestResult, Permissions } from '@kit.AbilityKit';
import { geoLocationManager } from '@kit.LocationKit';
import {
  getCardAccentColor,
  getCardSubColor,
  getDifficultyColor,
  HikingRouteItem,
  HikingRouteResponse
} from '../model/HikingRouteModel';
import { util } from '@kit.ArkTS';
import { BusinessError } from '@kit.BasicServicesKit';
import { RouteDetailParam } from './RouteDetailPage';
import { BannerDetailParam } from './BannerDetailPage';
import { VideoPlayerView } from './VideoPlayerView';
import { updateStatusBarContentColor } from '../utils/SystemBarHelper';
import { saveCurrentLocation } from '../utils/LocationStore';

/** 城市选择页面传参 */
interface CitySelectParam {
  currentCity: string;
}

/** Banner 数据模型 */
interface SampleBanner {
  id: number;
  title: string;
  subTitle: string;
  desc: string;
  mediaUrl: Resource;
  themeColor: ResourceColor;
  content: string;
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
  // ===== 徒步路线列表 =====
  /** 全部路线数据（从 JSON 一次性加载） */
  @State allRoutes: HikingRouteItem[] = [];
  /** 当前已展示的路线数据（分页追加） */
  @State displayedRoutes: HikingRouteItem[] = [];
  /** 是否正在加载更多 */
  @State routesLoadingMore: boolean = false;
  /** 是否已全部加载 */
  @State routesAllLoaded: boolean = false;
  /** 视频静音状态映射：routeId -> muted */
  @State videoMutedMap: Record<string, boolean> = {} as Record<string, boolean>;
  /** 视频可见状态映射：routeId -> isVisible */
  @State videoVisibleMap: Record<string, boolean> = {} as Record<string, boolean>;
  /** 路线卡片图片高度（根据屏幕宽度计算） */
  @State cardImageHeight: number = 0;
  /** 应用前后台状态 */
  @StorageLink(AppStorageKeys.IS_FOREGROUND) isAppForeground: boolean = true;
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
  /** Banner 示例数据 */
  private sampleBanners: SampleBanner[] = [
    {
      id: 5,
      title: '骑行城市绿道',
      subTitle: '鄞州绿道骑行',
      desc: '14.5km 休闲骑行，城市中的绿色氧吧',
      mediaUrl: $rawfile('image/banner/banner_arkui.png'),
      themeColor: $r('app.color.brand_green'),
      content: '鄞州绿道全长约 14.5 公里，沿河而建，路面平坦宽阔，非常适合休闲骑行。沿途绿树成荫，空气清新，是城市中难得的绿色氧吧。\n\n路线起点位于鄞州公园南门，途经宁南南路、首南东路、日丽中路，最终到达东部新城。全程约需 1-1.5 小时，适合各年龄段骑行爱好者。\n\n骑行装备建议：\n• 城市通勤车或山地车均可\n• 必备头盔和前后车灯\n• 随车携带简易维修工具\n• 夏季注意防晒和补水\n\n沿途设有多处休息驿站和饮水点，补给充足。周末和节假日人流较多，建议错峰出行，注意礼让行人。'
    },
    {
      id: 6,
      title: '装备速查宝典',
      subTitle: '一键选购',
      desc: '登山杖、徒步鞋、防晒衣，专业装备推荐',
      mediaUrl: $rawfile('image/banner/banner_enabling_kit.png'),
      themeColor: $r('app.color.theme_orange'),
      content: '户外装备是安全出行的基础。无论你是初入户外的新手，还是经验丰富的老驴，选对装备都能让你的旅途更加安全舒适。\n\n登山杖推荐：\n• 碳纤维超轻款：重量仅 185g，适合长距离徒步\n• 铝合金三节款：性价比高，耐用可靠\n• 折叠收纳款：便携性好，适合旅行携带\n\n徒步鞋选购要点：\n• 防水透气 GORE-TEX 面料为首选\n• Vibram 大底提供优秀抓地力\n• 中高帮设计保护脚踝\n• 建议买大半码，预留长途肿胀空间\n\n防晒装备清单：\n• UPF50+ 防晒衣：轻薄透气，阻挡 99% 紫外线\n• 宽沿防晒帽：保护面部和颈部\n• 运动防晒霜：SPF50+，防水防汗配方\n• UV400 偏光太阳镜：保护眼睛'
    },
    {
      id: 7,
      title: '新手入门攻略',
      subTitle: '从零开始',
      desc: '第一次户外？看这篇就够了',
      mediaUrl: $rawfile('image/banner/banner_quick_start.png'),
      themeColor: $r('app.color.theme_purple'),
      content: '第一次参加户外活动，既兴奋又紧张？别担心，这篇攻略帮你从零开始，安全踏上户外之旅。\n\n出发前准备：\n1. 选择合适的路线：新手建议从 5km 以内的平坦步道开始\n2. 查看天气预报：避免雨天和大风天出行\n3. 告知亲友行程：分享你的路线和预计返回时间\n4. 检查手机电量：充满电并携带充电宝\n\n必备物品清单：\n• 饮用水（至少 1L）和能量零食\n• 防晒霜、帽子和太阳镜\n• 轻便雨衣（以防突发降雨）\n• 基础急救包（创可贴、消毒棉、绷带）\n• 手电筒或头灯\n\n安全须知：\n• 不要独自前往陌生路线\n• 遇到危险及时拨打救援电话\n• 保持手机通讯畅通\n• 留意路标和指示牌，避免迷路\n• 量力而行，不要逞强\n\n记住：安全永远是第一位的。慢慢来，享受户外的美好！'
    }
  ];
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
  private navigateToBannerDetail(banner: SampleBanner): void {
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
  private navigateToRouteDetail(route: HikingRouteItem): void {
    const param: RouteDetailParam = {
      route: route
    };
    this.getUIContext().animateTo({
      duration: 500,
      curve: curves.interpolatingSpring(0, 1, 273, 33)
    }, () => {
      this.appPageContext.navPathStack.pushPath(new NavPathInfo(PageEnum.ROUTE_DETAIL, param), false);
    });
  }

  /** 判断路线视频是否静音 */
  private isVideoMuted(routeId: string): boolean {
    return this.videoMutedMap[routeId] ?? true;
  }

  /** 切换路线视频静音状态（同时静音其他视频） */
  private toggleVideoMute(routeId: string): void {
    const currentMuted = this.isVideoMuted(routeId);
    const newMap: Record<string, boolean> = {} as Record<string, boolean>;
    const keys = Object.keys(this.videoMutedMap);
    for (let i = 0; i < keys.length; i++) {
      newMap[keys[i]] = this.videoMutedMap[keys[i]];
    }
    if (currentMuted) {
      for (let i = 0; i < keys.length; i++) {
        newMap[keys[i]] = true;
      }
      newMap[routeId] = false;
    } else {
      newMap[routeId] = true;
    }
    this.videoMutedMap = newMap;
  }

  /** 视频进入可视区域：标记可见 */
  private onVideoVisible(routeId: string): void {
    const newMap: Record<string, boolean> = {} as Record<string, boolean>;
    const keys = Object.keys(this.videoVisibleMap);
    for (let i = 0; i < keys.length; i++) {
      newMap[keys[i]] = this.videoVisibleMap[keys[i]];
    }
    newMap[routeId] = true;
    this.videoVisibleMap = newMap;
  }

  /** 视频离开可视区域：标记不可见 */
  private onVideoInvisible(routeId: string): void {
    const newMap: Record<string, boolean> = {} as Record<string, boolean>;
    const keys = Object.keys(this.videoVisibleMap);
    for (let i = 0; i < keys.length; i++) {
      newMap[keys[i]] = this.videoVisibleMap[keys[i]];
    }
    newMap[routeId] = false;
    this.videoVisibleMap = newMap;
  }

  /** 应用前后台切换：shouldPlay prop 自动驱动播放/暂停，无需手动控制 */

  /** 从 rawfile 加载全部路线数据 */
  private loadAllRoutes(): void {
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext
      const resMgr = context.resourceManager
      const rawContent = resMgr.getRawFileContentSync('hiking_routes.json')
      const textDecoder = util.TextDecoder.create('utf-8')
      const jsonStr = textDecoder.decodeToString(rawContent)
      const response: HikingRouteResponse = JSON.parse(jsonStr) as HikingRouteResponse
      if (response.code === 0 && response.data && response.data.routes) {
        this.allRoutes = response.data.routes
        this.loadMoreRoutes()
      }
    } catch (err) {
      const error = err as BusinessError
      console.error(`[HomeListView] load routes failed: code ${error.code}, message ${error.message}`)
    }
  }

  /** 分页加载更多路线数据 */
  private loadMoreRoutes(): void {
    if (this.routesAllLoaded || this.routesLoadingMore) {
      return
    }
    this.routesLoadingMore = true
    const start = this.routesCurrentPage * this.routesPageSize
    const end = Math.min(start + this.routesPageSize, this.allRoutes.length)
    if (start >= this.allRoutes.length) {
      this.routesAllLoaded = true
      this.routesLoadingMore = false
      return
    }
    const newRoutes: HikingRouteItem[] = this.allRoutes.slice(start, end)
    this.displayedRoutes.push(...newRoutes)
    this.routesCurrentPage++
    if (end >= this.allRoutes.length) {
      this.routesAllLoaded = true
    }
    this.routesLoadingMore = false
  }

  /** 组件初始化：初始化尺寸、启动轮播、请求定位、加载路线 */
  aboutToAppear(): void {
    this.initBannerHeight();
    this.restartBannerProgress();
    this.requestLocationPermission();
    this.loadAllRoutes();
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
        ForEach(this.sampleBanners, (banner: SampleBanner) => {
          this.buildBannerItem(banner);
        }, (banner: SampleBanner) => banner.id.toString())
      }
      .loop(true)
      .autoPlay(this.sampleBanners.length > 1)
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
        ForEach(this.sampleBanners, (_banner: SampleBanner, index: number) => {
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
        }, (_banner: SampleBanner, index: number) => index.toString())
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
  buildBannerItem(banner: SampleBanner) {
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
        } else if (route.videoUrl.length > 0) {
          VideoPlayerView({
            videoSrc: route.videoUrl,
            isMuted: this.isVideoMuted(route.id),
            shouldPlay: this.isAppForeground && (this.videoVisibleMap[route.id] ?? false),
            onMuteToggle: () => {
              this.toggleVideoMute(route.id);
            }
          })
            .width('100%')
            .height(this.cardImageHeight)
            .borderRadius({ topLeft: 20, topRight: 20 })
            .onVisibleAreaChange([0.0, 0.75], (isVisible: boolean, currentRatio: number) => {
              if (isVisible && currentRatio >= 0.75) {
                this.onVideoVisible(route.id);
              } else if (!isVisible || currentRatio < 0.75) {
                this.onVideoInvisible(route.id);
              }
            })
        } else {
          // 渐变占位图
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
    .geometryTransition(`route_hero_${route.id}`, { follow: true })
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
