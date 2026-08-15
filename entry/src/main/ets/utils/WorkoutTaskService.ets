import { backgroundTaskManager } from '@kit.BackgroundTasksKit';
import { notificationManager } from '@kit.NotificationKit';
import { common, wantAgent, WantAgent } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';

/**
 * 运动长时任务服务：申请后台定位长时任务，并在状态栏展示/更新运动通知。
 * 应用退至后台后，长时任务保证进程不被挂起，运动计时与轨迹记录继续；
 * 用户点击状态栏通知可回到应用。
 */
export class WorkoutTaskService {
  /** 系统为长时任务创建的通知 ID，-1 表示尚未运行 */
  private static notificationId: number = -1;
  /** 点击通知拉起应用的 WantAgent */
  private static wantAgentObj?: WantAgent = undefined;
  /** 通知附加文案（启动时从字符串资源读取） */
  private static clickBackText: string = '点击回到运动记录';

  /** 长时任务是否运行中 */
  static isRunning(): boolean {
    return WorkoutTaskService.notificationId >= 0;
  }

  /** 启动运动长时任务（后台定位），返回是否启动成功 */
  static async start(context: common.UIAbilityContext): Promise<boolean> {
    if (WorkoutTaskService.notificationId >= 0) {
      return true;
    }
    try {
      if (WorkoutTaskService.wantAgentObj === undefined) {
        const wantAgentInfo: wantAgent.WantAgentInfo = {
          wants: [{
            bundleName: context.abilityInfo.bundleName,
            abilityName: context.abilityInfo.name
          }],
          actionType: wantAgent.OperationType.START_ABILITY,
          requestCode: 0,
          actionFlags: [wantAgent.WantAgentFlags.UPDATE_PRESENT_FLAG]
        };
        WorkoutTaskService.wantAgentObj = await wantAgent.getWantAgent(wantAgentInfo);
      }
      const notification: backgroundTaskManager.ContinuousTaskNotification =
        await backgroundTaskManager.startBackgroundRunning(context, ['location'], WorkoutTaskService.wantAgentObj);
      WorkoutTaskService.notificationId = notification.notificationId;
      try {
        WorkoutTaskService.clickBackText =
          context.resourceManager.getStringSync($r('app.string.notify_click_back').id);
      } catch (err) {
        console.error(`WorkoutTaskService resolve text failed: ${(err as BusinessError).message}`);
      }
      return true;
    } catch (err) {
      WorkoutTaskService.notificationId = -1;
      console.error(`WorkoutTaskService start failed: ${(err as BusinessError).message}`);
      return false;
    }
  }

  /** 更新状态栏运动通知内容 */
  static update(title: string, text: string): void {
    if (WorkoutTaskService.notificationId < 0) {
      return;
    }
    const request: notificationManager.NotificationRequest = {
      id: WorkoutTaskService.notificationId,
      content: {
        notificationContentType: notificationManager.ContentType.NOTIFICATION_CONTENT_BASIC_TEXT,
        normal: {
          title: title,
          text: text,
          additionalText: WorkoutTaskService.clickBackText
        }
      },
      updateOnly: true
    };
    notificationManager.publish(request).catch((err: BusinessError) => {
      console.error(`WorkoutTaskService update notification failed: ${err.code} ${err.message}`);
    });
  }

  /** 停止长时任务并移除状态栏通知 */
  static async stop(context: common.UIAbilityContext): Promise<void> {
    const id: number = WorkoutTaskService.notificationId;
    WorkoutTaskService.notificationId = -1;
    if (id < 0) {
      return;
    }
    try {
      await backgroundTaskManager.stopBackgroundRunning(context);
    } catch (err) {
      console.error(`WorkoutTaskService stop background failed: ${(err as BusinessError).message}`);
    }
    try {
      await notificationManager.cancel(id);
    } catch (err) {
      console.error(`WorkoutTaskService cancel notification failed: ${(err as BusinessError).message}`);
    }
  }
}
