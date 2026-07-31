import {
  hdsMaterial,
  HdsNavigation,
  HdsNavigationTitleMode,
  IconStyleMode,
  ScrollEffectType
} from '@kit.UIDesignKit';
import { promptAction } from '@kit.ArkUI';

/**
 * 我的 Tab 组件
 * 
 * 功能：
 * - 用户信息
 * - 设置选项
 * - 其他功能入口
 */
@Component
export struct MineTab {
  @StorageLink('topInset') topInset: number = 0
  @StorageLink('bottomInset') bottomInset: number = 0
  @State materialLevel: hdsMaterial.MaterialLevel = hdsMaterial.MaterialLevel.ADAPTIVE
  @State materialType: hdsMaterial.MaterialType = hdsMaterial.MaterialType.IMMERSIVE
  private scrollerForScroll: Scroller = new Scroller()

  build() {
    HdsNavigation() {
      Scroll(this.scrollerForScroll) {
        Column() {
          // 个人中心内容
          Text('个人中心')
            .fontSize(16)
            .fontColor($r('sys.color.ohos_id_color_text_primary'))
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Start)
        .alignItems(HorizontalAlign.Center)
      }
      .edgeEffect(EdgeEffect.Spring)
      .height('100%')
    }
    .padding({ top: this.topInset })
    .titleBar({
      enableComponentSafeArea: true,
      content: {
        menu: {
          value: [
            {
              content: {
                icon: $r('sys.symbol.gearshape'),
                type: IconStyleMode.NORMAL,
                isEnabled: true,
                label: 'settings',
                action: () => {
                  promptAction.showToast({ message: '设置功能' });
                }
              }
            }
          ]
        }
      },
      style: {
        scrollEffectOpts: {
          scrollEffectType: ScrollEffectType.IMMERSIVE_GRADIENT_BLUR
        },
        originalStyle: {
          contentStyle: {
            menuStyle: {
              iconColor: $r('sys.color.icon_primary')
            }
          }
        },
        scrollEffectStyle: {
          contentStyle: {
            menuStyle: {
              iconColor: $r('sys.color.icon_primary')
            }
          }
        },
        systemMaterialEffect: {
          materialType: this.materialType,
          materialLevel: this.materialLevel
        }
      }
    })
    .bindToScrollable([this.scrollerForScroll])
    .hideBackButton(true)
    .titleMode(HdsNavigationTitleMode.MINI)
    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
    .hideTitleBar(false)
    .hideToolBar(false)
  }
}
