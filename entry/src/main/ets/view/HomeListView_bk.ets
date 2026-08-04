import {
  hdsMaterial,
  HdsNavDestination,
  HdsNavDestinationTitleMode,
  HdsNavigationMenuItemOptions,
  HdsTabsController,
  IconStyleMode,
  ScrollEffectType,
  TitleBarStyleOptions
} from '@kit.UIDesignKit';
import { Chip, ChipSize, curves, display, LengthMetrics, promptAction, SymbolGlyphModifier, window } from '@kit.ArkUI';
import { abilityAccessCtrl, common, PermissionRequestResult, Permissions } from '@kit.AbilityKit';
import { geoLocationManager } from '@kit.LocationKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { AppStorageKeys } from '../constant/AppStorageKeys';
import { PageEnum } from '../constant/PageEnum';
import { StorageKey } from '../constant/StorageKey';
import { PageContext } from '../router/PageContext';
import { BannerDetailParam } from './BannerDetailPage';

interface RouteRecommend {
  title: string;
  subtitle: string;
  tag: string;
  level: string;
}

interface OutdoorTip {
  title: string;
  content: string;
  icon: Resource;
}

interface HomeListParams {
  scroller: Scroller;
  homeTabController: HdsTabsController;
}

interface CitySelectParam {
  currentCity: string;
}

interface SampleBanner {
  id: number;
  title: string;
  subTitle: string;
  desc: string;
  mediaUrl: Resource;
  themeColor: ResourceColor;
  content: string;
}

const BANNER_SCALE_FACTOR: number = 3;
const STATUS_BAR_LIGHT_THRESHOLD: number = 140;
const BANNER_PROGRESS_VALUE_MAX: number = 2300;
const BANNER_PROGRESS_FRAME_TIME: number = 1000 / 30;
const BANNER_PROGRESS_RESTART_DELAY: number = 50;

@Component
struct HomeListView {
  @StorageLink(AppStorageKeys.TOP_INSET) topInset: number = 0;
  @StorageLink(AppStorageKeys.BOTTOM_INSET) bottomInset: number = 0;
  @StorageLink(StorageKey.HOME_PAGE_CONTEXT) appPageContext: PageContext =
    AppStorage.get<PageContext>(StorageKey.HOME_PAGE_CONTEXT) ?? new PageContext();
  @StorageLink('selectedCity') @Watch('onCitySelected') selectedCity: string = '';
  @State currentCity: string = '定位中...';
  @State locationFailed: boolean = false;
  @State currentBannerIndex: number = 0;
  @State currentProgressValue: number = 0;
  @State bannerHeight: number = 0;
  private originBannerHeight: number = 0;
  private currentScrollState: ScrollState = ScrollState.Idle;
  private bannerController: SwiperController = new SwiperController();
  private bannerProgressIntervalId: number = -1;
  private bannerProgressTimer?: number;
  private locationPermissions: Array<Permissions> =
    ['ohos.permission.APPROXIMATELY_LOCATION', 'ohos.permission.LOCATION'];
  private sampleBanners: SampleBanner[] = [
    // {
    //   id: 1,
    //   title: '春日徒步季',
    //   subTitle: '东钱湖环湖步道',
    //   desc: '6.2km 轻松路线，湖光山色尽收眼底',
    //   mediaUrl: $rawfile('image/banner/banner_hope.jpg'),
    //   themeColor: '#0A58BF',
    //   content: ''
    // },
    // {
    //   id: 2,
    //   title: '山野露营指南',
    //   subTitle: '星空下的帐篷',
    //   desc: '从选址到搭帐，新手露营全攻略',
    //   mediaUrl: $rawfile('image/banner/banner_HMOS.png'),
    //   themeColor: '#2D6A4F',
    //   content: ''
    // },
    // {
    //   id: 3,
    //   title: '四明山森林探险',
    //   subTitle: '进阶路线推荐',
    //   desc: '12.8km 森林穿越，挑战自我极限',
    //   mediaUrl: $rawfile('image/banner/banner_ui_design.png'),
    //   themeColor: '#6C57F2',
    //   content: ''
    // },
    // {
    //   id: 4,
    //   title: '户外安全手册',
    //   subTitle: '安全第一',
    //   desc: '急救包清单、天气查询、紧急联络一网打尽',
    //   mediaUrl: $rawfile('image/banner/banner_ai.png'),
    //   themeColor: '#174FBF',
    //   content: ''
    // },
    {
      id: 5,
      title: '骑行城市绿道',
      subTitle: '鄞州绿道骑行',
      desc: '14.5km 休闲骑行，城市中的绿色氧吧',
      mediaUrl: $rawfile('image/banner/banner_arkui.png'),
      themeColor: '#00A991',
      content: '鄞州绿道全长约 14.5 公里，沿河而建，路面平坦宽阔，非常适合休闲骑行。沿途绿树成荫，空气清新，是城市中难得的绿色氧吧。\n\n路线起点位于鄞州公园南门，途经宁南南路、首南东路、日丽中路，最终到达东部新城。全程约需 1-1.5 小时，适合各年龄段骑行爱好者。\n\n骑行装备建议：\n• 城市通勤车或山地车均可\n• 必备头盔和前后车灯\n• 随车携带简易维修工具\n• 夏季注意防晒和补水\n\n沿途设有多处休息驿站和饮水点，补给充足。周末和节假日人流较多，建议错峰出行，注意礼让行人。'
    },
    {
      id: 6,
      title: '装备速查宝典',
      subTitle: '一键选购',
      desc: '登山杖、徒步鞋、防晒衣，专业装备推荐',
      mediaUrl: $rawfile('image/banner/banner_enabling_kit.png'),
      themeColor: '#C7792B',
      content: '户外装备是安全出行的基础。无论你是初入户外的新手，还是经验丰富的老驴，选对装备都能让你的旅途更加安全舒适。\n\n登山杖推荐：\n• 碳纤维超轻款：重量仅 185g，适合长距离徒步\n• 铝合金三节款：性价比高，耐用可靠\n• 折叠收纳款：便携性好，适合旅行携带\n\n徒步鞋选购要点：\n• 防水透气 GORE-TEX 面料为首选\n• Vibram 大底提供优秀抓地力\n• 中高帮设计保护脚踝\n• 建议买大半码，预留长途肿胀空间\n\n防晒装备清单：\n• UPF50+ 防晒衣：轻薄透气，阻挡 99% 紫外线\n• 宽沿防晒帽：保护面部和颈部\n• 运动防晒霜：SPF50+，防水防汗配方\n• UV400 偏光太阳镜：保护眼睛'
    },
    {
      id: 7,
      title: '新手入门攻略',
      subTitle: '从零开始',
      desc: '第一次户外？看这篇就够了',
      mediaUrl: $rawfile('image/banner/banner_quick_start.png'),
      themeColor: '#5C3D8F',
      content: '第一次参加户外活动，既兴奋又紧张？别担心，这篇攻略帮你从零开始，安全踏上户外之旅。\n\n出发前准备：\n1. 选择合适的路线：新手建议从 5km 以内的平坦步道开始\n2. 查看天气预报：避免雨天和大风天出行\n3. 告知亲友行程：分享你的路线和预计返回时间\n4. 检查手机电量：充满电并携带充电宝\n\n必备物品清单：\n• 饮用水（至少 1L）和能量零食\n• 防晒霜、帽子和太阳镜\n• 轻便雨衣（以防突发降雨）\n• 基础急救包（创可贴、消毒棉、绷带）\n• 手电筒或头灯\n\n安全须知：\n• 不要独自前往陌生路线\n• 遇到危险及时拨打救援电话\n• 保持手机通讯畅通\n• 留意路标和指示牌，避免迷路\n• 量力而行，不要逞强\n\n记住：安全永远是第一位的。慢慢来，享受户外的美好！'
    }
  ];
  scroller: Scroller = new Scroller();
  homeTabController: HdsTabsController = new HdsTabsController();

  aboutToDisappear(): void {
    clearInterval(this.bannerProgressIntervalId);
    if (this.bannerProgressTimer) {
      clearTimeout(this.bannerProgressTimer);
      this.bannerProgressTimer = undefined;
    }
  }

  aboutToAppear(): void {
    this.resetBannerHeight();
    this.requestLocationPermission();
  }

  onPageShow(): void {
    const selectedCity = AppStorage.get<string>('selectedCity');
    if (selectedCity && selectedCity.length > 0) {
      this.currentCity = selectedCity;
      AppStorage.setOrCreate('selectedCity', '');
    }
  }

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
        this.locationFailed = true;
      }
    } catch (err) {
      this.currentCity = '定位失败';
      this.locationFailed = true;
      console.error(`Request location permission failed: ${JSON.stringify(err)}`);
    }
  }

  private locateCurrentCity(): void {
    this.tryCachedLocation();
    this.requestFreshLocation();
  }

  private tryCachedLocation(): void {
    try {
      const location = geoLocationManager.getLastLocation();
      if (location) {
        this.reverseGeocode(location.latitude, location.longitude);
      }
    } catch (err) {
      console.info(`No cached location: ${JSON.stringify(err)}`);
    }
  }

  private requestFreshLocation(): void {
    const request: geoLocationManager.SingleLocationRequest = {
      locatingPriority: 0x502,
      locatingTimeoutMs: 10000
    };
    geoLocationManager.getCurrentLocation(request).then((location: geoLocationManager.Location) => {
      this.reverseGeocode(location.latitude, location.longitude);
    }).catch((err: BusinessError) => {
      if (this.currentCity === '定位中...') {
        this.currentCity = '定位失败';
        this.locationFailed = true;
      }
      console.error(`Get current location failed: ${JSON.stringify(err)}`);
    });
  }

  private reverseGeocode(latitude: number, longitude: number): void {
    const reverseRequest: geoLocationManager.ReverseGeoCodeRequest = {
      latitude: latitude,
      longitude: longitude,
      maxItems: 1
    };
    geoLocationManager.getAddressesFromLocation(reverseRequest).then((data: geoLocationManager.GeoAddress[]) => {
      if (data && data.length > 0 && data[0].locality && data[0].locality.length > 0) {
        this.currentCity = this.stripCitySuffix(data[0].locality!);
        this.locationFailed = false;
      } else if (this.currentCity === '定位中...') {
        this.currentCity = '定位失败';
        this.locationFailed = true;
      }
    }).catch((err: BusinessError) => {
      if (this.currentCity === '定位中...') {
        this.currentCity = '定位失败';
        this.locationFailed = true;
      }
      console.error(`Reverse geocode failed: ${JSON.stringify(err)}`);
    });
  }

  private stripCitySuffix(city: string): string {
    return city.replace(/(市|自治区|特别行政区|自治州|地区|盟)$/, '');
  }

  private onCitySelected(): void {
    if (this.selectedCity && this.selectedCity.length > 0) {
      this.currentCity = this.selectedCity;
      this.selectedCity = '';
    }
  }

  private resetBannerHeight(): void {
    const uiContext: UIContext = this.getUIContext();
    const displayInfo = display.getDefaultDisplaySync();
    const deviceWidth = uiContext.px2vp(displayInfo.width);
    this.originBannerHeight = deviceWidth * 1.28;
    this.bannerHeight = this.originBannerHeight;
  }

  private handlePullBanner(offset: number, state: ScrollState): boolean {
    const yOffset = this.scroller.currentOffset().yOffset;
    if (yOffset > 0) {
      return false;
    }
    if (state === ScrollState.Scroll && offset < 0) {
      this.currentScrollState = ScrollState.Scroll;
      this.bannerHeight += -(offset / BANNER_SCALE_FACTOR);
      return true;
    }
    if (state === ScrollState.Scroll && offset > 0 && this.bannerHeight > this.originBannerHeight) {
      this.bannerHeight = Math.max(this.originBannerHeight, this.bannerHeight - offset);
      return true;
    }
    if (this.currentScrollState === ScrollState.Scroll && state === ScrollState.Fling) {
      this.resetBannerWithAnimation();
      return true;
    }
    return false;
  }

  private resetBannerWithAnimation(): void {
    if (this.bannerHeight <= this.originBannerHeight) {
      this.bannerHeight = this.originBannerHeight;
      return;
    }
    this.currentScrollState = ScrollState.Fling;
    this.getUIContext().animateTo({ curve: curves.interpolatingSpring(0, 1, 273, 33), duration: 250 }, () => {
      this.bannerHeight = this.originBannerHeight;
    });
  }

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

  private stopBannerProgress(): void {
    clearInterval(this.bannerProgressIntervalId);
  }

  private delayRestartBannerProgress(): void {
    if (this.bannerProgressTimer) {
      clearTimeout(this.bannerProgressTimer);
    }
    this.bannerProgressTimer = setTimeout(() => {
      this.restartBannerProgress();
    }, BANNER_PROGRESS_RESTART_DELAY);
  }

  private handleOnReady(ctx: NavDestinationContext): void {
    const params = ctx.pathInfo.param as HomeListParams | undefined;
    if (params?.scroller) {
      this.scroller = params.scroller;
    }
    if (params?.homeTabController) {
      this.homeTabController = params.homeTabController;
    }
    this.updateStatusBarContentColor(true);
    this.restartBannerProgress();
  }

  private routeList: RouteRecommend[] = [
    {
      title: '东钱湖环湖步道',
      subtitle: '轻松 · 6.2km · 约 1.5 小时',
      tag: '湖景',
      level: '适合新手'
    },
    {
      title: '四明山森林线',
      subtitle: '进阶 · 12.8km · 约 4 小时',
      tag: '森林',
      level: '体能挑战'
    },
    {
      title: '鄞州城市绿道',
      subtitle: '休闲 · 14.5km · 约 1 小时',
      tag: '骑行',
      level: '轻松'
    }
  ];
  private tips: OutdoorTip[] = [
    {
      title: '天气',
      content: '出发前确认降雨、风力和紫外线',
      icon: $r('sys.symbol.cloud_sun_fill')
    },
    {
      title: '装备',
      content: '带好饮水、补给、充电宝和急救包',
      icon: $r('sys.symbol.gearshape')
    },
    {
      title: '安全',
      content: '提前告知亲友路线并保持手机电量',
      icon: $r('sys.symbol.cross_case_fill')
    }
  ];
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
  private titleBarStyle: TitleBarStyleOptions = {
    scrollEffectOpts: {
      enableScrollEffect: true,
      scrollEffectType: ScrollEffectType.IMMERSIVE_GRADIENT_BLUR,
      blurEffectiveStartOffset: LengthMetrics.vp(this.bannerHeight),
      blurEffectiveEndOffset: LengthMetrics.vp(this.bannerHeight + 96)
    },
    originalStyle: {
      backgroundStyle: {
        backgroundColor: Color.Transparent,
        maskExtraHeight: 24,
        blurRadius: 12
      },
      contentStyle: {
        menuStyle: {
          backgroundColor: $r('sys.color.comp_background_tertiary'),
          iconColor: $r('sys.color.icon_primary')
        }
      }
    },
    scrollEffectStyle: {
      backgroundStyle: {
        backgroundColor: $r('sys.color.background_secondary'),
        maskExtraHeight: 32,
        blurRadius: 18
      },
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
  };

  private updateStatusBarContentColor(isLight: boolean): void {
    const mainWindow = AppStorage.get<window.Window>(AppStorageKeys.MAIN_WINDOW);
    mainWindow?.setWindowSystemBarProperties({
      statusBarContentColor: isLight ? '#FFFFFF' : '#000000'
    });
  }

  private handleHomeScroll(): void {
    const yOffset = this.scroller.currentOffset().yOffset;
    this.updateStatusBarContentColor(yOffset < STATUS_BAR_LIGHT_THRESHOLD);
  }

  private navigateToSearch(): void {
    this.appPageContext.openPage({ routerName: PageEnum.SEARCH_PAGE });
  }

  private navigateToBannerDetail(banner: SampleBanner): void {
    const detailParam: BannerDetailParam = {
      id: banner.id,
      title: banner.title,
      subTitle: banner.subTitle,
      desc: banner.desc,
      themeColor: banner.themeColor,
      mediaUrl: banner.mediaUrl,
      content: banner.content
    };
    this.getUIContext().animateTo({
      duration: 500,
      curve: curves.interpolatingSpring(0, 1, 273, 33)
    }, () => {
      this.appPageContext.navPathStack.pushPath(
        new NavPathInfo(PageEnum.BANNER_DETAIL, detailParam), false
      );
    });
  }

  build() {
    HdsNavDestination() {
      Scroll(this.scroller) {
        Column() {
          this.buildHeroBanner();
          Column({ space: 16 }) {
            this.buildQuickActions();
            this.buildRecommendSection();
            this.buildPreparationSection();
            this.buildSafetyTips();
          }
          .width('100%')
          .padding({
            left: 16,
            right: 16,
            bottom: this.bottomInset + 104
          })
          .margin({ top: 16 })
        }
        .width('100%')
      }
      .edgeEffect(EdgeEffect.None)
      .scrollBar(BarState.Off)
      // .clip(false)
      .height('100%')
      .onScrollFrameBegin((offset: number, state: ScrollState) => {
        if (this.handlePullBanner(offset, state)) {
          return { offsetRemain: 0 };
        }
        return { offsetRemain: offset };
      })
      .onDidScroll(() => {
        this.handleHomeScroll();
      })
      .onTouch((event: TouchEvent) => {
        if (event.type === TouchType.Up) {
          this.resetBannerWithAnimation();
        }
      })
    }
    .onReady((ctx: NavDestinationContext) => {
      this.handleOnReady(ctx);
    })
    .bindToScrollable([this.scroller])
    .hideBackButton(true)
    .titleMode(HdsNavDestinationTitleMode.MINI)
    .titleBar({
      avoidLayoutSafeArea: true,
      content: {
        title: { mainTitle: '' },
        stackBuilder: (): void => this.buildTopOperationBar(),
        menu: {
          value: this.hdsMenuItems
        }
      },
      style: this.titleBarStyle
    })
    .backgroundColor(Color.Transparent)
    .hideTitleBar(false)
    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
    .width('100%')
    .height('100%')
  }

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
      backgroundColor: $r('sys.color.comp_background_primary'),
      borderRadius: 20,
      onClicked: () => {
        const navParam: CitySelectParam = { currentCity: this.currentCity };
        this.appPageContext.openPage({ routerName: PageEnum.CITY_SELECT, param: navParam });
      }
    })
  }

  @Builder
  buildHeroBanner() {
    Stack({ alignContent: Alignment.Bottom }) {
      Swiper(this.bannerController) {
        ForEach(this.sampleBanners, (banner: SampleBanner) => {
          this.buildSampleBannerItem(banner);
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
      .onTouch((event: TouchEvent) => {
        if (event.type === TouchType.Down) {
          this.stopBannerProgress();
        } else if (event.type === TouchType.Up) {
          this.delayRestartBannerProgress();
        }
      })

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
    }
    .width('100%')
    .height(this.bannerHeight)
    .backgroundColor('#0A58BF')
  }

  @Builder
  buildSampleBannerItem(banner: SampleBanner) {
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
    }
    .width('100%')
    .height('100%')
    .renderGroup(true)
    .geometryTransition(`banner_hero_${banner.id}`, { follow: true })
    .onClick(() => {
      this.navigateToBannerDetail(banner);
    })
  }

  @Builder
  buildHeroTag(text: string) {
    Text(text)
      .fontSize(13)
      .fontColor('#007D74')
      .padding({
        left: 12,
        right: 12,
        top: 6,
        bottom: 6
      })
      .backgroundColor($r('sys.color.comp_background_primary'))
      .borderRadius(14)
  }

  @Builder
  buildQuickActions() {
    Row({ space: 12 }) {
      this.buildActionItem('路线', $r('sys.symbol.route'));
      this.buildActionItem('天气', $r('sys.symbol.cloud_sun_fill'));
      this.buildActionItem('装备', $r('sys.symbol.gearshape'));
      this.buildActionItem('救援', $r('sys.symbol.cross_case_fill'));
    }
    .width('100%')
  }

  @Builder
  buildActionItem(title: string, icon: Resource) {
    Column({ space: 8 }) {
      SymbolGlyph(icon)
        .fontSize(26)
        .fontColor(['#00A991'])

      Text(title)
        .fontSize(13)
        .fontColor($r('sys.color.ohos_id_color_text_primary'))
    }
    .layoutWeight(1)
    .height(86)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(20)
    .onClick(() => {
      promptAction.showToast({ message: title });
    })
  }

  @Builder
  buildRecommendSection() {
    Column({ space: 12 }) {
      this.buildSectionHeader('推荐路线', '根据当前位置推荐');

      ForEach(this.routeList, (item: RouteRecommend) => {
        this.buildRouteCard(item);
      }, (item: RouteRecommend) => item.title)
    }
    .width('100%')
  }

  @Builder
  buildRouteCard(item: RouteRecommend) {
    Row({ space: 14 }) {
      Column() {
        SymbolGlyph($r('sys.symbol.mountain_2_fill'))
          .fontSize(28)
          .fontColor(['#00A991'])
      }
      .width(52)
      .height(52)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .backgroundColor($r('sys.color.comp_background_tertiary'))
      .borderRadius(18)

      Column({ space: 8 }) {
        Row() {
          Text(item.title)
            .fontSize(17)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.ohos_id_color_text_primary'))
            .layoutWeight(1)

          Text(item.tag)
            .fontSize(12)
            .fontColor('#007D74')
            .padding({
              left: 8,
              right: 8,
              top: 4,
              bottom: 4
            })
            .backgroundColor($r('sys.color.comp_background_tertiary'))
            .borderRadius(10)
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        Text(item.subtitle)
          .fontSize(13)
          .fontColor($r('sys.color.ohos_id_color_text_secondary'))

        Text(item.level)
          .fontSize(12)
          .fontColor($r('sys.color.ohos_id_color_text_secondary'))
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      SymbolGlyph($r('sys.symbol.chevron_right'))
        .fontSize(18)
        .fontColor([$r('sys.color.ohos_id_color_text_secondary')])
    }
    .width('100%')
    .padding(16)
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(22)
    .onClick(() => {
      promptAction.showToast({ message: item.title });
    })
  }

  @Builder
  buildPreparationSection() {
    Column({ space: 12 }) {
      this.buildSectionHeader('出发准备', '让每次户外更安心');

      Row({ space: 12 }) {
        this.buildPreparationCard('补给', '水和能量棒', $r('sys.symbol.drop_fill'));
        this.buildPreparationCard('电量', '手机与充电宝', $r('sys.symbol.bolt_fill'));
      }
      .width('100%')
    }
    .width('100%')
  }

  @Builder
  buildPreparationCard(title: string, content: string, icon: Resource) {
    Column({ space: 8 }) {
      SymbolGlyph(icon)
        .fontSize(24)
        .fontColor(['#00A991'])

      Text(title)
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.ohos_id_color_text_primary'))

      Text(content)
        .fontSize(12)
        .fontColor($r('sys.color.ohos_id_color_text_secondary'))
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Start)
    .padding(16)
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(20)
  }

  @Builder
  buildSafetyTips() {
    Column({ space: 12 }) {
      this.buildSectionHeader('安全提醒', '出发前快速检查');

      ForEach(this.tips, (item: OutdoorTip) => {
        this.buildTipItem(item);
      }, (item: OutdoorTip) => item.title)
    }
    .width('100%')
  }

  @Builder
  buildTipItem(item: OutdoorTip) {
    Row({ space: 12 }) {
      Column() {
        SymbolGlyph(item.icon)
          .fontSize(22)
          .fontColor(['#00A991'])
      }
      .width(42)
      .height(42)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .backgroundColor($r('sys.color.comp_background_tertiary'))
      .borderRadius(14)

      Column({ space: 4 }) {
        Text(item.title)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.ohos_id_color_text_primary'))

        Text(item.content)
          .fontSize(12)
          .fontColor($r('sys.color.ohos_id_color_text_secondary'))
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .padding(14)
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(18)
  }

  @Builder
  buildSectionHeader(title: string, subtitle: string) {
    Row() {
      Column({ space: 4 }) {
        Text(title)
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('sys.color.ohos_id_color_text_primary'))

        Text(subtitle)
          .fontSize(12)
          .fontColor($r('sys.color.ohos_id_color_text_secondary'))
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Text('更多')
        .fontSize(13)
        .fontColor('#00A991')
        .onClick(() => {
          promptAction.showToast({ message: title });
        })
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }
}

@Builder
export function HomeListViewBuilder() {
  HomeListView()
}

export { HomeListView };
