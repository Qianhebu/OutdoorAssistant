# OutdoorAssistant

轻户外路线与运动记录助手（HarmonyOS）。

采用官方推荐的 **common / features / products 多模块分层架构**（HAR + HAP），MVVM 分层：View → ViewModel/组件 → Model/Service/Api。

## 目录结构

```
OutdoorAssistant/
├── common/                       # @ohos/common — 基础共享层 (HAR)
│   ├── Index.ets                 #   桶导出入口
│   └── src/main/
│       ├── ets/
│       │   ├── constant/         #   全局常量/枚举
│       │   │   ├── AppStorageKeys.ets   - AppStorage 键名枚举
│       │   │   ├── PageEnum.ets         - 路由名称枚举
│       │   │   └── StorageKey.ets       - 页面上下文存储键名枚举
│       │   ├── model/            #   数据模型
│       │   │   ├── HikingRouteModel.ets - 徒步路线模型 + 难度配色
│       │   │   ├── TabBarModel.ets      - Tab 栏模型（首页/记录/我的）
│       │   │   ├── WeatherModel.ets     - 天气预警模型
│       │   │   ├── WorkoutModels.ets    - 运动类型/指标/地图图层模型
│       │   │   └── RecordMetricModel.ets- 记录指标配置（AppStorageV2）
│       │   ├── util/             #   工具类
│       │   │   ├── SafeAreaManager.ets  - 安全区域管理器
│       │   │   ├── SystemBarHelper.ets  - 状态栏文字颜色辅助
│       │   │   ├── LocationStore.ets    - 定位缓存（AppStorage）
│       │   │   └── WorkoutFormat.ets    - 运动数据格式化 + 卡尔曼滤波
│       │   ├── service/          #   服务层
│       │   │   ├── WeatherService.ets   - 天气预警（系统天气服务 + 启发式降级）
│       │   │   ├── WorkoutTaskService.ets - 运动任务服务
│       │   │   └── WorkoutVoice.ets     - 运动语音播报
│       │   ├── api/              #   模拟接口层（页面统一通过接口取数）
│       │   │   ├── MockApi.ets          - ApiResponse 封装 / 模拟请求 / rawfile 读取
│       │   │   ├── HikingRouteApi.ets   - 徒步路线分页/详情接口
│       │   │   ├── HomeApi.ets          - 首页 Banner 接口
│       │   │   ├── CityApi.ets          - 城市列表/搜索接口
│       │   │   └── SearchApi.ets        - 热门搜索/搜索接口
│       │   ├── router/           #   路由管理
│       │   │   └── PageContext.ets      - NavPathStack 封装（openPage/popPage）
│       │   └── component/        #   公共组件
│       │       └── VideoPlayerView.ets  - 视频播放器（预留）
│       └── resources/            #   公共资源（颜色/字符串/地图缩略图/路线 JSON/Banner 图）
├── features/                     # @ohos/* — 业务功能层 (HAR)
│   ├── home/                     #   @ohos/home — 首页业务
│   │   ├── Index.ets
│   │   └── src/main/ets/view/    #     HomeView / HomeTab / HomeListView / SearchPage / CitySelectPage / BannerDetailPage / RouteDetailPage
│   │   └──（含徒步照片/视频等 rawfile 资源）
│   ├── map/                      #   @ohos/map — 地图与运动记录
│   │   ├── Index.ets
│   │   └── src/main/ets/
│   │       ├── view/MapTab.ets
│   │       └── constant/MapConstants.ets
│   └── mine/                     #   @ohos/mine — 我的
│       ├── Index.ets
│       └── src/main/ets/view/    #     MineTab / MineDetailNavPage / PrivacyPolicyPage / EditMetricsPage
└── entry/                        # 产品入口 (HAP) — 应用装配与启动
    └── src/main/
        ├── ets/
        │   ├── entryability/EntryAbility.ets
        │   ├── entrybackupability/EntryBackupAbility.ets
        │   ├── pages/SplashPage.ets     - 启动页（唯一 @Entry）
        │   └── view/MainPage.ets        - 主页面（Tab 装配）
        └── resources/                   - 应用图标/启动图/字体等入口资源
```

**分层依赖**：`entry` → `features/*` → `common`。跨模块 import 使用 `@ohos/*` 包名，各模块通过 `Index.ets` 桶导出。

**跨模块路由**：每个模块在自身 `router_map.json` 中注册页面（系统路由表），页面跳转统一使用 `PageContext.navPathStack.pushPath(new NavPathInfo(PageEnum.XXX, param))`。

## 模拟接口层（common/api）

页面不直接读取本地数据，统一通过接口获取，便于后续替换为真实后端：

| 接口 | 说明 |
| --- | --- |
| `fetchHikingRoutes(page, pageSize)` | 徒步路线分页查询（数据源：`rawfile/hiking_routes.json`） |
| `fetchRouteDetail(routeId)` | 路线详情 |
| `fetchHomeBanners()` | 首页 Banner 列表 |
| `fetchCityList()` | 城市列表（热门 + 字母分组） |
| `searchCities(keyword)` | 城市搜索 |
| `fetchHotSearches()` | 热门搜索词 |
| `searchRoutes(keyword)` | 路线/装备搜索 |

所有接口返回 `Promise<ApiResponse<T>>`（`{ code, message, data }`），并模拟网络延迟。

## 页面结构

### MainPage - 主页面（entry）

`HdsNavDestination` 包裹 `HomeView`，处理返回键逻辑（记录 Tab 返回上一 Tab、连按两次退出应用）。

### HomeView / HomeTab - Tab 外壳（features/home）

- `HomeView`：`HdsTabs` 三个 Tab（首页/记录/我的），绑定各 Tab Scroller，管理 Tab 切换与状态栏颜色。
- `HomeTab`：首页 Tab，内嵌 `HomeListView`。

### HomeListView - 首页内容视图（features/home）

布局：`HdsNavDestination` > `WaterFlow`。

- **Hero Banner**：Swiper 轮播（数据来自 `fetchHomeBanners`），沉浸式大图 + 底部进度条指示器；支持下拉弹性拉伸、触摸暂停自动轮播、松手延迟恢复。
- **徒步路线卡片**：分页加载（`fetchHikingRoutes`），卡片含图片轮播/渐变占位图、难度标签、距离/时长/爬升；点击通过共享元素转场进入 `RouteDetailPage`。当前版本不含视频展示（含视频数据以渐变占位图呈现）。
- **城市定位**：请求位置权限 → 缓存定位 → 精确定位 → 逆地理编码；点击城市 Chip 进入 `CitySelectPage`，回传结果经 `AppStorage('selectedCity')` 监听更新。
- 状态栏文字颜色随 Banner 滚动区域切换。

### MapTab - 地图与运动记录（features/map）

布局：`MapKit` 地图组件 + 自定义控件 + 运动面板半模态。

- **地图能力**：2D/3D 切换、图层（标准/地形/卫星，卫星图缩小到阈值自动叠加路网）、自定义指南针、坐标/GNSS 卫星状态标题栏、定位蓝点。
- **运动记录**：选择运动类型（爬山/跑步/徒步），点击开始记录轨迹（GPS 坐标 + Haversine 距离累计），实时面板展示距离/时间/爬升/步数/热量/配速；支持暂停/继续、锁定、语音播报。
- **轨迹**：卡尔曼滤波平滑、精度/速度过滤，折线覆盖物绘制；长按结束运动。
- **天气预警**：`fetchWeatherWarnings`（系统天气服务，失败降级模拟警示）。
- 指标配置：`EditMetricsPage`（features/mine）编辑展示指标。

### MineTab - 我的页面（features/mine）

- 账号卡片：华为账号登录（`@kit.AccountKit`），显示头像/昵称。
- 分组列表（`MineSection`/`MineItem`）：我的成就、我的收藏、我的路线、离线地图、缓存管理 / 更新日志、关于应用、隐私政策 / 常见问题、意见与反馈。
- 条目点击支持路由跳转（`openPage`）或底部 Sheet 弹窗（无 onclick 条目）。

### SearchPage - 搜索页面（features/home）

- 标题栏内嵌搜索框，自动聚焦；历史记录 + 热门搜索（`fetchHotSearches`）。
- 搜索通过 `searchRoutes(keyword)` 接口过滤，结果列表 + 空状态。

### CitySelectPage - 城市选择页面（features/home）

- 城市数据来自 `fetchCityList()`：当前定位 + 热门城市 + 字母分组列表 + 右侧 `AlphabetIndexer` 索引条（触摸弹窗二级城市）。
- 搜索模式：标题栏内 Search 组件，`searchCities(keyword)` 过滤。
- 选中城市写入 `AppStorage('selectedCity')` 并返回。

### RouteDetailPage - 路线详情（features/home）

- 首图 Hero（按真实宽高比锁定高度，与首页卡片共享元素转场）、难度/海拔信息、距离/用时/爬升/下降统计、路线详情与注意事项。
- Hero 支持下拉弹性拉伸。

### BannerDetailPage - Banner 详情（features/home）

- Hero 大图展开动画 + 富文本内容区。

### SplashPage - 启动页（entry）

`@Entry` 唯一入口页，展示应用图标与名称，延时后跳转 `MainPage`。

## 工具类与服务（common）

### SafeAreaManager - 安全区域管理器

单例；在 `EntryAbility.onWindowStageCreate` 中调用 `SafeAreaManager.init(context, windowStage)`，将状态栏/导航条高度写入 AppStorage（`topInset`/`bottomInset`），全局通过 `@StorageLink` 读取。

### SystemBarHelper - 状态栏样式

`updateStatusBarContentColor(isLightBackground)` 切换状态栏文字黑白。

### WorkoutFormat - 运动数据格式化

时长/配速/距离/热量/步数格式化、度分秒坐标、Haversine 距离、`KalmanFilter` 卡尔曼滤波。

### WeatherService - 天气预警

基于 `@kit.WeatherServiceKit` 获取气象预警，无预警时按温度/风力启发式评估，服务异常时降级返回模拟警示。

### WorkoutTaskService / WorkoutVoice

运动任务管理、运动语音播报（开始/暂停/继续/结束）。

## 路由

- 各模块 `resources/base/profile/router_map.json` 注册路由名与 Builder；
- `common/constant/PageEnum.ets` 定义路由名枚举；
- `PageContext` 封装 `pushPath`/`popPage`/`replacePage`，全局经 `AppStorage(StorageKey.HOME_PAGE_CONTEXT)` 共享。

## EntryAbility - 应用入口

- 缓存窗口对象与全局 UIAbilityContext 到 AppStorage（`MAIN_WINDOW`/`HOST_CONTEXT`）。
- 初始化 `PageContext`、注册字体、初始化安全区域、同步主题色模式。
- 监听系统主题变化、前后台切换，设置状态栏样式。
