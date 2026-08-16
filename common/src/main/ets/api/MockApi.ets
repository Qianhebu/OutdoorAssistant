import { common } from '@kit.AbilityKit';
import { util } from '@kit.ArkTS';
import { AppStorageKeys } from '../constant/AppStorageKeys';

/** 模拟接口统一响应结构 */
export interface ApiResponse<T> {
  code: number;
  message: string;
  data: T;
}

/** 模拟网络请求：延迟后返回统一结构的响应 */
export function mockRequest<T>(data: T, delay: number = 200): Promise<ApiResponse<T>> {
  return new Promise<ApiResponse<T>>((resolve) => {
    setTimeout(() => {
      resolve({ code: 0, message: 'ok', data: data });
    }, delay);
  });
}

/** 获取应用启动时写入 AppStorage 的全局 UIAbilityContext */
export function getAbilityContext(): common.UIAbilityContext | undefined {
  return AppStorage.get<common.UIAbilityContext>(AppStorageKeys.HOST_CONTEXT);
}

/** 同步读取 rawfile 文本内容（作为模拟服务端数据源） */
export function readRawFileText(fileName: string): string {
  const context = getAbilityContext();
  if (context === undefined) {
    return '';
  }
  const rawContent = context.resourceManager.getRawFileContentSync(fileName);
  const textDecoder = util.TextDecoder.create('utf-8');
  return textDecoder.decodeToString(rawContent);
}
