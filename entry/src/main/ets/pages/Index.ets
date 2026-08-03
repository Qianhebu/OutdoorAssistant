import { DividerMode, hdsMaterial, HdsTabs, HdsTabsController } from '@kit.UIDesignKit';
import { SymbolGlyphModifier } from '@kit.ArkUI';
import { AppStorageKeys } from '../common/AppStorageKeys';
import { OUTDOOR_TABS_LIST, OutdoorTabType } from '../common/TabBarModel';
import { HomeTab } from './tabs/HomeTab';
import { RecordTab } from './tabs/RecordTab';
import { MineTab } from './tabs/MineTab';

@Entry
@Component
struct Index {
  @StorageLink(AppStorageKeys.BOTTOM_INSET) bottomInset: number = 0;
  @State currentIndex: number = OutdoorTabType.HOME;
  private controller: HdsTabsController = new HdsTabsController();
  private homeScroller: Scroller = new Scroller();
  private recordScroller: Scroller = new Scroller();
  private mineScroller: Scroller = new Scroller();

  aboutToAppear(): void {
    AppStorage.setOrCreate(AppStorageKeys.CURRENT_TAB, this.currentIndex);
    this.bindTabScroller();
  }

  private bindTabScroller(): void {
    this.controller.bindScroller(OutdoorTabType.HOME, this.homeScroller);
    this.controller.bindScroller(OutdoorTabType.RECORD, this.recordScroller);
    this.controller.bindScroller(OutdoorTabType.MINE, this.mineScroller);
  }

  private changeTab(index: number): void {
    this.currentIndex = index;
    AppStorage.setOrCreate(AppStorageKeys.CURRENT_TAB, index);
  }

  build() {
    Stack() {
      HdsTabs({ controller: this.controller, index: this.currentIndex }) {
        TabContent() {
          HomeTab({
            scroller: this.homeScroller,
            homeTabController: this.controller
          })
        }
        .tabBar(this.buildBottomTabStyle(OutdoorTabType.HOME))

        TabContent() {
          RecordTab({
            scroller: this.recordScroller,
            homeTabController: this.controller
          })
        }
        .tabBar(this.buildBottomTabStyle(OutdoorTabType.RECORD))

        TabContent() {
          MineTab({
            scroller: this.mineScroller,
            homeTabController: this.controller
          })
        }
        .tabBar(this.buildBottomTabStyle(OutdoorTabType.MINE))
      }
      .barOverlap(true)
      .barPosition(BarPosition.End)
      .vertical(false)
      .scrollable(false)
      .divider({ mode: DividerMode.NONE })
      .barFloatingStyle({
        barWidth: { smallWidth: 200, mediumWidth: 300, largeWidth: 400 },
        barBottomMargin: 28,
        gradientMask: { maskColor: '#00000000' },
        systemMaterialEffect: {
          materialType: hdsMaterial.MaterialType.IMMERSIVE,
          materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
        }
      })
      .backgroundColor(Color.Transparent)
      .width('100%')
      .height('100%')
      .onAttach(() => {
        this.controller.preloadItems([OutdoorTabType.HOME, OutdoorTabType.RECORD]);
      })
      .onChange((index: number) => {
        this.changeTab(index);
      })
    }
    // .backgroundColor($r('app.color.start_window_background'))
    .backgroundColor(Color.Orange)
    .width('100%')
    .height('100%')
    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
  }

  private buildBottomTabStyle(tabType: OutdoorTabType): BottomTabBarStyle {
    const tabItem = OUTDOOR_TABS_LIST[tabType];
    return BottomTabBarStyle.of({
      normal: new SymbolGlyphModifier(tabItem.icon)
        .fontColor([$r('sys.color.ohos_id_color_text_secondary')]),
      selected: new SymbolGlyphModifier(tabItem.icon)
        .fontColor(['#00A991'])
    }, tabItem.title)
      .labelStyle({
        unselectedColor: $r('sys.color.ohos_id_color_text_secondary'),
        selectedColor: '#00A991'
      })
  }
}
