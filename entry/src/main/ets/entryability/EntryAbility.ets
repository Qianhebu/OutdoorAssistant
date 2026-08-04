import { AbilityConstant, Configuration, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';
import { SafeAreaManager } from '../utils/SafeAreaManager';
import { AppStorageKeys } from '../constant/AppStorageKeys';
import { StorageKey } from '../constant/StorageKey';
import { PageContext } from '../router/PageContext';
import { WindowInfo } from '../utils/WindowInfo';

const DOMAIN = 0x0000;
const TAG = 'OutdoorAssistant';

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    this.initColorMode()
    hilog.info(DOMAIN, TAG, 'Ability onCreate')
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    let mainWindow = windowStage.getMainWindowSync()

    AppStorage.setOrCreate(AppStorageKeys.MAIN_WINDOW, mainWindow);
    AppStorage.setOrCreate(StorageKey.HOME_PAGE_CONTEXT, new PageContext());

    let colorMode = this.context.config.colorMode ?? ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT;
    AppStorage.setOrCreate(AppStorageKeys.COLOR_MODE, colorMode);

    mainWindow.setUIContent('pages/SplashPage')
      .then(async () => {
        await SafeAreaManager.init(this.context, windowStage)
        WindowInfo.init(mainWindow)
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
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onBackground');
  }

  setStatusBarStyle(colorMode: ConfigurationConstant.ColorMode, windowClass: window.Window): void {
    hilog.info(DOMAIN, 'testTag', 'Setting status bar for colorMode: %{public}d', colorMode);

    if (colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK) {
      windowClass.setWindowSystemBarProperties({
        statusBarContentColor: '#FFFFFF',
        navigationBarContentColor: '#FFFFFF'
      }).then(() => {
        hilog.info(DOMAIN, 'testTag', 'Dark mode status bar set successfully');
      }).catch((err: BusinessError) => {
        hilog.error(DOMAIN, 'testTag', 'Failed to set dark mode status bar. Code: %{public}d, Message: %{public}s',
          err.code, err.message);
      });
    } else {
      windowClass.setWindowSystemBarProperties({
        statusBarContentColor: '#000000',
        navigationBarContentColor: '#000000'
      }).then(() => {
        hilog.info(DOMAIN, 'testTag', 'Light mode status bar set successfully');
      }).catch((err: BusinessError) => {
        hilog.error(DOMAIN, 'testTag', 'Failed to set light mode status bar. Code: %{public}d, Message: %{public}s',
          err.code, err.message);
      });
    }
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