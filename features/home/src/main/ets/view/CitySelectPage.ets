import {
  BottomBuilderShowType,
  hdsMaterial,
  HdsNavDestination,
  HdsNavDestinationTitleMode,
  HdsNavigationMenuContentOptions,
  HdsNavigationMenuItemOptions,
  HideMode,
  IconStyleMode,
  ScrollEffectType
} from '@kit.UIDesignKit';
import { LengthMetrics } from '@kit.ArkUI';
import { vibrator } from '@kit.SensorServiceKit';
import { geoLocationManager } from '@kit.LocationKit';
import { abilityAccessCtrl, common, PermissionRequestResult, Permissions } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { StorageKey } from '@ohos/common';
import { PageContext } from '@ohos/common';
import { CityGroup, fetchCityList, searchCities } from '@ohos/common';

interface CitySelectParam {
  currentCity?: string;
}

@Component
export struct CitySelectPage {
  @StorageLink(StorageKey.HOME_PAGE_CONTEXT) appPageContext: PageContext =
    AppStorage.get<PageContext>(StorageKey.HOME_PAGE_CONTEXT) ?? new PageContext();
  @State currentCity: string = '';
  @State selected: number = 0;
  @State searchMode: boolean = false;
  @State searchText: string = '';
  @State searchResults: string[] = [];
  @State indexerPopupEnabled: boolean = false;
  @State indexerTouching: boolean = false;
  @State titleSearchOpacity: number = 0;
  @State titleBarSearchVisible: boolean = false;
  @State relocating: boolean = false;
  @State bottomBuilderHidden: boolean = false;
  private popupHideTimer: number = -1;
  private listScroller: Scroller = new Scroller();
  private locationPermissions: Permissions[] = ['ohos.permission.APPROXIMATELY_LOCATION', 'ohos.permission.LOCATION'];
  private titleSearchController: SearchController = new SearchController();
  private lastHapticIndex: number = -1;
  /** 热门城市（通过接口加载） */
  @State hotCities: string[] = [];
  /** 按字母分组的城市列表（通过接口加载） */
  @State cityGroups: CityGroup[] = [];
  /** 索引字母 */
  @State indexerLetters: string[] = ['#'];
  private searchMenuItem: HdsNavigationMenuItemOptions = {
    content: {
      icon: $r('sys.symbol.magnifyingglass'),
      type: IconStyleMode.NORMAL,
      isEnabled: true,
      label: 'search',
      action: () => {
        this.focusTitleSearch();
      }
    }
  };
  @State menuOptions: HdsNavigationMenuContentOptions = { value: [] };

  /** 通过接口加载城市列表 */
  private loadCityList(): void {
    fetchCityList().then((response) => {
      if (response.code === 0 && response.data) {
        this.hotCities = response.data.hotCities;
        this.cityGroups = response.data.groups;
        this.indexerLetters = ['#', ...response.data.groups.map((g: CityGroup) => g.letter)];
      }
    }).catch((err: BusinessError) => {
      console.error(`[CitySelectPage] load city list failed: ${JSON.stringify(err)}`);
    });
  }

  /** 通过接口搜索城市 */
  private doSearch(query: string): void {
    const keyword = query.trim();
    if (keyword.length === 0) {
      this.searchResults = [];
      return;
    }
    searchCities(keyword).then((response) => {
      if (response.code === 0) {
        this.searchResults = response.data;
      }
    }).catch((err: BusinessError) => {
      console.error(`[CitySelectPage] search city failed: ${JSON.stringify(err)}`);
    });
  }

  private updateSearchText(value: string): void {
    this.searchText = value;
    this.doSearch(value);
    this.selected = 0;
    this.indexerPopupEnabled = false;
    this.listScroller.scrollToIndex(0, false);
  }

  private exitTitleSearchMode(): void {
    this.searchMode = false;
    this.titleBarSearchVisible = false;
    this.searchText = '';
    this.searchResults = [];
  }

  aboutToAppear(): void {
    this.loadCityList();
  }

  private selectCity(city: string): void {
    AppStorage.setOrCreate('selectedCity', city);
    this.appPageContext.popPage();
  }

  private stripCitySuffix(city: string): string {
    return city.replace(/(市|自治区|特别行政区|自治州|地区|盟)$/, '');
  }

  private enableIndexerPopup(): void {
    this.indexerPopupEnabled = true;
    if (this.popupHideTimer !== -1) {
      clearTimeout(this.popupHideTimer);
    }
  }

  private disableIndexerPopup(): void {
    this.indexerPopupEnabled = false;
    if (this.popupHideTimer !== -1) {
      clearTimeout(this.popupHideTimer);
      this.popupHideTimer = -1;
    }
  }

  private async relocate(): Promise<void> {
    this.relocating = true;
    this.currentCity = '定位中...';
    try {
      const atManager: abilityAccessCtrl.AtManager = abilityAccessCtrl.createAtManager();
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const result: PermissionRequestResult =
        await atManager.requestPermissionsFromUser(context, this.locationPermissions);
      const granted = result.authResults.every((status: number) => status === 0);
      if (!granted) {
        this.currentCity = '定位失败';
        this.relocating = false;
        return;
      }
      this.requestFreshLocation();
    } catch (err) {
      this.currentCity = '定位失败';
      this.relocating = false;
      console.error(`Relocate permission failed: ${JSON.stringify(err)}`);
    }
  }

  private requestFreshLocation(): void {
    const request: geoLocationManager.SingleLocationRequest = {
      locatingPriority: 0x502,
      locatingTimeoutMs: 10000
    };
    geoLocationManager.getCurrentLocation(request).then((location: geoLocationManager.Location) => {
      this.reverseGeocode(location.latitude, location.longitude);
    }).catch((err: BusinessError) => {
      this.currentCity = '定位失败';
      this.relocating = false;
      console.error(`Relocate failed: ${JSON.stringify(err)}`);
    });
  }

  private reverseGeocode(latitude: number, longitude: number): void {
    const reverseRequest: geoLocationManager.ReverseGeoCodeRequest = {
      latitude: latitude,
      longitude: longitude,
      maxItems: 1
    };
    geoLocationManager.getAddressesFromLocation(reverseRequest).then((data: geoLocationManager.GeoAddress[]) => {
      if (data && data.length > 0 && data[0].locality && data[0].locality.length > 0) {
        this.currentCity = this.stripCitySuffix(data[0].locality!);
        this.relocating = false;
        this.selectCity(this.currentCity);
      } else {
        this.currentCity = '定位失败';
        this.relocating = false;
      }
    }).catch((err: BusinessError) => {
      this.currentCity = '定位失败';
      this.relocating = false;
      console.error(`Relocate reverse geocode failed: ${JSON.stringify(err)}`);
    });
  }

  private updateSelectedByListStart(startIndex: number): void {
    if (this.searchText.trim().length > 0) {
      this.selected = 0;
      return;
    }
    const nextSelected = startIndex <= 2 ? 0 : Math.min(startIndex - 2, this.indexerLetters.length - 1);
    if (this.selected !== nextSelected) {
      this.selected = nextSelected;
    }
  }

  private focusTitleSearch(): void {
    this.updateSearchText('');
    this.getUIContext().getFocusController().requestFocus('city_bottom_search');
  }

  private playIndexerHaptic(index: number): void {
    if (this.lastHapticIndex === index) {
      return;
    }
    this.lastHapticIndex = index;
    try {
      vibrator.startVibration({
        type: 'time',
        duration: 20
      }, {
        id: 0,
        usage: 'touch'
      }).catch((error: Error) => {
        console.error(`City indexer haptic failed: ${JSON.stringify(error)}`);
      });
    } catch (error) {
      console.error(`City indexer haptic failed: ${JSON.stringify(error)}`);
    }
  }

  build() {
    HdsNavDestination() {
      Stack({ alignContent: Alignment.End }) {
        List({ space: 0, initialIndex: 0, scroller: this.listScroller }) {
          if (this.searchText.trim().length > 0) {
            if (this.searchResults.length === 0) {
              ListItem() {
                this.buildEmptySearchResult()
              }
            } else {
              ForEach(this.searchResults, (city: string) => {
                ListItem() {
                  this.buildCityRow(city)
                }
              }, (city: string, index: number) => `search_${city}_${index}`)
            }
          } else {
            ListItem() {
              this.buildCurrentLocation()
            }

            ListItem() {
              this.buildHotCities()
            }

            ForEach(this.cityGroups, (group: CityGroup) => {
              ListItem() {
                this.buildCityGroup(group)
              }
            }, (group: CityGroup) => group.letter)
          }
        }
        .width('100%')
        .height('100%')
        .clip(false)
        .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
        .scrollBar(BarState.Off)
        .sticky(StickyStyle.Header)
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
        .onScrollIndex((start: number) => {
          this.updateSelectedByListStart(start);
        })
        .onDidScroll(() => {
          if (!this.indexerTouching) {
            this.disableIndexerPopup();
          }
          const yOffset = Math.max(0, this.listScroller.currentOffset().yOffset);
          const shouldShowMenu = yOffset > 56;
          if (shouldShowMenu !== this.bottomBuilderHidden) {
            this.bottomBuilderHidden = shouldShowMenu;
            this.menuOptions = { value: shouldShowMenu ? [this.searchMenuItem] : [] };
          }
        })

        if (this.searchText.trim().length === 0) {
          AlphabetIndexer({ arrayValue: this.indexerLetters, selected: this.selected })
            .autoCollapse(false)
            .enableHapticFeedback(true)
            .selectedColor($r('sys.color.ohos_id_color_text_primary_dark'))
            .popupColor(0x00A991)
            .selectedBackgroundColor(0x00A991)
            .popupBackground($r('sys.color.ohos_id_color_dialog_bg'))
            .usingPopup(this.indexerPopupEnabled)
            .selectedFont({ size: 12, weight: FontWeight.Bold })
            .popupFont({ size: 24, weight: FontWeight.Bold })
            .itemSize(26)
            .alignStyle(IndexerAlign.Right)
            .popupItemBorderRadius(26)
            .popupItemFont({ size: 18 })
            .itemBorderRadius(13)
            .color($r('sys.color.ohos_id_color_text_secondary'))
            .font({ size: 12 })
            .margin({ right: 4 })
            .onSelect((index: number) => {
              this.playIndexerHaptic(index);
              this.selected = index;
              const targetIdx = index === 0 ? 0 : index + 2;
              this.listScroller.scrollToIndex(targetIdx, false, ScrollAlign.CENTER);
            })
            .onRequestPopupData((index: number): Array<string> => {
              if (index === 0) {
                return this.hotCities;
              }
              const groupIdx = index - 1;
              if (groupIdx >= 0 && groupIdx < this.cityGroups.length) {
                return this.cityGroups[groupIdx].cities;
              }
              return [];
            })
            .onPopupSelect((popupIndex: number) => {
              const idx = this.selected;
              let city: string = '';
              if (idx === 0) {
                if (popupIndex >= 0 && popupIndex < this.hotCities.length) {
                  city = this.hotCities[popupIndex];
                }
              } else {
                const groupIdx = idx - 1;
                if (groupIdx >= 0 && groupIdx < this.cityGroups.length) {
                  const cities = this.cityGroups[groupIdx].cities;
                  if (popupIndex >= 0 && popupIndex < cities.length) {
                    city = cities[popupIndex];
                  }
                }
              }
              if (city.length > 0) {
                this.selectCity(city);
              }
            })
            .onTouch((event: TouchEvent) => {
              if (event.type === TouchType.Down) {
                this.indexerTouching = true;
                this.enableIndexerPopup();
              } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
                this.indexerTouching = false;
                if (this.popupHideTimer !== -1) {
                  clearTimeout(this.popupHideTimer);
                }
                this.popupHideTimer = setTimeout(() => {
                  this.indexerPopupEnabled = false;
                  this.popupHideTimer = -1;
                }, 1000);
              }
            })

        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.start_window_background'))
      .clip(false)
    }
    .titleBar({
      content: {
        title: { mainTitle: '选择城市' },
        bottomBuilder: {
          builder: (): void => this.bottomBuilder(),
          height: 56,
          showType: BottomBuilderShowType.DIRECTLY_SHOW
        },
        menu: this.menuOptions
      },
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
      enableComponentSafeArea: true
    })
    .bindToScrollable([this.listScroller])
    .dynamicHideTitleBar({
      hideTitleArea: false,
      hideBottomBuilder: true,
      mode: HideMode.SCROLL_UP_TO
    })
    .titleMode(HdsNavDestinationTitleMode.MINI)
    .backgroundColor($r('app.color.start_window_background'))
    .width('100%')
    .height('100%')
    .onReady((ctx: NavDestinationContext) => {
      const param = ctx.pathInfo.param as CitySelectParam;
      if (param?.currentCity) {
        this.currentCity = param.currentCity;
      }
    })
  }

  @Builder
  bottomBuilder() {
    Flex({ justifyContent: FlexAlign.Center, alignItems: ItemAlign.Center }) {
      Search({ value: this.searchText, placeholder: '搜索城市', controller: this.titleSearchController })
        .id('city_bottom_search')
        .width('100%')
        .height(40)
        .backgroundColor($r('sys.color.comp_background_primary'))
        .placeholderColor($r('sys.color.ohos_id_color_text_tertiary'))
        .placeholderFont({ size: 14 })
        .textFont({ size: 14 })
        .fontColor($r('sys.color.ohos_id_color_text_primary'))
        .defaultFocus(false)
        .onChange((value: string) => {
          this.updateSearchText(value);
        })
        .onSubmit((value: string) => {
          this.updateSearchText(value);
        })
    }
    .padding({ left: 16, right: 16 })
  }


  @Builder
  buildEmptySearchResult() {
    Column() {
      Text('未找到匹配的城市')
        .fontSize(14)
        .fontColor($r('sys.color.ohos_id_color_text_secondary'))
        .margin({ top: 40 })
    }
    .width('100%')
    .height(160)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  buildCurrentLocation() {
    Column() {
      Flex({ justifyContent: FlexAlign.SpaceBetween, alignItems: ItemAlign.Center }) {
        Text('当前位置')
          .fontSize(13)
          .fontColor($r('sys.color.ohos_id_color_text_secondary'))
        Button({ type: ButtonType.Normal }) {
          if (this.relocating) {
            LoadingProgress()
              .width(14)
              .height(14)
              .color($r('sys.color.ohos_id_color_text_secondary'))
          } else {
            Row({ space: 2 }) {
              SymbolGlyph($r('sys.symbol.position'))
                .fontSize(12)
                .fontColor([$r('sys.color.ohos_id_color_text_secondary')])
              Text('重新定位')
                .fontSize(12)
                .fontColor($r('sys.color.ohos_id_color_text_secondary'))
            }
          }
        }
        .height(28)
        .padding({ left: 8, right: 8 })
        .backgroundColor(Color.Transparent)
        .onClick(() => {
          if (!this.relocating) {
            this.relocate();
          }
        })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 10 })

      Flex({ justifyContent: FlexAlign.Start, alignItems: ItemAlign.Center }) {
        SymbolGlyph($r('sys.symbol.local_fill'))
          .fontSize(16)
          .fontColor([$r('app.color.brand_green')])
        Text(this.relocating ? '定位中...' : (this.currentCity.length > 0 ? this.currentCity : '定位中...'))
          .fontSize(15)
          .fontColor($r('app.color.brand_green'))
          .fontWeight(FontWeight.Medium)
          .margin({ left: 4 })
          .layoutWeight(1)
      }
      .width('100%')
      .padding({
        left: 16,
        right: 16,
        top: 8,
        bottom: 12
      })
      .onClick(() => {
        if (!this.relocating && this.currentCity.length > 0 && this.currentCity !== '定位失败' &&
          this.currentCity !== '定位中...') {
          this.selectCity(this.currentCity);
        }
      })
    }
    .width('100%')
  }

  @Builder
  buildHotCities() {
    Column({ space: 8 }) {
      Text('热门城市')
        .fontSize(13)
        .fontColor($r('sys.color.ohos_id_color_text_secondary'))
        .width('100%')
        .padding({ left: 16, top: 4 })
      Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
        ForEach(this.hotCities, (city: string) => {
          Text(city)
            .fontSize(14)
            .fontColor(this.currentCity === city ? $r('app.color.brand_green') : $r('sys.color.ohos_id_color_text_primary'))
            .fontWeight(this.currentCity === city ? FontWeight.Medium : FontWeight.Normal)
            .padding({
              left: 12,
              right: 12,
              top: 8,
              bottom: 8
            })
            .backgroundColor($r('sys.color.comp_background_primary'))
            .borderRadius(8)
            .margin({
              left: 5,
              right: 5,
              top: 5,
              bottom: 5
            })
            .onClick(() => this.selectCity(city))
        }, (city: string, index: number) => `hot_${city}_${index}`)
      }
      .width('100%')
      .padding({ left: 10, right: 10 })
    }
    .width('100%')
    .padding({ bottom: 8 })
  }

  @Builder
  buildCityGroup(group: CityGroup) {
    Column() {
      Text(group.letter)
        .fontSize(14)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('sys.color.ohos_id_color_text_primary'))
        .width('100%')
        .padding({ left: 16, top: 8, bottom: 6 })
        .backgroundColor($r('app.color.start_window_background'))
      ForEach(group.cities, (city: string) => {
        this.buildCityRow(city)
      }, (city: string, index: number) => `${group.letter}_${city}_${index}`)
    }
    .width('100%')
  }

  @Builder
  buildCityRow(city: string) {
    Row() {
      Text(city)
        .fontSize(15)
        .fontColor($r('sys.color.ohos_id_color_text_primary'))
        .fontWeight(FontWeight.Normal)
        .layoutWeight(1)
    }
    .width('100%')
    .padding({
      left: 16,
      right: 16,
      top: 14,
      bottom: 14
    })
    .onClick(() => this.selectCity(city))
  }
}

@Builder
export function CitySelectPageBuilder() {
  CitySelectPage();
}
