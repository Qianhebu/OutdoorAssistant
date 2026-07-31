import { common } from '@kit.AbilityKit';
import { window, UIContext } from '@kit.ArkUI';

/**
 * 安全区域信息接口
 */
export interface SafeAreaInfo {
  topInset: number;
  bottomInset: number;
}

/**
 * 安全区域管理器
 * 
 * 用于管理应用的安全区域信息（状态栏高度、导航栏高度等）
 * 使用 AppStorage 存储全局数据，所有页面都可以访问
 * 
 * @example
 * ```arkts
 * // 在 Ability 的 onWindowStageCreate 中初始化
 * SafeAreaManager.init(context, windowStage)
 * 
 * // 在页面中使用
 * @StorageLink('topInset') topInset: number = 0
 * @StorageLink('bottomInset') bottomInset: number = 0
 * ```
 */
export class SafeAreaManager {
  private static instance: SafeAreaManager | null = null;
  private context: common.UIAbilityContext | null = null;
  private uiContext: UIContext | null = null;
  
  // 私有构造函数，单例模式
  private constructor() {}
  
  /**
   * 获取单例实例
   */
  static getInstance(): SafeAreaManager {
    if (!SafeAreaManager.instance) {
      SafeAreaManager.instance = new SafeAreaManager();
    }
    return SafeAreaManager.instance;
  }
  
  /**
   * 初始化安全区域管理器
   * 应在 Ability 的 onWindowStageCreate 中调用
   * 
   * @param context - UIAbility 上下文
   * @param windowStage - 窗口舞台，用于获取 UIContext
   */
  static async init(context: common.UIAbilityContext, windowStage: window.WindowStage): Promise<void> {
    const manager = SafeAreaManager.getInstance();
    manager.context = context;
    
    // 获取 UIContext 用于单位转换
    try {
      const mainWindow = windowStage.getMainWindowSync();
      manager.uiContext = mainWindow.getUIContext();
    } catch (err) {
      const errorMsg = err instanceof Error ? err.message : String(err);
      console.error('SafeAreaManager: Failed to get UIContext:', errorMsg);
    }
    
    await manager.updateSafeAreaInsets();
  }
  
  /**
   * 更新安全区域信息
   * 将数据存储到 AppStorage 中供全局访问
   */
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
      
      // 获取顶部系统栏（状态栏）避让区域
      const topArea = wind.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
      const topInset = this.uiContext.px2vp(topArea.topRect.height);
      
      // 获取底部导航条避让区域
      const bottomArea = wind.getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR);
      const bottomInset = this.uiContext.px2vp(bottomArea.bottomRect.height);
      
      // 存储到 AppStorage
      AppStorage.setOrCreate('topInset', topInset);
      AppStorage.setOrCreate('bottomInset', bottomInset);
      
      console.info(`SafeAreaManager: topInset=${topInset}, bottomInset=${bottomInset}`);
    } catch (err) {
      const errorMsg = err instanceof Error ? err.message : String(err);
      console.error('SafeAreaManager: Failed to get avoid area:', errorMsg);
    }
  }
  
  /**
   * 获取当前的安全区域信息
   */
  static getSafeAreaInfo(): SafeAreaInfo {
    const topInset = AppStorage.get<number>('topInset');
    const bottomInset = AppStorage.get<number>('bottomInset');
    
    return {
      topInset: topInset !== undefined ? topInset : 0,
      bottomInset: bottomInset !== undefined ? bottomInset : 0
    };
  }
}
