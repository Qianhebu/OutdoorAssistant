import {
  hdsMaterial,
  HdsNavDestination,
  HdsNavDestinationTitleMode,
  HdsNavigation,
  HdsNavigationMenuItemOptions,
  HdsNavigationTitleMode,
  HdsTabsController,
  IconStyleMode,
  ScrollEffectType,
  TitleBarStyleOptions
} from '@kit.UIDesignKit';
import { LengthMetrics, promptAction } from '@kit.ArkUI';
import { authentication } from '@kit.AccountKit';
import type { BusinessError } from '@kit.BasicServicesKit';
import { util } from '@kit.ArkTS';
import { AppStorageKeys } from '../../common/AppStorageKeys';
import { PageEnum } from '../../common/PageEnum';
import { StorageKey } from '../../common/StorageKey';
import { PageContext } from '../../router/PageContext';

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
  @StorageLink(StorageKey.MINE_TAB_PAGE_CONTEXT) minePageContext: PageContext =
    AppStorage.get<PageContext>(StorageKey.MINE_TAB_PAGE_CONTEXT) ?? new PageContext();
  scroller: Scroller = new Scroller();
  homeTabController: HdsTabsController = new HdsTabsController();

  aboutToAppear(): void {
    if (this.minePageContext.navPathStack.size() === 0) {
      this.minePageContext.openPage({ routerName: PageEnum.MINE_LIST_VIEW }, false);
    }
  }

  build() {
    HdsNavigation(this.minePageContext.navPathStack) {
      MineTabContent({ scroller: this.scroller, homeTabController: this.homeTabController })
    }
    .mode(NavigationMode.Stack)
    .hideBackButton(true)
    .hideTitleBar(true)
    .titleMode(HdsNavigationTitleMode.MINI)
    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
    .width('100%')
    .height('100%')
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
            builder: wrapBuilder(SimpleSheetBuilder),
            // subtitle: '记录你的户外里程碑——首次登顶、累计里程、连续打卡等。完成挑战即可解锁成就徽章，持续探索解锁更多。'
          },
          {
            title: '我的收藏',
            icon: $r('sys.symbol.star'),
            builder: wrapBuilder(SimpleSheetBuilder),
            // subtitle: '你收藏的路线、景点和户外攻略都在这里。方便下次快速查看，离线时也能访问已下载的收藏内容。'
          },
          {
            title: '我的路线',
            icon: $r('sys.symbol.route'),
            builder: wrapBuilder(SimpleSheetBuilder),
            // subtitle: '查看你创建和参与的所有户外路线。包括徒步、骑行、登山等类型的路线记录和轨迹回放。'
          },
          {
            title: '离线地图',
            icon: $r('sys.symbol.local_badge_arrow_down'),
            builder: wrapBuilder(SimpleSheetBuilder),
            // subtitle: '管理已下载的离线地图包。在无网络环境下也能导航和查看路线，建议出发前提前下载目标区域地图。'
          },
          {
            title: '缓存管理',
            icon: $r('sys.symbol.archivebox'),
            builder: wrapBuilder(SimpleSheetBuilder),
            // subtitle: '查看和清理应用缓存数据，包括图片缓存、路线数据缓存和临时文件。释放存储空间，保持应用流畅运行。'
          }
        ]
      },
      {
        items: [
          {
            title: '更新日志',
            icon: $r('sys.symbol.doc_plaintext'),
            builder: wrapBuilder(SimpleSheetBuilder),
            // subtitle: '查看 Outdoor 助手的版本更新记录。了解每次更新带来的新功能、优化和问题修复。'
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
            builder: wrapBuilder(SimpleSheetBuilder),
            // subtitle: '汇总用户常见问题及解答，包括账号登录、健康数据同步、离线地图下载、路线导航等使用指南。'
          },
          {
            title: '意见与反馈',
            icon: $r('sys.symbol.square_and_pencil'),
            onclick: () => {
              const navParam: MineDetailNavParam = {
                title: '意见与反馈',
                subtitle: '告诉我们你的体验问题和改进建议',
                // detail: '你可以反馈路线推荐、活动记录、健康授权、离线地图或界面体验中的问题，也可以提交希望增加的新功能。我们会根据反馈持续优化 Outdoor 的户外助手能力。'
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
            subtitle: '告诉我们你的体验问题和改进建议',
            // detail: '你可以反馈路线推荐、活动记录、健康授权、离线地图或界面体验中的问题，也可以提交希望增加的新功能。我们会根据反馈持续优化 Outdoor 的户外助手能力。'
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
          preferType: SheetType.BOTTOM,
          blurStyle: BlurStyle.Regular,
          detents: [SheetSize.LARGE],
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
          .fontColor(['#00A991'])
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
      left: 6,
      right: 6,
      top: 6,
      bottom: 6
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
        .color('rgba(0, 0, 0, 0.06)')
        .margin({ left: 68, right: 12 })
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
          .fontColor(['#00A991'])
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

@Builder
export function MineTabContentViewBuilder() {
  MineTabContent();
}
