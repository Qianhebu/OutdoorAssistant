import { preferences } from '@kit.ArkData';
import { HealthProfile, HealthServiceHelper } from '../utils/HealthServiceHelper';
import { common } from '@kit.AbilityKit';
import { hdsMaterial, HdsTabs, HdsTabsController } from '@kit.UIDesignKit';

interface ActivityItem {
  id: string;
  title: string;
  date: string;
  distance: string;
  duration: string;
  type: string; // 'hiking' | 'running' | 'cycling'
  icon: string;
}

interface WeatherInfo {
  temperature: number;
  condition: string;
  icon: string;
  wind: string;
  humidity: number;
}


@Entry
@Component
struct Index_bk {
  @State currentTabIndex: number = 0;
  @State totalTrips: number = 0;
  @State totalDays: number = 0;
  @State gearCount: number = 0;
  @State completedCount: number = 0;
  @State activities: ActivityItem[] = [];
  @State weatherInfo: WeatherInfo | null = null;
  @State healthData: HealthProfile = {
    steps: 0,
    calories: 0,
    distance: 0,
    source: '加载中...',
    updateTime: ''
  };
  @State isLoading: boolean = true;
  @State userName: string = '户外爱好者';
  @State todayDate: string = '';
  private controller: HdsTabsController = new HdsTabsController();

  getAbilityContext(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext;
  }

  showToast(message: string) {
    try {
      this.getUIContext().getPromptAction().showToast({ message: message });
    } catch (e) {
      console.error('显示提示失败:', e);
    }
  }

  buildBottomTabStyle(icon: Resource, text: string): BottomTabBarStyle {
    return BottomTabBarStyle.of(icon, text)
      .labelStyle({
        font: {
          size: 11,
          weight: FontWeight.Medium
        },
        selectedColor: '#16A34A',
        unselectedColor: '#6B7280'
      })
      .iconStyle({
        selectedColor: '#16A34A',
        unselectedColor: '#94A3B8'
      })
      .padding({
        left: 6,
        right: 6,
        top: 6,
        bottom: 4
      })
      .layoutMode(LayoutMode.VERTICAL)
      .verticalAlign(VerticalAlign.Center);
  }

  // 生命周期
  aboutToAppear() {
    this.initDate();
    this.loadUserData();
    this.loadStats();
    this.loadActivities();
    this.loadWeather();
    this.loadHealthData();
    this.initHealthService();
  }

  // 初始化日期
  initDate() {
    const now = new Date();
    const weekdays = ['周日', '周一', '周二', '周三', '周四', '周五', '周六'];
    const month = (now.getMonth() + 1).toString().padStart(2, '0');
    const day = now.getDate().toString().padStart(2, '0');
    const weekday = weekdays[now.getDay()];
    this.todayDate = `${month}月${day}日 ${weekday}`;
  }

  // 加载用户数据（从Preferences读取）
  async loadUserData() {
    try {
      const prefs = await preferences.getPreferences(this.getAbilityContext(), 'user_config');
      const name = await prefs.get('user_name', '户外爱好者');
      this.userName = name as string;
    } catch (e) {
      console.error('加载用户名失败:', e);
    }
  }

  // 加载统计数据
  async loadStats() {
    try {
      const prefs = await preferences.getPreferences(this.getAbilityContext(), 'stats_data');
      this.totalTrips = await prefs.get('total_trips', 12) as number;
      this.totalDays = await prefs.get('total_days', 36) as number;
      this.gearCount = await prefs.get('gear_count', 28) as number;
      this.completedCount = await prefs.get('completed_count', 8) as number;
    } catch (e) {
      console.error('加载统计数据失败:', e);
      // 使用默认值
      this.totalTrips = 12;
      this.totalDays = 36;
      this.gearCount = 28;
      this.completedCount = 8;
    }
  }

  // 加载活动列表
  async loadActivities() {
    try {
      const prefs = await preferences.getPreferences(this.getAbilityContext(), 'activity_data');
      const saved = await prefs.get('activities', '');
      if (saved) {
        this.activities = JSON.parse(saved as string) as ActivityItem[];
        return;
      }
    } catch (e) {
      console.error('加载活动列表失败:', e);
    }

    // 默认示例数据
    this.activities = [
      {
        id: '1',
        title: '四明山徒步穿越',
        date: '2026-07-26',
        distance: '12.8 km',
        duration: '4h 20min',
        type: 'hiking',
        icon: '🏔️'
      },
      {
        id: '2',
        title: '东钱湖晨跑',
        date: '2026-07-25',
        distance: '8.2 km',
        duration: '48min',
        type: 'running',
        icon: '🏃'
      },
      {
        id: '3',
        title: '环湖骑行',
        date: '2026-07-23',
        distance: '35.6 km',
        duration: '2h 15min',
        type: 'cycling',
        icon: '🚴'
      }
    ];
  }

  // 加载天气信息（模拟）
  async loadWeather() {
    // 实际项目调用天气API，这里用模拟数据
    this.weatherInfo = {
      temperature: 28,
      condition: '晴',
      icon: '☀️',
      wind: '东南风 3级',
      humidity: 65
    };

    // 模拟从缓存读取
    try {
      const prefs = await preferences.getPreferences(this.getAbilityContext(), 'weather_cache');
      const cached = await prefs.get('weather', '');
      if (cached) {
        const parsed = JSON.parse(cached as string) as WeatherInfo;
        this.weatherInfo = parsed;
      }
    } catch (e) {
      console.error('加载天气缓存失败:', e);
    }
  }

  // 加载运动健康数据
  async loadHealthData() {
    try {
      const context = this.getAbilityContext();
      const prefs = await preferences.getPreferences(context, 'health_cache');
      const steps = await prefs.get('today_steps', 0);
      const calories = await prefs.get('today_calories', 0);
      const distance = await prefs.get('today_distance', 0);
      const updateTime = await prefs.get('update_time', '');

      if (steps > 0) {
        this.healthData = {
          steps: steps as number,
          calories: calories as number,
          distance: distance as number,
          source: '缓存数据',
          updateTime: updateTime as string || new Date().toLocaleString()
        };
      }
    } catch (e) {
      console.error('加载健康缓存失败:', e);
    }

    // 异步刷新最新数据
    this.refreshHealthFromKit();
  }

  // 初始化Health Service Kit
  async initHealthService() {
    try {
      const context = this.getAbilityContext();
      await HealthServiceHelper.init(context);
      console.info('HealthService初始化成功');
    } catch (e) {
      console.error('HealthService初始化失败:', e);
    }
  }

  // 从Health Kit刷新数据
  async refreshHealthFromKit() {
    try {
      const context = this.getAbilityContext();
      const data = await HealthServiceHelper.queryTodayData(context);
      if (data.steps > 0 || this.healthData.source.includes('未授权')) {
        this.healthData = data;
      }
    } catch (e) {
      console.error('Health Kit刷新失败:', e);
    } finally {
      this.isLoading = false;
    }
  }

  // 手动刷新健康数据（下拉刷新）
  async refreshHealthData() {
    this.isLoading = true;
    try {
      const context = this.getAbilityContext();
      const data = await HealthServiceHelper.queryTodayData(context);
      this.healthData = data;
      this.showToast('✅ 数据已刷新');
    } catch (e) {
      this.showToast('刷新失败，请重试');
    } finally {
      this.isLoading = false;
    }
  }

  // 格式化步数（千位分隔）
  formatSteps(steps: number): string {
    if (steps >= 10000) {
      return (steps / 10000).toFixed(1) + '万';
    }
    return steps.toLocaleString();
  }

  // 活动类型对应的颜色
  getActivityColor(type: string): string {
    const colorMap: Record<string, string> = {
      'hiking': '#4CAF50',
      'running': '#FF6B35',
      'cycling': '#2196F3'
    };
    return colorMap[type] || '#999999';
  }

  // 跳转到指定页面
  async navigateTo(page: string) {
    try {
      await this.getUIContext().getRouter().pushUrl({ url: `pages/${page}` });
    } catch (e) {
      console.error('页面跳转失败:', e);
      this.showToast('功能开发中...');
    }
  }

  // 开始户外记录
  startRecording() {
    // 检查定位权限
    this.navigateTo('RecordPage');
  }

  // 查看全部活动
  viewAllActivities() {
    this.navigateTo('ActivityListPage');
  }

  build() {
    Column() {
      // 顶部Header
      this.buildHeader();

      HdsTabs({ controller: this.controller }) {
        TabContent() {
          this.buildHomeTab();
        }
        .tabBar(this.buildBottomTabStyle($r('app.media.icon_home'), '首页'))

        TabContent() {
          this.buildRecordTab();
        }
        .tabBar(this.buildBottomTabStyle($r('app.media.icon_record'), '记录'))

        TabContent() {
          this.buildHealthTab();
        }
        .tabBar(this.buildBottomTabStyle($r('app.media.icon_health'), '健康'))

        TabContent() {
          this.buildMineTab();
        }
        .tabBar(this.buildBottomTabStyle($r('app.media.icon_mine'), '我的'))
      }
      .barOverlap(true)
      .barPosition(BarPosition.End)
      .vertical(false)
      // 设置页签栏悬浮样式
      .barFloatingStyle({
        barWidth: { smallWidth: 200, mediumWidth: 300, largeWidth: 400 },
        barBottomMargin: 28,
        gradientMask: { maskColor: '#66F1F3F5', maskHeight: 92 },
        systemMaterialEffect: {
          materialType: hdsMaterial.MaterialType.IMMERSIVE,
          materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
        },
      })
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])

      // // Tab内容区
      // Tabs({ index: this.currentTabIndex }) {
      //   TabContent() {
      //     this.buildHomeTab();
      //   }
      //   .tabBar(this.buildBottomTabStyle($r('app.media.icon_home'), '首页'))
      //
      //   TabContent() {
      //     this.buildRecordTab();
      //   }
      //   .tabBar(this.buildBottomTabStyle($r('app.media.icon_record'), '记录'))
      //
      //   TabContent() {
      //     this.buildHealthTab();
      //   }
      //   .tabBar(this.buildBottomTabStyle($r('app.media.icon_health'), '健康'))
      //
      //   TabContent() {
      //     this.buildMineTab();
      //   }
      //   .tabBar(this.buildBottomTabStyle($r('app.media.icon_mine'), '我的'))
      // }
      // .barPosition(BarPosition.End)
      // .barWidth('100%')
      // .barHeight(64)
      // .barOverlap(true)
      // .barBackgroundColor('#D9FFFFFF')
      // .barBackgroundBlurStyle(BlurStyle.BACKGROUND_THIN)
      // .barBackgroundEffect({
      //   radius: 28,
      //   saturation: 1.8,
      //   brightness: 1.12,
      //   color: '#66FFFFFF'
      // })
      // .divider({
      //   strokeWidth: 0.5,
      //   color: '#33FFFFFF'
      // })
      // .backgroundColor('#00FFFFFF')
      // .layoutWeight(1)
      // .onChange((index: number) => {
      //   this.currentTabIndex = index;
      // })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F7FA');
  }

  // 顶部Header
  @Builder
  buildHeader() {
    Row() {
      Column() {
        Row() {
          Text(`你好，${this.userName}`)
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor('#1A1A2E');
          Text('👋')
            .fontSize(20)
            .margin({ left: 4 });
        }
        .alignItems(VerticalAlign.Center);

        Row() {
          Text(this.todayDate)
            .fontSize(13)
            .fontColor('#999999');
          Text('·')
            .fontSize(13)
            .fontColor('#999999')
            .margin({ left: 4, right: 4 });
          Text(this.weatherInfo ? `${this.weatherInfo.icon} ${this.weatherInfo.temperature}°C` : '加载天气...')
            .fontSize(13)
            .fontColor('#999999');
        }
        .margin({ top: 2 });
      }
      .alignItems(HorizontalAlign.Start);

      Blank();

      // 消息通知按钮
      Stack() {
        Button()
          .width(40)
          .height(40)
          .borderRadius(20)
          .backgroundColor('#F0F0F0')
          .onClick(() => {
            this.navigateTo('NotificationPage');
          });
        Text('🔔')
          .fontSize(18)
          .hitTestBehavior(HitTestMode.None);
        // 小红点
        Circle({ width: 8, height: 8 })
          .fill('#E53935')
          .position({ x: 28, y: 6 });
      }
    }
    .width('100%')
    .padding({
      left: 16,
      right: 16,
      top: 14,
      bottom: 10
    })
    .backgroundColor('#FFFFFF');
  }

  // 首页Tab
  @Builder
  buildHomeTab() {
    Scroll() {
      Column() {
        // 统计卡片
        this.buildStatsCard();

        // 快捷入口
        this.buildQuickActions();

        // 今日健康摘要
        this.buildHealthSummary();

        // 近期活动
        this.buildActivitySection();
      }
      .width('100%')
      .padding({ bottom: 20 });
    }
    .width('100%')
    .layoutWeight(1)
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring);
  }

  // 统计卡片
  @Builder
  buildStatsCard() {
    Row() {
      this.statItem(this.totalTrips.toString(), '总行程', '#FF6B35', '📋');
      this.statItem(this.totalDays.toString(), '累计天数', '#2196F3', '📅');
      this.statItem(this.gearCount.toString(), '装备总数', '#4CAF50', '🎒');
      this.statItem(this.completedCount.toString(), '已完成', '#9C27B0', '✅');
    }
    .width('100%')
    .padding({
      top: 16,
      bottom: 16,
      left: 8,
      right: 8
    })
    .backgroundColor('#FFFFFF')
    .borderRadius(12)
    .margin({ left: 16, right: 16, top: 12 });
  }

  @Builder
  statItem(value: string, label: string, color: string, icon: string) {
    Column() {
      Row() {
        Text(icon)
          .fontSize(14);
        Text(value)
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor(color)
          .margin({ left: 4 });
      }
      .alignItems(VerticalAlign.Center);

      Text(label)
        .fontSize(11)
        .fontColor('#999999')
        .margin({ top: 2 });
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Center);
  }

  // 快捷入口
  @Builder
  buildQuickActions() {
    Row() {
      this.actionItem('🎒', '装备库', () => {
        this.navigateTo('GearPage');
      });
      this.actionItem('📝', '打包清单', () => {
        this.navigateTo('PackPage');
      });
      this.actionItem('📍', '开始记录', () => {
        this.startRecording();
      });
      this.actionItem('📊', '统计', () => {
        this.navigateTo('StatisticsPage');
      });
    }
    .width('100%')
    .padding({
      top: 14,
      bottom: 14,
      left: 8,
      right: 8
    })
    .backgroundColor('#FFFFFF')
    .borderRadius(12)
    .margin({ left: 16, right: 16, top: 12 });
  }

  @Builder
  actionItem(icon: string, label: string, action: () => void) {
    Column() {
      Stack() {
        Circle({ width: 48, height: 48 })
          .fill('#F0F7FF');
        Text(icon)
          .fontSize(22);
      }

      Text(label)
        .fontSize(11)
        .fontColor('#666666')
        .margin({ top: 6 });
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Center)
    .onClick(action);
  }

  // 今日健康摘要
  @Builder
  buildHealthSummary() {
    Row() {
      Column() {
        Row() {
          Text('❤️ 今日运动')
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor('#1A1A2E');

          Blank();

          Text(this.isLoading ? '加载中...' : '查看详情 ›')
            .fontSize(12)
            .fontColor('#2196F3')
            .onClick(() => {
              this.navigateTo('HealthPage');
            });
        }
        .width('100%')
        .margin({ bottom: 10 });

        Row() {
          this.healthItem('🚶', '步数', this.formatSteps(this.healthData.steps));
          this.healthItem('🔥', '热量', `${this.healthData.calories}kcal`);
          this.healthItem('📏', '距离', `${this.healthData.distance}km`);
        }
        .width('100%')
        .justifyContent(FlexAlign.SpaceAround);

        if (this.healthData.source.includes('未授权')) {
          Button('授权运动数据')
            .width('100%')
            .height(36)
            .fontSize(13)
            .backgroundColor('#16A34A')
            .fontColor('#FFFFFF')
            .borderRadius(18)
            .margin({ top: 10 })
            .onClick(async () => {
              const context = this.getAbilityContext();
              await HealthServiceHelper.requestAuthorization(context);
              await this.refreshHealthFromKit();
            });
        }
      }
      .width('100%')
      .padding(14)
      .backgroundColor('#FFFFFF')
      .borderRadius(12)
      .margin({ left: 16, right: 16, top: 12 });
    }
    .width('100%');
  }

  @Builder
  healthItem(icon: string, label: string, value: string) {
    Column() {
      Text(icon)
        .fontSize(18);
      Text(value)
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor('#1A1A2E')
        .margin({ top: 2 });
      Text(label)
        .fontSize(10)
        .fontColor('#999999');
    }
    .alignItems(HorizontalAlign.Center);
  }

  // 近期活动
  @Builder
  buildActivitySection() {
    Column() {
      Row() {
        Text('🏕️ 近期活动')
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor('#1A1A2E');

        Blank();

        Text('查看全部 ›')
          .fontSize(12)
          .fontColor('#2196F3')
          .onClick(() => {
            this.viewAllActivities();
          });
      }
      .width('100%')
      .padding({ left: 4, right: 4, bottom: 10 });

      Column() {
        if (this.activities.length === 0) {
          Text('暂无活动记录，开始你的第一次户外探索吧！')
            .fontSize(13)
            .fontColor('#999999')
            .padding(20);
        } else {
          ForEach(this.activities, (item: ActivityItem, index: number) => {
            this.activityItem(item, index);
          }, (item: ActivityItem) => item.id);
        }
      }
      .width('100%')
      .padding({ left: 4, right: 4 })
      .backgroundColor('#FFFFFF')
      .borderRadius(12);
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 12 });
  }

  @Builder
  activityItem(item: ActivityItem, index: number) {
    Row() {
      // 图标
      Circle({ width: 44, height: 44 })
        .fill(this.getActivityColor(item.type) + '20');
      Text(item.icon)
        .fontSize(20)
        .position({ x: 12, y: 12 });

      // 内容
      Column() {
        Text(item.title)
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor('#1A1A2E')
          .width('100%');

        Row() {
          Text(item.date)
            .fontSize(11)
            .fontColor('#999999');
          Text('·')
            .fontSize(11)
            .fontColor('#999999')
            .margin({ left: 4, right: 4 });
          Text(item.distance)
            .fontSize(11)
            .fontColor('#999999');
          Text('·')
            .fontSize(11)
            .fontColor('#999999')
            .margin({ left: 4, right: 4 });
          Text(item.duration)
            .fontSize(11)
            .fontColor('#999999');
        }
        .width('100%')
        .margin({ top: 2 });
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      .margin({ left: 12 });

      // 箭头
      Text('›')
        .fontSize(18)
        .fontColor('#CCCCCC');
    }
    .width('100%')
    .padding({ top: 12, bottom: 12 })
    .border({
      width: { bottom: index < this.activities.length - 1 ? 1 : 0 },
      color: '#F0F0F0'
    })
    .onClick(() => {
      this.navigateTo('TrackDetailPage');
    });
  }

  // 记录Tab（占位）
  @Builder
  buildRecordTab() {
    Column() {
      Text('📝 记录页面')
        .fontSize(20)
        .fontColor('#1A1A2E')
        .margin({ top: 40 });
      Text('轨迹记录、历史活动列表')
        .fontSize(14)
        .fontColor('#999999')
        .margin({ top: 8 });
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F7FA')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center);
  }

  // 健康Tab（占位）
  @Builder
  buildHealthTab() {
    Column() {
      Text('❤️ 健康页面')
        .fontSize(20)
        .fontColor('#1A1A2E')
        .margin({ top: 40 });
      Text('详细健康数据、趋势图表')
        .fontSize(14)
        .fontColor('#999999')
        .margin({ top: 8 });
      // 实际项目中跳转到 HealthPage
      Button('查看完整健康数据')
        .width('80%')
        .height(44)
        .backgroundColor('#2196F3')
        .fontColor('#FFFFFF')
        .borderRadius(22)
        .margin({ top: 20 })
        .onClick(() => {
          this.navigateTo('HealthPage');
        });
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F7FA')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center);
  }

  // 我的Tab（占位）
  @Builder
  buildMineTab() {
    Column() {
      Text('👤 我的页面')
        .fontSize(20)
        .fontColor('#1A1A2E')
        .margin({ top: 40 });
      Text('个人信息、设置、装备管理')
        .fontSize(14)
        .fontColor('#999999')
        .margin({ top: 8 });
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F7FA')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center);
  }
}
