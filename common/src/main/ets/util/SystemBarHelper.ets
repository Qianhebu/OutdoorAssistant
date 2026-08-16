import { ConfigurationConstant } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { AppStorageKeys } from '../constant/AppStorageKeys';

/**
 * 统一更新状态栏文字颜色，遵循暗色主题。
 * @param isLightBackground 是否处于浅色背景（如首页 Banner 区域），此时固定使用白色文字
 */
export function updateStatusBarContentColor(isLightBackground: boolean): void {
  const colorMode: ConfigurationConstant.ColorMode =
    AppStorage.get<ConfigurationConstant.ColorMode>(AppStorageKeys.COLOR_MODE) ??
      ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT;
  const isDark: boolean = colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
  // 状态栏文字颜色：setWindowSystemBarProperties 仅接受 string 色值
  const color: string = isLightBackground || isDark ? '#FFFFFF' : '#000000';
  const mainWindow = AppStorage.get<window.Window>(AppStorageKeys.MAIN_WINDOW);
  mainWindow?.setWindowSystemBarProperties({
    statusBarContentColor: color
  });
}
