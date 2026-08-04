import { ConfigurationConstant } from '@kit.AbilityKit';
import { HdsNavigation } from '@kit.UIDesignKit';
import { AppStorageKeys } from '../constant/AppStorageKeys';
import { PageEnum } from '../constant/PageEnum';
import { StorageKey } from '../constant/StorageKey';
import { PageContext, RouterParam } from '../router/PageContext';

const SPLASH_DURATION = 500;

@Entry
@Component
struct SplashPage {
  @StorageProp(AppStorageKeys.COLOR_MODE) colorMode: ConfigurationConstant.ColorMode =
    AppStorage.get<ConfigurationConstant.ColorMode>(AppStorageKeys.COLOR_MODE) ??
      ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT;
  @StorageLink(StorageKey.HOME_PAGE_CONTEXT) pageContext: PageContext =
    AppStorage.get<PageContext>(StorageKey.HOME_PAGE_CONTEXT) ?? new PageContext();
  private appPathInfo: NavPathStack = this.pageContext.navPathStack;

  aboutToAppear(): void {
    setTimeout(() => {
      const routerParam: RouterParam = {
        routerName: PageEnum.MAIN_PAGE
      };
      AppStorage.get<PageContext>(StorageKey.HOME_PAGE_CONTEXT)?.replacePage(routerParam, false);
    }, SPLASH_DURATION);
  }

  build() {
    WithTheme({
      colorMode: this.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK ?
        ThemeColorMode.DARK : ThemeColorMode.LIGHT
    }) {
      HdsNavigation(this.appPathInfo) {
        this.buildSplashContent()
      }
      .withTheme({ enableThemeColorMode: true })
      .hideTitleBar(true)
      .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
      .mode(NavigationMode.Stack)
      .height('100%')
      .width('100%')
    }
  }

  @Builder
  buildSplashContent() {
    Stack({ alignContent: Alignment.Center }) {
      Column({ space: 16 }) {
        Image($r('app.media.startIcon'))
          .width(88)
          .height(88)
          .borderRadius(24)

        Text('Outdoor Assistant')
          .fontSize(28)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('sys.color.ohos_id_color_text_primary'))

        Text('轻户外路线与活动助手')
          .fontSize(14)
          .fontColor($r('sys.color.ohos_id_color_text_secondary'))
      }
      .alignItems(HorizontalAlign.Center)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.start_window_background'))
  }
}
