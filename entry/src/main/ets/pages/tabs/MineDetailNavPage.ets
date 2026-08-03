import {
  hdsMaterial,
  HdsNavDestination,
  ScrollEffectType
} from '@kit.UIDesignKit';
import { LengthMetrics } from '@kit.ArkUI';

interface MineDetailParams {
  title?: string;
  subtitle?: string;
  detail?: string;
}

@Component
export struct MineDetailNavPage {
  private scroller: Scroller = new Scroller();
  @State params: MineDetailParams = {};

  build() {
    HdsNavDestination() {
      Scroll(this.scroller) {
        Column({ space: 14 }) {
          if (this.params.subtitle && this.params.subtitle.length > 0) {
            Text(this.params.subtitle!)
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('sys.color.ohos_id_color_text_primary'))
              .width('100%')
          }

          if (this.params.detail && this.params.detail.length > 0) {
            Text(this.params.detail!)
              .fontSize(15)
              .lineHeight(24)
              .fontColor($r('sys.color.ohos_id_color_text_secondary'))
              .width('100%')
          }
        }
        .width('100%')
        .padding({ left: 20, right: 20, top: 12, bottom: 40 })
      }
      .clip(false)
      .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
      .scrollBar(BarState.Auto)
      .width('100%')
      .height('100%')
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    }
    .titleBar({
      content: { title: { mainTitle: this.params.title ?? '详情' } },
      style: {
        systemMaterialEffect: {
          materialType: hdsMaterial.MaterialType.ADAPTIVE,
          materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
        },
        scrollEffectOpts: {
          enableScrollEffect: true,
          scrollEffectType: ScrollEffectType.GRADIENT_BLUR,
          blurEffectiveStartOffset: LengthMetrics.vp(0),
          blurEffectiveEndOffset: LengthMetrics.vp(20)
        }
      },
      enableComponentSafeArea: true
    })
    .bindToScrollable([this.scroller])
    .backgroundColor($r('app.color.start_window_background'))
    .width('100%')
    .height('100%')
    .onReady((ctx: NavDestinationContext) => {
      const param = ctx.pathInfo.param as MineDetailParams;
      if (param) {
        this.params = param;
      }
    })
  }
}

@Builder
export function MineDetailNavPageBuilder() {
  MineDetailNavPage();
}
