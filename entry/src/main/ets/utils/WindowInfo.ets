import { display, window } from '@kit.ArkUI';
import { AppStorageKeys } from '../constant/AppStorageKeys';

export class WindowInfo {
  public static windowWidth_px: number = 0;
  public static windowHeight_px: number = 0;
  public static topAvoidAreaHeight_px: number = 0;

  public static init(mainWindow: window.Window): void {
    let displayInfo = display.getDefaultDisplaySync();
    WindowInfo.windowWidth_px = displayInfo.width;
    WindowInfo.windowHeight_px = displayInfo.height;
    let avoidArea = mainWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
    WindowInfo.topAvoidAreaHeight_px = avoidArea.topRect.height;
  }
}
