import { hdsMaterial, HdsNavDestination, ScrollEffectType } from '@kit.UIDesignKit';
import { curves, display, LengthMetrics } from '@kit.ArkUI';
import { AppStorageKeys } from '../constant/AppStorageKeys';
import { StorageKey } from '../constant/StorageKey';
import { PageContext } from '../router/PageContext';

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

  aboutToAppear(): void {
    const displayInfo = display.getDefaultDisplaySync();
    const uiContext = this.getUIContext();
    const deviceWidth = uiContext.px2vp(displayInfo.width);
    this.heroHeight = deviceWidth * 1.28;
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
      }
      .clip(true)
      .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
      .scrollBar(BarState.Auto)
      .width('100%')
      .height('100%')
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    }
    .titleBar({
      content: { title: { mainTitle: this.params?.title ?? '详情' } },
      style: {
        systemMaterialEffect: {
          materialType: hdsMaterial.MaterialType.IMMERSIVE,
          materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
        },
        scrollEffectOpts: {
          enableScrollEffect: true,
          scrollEffectType: ScrollEffectType.IMMERSIVE_GRADIENT_BLUR,
          blurEffectiveStartOffset: LengthMetrics.vp(24),
          blurEffectiveEndOffset: LengthMetrics.vp(96)
        },
        originalStyle: {
          backgroundStyle: {
            backgroundColor: Color.Transparent,
            maskExtraHeight: 24,
            blurRadius: 12
          },
          contentStyle: {
            titleStyle: {
              mainTitleColor: $r('sys.color.font_on_primary')
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
      enableComponentSafeArea: true
    })
    .bindToScrollable([this.scroller])
    .hideTitleBar(false)
    .backgroundColor($r('app.color.start_window_background'))
    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
    .width('100%')
    .height('100%')
    .onReady((ctx: NavDestinationContext) => {
      this.pageInfos = ctx.pathStack;
      const param = ctx.pathInfo.param as BannerDetailParam;
      if (param) {
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
    Stack({ alignContent: Alignment.BottomStart }) {
      Image(this.params!.mediaUrl)
        .objectFit(ImageFit.Cover)
        .width('100%')
        .height('100%')
        .backgroundColor(this.params!.themeColor)

      Column() {
        Text(this.params!.title)
          .fontColor($r('sys.color.font_on_primary'))
          .fontSize(24)
          .fontWeight(FontWeight.Bold)

        Text(this.params!.subTitle)
          .fontColor($r('sys.color.font_on_primary'))
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .margin({ top: 8, bottom: 6 })

        Text(this.params!.desc)
          .fontColor($r('sys.color.font_on_secondary'))
          .fontSize(13)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width('100%')
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
    .height(this.heroHeight)
    .renderGroup(true)
    .geometryTransition(`banner_hero_${this.params!.id}`, { follow: true })
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
