import { AppStorageKeys, HikingRouteItem } from '@ohos/common';
import { PhotoPreviewItem } from './PhotoPreviewItem';
import { PhotoSaveHelper } from './PhotoSaveHelper';
import { common, ConfigurationConstant } from '@kit.AbilityKit';
import { promptAction, window } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';

@Component
export struct RouteDetailSheet {
  route?: HikingRouteItem = undefined;
  private elevationCanvasCtx: CanvasRenderingContext2D =
    new CanvasRenderingContext2D(new RenderingContextSettings(true));
  private stepsCanvasCtx: CanvasRenderingContext2D = new CanvasRenderingContext2D(new RenderingContextSettings(true));
  private floorsCanvasCtx: CanvasRenderingContext2D = new CanvasRenderingContext2D(new RenderingContextSettings(true));
  @State showPhotoPreview: boolean = false;
  @State previewIndex: number = 0;
  @State isSaving: boolean = false;
  @StorageLink(AppStorageKeys.TOP_INSET) topInset: number = 0;
  @StorageLink(AppStorageKeys.BOTTOM_INSET) bottomInset: number = 0;
  @Provide isDisableSwipe: boolean = false;
  @Provide isImageReset: boolean = false;
  @Provide isArriveBoundary: boolean = false;
  @Provide isViewingOriginal: boolean = false;
  private swipeController: SwiperController = new SwiperController();

  build() {
    Column({ space: 0 }) {
      if (this.route) {
        this.buildSheetHeader()
      }
    }
    .width('100%')
    .padding({ top: 12 })
    .bindContentCover(this.showPhotoPreview, this.buildPhotoPreview(), {
      modalTransition: ModalTransition.NONE,
      backgroundColor: Color.Transparent
    })
  }

  private formatDateTime(dateStr: string): string {
    const d: Date = new Date(dateStr);
    const month: number = d.getMonth() + 1;
    const day: number = d.getDate();
    const hour: number = d.getHours();
    return `${month}月${day}日${hour}时`;
  }

  private parseDurationHours(display: string): number {
    let hours: number = 0;
    const hMatch: RegExpMatchArray | null = display.match(new RegExp('(\\d+)小时'));
    const mMatch: RegExpMatchArray | null = display.match(new RegExp('(\\d+)分钟'));
    if (hMatch && hMatch.length > 1) {
      hours += parseInt(hMatch[1], 10);
    }
    if (mMatch && mMatch.length > 1) {
      hours += parseInt(mMatch[1], 10) / 60;
    }
    return hours;
  }

  private getTimeRange(): string {
    if (this.route?.startTime && this.route?.endTime) {
      return `${this.formatDateTime(this.route.startTime)} - ${this.formatDateTime(this.route.endTime)}`;
    }
    const now: Date = new Date();
    const startMonth: number = now.getMonth() + 1;
    const startDay: number = now.getDate();
    const startHour: number = 8;
    const durationHours: number = this.parseDurationHours(this.route?.durationDisplay ?? '3小时');
    const endHour: number = startHour + Math.ceil(durationHours);
    return `${startMonth}月${startDay}日${startHour}时 - ${startMonth}月${startDay}日${endHour}时`;
  }

  private getNickname(): string {
    return this.route?.userNickname ?? '户外探索者';
  }

  private getAvatar(): string {
    return this.route?.userAvatar ?? '';
  }

  @Builder
  buildSheetHeader() {
    Row() {
      Row({ space: 12 }) {
        Stack() {
          Circle()
            .width(48)
            .height(48)
            .fill($r('sys.color.comp_background_tertiary'))
          SymbolGlyph($r('sys.symbol.person_fill'))
            .fontSize(22)
            .fontColor([$r('sys.color.icon_secondary')])
        }
        .width(48)
        .height(48)

        Column({ space: 4 }) {
          Text(this.getNickname())
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('sys.color.font_primary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          Text(this.getTimeRange())
            .fontSize(13)
            .fontColor($r('sys.color.font_tertiary'))
        }
        .alignItems(HorizontalAlign.Start)
      }
      .layoutWeight(1)
      .alignItems(VerticalAlign.Center)

      if ((this.route!.photos ?? []).length > 0) {
        this.buildPhotoWall()
      }
    }
    .width('100%')
    .padding({ left: 20, right: 20 })
    .alignItems(VerticalAlign.Center)
  }

  private getDisplayPhotos(): string[] {
    const photoList: string[] = this.route?.photos ?? [];
    return photoList.length > 3 ? photoList.slice(0, 3) : photoList;
  }

  private getPreviewPhotos(): string[] {
    return this.route?.photos ?? [];
  }

  private getPolaroidAngle(index: number): number {
    const angles: number[] = [-6, 4, -2];
    return angles[index] ?? 0;
  }

  private getPolaroidOffsetX(index: number): number {
    const offsets: number[] = [-4, 3, 7];
    return offsets[index] ?? 0;
  }

  private getPolaroidOffsetY(index: number): number {
    const offsets: number[] = [0, 3, 6];
    return offsets[index] ?? 0;
  }

  private getPolaroidDate(): string {
    if (this.route?.startTime) {
      const d: Date = new Date(this.route.startTime);
      const month: number = d.getMonth() + 1;
      const day: number = d.getDate();
      return `${month}.${day}`;
    }
    return '';
  }

  @Builder
  buildPhotoWall() {
    Stack() {
      ForEach(this.getDisplayPhotos(), (photo: string, index: number) => {
        Column() {
          Image($rawfile(photo))
            .objectFit(ImageFit.Cover)
            .interpolation(ImageInterpolation.High)
            .width(60)
            .height(60)
            .geometryTransition(`routePhoto_${index}`)
            .transition(TransitionEffect.OPACITY)

          Text(this.getPolaroidDate())
            .fontSize(8)
            .fontColor('#8B7355')
            .margin({ top: 3 })
        }
        .padding({
          left: 6,
          right: 6,
          top: 6,
          bottom: 10
        })
        .backgroundColor(Color.White)
        .border({ width: 1, color: Color.White })
        .shadow({
          radius: 8,
          color: 'rgba(0,0,0,0.2)',
          offsetX: 0,
          offsetY: 2
        })
        .rotate({ angle: this.getPolaroidAngle(index) })
        .offset({ x: this.getPolaroidOffsetX(index), y: this.getPolaroidOffsetY(index) })
        .onClick(() => {
          this.onPhotoClick(index);
        })
      }, (photo: string, index: number) => `polaroid_${index}_${photo}`)
    }
    .width(100)
    .height(100)
    .margin({ left: 4 })
  }

  private onPhotoClick(index: number): void {
    this.previewIndex = index;
    this.isViewingOriginal = false;
    this.updateSystemBarForPreview(true);
    this.getUIContext().animateTo({
      duration: 400,
      curve: Curve.FastOutSlowIn
    }, () => {
      this.showPhotoPreview = true;
    });
  }

  private async saveCurrentPhoto(): Promise<void> {
    if (this.isSaving) {
      return;
    }
    const photos: string[] = this.getPreviewPhotos();
    if (this.previewIndex < 0 || this.previewIndex >= photos.length) {
      return;
    }
    this.isSaving = true;
    try {
      const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
      const success: boolean = await PhotoSaveHelper.saveRawfileToGallery(context, photos[this.previewIndex]);
      if (success) {
        promptAction.showToast({ message: '已保存到图库', duration: 2000 });
      }
    } catch (e) {
      promptAction.showToast({ message: '保存失败', duration: 2000 });
    } finally {
      this.isSaving = false;
    }
  }

  private toggleViewOriginal(): void {
    this.isViewingOriginal = !this.isViewingOriginal;
  }

  @Builder
  buildPhotoPreview() {
    Stack() {
      Swiper(this.swipeController) {
        ForEach(this.getPreviewPhotos(), (photo: string, index: number) => {
          PhotoPreviewItem({
            photoSrc: photo,
            geometryId: index === this.previewIndex ? `routePhoto_${index}` : '',
            initialWidth: 60,
            initialHeight: 60,
            isViewingOriginal: this.isViewingOriginal
          })
        }, (photo: string, index: number) => `preview_${index}_${photo}`)
      }
      .index(this.previewIndex)
      .loop(false)
      .indicator(false)
      .disableSwipe(this.isDisableSwipe)
      .onChange((index: number) => {
        this.previewIndex = index;
        this.isDisableSwipe = false;
      })
      .width('100%')
      .height('100%')

      Column() {
        Row() {
          Blank()
          Flex({ justifyContent: FlexAlign.Center, alignItems: ItemAlign.Center }) {
            SymbolGlyph($r('sys.symbol.xmark'))
              .fontSize(20)
              .fontColor([Color.White])
          }
          .width(40)
          .height(40)
          .borderRadius(20)
          .border({ width: 1, color: $r('sys.color.indicator_border_color') })
          .backgroundBlurStyle(BlurStyle.Thin, { colorMode: ThemeColorMode.SYSTEM })
          .onClick(() => {
            this.getUIContext().animateTo({
              duration: 400,
              curve: Curve.FastOutSlowIn
            }, () => {
              this.showPhotoPreview = false;
            });
            this.updateSystemBarForPreview(false);
          })
        }
        .width('100%')
        .height(56)
        .alignItems(VerticalAlign.Center)
        .margin({ top: this.topInset })
        .padding({ left: 16, right: 16 })

        Column() {
          // 底部工具栏：保存 + 原图
          Row() {
            Row() {
              SymbolGlyph($r('sys.symbol.square_and_arrow_down'))
                .fontSize(16)
                .fontColor([Color.White])
              Text('保存')
                .fontSize(14)
                .fontColor(Color.White)
                .margin({ left: 4 })
            }
            .padding({
              left: 16,
              right: 16,
              top: 8,
              bottom: 8
            })
            .border({ width: 1, color: 'rgba(255,255,255,0.3)' })
            .borderRadius(20)
            .onClick(() => {
              this.saveCurrentPhoto();
            })

            Row() {
              Text(this.isViewingOriginal ? '适应屏幕' : '查看原图')
                .fontSize(14)
                .fontColor(Color.White)
            }
            .padding({
              left: 16,
              right: 16,
              top: 8,
              bottom: 8
            })
            .border({ width: 1, color: 'rgba(255,255,255,0.3)' })
            .borderRadius(20)
            .margin({ left: 12 })
            .onClick(() => {
              this.toggleViewOriginal();
            })
          }
          .width('100%')
          .justifyContent(FlexAlign.Center)
          .margin({ bottom: 12 })

          // 页码指示器
          Row() {
            Blank()
            Text(`${this.previewIndex + 1}/${this.getPreviewPhotos().length}`)
              .fontSize(13)
              .fontColor(Color.White)
              .backgroundColor('rgba(0,0,0,0.4)')
              .borderRadius(12)
              .padding({
                left: 10,
                right: 10,
                top: 4,
                bottom: 4
              })
            Blank()
          }
          .width('100%')
        }
        .width('100%')
        .padding({ bottom: this.bottomInset + 16 })
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.SpaceBetween)
      .hitTestBehavior(HitTestMode.Transparent)
    }
    .width('100%')
    .height('100%')
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    .backgroundColor(Color.Black)
    .onDisAppear(() => {
      this.showPhotoPreview = false;
      this.isDisableSwipe = false;
      this.isArriveBoundary = false;
      this.isImageReset = false;
      this.isViewingOriginal = false;
      this.updateSystemBarForPreview(false);
    })
  }

  private updateSystemBarForPreview(isPreview: boolean): void {
    const mainWindow: window.Window | undefined = AppStorage.get<window.Window>(AppStorageKeys.MAIN_WINDOW);
    if (mainWindow === undefined) {
      return;
    }
    const colorMode: ConfigurationConstant.ColorMode | undefined = AppStorage.get<ConfigurationConstant.ColorMode>(AppStorageKeys.COLOR_MODE);
    const isDark: boolean = colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
    const contentColor: string = isPreview || isDark ? '#FFFFFF' : '#000000';
    mainWindow.setWindowSystemBarProperties({
      statusBarContentColor: contentColor,
      navigationBarContentColor: contentColor
    }).catch((err: BusinessError) => {
      console.error(`RouteDetailSheet: set system bar failed: ${JSON.stringify(err)}`);
    });
  }
}
