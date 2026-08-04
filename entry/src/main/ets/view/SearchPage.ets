import { AppStorageKeys } from '../constant/AppStorageKeys';
import {
  hdsMaterial,
  HdsNavDestination,
  HdsNavDestinationTitleMode,
  ScrollEffectType,
  TitleBarStyleOptions
} from '@kit.UIDesignKit';
import { LengthMetrics, promptAction } from '@kit.ArkUI';
import { StorageKey } from '../constant/StorageKey';
import { PageContext } from '../router/PageContext';

interface HotSearchItem {
  title: string;
  heat: number;
}

interface SearchResultItem {
  title: string;
  subtitle: string;
  tag: string;
}

@Component
struct SearchPage {
  @StorageLink(AppStorageKeys.TOP_INSET) topInset: number = 0;
  @StorageLink(AppStorageKeys.BOTTOM_INSET) bottomInset: number = 0;
  @StorageLink(StorageKey.HOME_PAGE_CONTEXT) appPageContext: PageContext =
    AppStorage.get<PageContext>(StorageKey.HOME_PAGE_CONTEXT) ?? new PageContext();
  @State searchText: string = '';
  @State isSearching: boolean = false;
  @State searchHistory: string[] = ['东钱湖', '四明山', '徒步装备', '露营', '急救包'];
  @State searchResultList: SearchResultItem[] = [];
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
  private allSearchData: SearchResultItem[] = [
    { title: '东钱湖环湖步道', subtitle: '轻松 · 6.2km · 约 1.5 小时', tag: '湖景' },
    { title: '东钱湖骑行路线', subtitle: '休闲 · 14km · 约 2 小时', tag: '骑行' },
    { title: '四明山森林线', subtitle: '进阶 · 12.8km · 约 4 小时', tag: '森林' },
    { title: '四明山古道穿越', subtitle: '挑战 · 18km · 约 6 小时', tag: '古道' },
    { title: '鄞州城市绿道', subtitle: '休闲 · 14.5km · 约 1 小时', tag: '骑行' },
    { title: '登山杖推荐：碳纤维超轻款', subtitle: '装备 · 重量 185g', tag: '装备' },
    { title: '户外急救指南：野外生存手册', subtitle: '安全 · 必备知识', tag: '安全' },
    { title: '防晒装备清单', subtitle: '装备 · 防晒霜/帽/衣', tag: '装备' },
    { title: '徒步鞋测评：防水透气对比', subtitle: '装备 · 5 款对比', tag: '装备' },
    { title: '露营帐篷选购指南', subtitle: '装备 · 3 季/4 季款', tag: '装备' }
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

  private handleSearch(): void {
    const trimmedText = this.searchText.trim();
    if (trimmedText.length === 0) {
      this.isSearching = false;
      this.searchResultList = [];
      return;
    }
    const filtered = this.searchHistory.filter((item: string) => item !== trimmedText);
    this.searchHistory = [trimmedText, ...filtered];
    this.isSearching = true;
    this.searchResultList = this.allSearchData.filter((item: SearchResultItem) =>
    item.title.indexOf(trimmedText) >= 0 || item.tag.indexOf(trimmedText) >= 0
    );
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

  private clearSearch(): void {
    this.searchText = '';
    this.isSearching = false;
    this.searchResultList = [];
  }

  build() {
    HdsNavDestination() {
      Scroll(this.listScroller) {
        Column() {
          if (this.isSearching) {
            this.buildSearchResult();
          } else {
            this.buildSearchHistory();
            this.buildHotSearch();
          }
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
    .onShown(() => {
      this.getUIContext().getFocusController().requestFocus('search_input');
    })
  }

  @Builder
  stackBuilder() {
    Flex({ justifyContent: FlexAlign.End, alignItems: ItemAlign.Center }) {
      Search({ placeholder: '搜索地点、路线、装备...', value: this.searchText })
        .id('search_input')
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
          if (value.trim().length === 0) {
            this.clearSearch();
          }
        })
    }
    .width('100%')
    .height(56)
    .padding({ left: 64, right: 16 })
  }

  @Builder
  buildSearchResult() {
    Column({ space: 12 }) {
      if (this.searchResultList.length > 0) {
        Text(`找到 ${this.searchResultList.length} 个结果`)
          .fontSize(13)
          .fontColor($r('sys.color.ohos_id_color_text_secondary'))
          .width('100%')

        Column({ space: 0 }) {
          ForEach(this.searchResultList, (item: SearchResultItem, index: number) => {
            Row({ space: 12 }) {
              Column() {
                SymbolGlyph($r('sys.symbol.magnifyingglass'))
                  .fontSize(20)
                  .fontColor([$r('sys.color.ohos_id_color_text_secondary')])
              }
              .width(40)
              .height(40)
              .justifyContent(FlexAlign.Center)
              .alignItems(HorizontalAlign.Center)
              .backgroundColor($r('sys.color.comp_background_tertiary'))
              .borderRadius(12)

              Column({ space: 4 }) {
                Text(item.title)
                  .fontSize(15)
                  .fontColor($r('sys.color.ohos_id_color_text_primary'))
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })

                Text(item.subtitle)
                  .fontSize(12)
                  .fontColor($r('sys.color.ohos_id_color_text_secondary'))
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Start)

              Text(item.tag)
                .fontSize(12)
                .fontColor('#00A991')
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
            .height(64)
            .padding({ left: 16, right: 16 })
            .alignItems(VerticalAlign.Center)
            .onClick(() => {
              promptAction.showToast({ message: item.title });
            })

            if (index < this.searchResultList.length - 1) {
              Divider()
                .width('100%')
                .color($r('sys.color.comp_divider'))
                .margin({ left: 68 })
            }
          }, (item: SearchResultItem) => item.title)
        }
        .width('100%')
        .backgroundColor($r('sys.color.comp_background_primary'))
        .borderRadius(16)
      } else {
        Column({ space: 12 }) {
          SymbolGlyph($r('sys.symbol.magnifyingglass'))
            .fontSize(48)
            .fontColor([$r('sys.color.ohos_id_color_text_secondary')])

          Text('未找到相关结果')
            .fontSize(16)
            .fontColor($r('sys.color.ohos_id_color_text_secondary'))

          Text('换个关键词试试吧')
            .fontSize(13)
            .fontColor($r('sys.color.ohos_id_color_text_tertiary'))
        }
        .width('100%')
        .height(200)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
      }
    }
    .width('100%')
    .margin({ top: 16 })
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

        if (this.searchHistory.length > 0) {
          SymbolGlyph($r('sys.symbol.trash'))
            .fontSize(20)
            .fontColor([$r('sys.color.ohos_id_color_text_secondary')])
            .onClick(() => {
              this.clearHistory();
            })
        }
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
      } else {
        Text('暂无搜索历史')
          .fontSize(14)
          .fontColor($r('sys.color.ohos_id_color_text_tertiary'))
          .width('100%')
          .textAlign(TextAlign.Center)
          .margin({ top: 16, bottom: 16 })
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

@Builder
export function SearchPageBuilder() {
  SearchPage()
}
