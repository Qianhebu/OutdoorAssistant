# OutdoorAssistant

## 目录结构

```
entry/src/main/ets/
  constant/              ← 全局常量/枚举
    AppStorageKeys.ets     - AppStorage 键名枚举
    PageEnum.ets           - 路由名称枚举
    StorageKey.ets         - 页面上下文存储键名枚举
  entryability/          ← 入口 Ability
    EntryAbility.ets
  entrybackupability/    ← 备份 Ability
    EntryBackupAbility.ets
  model/                 ← 数据模型
    TabBarModel.ets        - Tab 栏数据模型
  pages/                 ← @Entry 入口页
    SplashPage.ets         - 启动页（唯一 @Entry）
  router/                ← 路由管理
    PageContext.ets        - NavPathStack 封装
  utils/                 ← 工具类
    HealthServiceHelper.ets - 健康数据服务
    SafeAreaManager.ets     - 安全区域管理器
  view/                  ← 页面视图组件
    CitySelectPage.ets     - 城市选择页
    HomeListView.ets       - 首页列表视图
    HomeTab.ets            - 首页 Tab 容器
    HomeView.ets           - 主 Tab 容器
    MainPage.ets           - 主页面
    MineDetailNavPage.ets  - 我的详情页
    MineTab.ets            - 我的 Tab
    PrivacyPolicyPage.ets  - 隐私政策页
    MapTab.ets          - 记录 Tab
    SearchPage.ets         - 搜索页
```

## 页面结构

### HomeListView - 首页内容视图

布局结构：HdsNavDestination > Scroll > Column
- Hero Banner：沉浸式大图轮播，支持下拉弹性拉伸，底部进度条指示器
- 快捷入口：路线 / 天气 / 装备 / 救援
- 推荐路线：根据当前位置推荐的户外路线卡片列表
- 出发准备：补给 + 电量提醒卡片
- 安全提醒：天气 / 装备 / 安全提示列表

标题栏：
- stackBuilder 自定义左侧城市选择器（Chip + 下拉箭头）
- 右侧菜单：搜索 + 更多
- 沉浸光感材质 + 渐变模糊滚动效果

数据流：
- 城市定位：请求位置权限 → 缓存定位 → 精确定位 → 逆地理编码
- 城市选择：CitySelectPage → AppStorage('selectedCity') → @Watch 回调更新
- 搜索跳转：appPageContext.openPage → SearchPage

Hero Banner 区域：
- Swiper 轮播大图
- 底部进度条指示器（当前项进度递增，已完成项满进度，未开始项零进度）
- 支持触摸暂停自动播放，松手后延迟恢复

处理 Banner 下拉弹性拉伸：
- 下拉时 Banner 高度增大（拉伸效果）
- 上拉且超过原始高度时逐步回缩
- Fling 状态触发弹簧动画回弹

常量：
- `BANNER_SCALE_FACTOR` - Banner 下拉拉伸缩放系数，值越小拉伸越明显
- `STATUS_BAR_LIGHT_THRESHOLD` - 状态栏浅色文字阈值：滚动偏移小于此值时状态栏文字为白色
- `BANNER_PROGRESS_VALUE_MAX` - Banner 进度条最大值（毫秒），到达后自动切换下一张
- `BANNER_PROGRESS_FRAME_TIME` - Banner 进度条每帧更新间隔（毫秒），约 30fps
- `BANNER_PROGRESS_RESTART_DELAY` - Banner 触摸结束后延迟重启进度计时器（毫秒）

接口：
- `RouteRecommend` - 推荐路线数据结构（title, subtitle, tag, level）
- `OutdoorTip` - 安全提醒数据结构（title, content, icon）
- `HomeListParams` - 首页路由参数：外部传入的 Scroller 和 HdsTabsController
- `CitySelectParam` - 城市选择页面路由参数（currentCity）
- `SampleBanner` - Banner 轮播项数据结构（id, title, subTitle, desc, mediaUrl, themeColor）

状态变量：
- 安全区 insets（topInset, bottomInset）
- 全局页面上下文（appPageContext）：用于城市选择、搜索页跳转
- selectedCity：监听城市选择页面回传的城市名（@Watch → onCitySelected）
- currentCity：当前定位城市名
- locationFailed：定位是否失败
- currentBannerIndex：当前 Banner 索引
- currentProgressValue：当前 Banner 进度值
- bannerHeight：Banner 高度（支持弹性拉伸）

方法：
- `resetBannerHeight()` - 根据屏幕宽度初始化 Banner 高度（宽高比 1:1.28）
- `handlePullBanner()` - 处理 Banner 下拉弹性拉伸
- `resetBannerWithAnimation()` - 弹簧动画回弹 Banner 到原始高度
- `restartBannerProgress()` - 重启 Banner 进度条计时器
- `stopBannerProgress()` - 停止 Banner 进度条计时器
- `delayRestartBannerProgress()` - 延迟重启进度条（触摸结束后延迟恢复自动播放）
- `handleOnReady()` - 路由 onReady 回调：接收外部传入的 Scroller 和 HdsTabsController
- `requestLocationPermission()` - 请求位置权限，授权后开始定位
- `locateCurrentCity()` - 开始定位：先尝试缓存位置，再请求精确定位
- `tryCachedLocation()` - 尝试使用上一次缓存的位置信息
- `requestFreshLocation()` - 请求精确定位并逆地理编码
- `reverseGeocode()` - 逆地理编码：经纬度 → 城市名
- `stripCitySuffix()` - 去除城市名后缀（市/自治区/特别行政区等）
- `onCitySelected()` - @Watch 回调：城市选择页面回传城市名时触发
- `updateStatusBarContentColor()` - 更新状态栏文字颜色（浅色背景用黑字，深色背景用白字）
- `handleHomeScroll()` - 根据滚动偏移更新状态栏文字颜色
- `navigateToSearch()` - 跳转到搜索页面

Builder 方法：
- `buildTopOperationBar()` - 标题栏自定义区域：左侧城市选择器
- `buildLocationSelector()` - 城市选择器 Chip：显示当前城市，点击跳转城市选择页
- `buildHeroBanner()` - Hero Banner 区域
- `buildSampleBannerItem()` - 单个 Banner 项：背景图 + 底部文字叠加层
- `buildHeroTag()` - Banner 标签（备用）
- `buildQuickActions()` - 快捷入口行：路线 / 天气 / 装备 / 救援
- `buildActionItem()` - 单个快捷入口项：图标 + 标题
- `buildRecommendSection()` - 推荐路线区域：标题 + 路线卡片列表
- `buildRouteCard()` - 推荐路线卡片：图标 + 标题/标签 + 副标题/难度 + 箭头
- `buildPreparationSection()` - 出发准备区域：标题 + 补给/电量卡片
- `buildPreparationCard()` - 出发准备卡片：图标 + 标题 + 说明
- `buildSafetyTips()` - 安全提醒区域：标题 + 提醒项列表
- `buildTipItem()` - 单条安全提醒项：图标 + 标题 + 内容
- `buildSectionHeader()` - 通用区域标题：主标题 + 副标题 + 右侧"更多"

### CitySelectPage - 城市选择页面

布局结构：HdsNavDestination > Stack(List + AlphabetIndexer)
- 顶部：当前定位 + 热门城市 + 字母分组城市列表
- 右侧：AlphabetIndexer 字母索引条（touch 时弹窗显示二级城市）
- titleBar：沉浸光感，暗色前景；滚动时内嵌搜索框渐隐，titleBar 搜索按钮渐显
- 搜索模式：点击 titleBar 搜索按钮切换为 titleBar 内 Search+取消，触发键盘

数据流：
- 选中城市 → AppStorage.setOrCreate('selectedCity') → HomeListView @Watch 接收
- 当前定位城市由路由参数 CitySelectParam.currentCity 传入

状态变量：
- `appPageContext` - 全局页面上下文，用于 popPage 返回
- `currentCity` - 路由传入的当前定位城市
- `selected` - AlphabetIndexer 当前选中索引
- `searchMode` - titleBar 搜索模式：true 时 titleBar 显示 Search+取消
- `searchText` / `searchResults` - 搜索文本与结果
- `indexerPopupEnabled` - AlphabetIndexer 弹窗控制：只有手指触摸索引条时才显示弹窗，列表滚动时关闭
- `indexerTouching` - 标记手指是否正在触摸索引条，防止 onDidScroll 误关弹窗
- `inlineSearchOpacity` - 页面内搜索框透明度（滚动时渐隐 1→0）
- `titleSearchOpacity` - titleBar 搜索按钮透明度（滚动时渐显 0→1）
- `titleBarSearchVisible` - titleBar 搜索按钮是否可见（opacity>0.5 时显示，避免不可见时仍可点击）
- `relocating` - 重新定位中状态
- `bottomBuilderHidden` - bottomBuilder 是否被隐藏（滚动上滑时）

私有变量：
- `popupHideTimer` - popup 自动隐藏定时器
- `listScroller` - 列表滚动控制器
- `locationPermissions` - 定位权限列表
- `titleSearchController` - titleBar 内 Search 组件控制器，用于 focusInput/caretPosition
- `lastHapticIndex` - 触觉反馈：同一索引不重复振动
- `hotCities` - 热门城市列表
- `cityGroups` - 字母分组城市数据
- `indexerLetters` - 索引条字母数组：# 对应热门/定位区域，A-Z 对应分组
- `searchMenuItem` - menu 始终包含搜索图标，通过 isEnabled 控制交互
- `menuOptions` - menu 响应式绑定（整体赋值触发 UI 刷新）

方法：
- `allCities()` - 将所有分组城市扁平化为一维数组，用于搜索过滤
- `doSearch()` - 搜索逻辑：关键词为空则清空结果，否则按包含匹配过滤
- `updateSearchText()` - 统一更新搜索文本：更新 searchText + 过滤结果 + 重置索引 + 滚动到顶部
- `exitTitleSearchMode()` - 退出 titleBar 搜索模式：恢复标题栏 + 清空搜索
- `selectCity()` - 选中城市：写入 AppStorage 并返回上一页
- `stripCitySuffix()` - 去除城市名后缀（市/自治区/特别行政区等），使定位结果与列表匹配
- `enableIndexerPopup()` - 开启 popup 并设置自动隐藏
- `disableIndexerPopup()` - 关闭 popup
- `relocate()` - 重新定位当前城市
- `requestFreshLocation()` - 请求精确定位
- `reverseGeocode()` - 逆地理编码获取城市名
- `updateSelectedByListStart()` - 根据列表滚动位置更新 AlphabetIndexer 选中项（startIndex<=2 表示还在热门/定位区域，选中 #；否则映射到对应字母索引）
- `focusTitleSearch()` - 切换到 titleBar 搜索模式：显示 Search+取消，延迟请求焦点并触发键盘
- `playIndexerHaptic()` - AlphabetIndexer 触觉反馈：同一索引不重复振动，20ms 轻触

Builder 方法：
- `bottomBuilder()` - 标题栏底部搜索框
- `buildInlineSearchBox()` - 页面内搜索框（当前定位上方），滚动时渐隐
- `buildEmptySearchResult()` - 搜索无结果占位
- `buildCurrentLocation()` - 当前定位区域：显示定位图标 + 城市名 + 重新定位按钮
- `buildHotCities()` - 热门城市区域：Flow 布局标签，当前城市高亮
- `buildCityGroup()` - 字母分组区域：吸顶字母头 + 城市列表
- `buildCityRow()` - 城市行：当前城市显示 checkmark + 高亮色

titleBar 样式：
- 沉浸光感材质效果（IMMERSIVE + ADAPTIVE）
- 滚动时渐变模糊效果（IMMERSIVE_GRADIENT_BLUR）
- 初始样式：透明背景 + 暗色前景（标题/图标/返回键）
- 滚动生效后样式：页面背景色 + 暗色前景
- 组件级安全区避让（HarmonyOS 6.1+），替代 avoidLayoutSafeArea

列表滚动行为：
- 列表滚动时同步更新 AlphabetIndexer 选中项
- 滚动偏移 > 56vp 时认为 bottomBuilder 已隐藏，显示 menu search

AlphabetIndexer 样式：
- 选中项文字颜色、弹窗一级索引文字颜色（主题绿）、选中项背景色（主题绿）
- 弹窗背景色、弹窗二级项圆角、索引条项圆角

### SearchPage - 搜索页面

- stackBuilder 自定义标题栏搜索区域：Search 组件在中间+右侧区域，左侧 padding 64vp 避开返回按钮
- 搜索结果：`isSearching` 状态切换，`buildSearchResult()` 显示数据列表 + 空状态（"未找到相关结果"）
- 搜索历史：标签式展示 + 清除按钮，空状态显示"暂无搜索历史"，空时隐藏垃圾桶图标
- 热门搜索：排行列表，前 3 名绿色高亮 + 热度值
- 搜索输入自动聚焦：`.id('search_input')` + `.onShown` → `requestFocus`
- 搜索 `onChange` 清空输入时回到历史/热门视图

### MineTab - 我的页面

- 账号卡片：支持华为账号登录（HuaweiIDProvider 授权），显示头像/昵称
- 分组列表：我的成就、我的收藏、我的路线、离线地图、缓存管理 / 更新日志、关于应用、隐私政策 / 常见问题、意见与反馈
- 绑定 Sheet 弹窗：点击无 onclick 的 item 弹出底部 Sheet
- 菜单项：更多（意见与反馈）
- 悬停/按压效果：账号卡片和列表项支持 hover/touch 视觉反馈

## 工具类

### SafeAreaManager - 安全区域管理器

用于管理应用的安全区域信息（状态栏高度、导航栏高度等）
使用 AppStorage 存储全局数据，所有页面都可以访问

单例模式，私有构造函数。

使用示例：
```arkts
SafeAreaManager.init(context, windowStage)

@StorageLink('topInset') topInset: number = 0
@StorageLink('bottomInset') bottomInset: number = 0
```

初始化方法参数：
- `context` - UIAbility 上下文
- `windowStage` - 窗口舞台，用于获取 UIContext

应在 Ability 的 onWindowStageCreate 中调用初始化。

方法：
- `getInstance()` - 获取单例实例
- `init()` - 初始化安全区域管理器，获取 UIContext 用于单位转换
- `updateSafeAreaInsets()` - 更新安全区域信息，将数据存储到 AppStorage 中供全局访问
- `getSafeAreaInfo()` - 获取当前的安全区域信息

内部实现：
- 获取顶部系统栏（状态栏）避让区域
- 获取底部导航条避让区域
- 存储到 AppStorage

### HealthServiceHelper - 健康数据服务

使用 static 方法，避免 this 问题。

方法：
- `init()` - 初始化 Health Kit（应用启动时调用）
- `requestAuthorization()` - 请求用户授权（注意：个人开发者可申请：步数、热量、距离）；授权后保存授权状态
- `checkAuthorization()` - 检查是否已授权，失败时尝试从缓存读取
- `getTodayRange()` - 获取今日起止时间
- `buildProfileFromSamples()` - 汇总每日活动采样点
- `readTodayActivities()` - 读取今日每日活动数据
- `saveAuthorizationStatus()` - 保存授权状态到 preferences
- `queryTodayData()` - 查询今日健康数据（检查授权 → 读取数据 → 缓存 → 降级）
- `getCachedData()` - 获取缓存数据
- `saveToCache()` - 保存数据到缓存
- `getFallbackProfile()` - 获取降级数据

## EntryAbility - 应用入口

- 缓存窗口对象到 AppStorage（MAIN_WINDOW）
- 初始化 PageContext（HOME_PAGE_CONTEXT, HOME_TAB_PAGE_CONTEXT）
- 获取当前主题模式（colorMode）并存储到 AppStorage
- 监听系统主题变化（onConfigurationUpdate）
- 应用进入前台时设置状态栏样式
- 状态栏样式：深色模式白色文字、浅色模式黑色文字
