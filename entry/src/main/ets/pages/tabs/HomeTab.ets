import {
  hdsMaterial,
  HdsNavigation,
  HdsNavigationTitleMode,
  IconStyleMode,
  ScrollEffectType
} from '@kit.UIDesignKit';
import { Chip, ChipSize, promptAction, SymbolGlyphModifier } from '@kit.ArkUI';

/**
 * 首页 Tab 组件
 *
 * 功能：
 * - 位置选择器（城市切换）
 * - 搜索入口
 * - 更多菜单
 */
@Component
export struct HomeTab {
  @StorageLink('topInset') topInset: number = 0
  @StorageLink('bottomInset') bottomInset: number = 0
  @State materialLevel: hdsMaterial.MaterialLevel = hdsMaterial.MaterialLevel.ADAPTIVE
  @State materialType: hdsMaterial.MaterialType = hdsMaterial.MaterialType.IMMERSIVE
  @State currentCity: string = '宁波'
  private scrollerForScroll: Scroller = new Scroller()

  /**
   * 跳转到搜索页面
   */
  private navigateToSearch(): void {
    try {
      this.getUIContext().getRouter().pushUrl({
        url: 'pages/SearchPage'
      });
    } catch (err) {
      console.error(`Navigate to search page failed: ${JSON.stringify(err)}`);
    }
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      // 背景层：通过 expandSafeArea 视觉上延伸到 status bar 区域
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('#00cec9')
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])

      HdsNavigation() {
        Scroll(this.scrollerForScroll) {
          Column() {
            // 首页内容区域
            Text('首页内容')
              .fontSize(16)
              .fontColor($r('sys.color.ohos_id_color_text_primary'))
          }
          .width('100%')
          .height('100%')
        }
        .edgeEffect(EdgeEffect.Spring)
        .height('100%')
        .backgroundColor(Color.Transparent)
      }
      .titleBar({
        enableComponentSafeArea: false,
        content: {
          stackBuilder: (): void => this.buildLocationSelector(),
          menu: {
            value: [
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
                  label: 'more',
                  icon: $r('sys.symbol.dot_grid_2x2'),
                  action: () => {
                    promptAction.showToast({ message: '点击more菜单的回调函数' });
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
      .titleMode(HdsNavigationTitleMode.FREE)
      .hideTitleBar(false)
      .hideToolBar(false)
      .width('100%')
      .height('100%')
    }
    .width('100%')
    .height('100%')
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }

  /**
   * 位置选择器（使用 Chip 组件）
   */
  @Builder
  buildLocationSelector() {
    Flex({ justifyContent: FlexAlign.Start, alignItems: ItemAlign.Center }) {
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
        backgroundColor: 'rgba(255, 255, 255, 0.6)',
        borderRadius: 20,
        onClicked: () => {
          promptAction.showToast({ message: '跳转到城市选择页面' });
        }
      })
    }
    .width('100%')
    .height(56)
    .padding({ left: 16 })
  }
}
