import { fileIo as fs, fileUri } from '@kit.CoreFileKit';
import { common } from '@kit.AbilityKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

/**
 * 图片保存助手：将 rawfile 图片保存到系统图库
 * 使用 showAssetsCreationDialog 弹窗授权，无需申请 WRITE_IMAGEVIDEO 权限
 */
export class PhotoSaveHelper {

  /**
   * 将 rawfile 图片保存到系统图库
   *
   * @param context UIAbilityContext
   * @param rawfileName rawfile 文件名，如 "photos/route1.jpg"
   * @returns true 保存成功，false 用户取消或保存失败
   */
  static async saveRawfileToGallery(context: common.UIAbilityContext, rawfileName: string): Promise<boolean> {
    let tempPath: string = '';
    try {
      // 1. 读取 rawfile 内容
      const fileData: Uint8Array = context.resourceManager.getRawFileContentSync(rawfileName);

      // 2. 写入临时文件
      const ext: string = rawfileName.includes('.') ?
        rawfileName.substring(rawfileName.lastIndexOf('.') + 1) : 'jpg';
      tempPath = `${context.tempDir}/temp_save_${Date.now()}.${ext}`;
      const tempFile = fs.openSync(tempPath, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE);
      fs.writeSync(tempFile.fd, fileData.buffer);
      fs.closeSync(tempFile);

      // 3. 获取文件 URI（必须用 fileUri.getUriFromPath 转换，否则弹窗无法预览缩略图）
      const srcFileUri: string = fileUri.getUriFromPath(tempPath);

      // 4. 调用系统保存弹窗
      const photoCreationConfigs: Array<photoAccessHelper.PhotoCreationConfig> = [{
        fileNameExtension: ext,
        photoType: photoAccessHelper.PhotoType.IMAGE,
      }];
      const phAccessHelper = photoAccessHelper.getPhotoAccessHelper(context);
      const desFileUris: Array<string> =
        await phAccessHelper.showAssetsCreationDialog([srcFileUri], photoCreationConfigs);

      // 5. 用户同意保存 → 将文件内容写入目标 URI
      if (desFileUris.length > 0) {
        const srcFile = fs.openSync(srcFileUri, fs.OpenMode.READ_ONLY);
        const desFile = fs.openSync(desFileUris[0], fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE);
        fs.copyFileSync(srcFile.fd, desFile.fd);
        fs.closeSync(srcFile);
        fs.closeSync(desFile);
        return true;
      }

      // 用户拒绝保存
      return false;
    } catch (e) {
      hilog.error(0x0001, 'PhotoSaveHelper', 'saveRawfileToGallery failed: %{public}s', JSON.stringify(e));
      return false;
    } finally {
      // 6. 清理临时文件
      if (tempPath) {
        try {
          fs.unlinkSync(tempPath);
        } catch (e) {
          hilog.warn(0x0001, 'PhotoSaveHelper', 'cleanup temp file failed: %{public}s', JSON.stringify(e));
        }
      }
    }
  }
}
