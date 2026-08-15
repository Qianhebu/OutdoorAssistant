import { textToSpeech } from '@kit.CoreSpeechKit';
import { BusinessError } from '@kit.BasicServicesKit';

/** 运动语音播报服务：基于文字转语音，输出到媒体通道跟随媒体音量 */
export class WorkoutVoice {
  private static ttsEngine?: textToSpeech.TextToSpeechEngine = undefined;

  /** 获取文字转语音引擎，未创建时懒加载 */
  private static async getEngine(): Promise<textToSpeech.TextToSpeechEngine | undefined> {
    if (WorkoutVoice.ttsEngine !== undefined) {
      return WorkoutVoice.ttsEngine;
    }
    // soundChannel: 1 表示媒体通道，跟随媒体音量（默认走小艺语音通道，可能被静音）
    const extraParam: Record<string, Object> = { 'style': 'interaction-broadcast', 'locate': 'CN', 'soundChannel': 1 };
    const params: textToSpeech.CreateEngineParams = {
      language: 'zh-CN',
      person: 0,
      online: 1,
      extraParams: extraParam
    };
    try {
      const engine: textToSpeech.TextToSpeechEngine = await textToSpeech.createEngine(params);
      WorkoutVoice.ttsEngine = engine;
      return engine;
    } catch (err) {
      console.error(`WorkoutVoice engine create failed: ${(err as BusinessError).code} ${(err as BusinessError).message}`);
      return undefined;
    }
  }

  /** 播报语音，enabled 为 false 时忽略 */
  static async speak(text: string, enabled: boolean): Promise<void> {
    if (!enabled) {
      return;
    }
    const engine: textToSpeech.TextToSpeechEngine | undefined = await WorkoutVoice.getEngine();
    if (engine === undefined) {
      return;
    }
    const params: textToSpeech.SpeakParams = {
      requestId: `voice_${Date.now()}`,
      extraParams: { 'soundChannel': 1 }
    };
    try {
      engine.speak(text, params);
    } catch (err) {
      console.error(`WorkoutVoice speak failed: ${JSON.stringify(err)}`);
    }
  }

  /** 预加载引擎，避免首次播报延迟 */
  static preload(): void {
    WorkoutVoice.getEngine();
  }

  /** 停止当前播报 */
  static stop(): void {
    if (WorkoutVoice.ttsEngine !== undefined) {
      try {
        WorkoutVoice.ttsEngine.stop();
      } catch (err) {
        console.error(`WorkoutVoice stop failed: ${JSON.stringify(err)}`);
      }
    }
  }
}
