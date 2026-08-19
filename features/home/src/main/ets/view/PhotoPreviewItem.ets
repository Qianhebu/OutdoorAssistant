import { image } from '@kit.ImageKit';
import { common } from '@kit.AbilityKit';
import { display } from '@kit.ArkUI';
import { PhotoPreviewModel } from '../model/PhotoPreviewModel';

@Component
export struct PhotoPreviewItem {
  @Prop photoSrc: string = '';
  @Prop geometryId: string = '';
  @Prop initialWidth: number = 60;
  @Prop initialHeight: number = 60;
  @State imageModel: PhotoPreviewModel = new PhotoPreviewModel();
  @State originalWidth: number = 0;
  @State originalHeight: number = 0;
  @Consume isDisableSwipe: boolean;
  @Consume isArriveBoundary: boolean;
  @Consume isImageReset: boolean;
  @Prop isViewingOriginal: boolean = false;

  aboutToAppear(): void {
    this.imageModel.imageWidth = this.initialWidth;
    this.imageModel.imageHeight = this.initialHeight;
    this.initImageSize();
  }

  private initImageSize(): void {
    try {
      const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
      const fd: number = context.resourceManager.getRawFdSync(this.photoSrc).fd;
      const imageSource: image.ImageSource = image.createImageSource(fd);
      imageSource.getImageInfo().then((info: image.ImageInfo) => {
        const ratio: number = Math.min(
          this.imageModel.componentWidth / info.size.width,
          this.imageModel.componentHeight / info.size.height
        );
        this.imageModel.imageWidth = info.size.width * ratio;
        this.imageModel.imageHeight = info.size.height * ratio;
        // 存储原图 1:1 尺寸（像素 → vp）
        const density: number = display.getDefaultDisplaySync().densityPixels;
        this.originalWidth = info.size.width / density;
        this.originalHeight = info.size.height / density;
      }).catch(() => {
        this.imageModel.imageWidth = this.imageModel.componentWidth;
        this.imageModel.imageHeight = this.imageModel.componentHeight;
      });
    } catch (_e) {
      this.imageModel.imageWidth = this.imageModel.componentWidth;
      this.imageModel.imageHeight = this.imageModel.componentHeight;
    }
  }

  build() {
    Stack() {
      Image($rawfile(this.photoSrc))
        .objectFit(ImageFit.Contain)
        .interpolation(ImageInterpolation.High)
        .width(this.isViewingOriginal && this.originalWidth > 0 ? this.originalWidth : this.imageModel.imageWidth)
        .height(this.isViewingOriginal && this.originalHeight > 0 ? this.originalHeight : this.imageModel.imageHeight)
        .geometryTransition(this.geometryId)
        .transition(TransitionEffect.OPACITY)
        .transform(this.imageModel.matrix)
        .translate({ x: this.imageModel.curOffsetX, y: this.imageModel.curOffsetY })
    }
    .width('100%')
    .height('100%')
    .alignContent(Alignment.Center)
    .onAreaChange((oldValue: Area, newValue: Area) => {
      const width: number = newValue.width as number;
      const height: number = newValue.height as number;
      if (width > 0 && height > 0) {
        this.imageModel.componentWidth = width;
        this.imageModel.componentHeight = height;
        this.initImageSize();
      }
    })
    .parallelGesture(
      GestureGroup(
        GestureMode.Exclusive,
        PanGesture({ fingers: 1, distance: this.isDisableSwipe ? 3 : 50 })
          .onActionUpdate((event: GestureEvent) => {
            this.isDisableSwipe = this.imageModel.panGestureUpdate(event);
          })
          .onActionEnd(() => {
            this.imageModel.gestureEnd();
          }),
        PinchGesture({ fingers: 2, distance: 1 })
          .onActionStart((event: GestureEvent) => {
            this.imageModel.pinchGestureStart(event);
          })
          .onActionUpdate((event: GestureEvent) => {
            this.isDisableSwipe = this.imageModel.pinchGestureUpdate(event);
          })
          .onActionEnd(() => {
            this.imageModel.pinchGestureEnd();
          }),
        TapGesture({ count: 2 })
          .onAction((event: GestureEvent) => {
            this.isDisableSwipe = this.imageModel.doubleTapGesture(event);
          }),
        TapGesture({ count: 1 })
          .onAction(() => {
          })
      ), GestureMask.Normal
    )
  }
}
