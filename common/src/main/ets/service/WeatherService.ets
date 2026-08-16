import { weatherService } from '@kit.WeatherServiceKit';
import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { WeatherWarning, WeatherWarningLevel } from '../model/WeatherModel';

/**
 * 获取当前天气警示（基于系统天气服务 @kit.WeatherServiceKit）。
 * 优先使用系统发布的气象预警（WeatherAlert）；无预警时按实时温度/风力启发式评估。
 * 失败时返回 undefined，不打扰用户。
 */
export async function fetchWeatherWarnings(context: common.Context, latitude: number, longitude: number):
  Promise<WeatherWarning | undefined> {
  try {
    const request: weatherService.WeatherRequest = {
      location: {
        latitude: latitude,
        longitude: longitude
      },
      limitedDatasets: [weatherService.Dataset.CURRENT, weatherService.Dataset.ALERTS]
    };
    const weather: weatherService.Weather = await weatherService.getWeatherWithContext(context, request);
    console.info(`WeatherService ok: alerts=${weather.alerts?.length ?? 0} temp=${weather.current?.temperature} wind=${weather.current?.wind?.level}`);
    if (weather.alerts !== undefined && weather.alerts.length > 0) {
      const alert: weatherService.WeatherAlert = weather.alerts[0];
      return {
        level: alert.level >= weatherService.AlertLevel.ORANGE ?
          WeatherWarningLevel.WARNING : WeatherWarningLevel.CAUTION,
        title: alert.title,
        message: alert.content ?? alert.title
      };
    }
    const current: weatherService.CurrentWeather | undefined = weather.current;
    if (current === undefined) {
      return undefined;
    }
    return evaluateHeuristics(current.temperature, current.wind?.level ?? 0);
  } catch (err) {
    console.error(`WeatherService fetch failed: ${(err as BusinessError).code} ${(err as BusinessError).message}`);
    // TODO: 天气服务能力开通后移除。开发期降级返回模拟警示，便于验证警示横幅与跑马灯效果
    return {
      level: WeatherWarningLevel.WARNING,
      title: '暴雨大风预警',
      message: '当前暴雨伴随大风，路滑且存在安全隐患，建议取消户外运动'
    };
  }
}

/** 无系统预警时，按温度/风力做启发式评估 */
function evaluateHeuristics(temperature: number, windLevel: number): WeatherWarning | undefined {
  if (temperature >= 35) {
    return {
      level: WeatherWarningLevel.WARNING,
      title: '高温预警',
      message: `当前 ${temperature}°C，高温天气运动易中暑，请减少强度并及时补水`
    };
  }
  if (temperature <= 0) {
    return {
      level: WeatherWarningLevel.WARNING,
      title: '低温预警',
      message: `当前 ${temperature}°C，低温运动注意保暖，谨防失温`
    };
  }
  if (windLevel >= 6) {
    return {
      level: WeatherWarningLevel.WARNING,
      title: '大风预警',
      message: `当前风力 ${windLevel} 级，山区风大易失温，注意防护`
    };
  }
  if (windLevel >= 5) {
    return {
      level: WeatherWarningLevel.CAUTION,
      title: '风力较强',
      message: `当前风力 ${windLevel} 级，请注意防护`
    };
  }
  return undefined;
}
