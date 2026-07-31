# 工具类使用指南

本目录包含可复用的工具类，用于简化开发并提供通用功能。

## 📁 文件结构

```
utils/
├── SafeAreaManager.ets        # 安全区域管理器
├── HealthServiceHelper.ets    # 健康服务辅助类
└── README.md                  # 本文档
```

---

## 📱 SafeAreaManager - 安全区域管理器

### 功能特性
- ✅ 统一管理安全区域信息（状态栏、导航栏高度）
- ✅ 使用 AppStorage 全局存储，所有页面共享
- ✅ 单例模式，确保数据一致性
- ✅ 使用 UIContext.px2vp() 进行单位转换（官方推荐）

### 初始化

在 `EntryAbility.ets` 中已自动初始化：

```arkts
import { SafeAreaManager } from '../utils/SafeAreaManager';

export default class EntryAbility extends UIAbility {
  onWindowStageCreate(windowStage: window.WindowStage): void {
    // 设置全屏
    mainWindow.setWindowLayoutFullScreen(true).then(() => {
      // 初始化安全区域管理器（传入 windowStage 获取 UIContext）
      SafeAreaManager.init(this.context, windowStage);
      
      // 加载页面
      mainWindow.setUIContent('pages/Index');
    })
  }
}
```

### 使用方法

#### 方式一：@StorageLink 直接绑定（推荐）⭐

```arkts
@Entry
@Component
struct MyPage {
  // 直接从 AppStorage 获取安全区域信息
  @StorageLink('topInset') topInset: number = 0
  @StorageLink('bottomInset') bottomInset: number = 0
  
  build() {
    Column() {
      Text('页面内容')
    }
    .padding({
      top: this.topInset,      // 状态栏高度
      bottom: this.bottomInset  // 导航栏高度
    })
  }
}
```

#### 方式二：使用 SafeAreaManager 工具类

```arkts
import { SafeAreaManager, SafeAreaInfo } from '../utils/SafeAreaManager';

@Entry
@Component
struct MyPage {
  @State safeAreaInfo: SafeAreaInfo = { topInset: 0, bottomInset: 0 }
  
  aboutToAppear(): void {
    // 获取当前安全区域信息
    this.safeAreaInfo = SafeAreaManager.getSafeAreaInfo()
  }
  
  build() {
    Column() {
      Text('页面内容')
    }
    .padding({
      top: this.safeAreaInfo.topInset,
      bottom: this.safeAreaInfo.bottomInset
    })
  }
}
```

### API 说明

#### SafeAreaManager.init(context, windowStage)
初始化安全区域管理器，应在 Ability 的 `onWindowStageCreate` 中调用。

| 参数 | 类型 | 说明 |
|------|------|------|
| context | common.UIAbilityContext | UIAbility 上下文 |
| windowStage | window.WindowStage | 窗口舞台，用于获取 UIContext |

#### SafeAreaManager.getSafeAreaInfo()
获取当前的安全区域信息。

**返回值：** `SafeAreaInfo`

```typescript
interface SafeAreaInfo {
  topInset: number;     // 顶部安全区域高度（vp）
  bottomInset: number;  // 底部安全区域高度（vp）
}
```

### 技术细节

#### 单位转换：UIContext.px2vp()

SafeAreaManager 使用官方推荐的 `UIContext.px2vp()` 进行单位转换：

```arkts
// ❌ 不推荐：全局 px2vp 已废弃
const vp = px2vp(px)

// ✅ 推荐：使用 UIContext.px2vp()
const uiContext = windowStage.getMainWindowSync().getUIContext()
const vp = uiContext.px2vp(px)
```

**优势：**
- ✅ 保证 UI 实例已创建，返回正确结果
- ✅ 避免默认屏幕虚拟像素比导致的转换错误
- ✅ API 12+ 推荐方式

---

## 🎯 最佳实践

### 1. 标准页面模板

```arkts
import { BackgroundDots } from '../common/BackgroundDots';

@Entry
@Component
struct StandardPage {
  @StorageLink('topInset') topInset: number = 0
  @StorageLink('bottomInset') bottomInset: number = 0
  
  build() {
    Stack() {
      // 1. 背景点阵
      BackgroundDots()
      
      // 2. 页面内容
      Column() {
        // 页面具体内容
      }
      .width('100%')
      .height('100%')
      .padding({
        top: this.topInset,
        bottom: this.bottomInset
      })
    }
    .width('100%')
    .height('100%')
  }
}
```

### 2. 带标签栏的页面模板

```arkts
import { BackgroundDots } from '../common/BackgroundDots';

@Entry
@Component
struct TabPage {
  @StorageLink('topInset') topInset: number = 0
  @StorageLink('bottomInset') bottomInset: number = 0
  
  build() {
    Stack() {
      // 背景点阵
      BackgroundDots()
      
      // 内容区域
      Column() {
        // 顶部内容
        Column() {
          Text('顶部内容')
        }
        .padding({ top: this.topInset })
        
        // 底部标签栏
        Tabs() {
          // 标签栏内容
        }
        .padding({ bottom: this.bottomInset })
      }
    }
  }
}
```

---

## 🔧 扩展建议

### 1. 添加更多工具类

可以在 `utils/` 目录下添加更多可复用工具类：

```
utils/
├── SafeAreaManager.ets
├── HealthServiceHelper.ets
├── ThemeManager.ets        # 主题管理器
├── DateUtils.ets           # 日期工具类
├── StringUtils.ets         # 字符串工具类
└── ValidationUtils.ets     # 数据验证工具类
```

### 2. 工具类设计原则

- ✅ 单例模式，确保全局唯一实例
- ✅ 使用 AppStorage 存储全局数据
- ✅ 提供清晰的 API 文档
- ✅ 错误处理和日志记录
- ✅ 类型安全（使用接口定义）

---

## 📝 注意事项

1. **初始化顺序**：确保 `SafeAreaManager.init()` 在页面加载前完成
2. **UIContext 获取**：必须在 `windowStage.loadContent` 或 `setUIContent` 之后才能获取 UIContext
3. **单位转换**：使用 `UIContext.px2vp()` 而不是全局 `px2vp()`（已废弃）
4. **响应式更新**：使用 `@StorageLink` 可自动响应安全区域变化

---

## 🤝 贡献指南

添加新的工具类时，请遵循以下规范：

1. ✅ 添加详细的 JSDoc 注释
2. ✅ 使用单例模式
3. ✅ 提供清晰的 API 文档
4. ✅ 错误处理和日志记录
5. ✅ 更新本文档

---

## 📚 相关文档

- [HarmonyOS 安全区域开发指南](https://developer.harmonyos.com/cn/docs/documentation/doc-guides/ui-safe-area)
- [HarmonyOS 单位转换最佳实践](https://developer.huawei.com/consumer/cn/doc/harmonyos-faqs/faqs-arkui-259)
- [HarmonyOS 状态管理](https://developer.harmonyos.com/cn/docs/documentation/doc-guides/ui-state-management)
