import {
  hdsMaterial, HdsNavDestination, HdsNavDestinationTitleMode, ScrollEffectType
} from '@kit.UIDesignKit';
import { display, LengthMetrics } from '@kit.ArkUI';
import { AppStorageKeys } from '@ohos/common';
import { StorageKey } from '@ohos/common';
import { PageContext } from '@ohos/common';

export interface BannerDetailParam {
  id: number;
  title: string;
  subTitle: string;
  desc: string;
  themeColor: ResourceColor;
  mediaUrl: Resource;
  content: string;
}

@Component
struct BannerDetailPage {
  private scroller: Scroller = new Scroller();
  @StorageLink(AppStorageKeys.TOP_INSET) topInset: number = 0;
  @StorageLink(StorageKey.HOME_PAGE_CONTEXT) appPageContext: PageContext =
    AppStorage.get<PageContext>(StorageKey.HOME_PAGE_CONTEXT) ?? new PageContext();
  @State params: BannerDetailParam | null = null;
  @State pageInfos: NavPathStack = new NavPathStack();
  @State heroHeight: number = 0;
  private deviceWidth: number = 0;
  private naturalHeight: number = 0;
  private hasExpanded: boolean = false;

  aboutToAppear(): void {
    const displayInfo = display.getDefaultDisplaySync();
    const uiContext = this.getUIContext();
    this.deviceWidth = uiContext.px2vp(displayInfo.width);
  }

  private startExpandAnimation(): void {
    if (this.hasExpanded || this.naturalHeight <= 0) {
      return;
    }
    this.hasExpanded = true;
    this.getUIContext().animateTo({ duration: 500, curve: Curve.Smooth }, () => {
      this.heroHeight = this.naturalHeight;
    });
  }

  build() {
    HdsNavDestination() {
      Scroll(this.scroller) {
        Column({ space: 0 }) {
          if (this.params) {
            this.buildHeroImage();
            this.buildContent();
          }
        }
        .width('100%')
        .height('100%')
      }
      .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true, effectEdge: EffectEdge.END })
      .scrollBar(BarState.Off)
      .width('100%')
      .height('100%')
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
    }
    .titleBar({
      avoidLayoutSafeArea: false,
      content: {
        title: { mainTitle: this.params?.title ?? '详情' }
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
      },
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
      const param = ctx.pathInfo.param as BannerDetailParam;
      if (param) {
        this.heroHeight = this.deviceWidth * 1.28;
        this.hasExpanded = false;
        this.params = param;
      }
    })
    .onBackPressed(() => {
      this.pageInfos.pop(true);
      return true;
    })
  }

  @Builder
  buildHeroImage() {
    Column() {
      Image(this.params!.mediaUrl)
        .objectFit(ImageFit.Cover)
        .width('100%')
        .height(this.heroHeight)
        .backgroundColor(this.params!.themeColor)
        .onComplete((event) => {
          if (event && event.width > 0 && event.height > 0) {
            this.naturalHeight = this.deviceWidth * event.height / event.width;
            this.startExpandAnimation();
          }
        })

      Column() {
        Text(this.params!.title)
          .fontColor($r('sys.color.font_primary'))
          .fontSize(24)
          .fontWeight(FontWeight.Bold)

        Text(this.params!.subTitle)
          .fontColor($r('sys.color.font_secondary'))
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .margin({ top: 8, bottom: 6 })

        Text(this.params!.desc)
          .fontColor($r('sys.color.font_tertiary'))
          .fontSize(13)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding({
        left: 16,
        right: 16,
        top: 16,
        bottom: 16
      })
    }
    .width('100%')
  }

  @Builder
  buildContent() {
    Column({ space: 16 }) {
      Text(this.params!.content)
        .fontSize(15)
        .lineHeight(26)
        .fontColor($r('sys.color.ohos_id_color_text_primary'))
        .width('100%')
    }
    .width('100%')
    .padding({
      left: 20,
      right: 20,
      top: 20,
      bottom: 40
    })
  }
}

@Builder
export function BannerDetailPageBuilder() {
  BannerDetailPage();
}
