import { hdsMaterial, HdsTabs, HdsTabsController } from '@kit.UIDesignKit';
import { ConfigurationConstant } from '@kit.AbilityKit';
import { BackgroundDots } from '../common/BackgroundDots';
import { HomeTab } from './tabs/HomeTab';
import { RecordTab } from './tabs/RecordTab';
import { MineTab } from './tabs/MineTab';

@Entry
@Component
struct Index {
  @StorageProp('colorMode') colorMode: number =
    ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT
  @StorageLink('topInset') topInset: number = 0
  @StorageLink('bottomInset') bottomInset: number = 0
  private tabIconSize: number = 26; // Tab 图标大小
  private controller: HdsTabsController = new HdsTabsController();

  build() {
    Flex({ direction: FlexDirection.Column, alignItems: ItemAlign.Stretch }) {
      // 背景点阵（使用绝对定位作为背景层）
      BackgroundDots()
        .position({ x: 0, y: 0 })
        .width('100%')
        .height('100%')
        .zIndex(0)

      // 底部导航（占满整个屏幕，在背景之上）
      HdsTabs({ controller: this.controller }) {
        TabContent() {
          HomeTab()
        }
        .tabBar(this.buildBottomTabStyle($r('sys.symbol.mountain_2_fill'), '首页'))

        TabContent() {
          RecordTab()
        }
        .tabBar(this.buildBottomTabStyle($r('sys.symbol.outward_curvature_fill'), '记录'))

        TabContent() {
          MineTab()
        }
        .tabBar(this.buildBottomTabStyle($r('sys.symbol.leaf_2_fill'), '我的'))
      }
      .barOverlap(true)
      .barPosition(BarPosition.End)
      .vertical(false)
      .scrollable(false)
      .barFloatingStyle({
        barWidth: { smallWidth: 200, mediumWidth: 300, largeWidth: 400 },
        barBottomMargin: 28,
        gradientMask: { maskColor: '#00000000' },
        systemMaterialEffect: {
          materialType: hdsMaterial.MaterialType.IMMERSIVE,
          materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
        },
      })
      .width('100%')
      .height('100%')
      .zIndex(1)
    }
    .width('100%')
    .height('100%')
  }

  // 底部 Tab 样式
  @Builder
  buildBottomTabStyle(icon: Resource, text: string) {
    Column() {
      SymbolGlyph(icon)
        .fontSize(this.tabIconSize)
        .fontColor([$r('sys.color.ohos_id_color_text_secondary')])

      Text(text)
        .fontSize(12)
        .fontColor($r('sys.color.ohos_id_color_text_secondary'))
        .margin({ top: 4 })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }
}
