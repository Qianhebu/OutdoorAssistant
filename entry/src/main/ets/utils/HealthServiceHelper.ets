// utils/HealthServiceHelper.ets
import { healthStore } from '@kit.HealthServiceKit';
import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { BusinessError } from '@kit.BasicServicesKit';

// ========== 类型定义 ==========
export interface HealthProfile {
  steps: number;
  calories: number;
  distance: number;
  source: string;
  updateTime: string;
}

type DailyActivities = healthStore.healthModels.DailyActivities;

interface TimeRange {
  startTime: number;
  endTime: number;
}

// ========== 注意：使用 static 方法，避免 this 问题 ==========
export class HealthServiceHelper {
  /**
   * 初始化 Health Kit（应用启动时调用）
   */
  static async init(context: common.UIAbilityContext): Promise<void> {
    try {
      await healthStore.init(context);
      console.info('HealthService Kit 已就绪');
    } catch (err) {
      const error = err as BusinessError;
      console.error(`HealthService 初始化失败: ${error.code} ${error.message}`);
    }
  }

  /**
   * 请求用户授权
   * 注意：个人开发者可申请：步数、热量、距离
   */
  static async requestAuthorization(context: common.UIAbilityContext): Promise<string[]> {
    try {
      const request: healthStore.AuthorizationRequest = {
        readDataTypes: [
          healthStore.healthDataTypes.DAILY_ACTIVITIES
        ],
        writeDataTypes: []
      };

      const response = await healthStore.requestAuthorizations(context, request);
      const granted = response.readDataTypes.map((dataType: healthStore.DataType): string => {
        return dataType.name ?? dataType.id.toString();
      });
      console.info(`用户授权成功: ${granted.join(', ')}`);

      // 保存授权状态
      await HealthServiceHelper.saveAuthorizationStatus(context, granted);

      return granted;
    } catch (err) {
      const error = err as BusinessError;
      console.error(`授权失败: ${error.code} ${error.message}`);
      return [];
    }
  }

  /**
   * 检查是否已授权
   */
  static async checkAuthorization(context: common.UIAbilityContext): Promise<boolean> {
    try {
      const request: healthStore.AuthorizationRequest = {
        readDataTypes: [
          healthStore.healthDataTypes.DAILY_ACTIVITIES
        ],
        writeDataTypes: []
      };
      const response = await healthStore.getAuthorizations(request);
      return response.readDataTypes.length > 0;
    } catch (err) {
      try {
        const prefs = await preferences.getPreferences(context, 'health_auth');
        const status = await prefs.get('authorized', 'false');
        return status === 'true';
      } catch (cacheErr) {
        console.error('读取授权缓存失败:', cacheErr);
        return false;
      }
    }
  }

  /**
   * 获取今日起止时间
   */
  private static getTodayRange(): TimeRange {
    const now = new Date();
    const startTime = new Date(now.getFullYear(), now.getMonth(), now.getDate()).getTime();
    return {
      startTime: startTime,
      endTime: Date.now()
    };
  }

  /**
   * 汇总每日活动采样点
   */
  private static buildProfileFromSamples(data: DailyActivities[]): HealthProfile {
    let steps = 0;
    let calories = 0;
    let distanceMeters = 0;

    for (const item of data) {
      steps += item.fields.step ?? 0;
      calories += item.fields.calorie ?? 0;
      distanceMeters += item.fields.distance ?? 0;
    }

    return {
      steps: Math.round(steps),
      calories: Math.round(calories),
      distance: Number((distanceMeters / 1000).toFixed(2)),
      source: 'Health Service Kit',
      updateTime: new Date().toLocaleString('zh-CN')
    };
  }

  /**
   * 读取今日每日活动数据
   */
  private static async readTodayActivities(): Promise<HealthProfile | null> {
    const timeRange = HealthServiceHelper.getTodayRange();
    const request: healthStore.SamplePointReadRequest<healthStore.healthFields.DailyActivities> = {
      samplePointDataType: healthStore.healthDataTypes.DAILY_ACTIVITIES,
      startTime: timeRange.startTime,
      endTime: timeRange.endTime
    };
    try {
      const data = await healthStore.readData<DailyActivities>(request);
      return HealthServiceHelper.buildProfileFromSamples(data);
    } catch (err) {
      const error = err as BusinessError;
      console.error(`读取数据失败: ${error.code} ${error.message}`);
      return null;
    }
  }

  /**
   * 保存授权状态
   */
  private static async saveAuthorizationStatus(context: common.UIAbilityContext, granted: string[]): Promise<void> {
    try {
      const prefs = await preferences.getPreferences(context, 'health_auth');
      await prefs.put('authorized', granted.length > 0 ? 'true' : 'false');
      await prefs.put('granted_types', JSON.stringify(granted));
      await prefs.flush();
    } catch (err) {
      console.error('保存授权状态失败:', err);
    }
  }

  /**
   * 查询今日健康数据
   */
  static async queryTodayData(context: common.UIAbilityContext): Promise<HealthProfile> {
    try {
      // 检查授权
      const isAuthorized = await HealthServiceHelper.checkAuthorization(context);
      if (!isAuthorized) {
        // 尝试重新授权
        const granted = await HealthServiceHelper.requestAuthorization(context);
        if (granted.length === 0) {
          return HealthServiceHelper.getFallbackProfile('用户未授权，请先授权');
        }
      }

      const profile = await HealthServiceHelper.readTodayActivities();
      if (profile) {
        await HealthServiceHelper.saveToCache(context, profile);
        return profile;
      }
      const cached = await HealthServiceHelper.getCachedData(context);
      if (cached) {
        return cached;
      }
      return HealthServiceHelper.getFallbackProfile('读取失败');
    } catch (err) {
      const error = err as BusinessError;
      console.error(`查询失败: ${error.code} ${error.message}`);
      // 尝试从缓存读取
      const cached = await HealthServiceHelper.getCachedData(context);
      if (cached) {
        return cached;
      }
      return HealthServiceHelper.getFallbackProfile(`查询错误: ${error.message}`);
    }
  }

  /**
   * 获取缓存数据
   */
  private static async getCachedData(context: common.UIAbilityContext): Promise<HealthProfile | null> {
    try {
      const prefs = await preferences.getPreferences(context, 'health_cache');
      const steps = await prefs.get('today_steps', 0);
      if (steps > 0) {
        return {
          steps: steps as number,
          calories: await prefs.get('today_calories', 0) as number,
          distance: await prefs.get('today_distance', 0) as number,
          source: '缓存数据',
          updateTime: await prefs.get('update_time', new Date().toLocaleString()) as string
        };
      }
      return null;
    } catch (err) {
      return null;
    }
  }

  /**
   * 保存数据到缓存
   */
  private static async saveToCache(context: common.UIAbilityContext, profile: HealthProfile): Promise<void> {
    try {
      const prefs = await preferences.getPreferences(context, 'health_cache');
      await prefs.put('today_steps', profile.steps);
      await prefs.put('today_calories', profile.calories);
      await prefs.put('today_distance', profile.distance);
      await prefs.put('update_time', profile.updateTime);
      await prefs.flush();
    } catch (err) {
      console.error('保存缓存失败:', err);
    }
  }

  /**
   * 获取降级数据
   */
  private static getFallbackProfile(reason: string): HealthProfile {
    return {
      steps: 0,
      calories: 0,
      distance: 0,
      source: `降级: ${reason}`,
      updateTime: new Date().toLocaleString('zh-CN')
    };
  }
}
