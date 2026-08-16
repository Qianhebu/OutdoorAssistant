import {
  hdsMaterial,
  HdsNavDestination,
  HdsNavDestinationTitleMode,
  HdsNavigationMenuItemOptions,
  HdsTabsController,
  IconStyleMode,
  ScrollEffectType,
  TitleBarStyleOptions
} from '@kit.UIDesignKit';
import { LengthMetrics, promptAction } from '@kit.ArkUI';
import { authentication } from '@kit.AccountKit';
import type { BusinessError } from '@kit.BasicServicesKit';
import { util } from '@kit.ArkTS';
import { AppStorageKeys } from '@ohos/common';
import { PageEnum } from '@ohos/common';
import { StorageKey } from '@ohos/common';
import { PageContext } from '@ohos/common';

@Observed
class MineItem {
  title: string = '';
  subtitle?: string = undefined;
  icon?: Resource = undefined;
  onclick?: () => void = undefined;
  builder?: WrappedBuilder<[]> = undefined;
}

@Observed
class MineSection {
  items: MineItem[] = [];
}

interface MineDetailNavParam {
  title: string;
  subtitle?: string;
  detail?: string;
}

@Component({ freezeWhenInactive: true })
export struct MineTab {
  scroller: Scroller = new Scroller();
  homeTabController: HdsTabsController = new HdsTabsController();

  build() {
    MineTabContent({ scroller: this.scroller, homeTabController: this.homeTabController })
  }
}

@Component
struct MineTabContent {
  @StorageLink(AppStorageKeys.TOP_INSET) topInset: number = 0;
  @StorageLink(AppStorageKeys.BOTTOM_INSET) bottomInset: number = 0;
  @StorageLink(StorageKey.HOME_PAGE_CONTEXT) appPageContext: PageContext =
    AppStorage.get<PageContext>(StorageKey.HOME_PAGE_CONTEXT) ?? new PageContext();
  @State sheetVisible: boolean = false;
  @State currentSheetItem?: MineItem = undefined;
  @State isLogin: boolean = false;
  @State nickname: string = '点击登录账号';
  @State avatarUrl: string = '';
  @State accountCardHover: boolean = false;
  @State accountCardPressed: boolean = false;
  @State hoverItemTitle: string = '';
  @State pressedItemTitle: string = '';
  scroller: Scroller = new Scroller();
  homeTabController: HdsTabsController = new HdsTabsController();
  private titleBarStyle: TitleBarStyleOptions = {
    systemMaterialEffect: {
      materialType: hdsMaterial.MaterialType.IMMERSIVE,
      materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
    },
    scrollEffectOpts: {
      enableScrollEffect: true,
      scrollEffectType: ScrollEffectType.IMMERSIVE_GRADIENT_BLUR,
      blurEffectiveStartOffset: LengthMetrics.vp(24),
      blurEffectiveEndOffset: LengthMetrics.vp(112)
    },
    originalStyle: {
      backgroundStyle: { backgroundColor: Color.Transparent, maskExtraHeight: 24, blurRadius: 12 },
      contentStyle: {
        titleStyle: {
          mainTitleColor: $r('sys.color.font_primary')
        },
        menuStyle: {
          backgroundColor: $r('sys.color.comp_background_tertiary'),
          iconColor: $r('sys.color.icon_primary')
        }
      }
    },
    scrollEffectStyle: {
      backgroundStyle: { backgroundColor: $r('sys.color.background_secondary'), maskExtraHeight: 32, blurRadius: 18 },
      contentStyle: {
        menuStyle: {
          backgroundColor: $r('sys.color.comp_background_tertiary'),
          iconColor: $r('sys.color.icon_primary')
        }
      }
    }
  };

  private openPage(routerName: PageEnum, param?: object): void {
    this.appPageContext.openPage({ routerName: routerName, param: param }, true);
  }

  private openSheet(item: MineItem): void {
    this.currentSheetItem = item;
    this.sheetVisible = true;
  }

  private async loginWithHuaweiAccount(): Promise<void> {
    if (this.isLogin) {
      const sheetItem: MineItem = {
        title: '账号信息',
        subtitle: this.nickname,
        builder: wrapBuilder(AccountSheetBuilder)
      };
      this.openSheet(sheetItem);
      return;
    }
    try {
      const authRequest = new authentication.HuaweiIDProvider().createAuthorizationWithHuaweiIDRequest();
      authRequest.scopes = ['profile'];
      authRequest.permissions = ['serviceauthcode'];
      authRequest.forceAuthorization = true;
      authRequest.state = util.generateRandomUUID();
      authRequest.idTokenSignAlgorithm = authentication.IdTokenSignAlgorithm.PS256;
      const controller = new authentication.AuthenticationController(this.getUIContext().getHostContext());
      const result = await controller.executeRequest(authRequest);
      const response = result as authentication.AuthorizationWithHuaweiIDResponse;
      if (response.state !== undefined && response.state !== authRequest.state) {
        promptAction.showToast({ message: '账号登录校验失败' });
        return;
      }
      const credential = response.data;
      if (!credential) {
        promptAction.showToast({ message: '未获取到账号信息' });
        return;
      }
      this.nickname = credential.nickName || '华为账号用户';
      this.avatarUrl = credential.avatarUri || '';
      this.isLogin = true;
      promptAction.showToast({ message: '登录成功' });
    } catch (err) {
      const error = err as BusinessError;
      const message = error?.code ? `登录失败：${error.code}` : '登录取消或失败';
      promptAction.showToast({ message });
      console.error(`Login with Huawei Account failed, code: ${error?.code}, message: ${error?.message}`);
    }
  }

  private handleItemClick(item: MineItem): void {
    if (item.onclick) {
      item.onclick();
    } else if (item.builder) {
      this.openSheet(item);
    }
  }

  private buildSections(): MineSection[] {
    return [
      {
        items: [
          {
            title: '我的成就',
            icon: $r('sys.symbol.medal'),
            builder: wrapBuilder(SimpleSheetBuilder)
          },
          {
            title: '我的收藏',
            icon: $r('sys.symbol.star'),
            builder: wrapBuilder(SimpleSheetBuilder)
          },
          {
            title: '我的路线',
            icon: $r('sys.symbol.route'),
            builder: wrapBuilder(SimpleSheetBuilder)
          },
          {
            title: '离线地图',
            icon: $r('sys.symbol.local_badge_arrow_down'),
            builder: wrapBuilder(SimpleSheetBuilder)
          },
          {
            title: '缓存管理',
            icon: $r('sys.symbol.archivebox'),
            builder: wrapBuilder(SimpleSheetBuilder)
          }
        ]
      },
      {
        items: [
          {
            title: '更新日志',
            icon: $r('sys.symbol.doc_plaintext'),
            builder: wrapBuilder(SimpleSheetBuilder)
          },
          {
            title: '关于应用',
            icon: $r('sys.symbol.info_circle'),
            onclick: () => {
              const navParam: MineDetailNavParam = {
                title: '关于应用',
                detail: 'Outdoor 助手——你的户外运动伴侣，提供路线推荐、活动记录、健康同步和离线地图等能力。'
              };
              this.openPage(PageEnum.MINE_DETAIL, navParam);
            }
          },
          {
            title: '隐私政策',
            icon: $r('sys.symbol.lock_shield'),
            onclick: () => {
              this.openPage(PageEnum.PRIVACY_POLICY);
            }
          }
        ]
      },
      {
        items: [
          {
            title: '常见问题',
            icon: $r('sys.symbol.questionmark_circle'),
            builder: wrapBuilder(SimpleSheetBuilder)
          },
          {
            title: '意见与反馈',
            icon: $r('sys.symbol.square_and_pencil'),
            onclick: () => {
              const navParam: MineDetailNavParam = {
                title: '意见与反馈',
                subtitle: '告诉我们你的体验问题和改进建议'
              };
              this.openPage(PageEnum.MINE_DETAIL, navParam);
            }
          }
        ]
      }
    ];
  }

  private menuItems: HdsNavigationMenuItemOptions[] = [
    {
      content: {
        icon: $r('sys.symbol.dot_grid_2x2'),
        type: IconStyleMode.NORMAL,
        isEnabled: true,
        label: 'feedback',
        action: () => {
          const navParam: MineDetailNavParam = {
            title: '意见与反馈',
            subtitle: '告诉我们你的体验问题和改进建议'
          };
          this.openPage(PageEnum.MINE_DETAIL, navParam);
        }
      }
    }
  ];

  build() {
    HdsNavDestination() {
      Scroll(this.scroller) {
        Flex({ direction: FlexDirection.Column, alignItems: ItemAlign.Start }) {
          this.buildAccountCard();
          ForEach(this.buildSections(), (section: MineSection, index: number) => {
            this.buildMineSection(section);
          }, (section: MineSection, index: number) => `mine_section_${index}`)
        }
        .width('100%')
        .padding({
          left: 16,
          right: 16,
          top: 56,
          bottom: this.bottomInset + 104
        })

        .bindSheet(this.sheetVisible, this.currentSheetItem?.builder?.builder(), {
          showClose: true,
          backgroundColor: $r('sys.color.comp_background_primary'),
          preferType: SheetType.BOTTOM,
          blurStyle: BlurStyle.Thin,
          detents: [SheetSize.LARGE, SheetSize.MEDIUM],
          title: { title: this.currentSheetItem?.title ?? '', subtitle: '' },
          onWillDisappear: () => {
            this.sheetVisible = false;
          }
        })
      }
      .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
      .scrollBar(BarState.Off)
      .height('100%')
      .width('100%')
      .backgroundColor($r('app.color.start_window_background'))
    }
    .titleBar({
      avoidLayoutSafeArea: true,
      content: { title: { mainTitle: '我的' }, menu: { value: this.menuItems } },
      style: this.titleBarStyle
    })
    .bindToScrollable([this.scroller])
    .hideBackButton(true)
    .titleMode(HdsNavDestinationTitleMode.MINI)
    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
    .backgroundColor($r('app.color.start_window_background'))
    .width('100%')
    .height('100%')
  }

  @Builder
  buildAccountCard() {
    Flex({ direction: FlexDirection.Row, alignItems: ItemAlign.Center }) {
      if (this.isLogin && this.avatarUrl.length > 0) {
        Image(this.avatarUrl)
          .width(48)
          .height(48)
          .borderRadius(24)
          .objectFit(ImageFit.Cover)
      } else {
        SymbolGlyph($r('sys.symbol.boy'))
          .fontSize(48)
          .fontColor([$r('app.color.brand_green')])
      }

      Column({ space: 4 }) {
        Text(this.nickname)
          .fontColor($r('sys.color.ohos_id_color_text_primary'))
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
        Text(this.isLogin ? '已登录华为账号' : '使用华为账号同步户外数据')
          .fontColor($r('sys.color.ohos_id_color_text_secondary'))
          .fontSize(12)
      }
      .alignItems(HorizontalAlign.Start)
      .margin({ left: 12 })
      .layoutWeight(1)

      SymbolGlyph($r('sys.symbol.chevron_right'))
        .fontSize(16)
        .fontColor([$r('sys.color.ohos_id_color_text_secondary')])
    }
    .width('100%')
    .padding(12)
    .margin({ bottom: 12 })
    .backgroundColor((this.accountCardHover || this.accountCardPressed) ? $r('sys.color.comp_background_tertiary') :
      $r('sys.color.comp_background_primary'))
    .borderRadius(24)
    .onHover((isHover: boolean) => {
      this.accountCardHover = isHover;
    })
    .onTouch((event: TouchEvent) => {
      if (event.type === TouchType.Down) {
        this.accountCardPressed = true;
      } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        this.accountCardPressed = false;
      }
    })
    .onClick(() => {
      this.loginWithHuaweiAccount();
    })
  }

  @Builder
  buildMineSection(section: MineSection) {
    Column() {
      ForEach(section.items, (item: MineItem, index: number) => {
        this.buildMineItem(item, index < section.items.length - 1);
      }, (item: MineItem, index: number) => `${item.title}_${index}`)
    }
    .width('100%')
    .padding({
      left: 4,
      right: 4,
      top: 4,
      bottom: 4
    })
    .margin({ bottom: 12 })
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(22)
  }

  @Builder
  buildMineItem(item: MineItem, showDivider: boolean) {
    Column() {
      Row({ space: 12 }) {
        if (item.icon) {
          SymbolGlyph(item.icon)
            .fontSize(21)
            .fontColor([$r('sys.color.icon_primary')])
        }

        Column({ space: 4 }) {
          Text(item.title)
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.ohos_id_color_text_primary'))
          if (item.subtitle && item.subtitle.length > 0) {
            Text(item.subtitle)
              .fontSize(12)
              .fontColor($r('sys.color.ohos_id_color_text_secondary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
        }.alignItems(HorizontalAlign.Start).layoutWeight(1)

        SymbolGlyph($r('sys.symbol.chevron_right'))
          .fontSize(16)
          .fontColor([$r('sys.color.ohos_id_color_text_secondary')])
      }
      .width('100%')
      .padding({
        left: 12,
        right: 12,
        top: 14,
        bottom: 14
      })
      .backgroundColor((this.hoverItemTitle === item.title || this.pressedItemTitle === item.title) ?
        $r('sys.color.comp_background_tertiary') : Color.Transparent)
      .borderRadius(16)
      .onHover((isHover: boolean) => {
        this.hoverItemTitle = isHover ? item.title : '';
      })
      .onTouch((event: TouchEvent) => {
        if (event.type === TouchType.Down) {
          this.pressedItemTitle = item.title;
        } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
          this.pressedItemTitle = '';
        }
      })
      .onClick(() => this.handleItemClick(item))

      Divider()
        .color($r('sys.color.ohos_id_color_list_separator'))
        .margin({ left: 46, right: 14 })
        .visibility(showDivider ? Visibility.Visible : Visibility.None)
    }.width('100%')
  }
}

@Component
struct SimpleSheetContent {
  @Prop detail: string = '';

  build() {
    Column({ space: 16 }) {
      Text(this.detail)
        .fontSize(15)
        .lineHeight(22)
        .textAlign(TextAlign.Center)
        .fontColor($r('sys.color.ohos_id_color_text_secondary'))
    }
    .width('100%')
    .padding({
      left: 24,
      right: 24,
      top: 8,
      bottom: 24
    })
    .alignItems(HorizontalAlign.Center)
  }
}

@Component
struct AccountSheetContent {
  @StorageLink(StorageKey.HOME_PAGE_CONTEXT) appPageContext: PageContext =
    AppStorage.get<PageContext>(StorageKey.HOME_PAGE_CONTEXT) ?? new PageContext();
  @Prop nickname: string = '';
  @Prop avatarUrl: string = '';

  build() {
    Column({ space: 16 }) {
      if (this.avatarUrl.length > 0) {
        Image(this.avatarUrl)
          .width(64)
          .height(64)
          .borderRadius(32)
          .objectFit(ImageFit.Cover)
      } else {
        SymbolGlyph($r('sys.symbol.person_crop_circle_fill'))
          .fontSize(64)
          .fontColor([$r('app.color.brand_green')])
      }
      Text(this.nickname)
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.ohos_id_color_text_primary'))
      Text('当前已登录华为账号，可同步活动记录、路线收藏、健康数据和户外偏好。')
        .fontSize(15)
        .lineHeight(22)
        .textAlign(TextAlign.Center)
        .fontColor($r('sys.color.ohos_id_color_text_secondary'))
    }
    .width('100%')
    .padding({
      left: 24,
      right: 24,
      top: 8,
      bottom: 24
    })
    .alignItems(HorizontalAlign.Center)
  }
}

@Builder
function SimpleSheetBuilder() {
  SimpleSheetContent();
}

@Builder
function AccountSheetBuilder() {
  AccountSheetContent();
}
