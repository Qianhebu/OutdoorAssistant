import { common } from '@kit.AbilityKit';
import { AppStorageKeys } from '../constant/AppStorageKeys';

/** 读取字符串资源为 string（供 @State 默认值、比较/拼接等需要 string 类型的位置使用） */
export function getStringSync(res: Resource): string {
  const context = AppStorage.get<common.UIAbilityContext>(AppStorageKeys.HOST_CONTEXT);
  if (context === undefined) {
    return '';
  }
  try {
    return context.resourceManager.getStringSync(res.id);
  } catch (err) {
    return '';
  }
}
