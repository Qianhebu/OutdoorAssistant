import { AbilityConstant, Configuration, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';
import { SafeAreaManager } from '../utils/SafeAreaManager';

const DOMAIN = 0x0000;

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    try {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    } catch (err) {
      hilog.error(DOMAIN, 'testTag', 'Failed to set colorMode. Cause: %{public}s', JSON.stringify(err));
    }

    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onCreate');
  }

  onDestroy(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onDestroy');
  }

  // 设置状态栏样式
  setStatusBarStyle(colorMode: ConfigurationConstant.ColorMode, windowClass: window.Window): void {
    hilog.info(DOMAIN, 'testTag', 'Setting status bar for colorMode: %{public}d', colorMode);

    if (colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK) {
      // 深色模式：状态栏文字为白色，背景为深色
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
      // 浅色模式：状态栏文字为黑色，背景为浅色
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

  onConfigurationUpdate(newConfig: Configuration): void {
    // 监听系统主题变化
    if (newConfig.colorMode !== undefined) {
      AppStorage.setOrCreate('colorMode', newConfig.colorMode);
      hilog.info(DOMAIN, 'testTag', 'Color mode changed to: %{public}d', newConfig.colorMode);

      // 获取缓存的窗口对象并更新状态栏样式
      let windowClass = AppStorage.get<window.Window>('mainWindow');
      if (windowClass) {
        this.setStatusBarStyle(newConfig.colorMode, windowClass);
      }
    }
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    // Main window is created, set main page for this ability
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageCreate');

    let mainWindow = windowStage.getMainWindowSync()

    // 缓存窗口对象到 AppStorage
    AppStorage.setOrCreate('mainWindow', mainWindow);

    // 获取当前主题模式
    let colorMode = this.context.config.colorMode ?? ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT;
    hilog.info(DOMAIN, 'testTag', 'Initial color mode: %{public}d', colorMode);
    AppStorage.setOrCreate('colorMode', colorMode);

    // 先设置全屏
    mainWindow.setWindowLayoutFullScreen(true).then(() => {
      hilog.info(DOMAIN, 'testTag', 'Window layout set to fullscreen');

      // 加载页面内容
      mainWindow.setUIContent('pages/Index').then(async () => {
        hilog.info(DOMAIN, 'testTag', 'Succeeded in loading the content.');
        
        // 页面加载完成后初始化安全区域管理器（此时 UIContext 可用）
        await SafeAreaManager.init(this.context, windowStage);
        hilog.info(DOMAIN, 'testTag', 'SafeAreaManager initialized');
        
        // 设置状态栏样式
        this.setStatusBarStyle(colorMode, mainWindow);
      }).catch((err: BusinessError) => {
        hilog.error(DOMAIN, 'testTag', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
      })
    }).catch((err: BusinessError) => {
      hilog.error(DOMAIN, 'testTag', 'Failed to set window layout fullscreen. Cause: %{public}s', JSON.stringify(err));
    })
  }

  onForeground(): void {
    // 应用进入前台时设置状态栏样式
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onForeground');

    let windowClass = AppStorage.get<window.Window>('mainWindow');
    if (windowClass) {
      let colorMode = this.context.config.colorMode ?? ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT;
      hilog.info(DOMAIN, 'testTag', 'onForeground color mode: %{public}d', colorMode);

      AppStorage.setOrCreate('colorMode', colorMode);
      this.setStatusBarStyle(colorMode, windowClass);
    }
  }

  onWindowStageDestroy(): void {
    // Main window is destroyed, release UI related resources
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageDestroy');
  }

  onBackground(): void {
    // Ability has back to background
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onBackground');
  }
}