import type { common } from '@kit.AbilityKit';
import { ConfigurationConstant } from '@kit.AbilityKit';
import { promptAction } from '@kit.ArkUI';
import { HdsNavDestination } from '@kit.UIDesignKit';
import { AppStorageKeys } from '../constant/AppStorageKeys';
import { OutdoorTabType } from '../model/TabBarModel';
import { HomeView } from './HomeView';

const BACK_PRESS_INTERVAL = 1500;

@Builder
export function MainPageBuilder() {
  MainPage()
}

@Component
struct MainPage {
  @StorageProp(AppStorageKeys.COLOR_MODE) colorMode: ConfigurationConstant.ColorMode =
    AppStorage.get<ConfigurationConstant.ColorMode>(AppStorageKeys.COLOR_MODE) ??
      ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT;
  @State currentIndex: number = OutdoorTabType.HOME;
  @State isShown: boolean = false;
  private backPressTime: number = 0;

  private handlePageShow(): void {
    this.isShown = true;
    AppStorage.setOrCreate(AppStorageKeys.CURRENT_TAB, this.currentIndex);
  }

  private handleBackPress(): boolean {
    const now = Date.now();
    if (this.backPressTime > 0 && now - this.backPressTime < BACK_PRESS_INTERVAL) {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      context.moveAbilityToBackground();
      return true;
    }
    this.backPressTime = now;
    promptAction.showToast({ message: '再按一次退出应用' });
    return true;
  }

  build() {
    HdsNavDestination() {
      HomeView({
        currentIndex: this.currentIndex,
        isShown: this.isShown
      })
    }
    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
    .hideTitleBar(true)
    .backgroundColor($r('sys.color.background_secondary'))
    .onBackPressed(() => {
      return this.handleBackPress();
    })
    .onShown(() => {
      this.handlePageShow();
    })
    .onHidden(() => {
      this.isShown = false;
    })
    .height('100%')
    .width('100%')
  }
}
