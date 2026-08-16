import { common } from '@kit.AbilityKit';
import { window, UIContext } from '@kit.ArkUI';

export interface SafeAreaInfo {
  topInset: number;
  bottomInset: number;
}

export class SafeAreaManager {
  private static instance: SafeAreaManager | null = null;
  private context: common.UIAbilityContext | null = null;
  private uiContext: UIContext | null = null;
  
  private constructor() {}
  
  static getInstance(): SafeAreaManager {
    if (!SafeAreaManager.instance) {
      SafeAreaManager.instance = new SafeAreaManager();
    }
    return SafeAreaManager.instance;
  }
  
  static async init(context: common.UIAbilityContext, windowStage: window.WindowStage): Promise<void> {
    const manager = SafeAreaManager.getInstance();
    manager.context = context;
    
    try {
      const mainWindow = windowStage.getMainWindowSync();
      manager.uiContext = mainWindow.getUIContext();
    } catch (err) {
      const errorMsg = err instanceof Error ? err.message : String(err);
      console.error('SafeAreaManager: Failed to get UIContext:', errorMsg);
    }
    
    await manager.updateSafeAreaInsets();
  }
  
  async updateSafeAreaInsets(): Promise<void> {
    if (!this.context) {
      console.error('SafeAreaManager: context is null, please call init() first');
      return;
    }
    
    if (!this.uiContext) {
      console.error('SafeAreaManager: uiContext is null, please call init() first');
      return;
    }
    
    try {
      const wind = await window.getLastWindow(this.context);
      
      const topArea = wind.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
      const topInset = this.uiContext.px2vp(topArea.topRect.height);
      
      const bottomArea = wind.getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR);
      const bottomInset = this.uiContext.px2vp(bottomArea.bottomRect.height);
      
      AppStorage.setOrCreate('topInset', topInset);
      AppStorage.setOrCreate('bottomInset', bottomInset);
      
      console.info(`SafeAreaManager: topInset=${topInset}, bottomInset=${bottomInset}`);
    } catch (err) {
      const errorMsg = err instanceof Error ? err.message : String(err);
      console.error('SafeAreaManager: Failed to get avoid area:', errorMsg);
    }
  }
  
  static getSafeAreaInfo(): SafeAreaInfo {
    const topInset = AppStorage.get<number>('topInset');
    const bottomInset = AppStorage.get<number>('bottomInset');
    
    return {
      topInset: topInset !== undefined ? topInset : 0,
      bottomInset: bottomInset !== undefined ? bottomInset : 0
    };
  }
}
