import {
  hdsMaterial,
  HdsNavDestination,
  HdsNavDestinationTitleMode,
  HdsNavigationMenuItemOptions,
  IconStyleMode,
  ScrollEffectType
} from '@kit.UIDesignKit';
import { curves, display, LengthMetrics, promptAction } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { media } from '@kit.MediaKit';
import { AppStorageKeys } from '../constant/AppStorageKeys';
import { StorageKey } from '../constant/StorageKey';
import { PageContext } from '../router/PageContext';
import {
  getCardAccentColor, getCardSubColor, getDifficultyColor, HikingRouteItem
} from '../model/HikingRouteModel';

export interface RouteDetailParam {
  route: HikingRouteItem;
  /** 首图按真实宽高比计算出的 hero 高度（vp），用于转场前锁定目标帧，避免高度跳变闪动 */
  heroHeight?: number;
}

@Component
struct RouteDetailPage {
  private scroller: Scroller = new Scroller();
  @StorageLink(AppStorageKeys.TOP_INSET) topInset: number = 0;
  @StorageLink(AppStorageKeys.BOTTOM_INSET) bottomInset: number = 0;
  @StorageLink(StorageKey.HOME_PAGE_CONTEXT) appPageContext: PageContext =
    AppStorage.get<PageContext>(StorageKey.HOME_PAGE_CONTEXT) ?? new PageContext();
  @State params: RouteDetailParam | null = null;
  @State pageInfos: NavPathStack = new NavPathStack();
  @State heroHeight: number = 0;
  @State originHeroHeight: number = 0;
  @State currentPhotoIndex: number = 0;
  @State videoMuted: boolean = true;
  private videoController: VideoController = new VideoController();
  private deviceWidth: number = 0;
  private mediaHeightCache: Record<string, number> = {};
  private currentScrollState: ScrollState = ScrollState.Idle;
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
          promptAction.showToast({ message: '更多功能' });
        }
      }
    }
  ];

  aboutToAppear(): void {
    const displayInfo = display.getDefaultDisplaySync();
    const uiContext = this.getUIContext();
    this.deviceWidth = uiContext.px2vp(displayInfo.width);
    this.heroHeight = this.deviceWidth;
    this.originHeroHeight = this.heroHeight;
  }

  private updateHeroHeightBySize(width: number, height: number, cacheKey?: string): void {
    if (width <= 0 || height <= 0 || this.deviceWidth <= 0) {
      return;
    }
    const mediaHeight = this.deviceWidth * height / width;
    if (cacheKey) {
      this.mediaHeightCache[cacheKey] = mediaHeight;
    }
    this.heroHeight = mediaHeight;
    this.originHeroHeight = mediaHeight;
  }

  private updateHeroHeightByVideo(videoUrl: string): void {
    if (videoUrl === 'video/default_route_video.mp4') {
      this.updateHeroHeightBySize(479.25, 852, videoUrl);
      return;
    }
    if (videoUrl === 'video/route_vode_1.mov') {
      this.updateHeroHeightBySize(2506, 1264, videoUrl);
      return;
    }
    this.heroHeight = this.deviceWidth;
    this.originHeroHeight = this.heroHeight;
  }

  private async updateHeroHeightByVideoMetadata(videoUrl: string): Promise<void> {
    const cachedHeight = this.mediaHeightCache[videoUrl];
    if (cachedHeight) {
      this.heroHeight = cachedHeight;
      this.originHeroHeight = cachedHeight;
      return;
    }

    let extractor: media.AVMetadataExtractor | undefined = undefined;
    let context: common.UIAbilityContext | undefined = undefined;
    let rawFdOpened: boolean = false;
    try {
      context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const rawFileDescriptor = context.resourceManager.getRawFdSync(videoUrl);
      rawFdOpened = true;
      extractor = await media.createAVMetadataExtractor();
      extractor.fdSrc = {
        fd: rawFileDescriptor.fd,
        offset: rawFileDescriptor.offset,
        length: rawFileDescriptor.length
      };
      const metadata = await extractor.fetchMetadata();
      let videoWidth = Number(metadata.videoWidth);
      let videoHeight = Number(metadata.videoHeight);
      const videoOrientation = Number(metadata.videoOrientation ?? '0');
      if (videoWidth <= 0 || videoHeight <= 0) {
        this.updateHeroHeightByVideo(videoUrl);
        return;
      }
      if (videoOrientation === 90 || videoOrientation === 270) {
        const displayWidth = videoHeight;
        videoHeight = videoWidth;
        videoWidth = displayWidth;
      }
      this.updateHeroHeightBySize(videoWidth, videoHeight, videoUrl);
    } catch (_err) {
      this.updateHeroHeightByVideo(videoUrl);
    } finally {
      await extractor?.release();
      if (rawFdOpened) {
        await context?.resourceManager.closeRawFd(videoUrl);
      }
    }
  }

  private handleDetailScroll(): void {
    const offset = this.scroller.currentOffset();
    const yOffset = offset?.yOffset ?? 0;
    if (yOffset === 0 && this.currentScrollState === ScrollState.Scroll) {
      this.heroSpringBack();
    }
  }

  private calculateHeroHeight(offset: number, state: ScrollState, yOffset: number): boolean {
    if (yOffset > 0) {
      return false;
    }
    if (state === ScrollState.Scroll && offset !== 0) {
      this.currentScrollState = ScrollState.Scroll;
      const currentHeroHeight: number = this.heroHeight - offset;
      if (currentHeroHeight < this.originHeroHeight) {
        this.currentScrollState = ScrollState.Fling;
        this.heroHeight = this.originHeroHeight;
        return false;
      }
      const heroOffset: number = -(offset / 2);
      this.heroHeight += heroOffset;
      return true;
    } else if (this.currentScrollState === ScrollState.Scroll && state === ScrollState.Fling) {
      this.heroSpringBack();
      return true;
    }
    return false;
  }

  private heroSpringBack(): void {
    this.currentScrollState = ScrollState.Fling;
    this.getUIContext().animateTo({ curve: Curve.EaseOut, duration: 250 }, () => {
      this.heroHeight = this.originHeroHeight;
    });
  }

  build() {
    HdsNavDestination() {
      Scroll(this.scroller) {
        Column({ space: 0 }) {
          if (this.params) {
            this.buildHeroImage();
            this.buildRouteInfo();
            this.buildStatsRow();
            this.buildDetailContent();
            this.buildTips();
          }
        }
        .height('100%')
        .width('100%')
      }
      .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true, effectEdge: EffectEdge.END })
      .scrollBar(BarState.Off)
      .width('100%')
      .height('100%')
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
      .onScrollFrameBegin((offset: number, state: ScrollState) => {
        const yOffset: number = this.scroller.currentOffset()?.yOffset ?? 0;
        const heroHeightChange: boolean = this.calculateHeroHeight(offset, state, yOffset);
        if (heroHeightChange) {
          return { offsetRemain: 0 };
        }
        return { offsetRemain: offset };
      })
      .onDidScroll(() => {
        this.handleDetailScroll();
      })
    }
    .titleBar({
      avoidLayoutSafeArea: false,
      content: {
        title: { mainTitle: this.params?.route.name ?? '路线详情' },
        menu: { value: this.hdsMenuItems }
      },
      style: {
        systemMaterialEffect: {
          materialType: hdsMaterial.MaterialType.IMMERSIVE,
          materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
        },
        scrollEffectOpts: {
          enableScrollEffect: true,
          scrollEffectType: ScrollEffectType.IMMERSIVE_GRADIENT_BLUR,
          blurEffectiveStartOffset: LengthMetrics.vp(this.heroHeight / 2),
          blurEffectiveEndOffset: LengthMetrics.vp(this.heroHeight / 2 + 48)
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
    .bindToScrollable([this.scroller])
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
        this.currentPhotoIndex = 0;
        this.heroHeight = (param.heroHeight && param.heroHeight > 0) ? param.heroHeight : this.deviceWidth;
        this.originHeroHeight = this.heroHeight;
        this.params = param;
      }
    })
    .onBackPressed(() => {
      this.getUIContext().animateTo({
        duration: 500,
        curve: curves.interpolatingSpring(0, 1, 273, 33)
      }, () => {
        this.pageInfos.pop(false);
      });
      return true;
    })
  }

  @Builder
  buildHeroImage() {
    Column({ space: 0 }) {
      if (this.params!.route.photos.length > 0) {
        Swiper() {
          ForEach(this.params!.route.photos, (photo: string, index: number) => {
            Image($rawfile(photo))
              .objectFit(ImageFit.Cover)
              .width('100%')
              .height('100%')
              .onComplete((event) => {
                if (!event) {
                  return;
                }
                const cacheKey = `${this.params!.route.id}_${index}`;
                this.mediaHeightCache[cacheKey] = this.deviceWidth * event.height / event.width;
                if (index === this.currentPhotoIndex) {
                  this.updateHeroHeightBySize(event.width, event.height, cacheKey);
                }
              })
          }, (photo: string, index: number) => `${this.params!.route.id}_${index}`)
        }
        .autoPlay(this.params!.route.photos.length > 1)
        .loop(this.params!.route.photos.length > 1)
        .onChange((index: number) => {
          this.currentPhotoIndex = index;
          const cacheKey = `${this.params!.route.id}_${index}`;
          if (this.mediaHeightCache[cacheKey]) {
            this.heroHeight = this.mediaHeightCache[cacheKey];
            this.originHeroHeight = this.mediaHeightCache[cacheKey];
          }
        })
        .indicator(false)
        .duration(800)
        .itemSpace(0)
        .width('100%')
        .height(this.heroHeight)

        if (this.params!.route.photos.length > 1) {
          Row({ space: 6 }) {
            ForEach(this.params!.route.photos, (_photo: string, index: number) => {
              Row()
                .width(index === this.currentPhotoIndex ? 40 : 30)
                .height(2)
                .borderRadius(1)
                .backgroundColor(index === this.currentPhotoIndex ? $r('app.color.brand_green') : 'rgba(0,0,0,0.18)')
            }, (_photo: string, index: number) => `${this.params!.route.id}_indicator_${index}`)
          }
          .width('100%')
          .height(2)
          .justifyContent(FlexAlign.Center)
          .alignItems(VerticalAlign.Center)
          .backgroundColor($r('app.color.start_window_background'))
        }
      } else {
        // 当前版本不展示视频，视频路线显示渐变占位图
        Column() {
          SymbolGlyph($r('sys.symbol.mountain_2_fill'))
            .fontSize(48)
            .fontColor([$r('app.color.white')])
        }
        .width('100%')
        .height(this.heroHeight)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .linearGradient({
          direction: GradientDirection.RightBottom,
          colors: [[getCardAccentColor(this.params!.route), 0], [getCardSubColor(this.params!.route), 1]]
        })
      }
    }
    .width('100%')
    .height(this.params!.route.photos.length > 1 ? this.heroHeight + 24 : this.heroHeight)
    .renderGroup(true)
    .geometryTransition(`route_hero_${this.params!.route.id}`, { follow: true })
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
    .padding({ left: 20, right: 20, top: 16 })
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
        Text('距离')
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
        Text('用时')
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
        Text('爬升')
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
        Text('下降')
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
      Text('路线详情')
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
      Text('注意事项')
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
}

@Builder
export function RouteDetailPageBuilder() {
  RouteDetailPage();
}
