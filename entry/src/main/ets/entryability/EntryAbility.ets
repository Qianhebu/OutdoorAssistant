import { AbilityConstant, Configuration, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';
import { SafeAreaManager } from '@ohos/common';
import { AppStorageKeys } from '@ohos/common';
import { StorageKey } from '@ohos/common';
import { PageContext } from '@ohos/common';


const DOMAIN = 0x0000;
const TAG = 'OutdoorAssistant';

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    this.initColorMode()
    hilog.info(DOMAIN, TAG, 'Ability onCreate')
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    let mainWindow = windowStage.getMainWindowSync()

    AppStorage.setOrCreate(AppStorageKeys.HOST_CONTEXT, this.context);
    AppStorage.setOrCreate(AppStorageKeys.MAIN_WINDOW, mainWindow);
    AppStorage.setOrCreate(StorageKey.HOME_PAGE_CONTEXT, new PageContext());

    let colorMode = this.context.config.colorMode ?? ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT;
    AppStorage.setOrCreate(AppStorageKeys.COLOR_MODE, colorMode);

    mainWindow.setUIContent('pages/SplashPage')
      .then(async () => {
        mainWindow.getUIContext().getFont().registerFont({
          familyName: 'SmileySans',
          familySrc: $rawfile('SmileySans-Oblique.ttf')
        });
        await SafeAreaManager.init(this.context, windowStage)
        this.updateSystemBarStyle(colorMode, mainWindow)
        hilog.info(DOMAIN, TAG, 'SplashPage loaded')
      })
      .catch((err: BusinessError) => {
        hilog.error(DOMAIN, TAG, 'Window init failed: %{public}s', JSON.stringify(err));
      })
  }

  onConfigurationUpdate(newConfig: Configuration): void {
    if (newConfig.colorMode === undefined) {
      return
    }

    AppStorage.setOrCreate(AppStorageKeys.COLOR_MODE, newConfig.colorMode);
    hilog.info(DOMAIN, TAG, 'Color mode changed to: %{public}d', newConfig.colorMode);

    let mainWindow = AppStorage.get<window.Window>(AppStorageKeys.MAIN_WINDOW);
    if (mainWindow) {
      this.updateSystemBarStyle(newConfig.colorMode, mainWindow)
    }
  }

  onForeground(): void {
    AppStorage.setOrCreate(AppStorageKeys.IS_FOREGROUND, true);
    let colorMode = this.context.config.colorMode ?? ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT;
    let mainWindow = AppStorage.get<window.Window>(AppStorageKeys.MAIN_WINDOW);

    AppStorage.setOrCreate(AppStorageKeys.COLOR_MODE, colorMode)
    if (mainWindow) {
      this.updateSystemBarStyle(colorMode, mainWindow)
    }
  }

  onDestroy(): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onDestroy');
  }

  onWindowStageDestroy(): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onWindowStageDestroy');
  }

  onBackground(): void {
    AppStorage.setOrCreate(AppStorageKeys.IS_FOREGROUND, false);
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onBackground');
  }


  private initColorMode(): void {
    try {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET)
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Set color mode failed: %{public}s', JSON.stringify(err));
    }
  }

  private updateSystemBarStyle(colorMode: ConfigurationConstant.ColorMode, mainWindow: window.Window): void {
    let isDark = colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK
    mainWindow.setWindowSystemBarProperties({
      statusBarContentColor: isDark ? '#FFFFFF' : '#000000',
      navigationBarContentColor: isDark ? '#FFFFFF' : '#000000'
    }).catch((err: BusinessError) => {
      hilog.error(DOMAIN, TAG, 'Set system bar failed: %{public}s', JSON.stringify(err))
    })
  }
}
