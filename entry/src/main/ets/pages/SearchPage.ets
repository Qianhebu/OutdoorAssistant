import { AppStorageKeys } from '../common/AppStorageKeys';
import {
  hdsMaterial,
  HdsNavDestination,
  HdsNavDestinationTitleMode,
  ScrollEffectType,
  TitleBarStyleOptions
} from '@kit.UIDesignKit';
import { LengthMetrics } from '@kit.ArkUI';

interface HotSearchItem {
  title: string;
  heat: number;
}

@Entry
@Component
struct SearchPage {
  @StorageLink(AppStorageKeys.TOP_INSET) topInset: number = 0;
  @StorageLink(AppStorageKeys.BOTTOM_INSET) bottomInset: number = 0;
  @State searchText: string = '';
  @State searchHistory: string[] = ['东钱湖', '四明山', '徒步装备', '露营', '急救包'];
  @State hotSearchList: HotSearchItem[] = [
    { title: '东钱湖环湖步道', heat: 98 },
    { title: '四明山森林线', heat: 92 },
    { title: '鄞州城市绿道', heat: 85 },
    { title: '登山杖推荐', heat: 78 },
    { title: '户外急救指南', heat: 75 },
    { title: '防晒装备', heat: 68 },
    { title: '徒步鞋测评', heat: 62 },
    { title: '露营帐篷', heat: 58 }
  ];
  private listScroller: Scroller = new Scroller();
  private titleBarStyle: TitleBarStyleOptions = {
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
        backgroundColor: $r('app.color.start_window_background'),
        maskExtraHeight: 24,
        blurRadius: 12
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
  };

  private handleBack(): void {
    this.getUIContext().getRouter().back();
  }

  private handleSearch(): void {
    if (this.searchText.trim().length === 0) {
      return;
    }
    const trimmedText = this.searchText.trim();
    const filtered = this.searchHistory.filter((item: string) => item !== trimmedText);
    this.searchHistory = [trimmedText, ...filtered];
  }

  private clearHistory(): void {
    this.searchHistory = [];
  }

  private onHistoryTagClick(tag: string): void {
    this.searchText = tag;
    this.handleSearch();
  }

  private onHotSearchClick(item: HotSearchItem): void {
    this.searchText = item.title;
    this.handleSearch();
  }

  build() {
    HdsNavDestination() {
      Scroll(this.listScroller) {
        Column() {
          this.buildSearchHistory();
          this.buildHotSearch();
        }
        .width('100%')
        .height('100%')
        .padding({ left: 16, right: 16, bottom: this.bottomInset + 16 })
      }
      .edgeEffect(EdgeEffect.Spring)
      .scrollBar(BarState.Auto)
      .clip(false)
      .height('100%')
    }
    .onBackPressed((): boolean => {
      this.handleBack();
      return true;
    })
    .titleBar({
      content: {
        title: { mainTitle: '' },
        stackBuilder: (): void => this.stackBuilder(),
      },
      style: this.titleBarStyle,
      enableComponentSafeArea: true
    })
    .bindToScrollable([this.listScroller])
    .titleMode(HdsNavDestinationTitleMode.MINI)
    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
    .backgroundColor($r('app.color.start_window_background'))
    .width('100%')
    .height('100%')
  }

  @Builder
  stackBuilder() {
    Flex({ justifyContent: FlexAlign.End, alignItems: ItemAlign.Center }) {
      Search({ placeholder: '搜索地点、路线、装备...' })
        .height(40)
        .backgroundColor($r('sys.color.comp_background_primary'))
        .placeholderColor($r('sys.color.ohos_id_color_text_secondary'))
        .placeholderFont({ size: 14 })
        .textFont({ size: 14 })
        .onSubmit((value: string) => {
          this.searchText = value;
          this.handleSearch();
        })
        .onChange((value: string) => {
          this.searchText = value;
        })
    }.width('100%').height(56).padding({ left: 64, right: 16 })

  }

  @Builder
  buildSearchHistory() {
    Column({ space: 12 }) {
      Row() {
        Text('搜索历史')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('sys.color.ohos_id_color_text_primary'))
          .layoutWeight(1)

        SymbolGlyph($r('sys.symbol.trash'))
          .fontSize(20)
          .fontColor([$r('sys.color.ohos_id_color_text_secondary')])
          .onClick(() => {
            this.clearHistory();
          })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      if (this.searchHistory.length > 0) {
        Flex({ wrap: FlexWrap.Wrap, space: { main: LengthMetrics.vp(8), cross: LengthMetrics.vp(8) } }) {
          ForEach(this.searchHistory, (item: string) => {
            Text(item)
              .fontSize(14)
              .fontColor($r('sys.color.ohos_id_color_text_primary'))
              .padding({
                left: 14,
                right: 14,
                top: 8,
                bottom: 8
              })
              .backgroundColor($r('sys.color.comp_background_primary'))
              .borderRadius(20)
              .onClick(() => {
                this.onHistoryTagClick(item);
              })
          }, (item: string) => item)
        }
        .width('100%')
      }
    }
    .width('100%')
    .margin({ top: 16 })
  }

  @Builder
  buildHotSearch() {
    Column({ space: 12 }) {
      Text('热门搜索')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('sys.color.ohos_id_color_text_primary'))
        .width('100%')

      Column({ space: 0 }) {
        ForEach(this.hotSearchList, (item: HotSearchItem, index: number) => {
          Row({ space: 12 }) {
            Text(`${index + 1}`)
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor(index < 3 ? '#00A991' : $r('sys.color.ohos_id_color_text_secondary'))
              .width(24)
              .textAlign(TextAlign.Center)

            Text(item.title)
              .fontSize(15)
              .fontColor($r('sys.color.ohos_id_color_text_primary'))
              .layoutWeight(1)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })

            Text(`${item.heat}`)
              .fontSize(12)
              .fontColor($r('sys.color.ohos_id_color_text_secondary'))
          }
          .width('100%')
          .height(52)
          .padding({ left: 16, right: 16 })
          .alignItems(VerticalAlign.Center)
          .borderRadius(12)
          .onClick(() => {
            this.onHotSearchClick(item);
          })

          if (index < this.hotSearchList.length - 1) {
            Divider()
              .width('100%')
              .color($r('sys.color.comp_divider'))
              .margin({ left: 52 })
          }
        }, (item: HotSearchItem) => item.title)
      }
      .width('100%')
      .backgroundColor($r('sys.color.comp_background_primary'))
      .borderRadius(16)
    }
    .width('100%')
    .margin({ top: 24 })
  }
}
