import { AppStorageKeys, ElevationPoint, HikingRouteItem, KmPaceItem } from '@ohos/common';
import { PhotoPreviewItem } from './PhotoPreviewItem';
import { PhotoSaveHelper } from './PhotoSaveHelper';
import { common, ConfigurationConstant } from '@kit.AbilityKit';
import { promptAction, window } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';

// Font size design tokens
const FONT_HERO: number = 48;
const FONT_DISPLAY: number = 32;
const FONT_HEADLINE: number = 24;
const FONT_TITLE: number = 20;
const FONT_SUBTITLE: number = 17;
const FONT_BODY: number = 14;
const FONT_CAPTION: number = 13;
const FONT_SMALL: number = 12;
const FONT_TINY: number = 11;

// Border radius design tokens
const RADIUS_SM: number = 4;
const RADIUS_MD: number = 8;
const RADIUS_LG: number = 10;
const RADIUS_XL: number = 12;
const RADIUS_XXL: number = 16;

// Spacing design tokens
const SPACE_XS: number = 4;
const SPACE_SM: number = 8;
const SPACE_MD: number = 12;
const SPACE_LG: number = 16;
const SPACE_XL: number = 20;
const SPACE_XXL: number = 24;
const SPACE_XXXL: number = 32;

// Canvas chart grid line color (matches neutral_divider token #E5E5EA, kept as string for Canvas API)
const CHART_GRID_COLOR: string = '#E5E5EA';

// Canvas chart line colors (kept as strings for Canvas API, values match design intent)
const CHART_PACE_COLOR: string = '#79D87B';
const CHART_HEART_RATE_COLOR: string = '#FF5C7A';
const CHART_RECOVERY_HR_COLOR: string = '#FF6B8A';
const CHART_CADENCE_COLOR: string = '#FFC938';
const CHART_ALTITUDE_COLOR: string = '#48D4DD';
const CHART_GROUND_TIME_COLOR: string = '#4E8DFF';
const CHART_BALANCE_COLOR: string = '#8DA8E8';
const CHART_VERTICAL_COLOR: string = '#55D8D0';

@Component
export struct RouteDetailSheet {
  @Prop route: HikingRouteItem | undefined = undefined;
  @State showPhotoPreview: boolean = false;
  @State previewIndex: number = 0;
  @State isSaving: boolean = false;
  @StorageLink(AppStorageKeys.TOP_INSET) topInset: number = 0;
  @StorageLink(AppStorageKeys.BOTTOM_INSET) bottomInset: number = 0;
  @StorageProp(AppStorageKeys.MAIN_WINDOW) mainWindow: window.Window | undefined = undefined;
  @StorageProp(AppStorageKeys.COLOR_MODE) colorMode: ConfigurationConstant.ColorMode | undefined = undefined;
  @Provide isDisableSwipe: boolean = false;
  @Provide isImageReset: boolean = false;
  @Provide isArriveBoundary: boolean = false;
  @Provide isViewingOriginal: boolean = false;
  private swipeController: SwiperController = new SwiperController();
  private paceChartCtx: CanvasRenderingContext2D = new CanvasRenderingContext2D(new RenderingContextSettings(true));
  private heartChartCtx: CanvasRenderingContext2D = new CanvasRenderingContext2D(new RenderingContextSettings(true));
  private altitudeChartCtx: CanvasRenderingContext2D = new CanvasRenderingContext2D(new RenderingContextSettings(true));
  private groundChartCtx: CanvasRenderingContext2D = new CanvasRenderingContext2D(new RenderingContextSettings(true));
  private balanceChartCtx: CanvasRenderingContext2D = new CanvasRenderingContext2D(new RenderingContextSettings(true));
  private amplitudeChartCtx: CanvasRenderingContext2D = new CanvasRenderingContext2D(new RenderingContextSettings(true));
  private verticalChartCtx: CanvasRenderingContext2D = new CanvasRenderingContext2D(new RenderingContextSettings(true));
  private cadenceChartCtx: CanvasRenderingContext2D = new CanvasRenderingContext2D(new RenderingContextSettings(true));

  build() {
    Column({ space: 0 }) {
      if (this.route) {
        this.buildSheetHeader()
        this.buildStatsCard()
      }
    }
    .width('100%')
    .padding({ top: 12, bottom: 12 })

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
          if (this.getAvatar()) {
            Image($rawfile(this.getAvatar()))
              .width(48)
              .height(48)
              .objectFit(ImageFit.Cover)
              .clip(new Circle({ width: 48, height: 48 }))
          } else {
            SymbolGlyph($r('sys.symbol.person_fill'))
              .fontSize(22)
              .fontColor([$r('sys.color.icon_secondary')])
          }
        }
        .width(48)
        .height(48)

        Column({ space: SPACE_XS }) {
          Text(this.getNickname())
            .fontSize(FONT_SUBTITLE)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('sys.color.font_primary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          Text(this.getTimeRange())
            .fontSize(FONT_CAPTION)
            .fontColor($r('sys.color.font_tertiary'))
        }
        .alignItems(HorizontalAlign.Start)
      }
      .layoutWeight(1)
      .alignItems(VerticalAlign.Center)

      if ((this.route?.photos ?? []).length > 0) {
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
            .fontSize(FONT_TINY)
            .fontColor($r('app.color.polaroid_date_text'))
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
          color: $r('app.color.polaroid_shadow'),
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
            .border({ width: 1, color: $r('app.color.photo_preview_border') })
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
            .border({ width: 1, color: $r('app.color.photo_preview_border') })
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
              .backgroundColor($r('app.color.photo_page_indicator_bg'))
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
    const mainWindow: window.Window | undefined = this.mainWindow;
    if (mainWindow === undefined) {
      return;
    }
    const colorMode: ConfigurationConstant.ColorMode | undefined = this.colorMode;
    const isDark: boolean = colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
    const contentColor: string = isPreview || isDark ? '#FFFFFF' : '#000000';
    const result: Promise<void> | undefined = mainWindow.setWindowSystemBarProperties({
      statusBarContentColor: contentColor,
      navigationBarContentColor: contentColor
    });
    if (result) {
      result.catch((err: BusinessError) => {
        console.error(`RouteDetailSheet: set system bar failed: ${JSON.stringify(err)}`);
      });
    }
  }

  private formatPace(paceMinPerKm: number): string {
    const totalSeconds: number = Math.round(paceMinPerKm * 60);
    const minutes: number = Math.floor(totalSeconds / 60);
    const seconds: number = totalSeconds % 60;
    return `${minutes}'${seconds < 10 ? '0' : ''}${seconds}"`;
  }

  private formatDurationShort(): string {
    const display: string = this.route?.durationDisplay ?? '0分钟';
    return display.replace('小时', ':').replace('分钟', '');
  }

  private formatDurationClock(): string {
    const display: string = this.route?.durationDisplay ?? '0分钟';
    const hMatch: RegExpMatchArray | null = display.match(new RegExp('(\\d+)小时'));
    const mMatch: RegExpMatchArray | null = display.match(new RegExp('(\\d+)分钟'));
    const hours: number = hMatch && hMatch.length > 1 ? parseInt(hMatch[1], 10) : 0;
    const minutes: number = mMatch && mMatch.length > 1 ? parseInt(mMatch[1], 10) : 0;
    return `${this.padNumber(hours)}:${this.padNumber(minutes)}:00`;
  }

  private getCalories(): number {
    return Math.round((this.route?.distanceKm ?? 0) * 54 + (this.route?.elevationGainMeters ?? 0) * 0.18);
  }

  private getStepCount(): number {
    if (this.route?.totalSteps) {
      return this.route.totalSteps;
    }
    return Math.round((this.route?.distanceKm ?? 0) * 1380);
  }

  private getFloors(): number {
    if (this.route?.floorsClimbed) {
      return this.route.floorsClimbed;
    }
    return Math.round((this.route?.elevationGainMeters ?? 0) / 3.1);
  }

  private padNumber(value: number): string {
    return value < 10 ? `0${value}` : `${value}`;
  }

  private formatStatDateTime(): string {
    const source: string | undefined = this.route?.startTime ?? this.route?.endTime;
    if (!source) {
      return '2026/5/17 7:31';
    }
    const date: Date = new Date(source);
    return `${date.getFullYear()}/${date.getMonth() + 1}/${date.getDate()} ${date.getHours()}:${this.padNumber(date.getMinutes())}`;
  }

  private formatNumberWithComma(value: number, fractionDigits: number = 0): string {
    const fixedValue: string = value.toFixed(fractionDigits);
    const parts: string[] = fixedValue.split('.');
    let integerPart: string = parts[0];
    let result: string = '';
    while (integerPart.length > 3) {
      result = `,${integerPart.slice(integerPart.length - 3)}${result}`;
      integerPart = integerPart.slice(0, integerPart.length - 3);
    }
    result = `${integerPart}${result}`;
    if (parts.length > 1) {
      return `${result}.${parts[1]}`;
    }
    return result;
  }

  private getActiveCalories(): number {
    return Math.round(this.getCalories() * 0.9);
  }

  private getAverageCadence(): number {
    const durationHours: number = this.parseDurationHours(this.route?.durationDisplay ?? '');
    const durationMinutes: number = durationHours * 60;
    if (durationMinutes > 0) {
      return Math.round(this.getStepCount() / durationMinutes);
    }
    return 139;
  }

  private getAverageSpeed(): string {
    const durationHours: number = this.parseDurationHours(this.route?.durationDisplay ?? '');
    if (durationHours <= 0) {
      return '0.00';
    }
    return ((this.route?.distanceKm ?? 0) / durationHours).toFixed(2);
  }

  private getPacePercent(pace: number): number {
    const maxPace: number = 28;
    const minPace: number = 10;
    const percent: number = 100 - ((pace - minPace) / (maxPace - minPace) * 45);
    if (percent < 42) {
      return 42;
    }
    if (percent > 96) {
      return 96;
    }
    return percent;
  }

  private getFastestPace(): number {
    const list: KmPaceItem[] = this.route?.kmPaceList ?? [];
    if (list.length === 0) {
      return Math.max((this.route?.avgPaceMinPerKm ?? 0) - 3.6, 4);
    }
    let fastest: number = list[0].paceMinPerKm;
    list.forEach((item: KmPaceItem) => {
      if (item.paceMinPerKm < fastest) {
        fastest = item.paceMinPerKm;
      }
    });
    return fastest;
  }

  private getSlowestPace(): number {
    const list: KmPaceItem[] = this.route?.kmPaceList ?? [];
    if (list.length === 0) {
      return (this.route?.avgPaceMinPerKm ?? 0) + 6;
    }
    let slowest: number = list[0].paceMinPerKm;
    list.forEach((item: KmPaceItem) => {
      if (item.paceMinPerKm > slowest) {
        slowest = item.paceMinPerKm;
      }
    });
    return slowest;
  }

  private getPaceBarWidth(pace: number): string {
    const slowest: number = Math.max(this.getSlowestPace(), 1);
    const percent: number = Math.max(32, Math.min(94, pace / slowest * 94));
    return `${percent}%`;
  }

  private getPaceBarStartColor(pace: number): ResourceColor {
    return pace === this.getFastestPace() ? $r('app.color.pace_bar_start_fast') : $r('app.color.pace_bar_start_normal');
  }

  private getPaceBarEndColor(pace: number): ResourceColor {
    return pace === this.getFastestPace() ? $r('app.color.pace_bar_end_fast') : $r('app.color.pace_bar_end_normal');
  }

  private getCumulativePaceSeconds(count: number): number {
    const list: KmPaceItem[] = this.route?.kmPaceList ?? [];
    let seconds: number = 0;
    list.slice(0, count).forEach((item: KmPaceItem) => {
      seconds += Math.round(item.paceMinPerKm * 60);
    });
    return seconds;
  }

  private getRecentPaceSeconds(endCount: number): number {
    const list: KmPaceItem[] = this.route?.kmPaceList ?? [];
    const startIndex: number = Math.max(0, endCount - 5);
    let seconds: number = 0;
    list.slice(startIndex, endCount).forEach((item: KmPaceItem) => {
      seconds += Math.round(item.paceMinPerKm * 60);
    });
    return seconds;
  }

  private formatDurationFromSeconds(totalSeconds: number): string {
    const hours: number = Math.floor(totalSeconds / 3600);
    const minutes: number = Math.floor((totalSeconds % 3600) / 60);
    const seconds: number = totalSeconds % 60;
    return `${this.padNumber(hours)}:${this.padNumber(minutes)}:${this.padNumber(seconds)}`;
  }

  private getRemainingDistance(): number {
    const fullKmCount: number = this.route?.kmPaceList?.length ?? 0;
    return Math.max(0, (this.route?.distanceKm ?? 0) - fullKmCount);
  }

  private getRemainingPaceText(): string {
    const remainingDistance: number = this.getRemainingDistance();
    if (remainingDistance <= 0) {
      return '';
    }
    const pace: number = this.route?.avgPaceMinPerKm ?? 0;
    return this.formatPace(pace * remainingDistance);
  }

  private getMiniSeries(seed: number, count: number): number[] {
    const values: number[] = [];
    for (let index = 0; index < count; index++) {
      const wave: number = Math.sin((index + seed) * 0.72) * 18;
      const ripple: number = Math.cos((index + seed) * 0.31) * 12;
      const spike: number = index % 9 === seed % 5 ? 18 : 0;
      values.push(50 + wave + ripple + spike);
    }
    return values;
  }

  private getElevationSeries(): number[] {
    const profile = this.route?.elevationProfile;
    if (profile && profile.length > 0) {
      return profile.map((item: ElevationPoint) => item.altitudeMeters);
    }
    return this.getMiniSeries(4, 36);
  }

  private drawLineChart(ctx: CanvasRenderingContext2D, values: number[], color: string, fillArea: boolean): void {
    if (values.length < 2) {
      return;
    }
    const width: number = 300;
    const height: number = 118;
    const top: number = 10;
    const bottom: number = 16;
    const chartHeight: number = height - top - bottom;
    let minValue: number = values[0];
    let maxValue: number = values[0];
    values.forEach((item: number) => {
      if (item < minValue) {
        minValue = item;
      }
      if (item > maxValue) {
        maxValue = item;
      }
    });
    const range: number = Math.max(maxValue - minValue, 1);
    ctx.clearRect(0, 0, width, height);
    ctx.lineWidth = 1;
    ctx.strokeStyle = CHART_GRID_COLOR;
    for (let index = 0; index < 4; index++) {
      const y: number = top + index * chartHeight / 3;
      ctx.beginPath();
      ctx.moveTo(0, y);
      ctx.lineTo(width, y);
      ctx.stroke();
    }
    ctx.beginPath();
    values.forEach((item: number, index: number) => {
      const x: number = index * width / (values.length - 1);
      const y: number = top + chartHeight - ((item - minValue) / range) * chartHeight;
      if (index === 0) {
        ctx.moveTo(x, y);
      } else {
        ctx.lineTo(x, y);
      }
    });
    if (fillArea) {
      ctx.lineTo(width, height - bottom);
      ctx.lineTo(0, height - bottom);
      ctx.closePath();
      ctx.globalAlpha = 0.18;
      ctx.fillStyle = color;
      ctx.fill();
      ctx.globalAlpha = 1;
      ctx.beginPath();
      values.forEach((item: number, index: number) => {
        const x: number = index * width / (values.length - 1);
        const y: number = top + chartHeight - ((item - minValue) / range) * chartHeight;
        if (index === 0) {
          ctx.moveTo(x, y);
        } else {
          ctx.lineTo(x, y);
        }
      });
    }
    ctx.lineWidth = 2;
    ctx.strokeStyle = color;
    ctx.stroke();
  }

  // 参数信息卡片
  @Builder
  buildStatsCard() {
    Column({ space: SPACE_MD }) {
      this.buildOverviewCard()
      this.buildPaceBarsCard()
      this.buildSplitTableCard()

      this.buildLineChartCard('实时配速', this.formatPace(this.route?.avgPaceMinPerKm ?? 0), '最快 ' +
        this.formatPace(Math.max((this.route?.avgPaceMinPerKm ?? 12) - 5, 4)), this.getMiniSeries(2, 48),
        CHART_PACE_COLOR, this.paceChartCtx, true)

      this.buildLineChartCard('心率', '182 次/分', '平均 148 次/分', this.getMiniSeries(7, 48), CHART_HEART_RATE_COLOR,
        this.heartChartCtx, true)
      this.buildLineChartCard('恢复心率', '7 次/分', '148/134 次/分', this.getMiniSeries(16, 48), CHART_RECOVERY_HR_COLOR,
        this.groundChartCtx, true)
      this.buildTrainingPerformanceCard()
      this.buildLineChartCard('步频', '139 步/分', '244 步/分', this.getMiniSeries(28, 48), CHART_CADENCE_COLOR,
        this.cadenceChartCtx, false)
      this.buildLineChartCard('海拔', `${this.route?.minAltitudeMeters ?? 0} m`, `${this.route?.maxAltitudeMeters ?? 0} m`,
        this.getElevationSeries(), CHART_ALTITUDE_COLOR, this.altitudeChartCtx, true)
      this.buildLineChartCard('触地时间', '257 ms', '209 ms', this.getMiniSeries(11, 48), CHART_GROUND_TIME_COLOR,
        this.balanceChartCtx, false)
      this.buildLineChartCard('左右触地平衡', '49.9%', '50.1%', this.getMiniSeries(15, 48), CHART_BALANCE_COLOR,
        this.amplitudeChartCtx, false)
      this.buildLineChartCard('垂直振幅', '7.9 cm', '10.2 cm', this.getMiniSeries(21, 48), CHART_VERTICAL_COLOR,
        this.verticalChartCtx, false)
    }
    .width('100%')
    .margin({ top: 20 })
  }

  @Builder
  buildOverviewCard() {
    Column({ space: SPACE_XXL }) {
      Column({ space: 8 }) {
        Row({ space: 8 }) {
          Text(`${(this.route?.distanceKm ?? 0).toFixed(2)}`)
            .fontSize(FONT_HERO)
            .fontWeight(FontWeight.Bold)
          Text('公里')
            .fontSize(FONT_BODY)
            .margin({ top: 24 })
        }
        .alignItems(VerticalAlign.Top)

        Text(`统计时间： ${this.formatStatDateTime()}`)
          .fontSize(FONT_SMALL)

        Column({ space: 4 }) {
          Row()
            .width('100%')
            .height(5)
            .borderRadius(RADIUS_MD)
            .linearGradient({
              direction: GradientDirection.Right,
              colors: [[$r('app.color.pace_gradient_start'), 0], [$r('app.color.pace_gradient_mid'), 0.58], [$r('app.color.pace_gradient_end'), 1]]
            })
            .margin({ top: 6 })

          Row() {
            Text(`最慢 ${this.formatPace((this.route?.avgPaceMinPerKm ?? 0) + 6)}`)
              .fontSize(FONT_TINY)
              .fontColor($r('app.color.pace_label_slow'))
            Blank()
            Text(`最快 ${this.formatPace(Math.max((this.route?.avgPaceMinPerKm ?? 0) - 3.6, 4))}`)
              .fontSize(FONT_TINY)
              .fontColor($r('app.color.pace_label_fast'))
          }
          .width('100%')
        }
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)


      Flex({ justifyContent: FlexAlign.Start, alignItems: ItemAlign.Center, wrap: FlexWrap.Wrap }) {
        this.buildOverviewMetric(this.formatDurationClock(), '', '运动时间')
        this.buildOverviewMetric(this.formatPace(this.route?.avgPaceMinPerKm ?? 0), '/公里', '平均配速')
        this.buildOverviewMetric(this.formatNumberWithComma(this.getCalories()), '千卡', '总消耗热量')
        this.buildOverviewMetric(this.formatNumberWithComma(this.getActiveCalories()), '千卡', '活动热量')
        this.buildOverviewMetric('182', '次/分钟', '平均心率')
        this.buildOverviewMetric(`${this.getAverageCadence()}`, '步/分钟', '平均步频')
        this.buildOverviewMetric('84', '厘米', '平均步幅')
        this.buildOverviewMetric(this.formatNumberWithComma(this.route?.elevationGainMeters ?? 0, 1), '米', '累计爬升')
        this.buildOverviewMetric(this.formatNumberWithComma(this.route?.elevationLossMeters ?? 0, 1), '米', '累计下降')
        this.buildOverviewMetric(this.formatNumberWithComma(this.getStepCount()), '步', '步数')
        this.buildOverviewMetric(this.getAverageSpeed(), '公里/小时', '平均速度')
      }
      .width('100%')
    }
    .width('100%')
    .borderRadius(RADIUS_XXL)
    .padding({
      top: 20,
      right: SPACE_LG,
      bottom: 20,
      left: SPACE_LG
    })
    .backgroundBlurStyle(BlurStyle.Thin, { colorMode: ThemeColorMode.SYSTEM })
  }

  @Builder
  buildPaceBarsCard() {
    Column({ space: SPACE_XL }) {
      Text('配速')
        .width('100%')
        .fontSize(FONT_TITLE)
        .fontWeight(FontWeight.Medium)
        .textAlign(TextAlign.Start)

      Row() {
        Column({ space: 4 }) {
          Row({ space: 4 }) {
            Text(this.formatPace(this.route?.avgPaceMinPerKm ?? 0))
              .fontSize(FONT_HEADLINE)
              .fontWeight(FontWeight.Bold)
            Text('/公里')
              .fontSize(FONT_SMALL)
              .fontColor($r('sys.color.font_tertiary'))
              .margin({ top: 12 })
          }
          .alignItems(VerticalAlign.Top)

          Text('平均配速')
            .fontSize(FONT_SMALL)
            .fontColor($r('sys.color.font_tertiary'))
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Column({ space: 4 }) {
          Row({ space: 4 }) {
            Text(this.formatPace(this.getFastestPace()))
              .fontSize(FONT_HEADLINE)
              .fontWeight(FontWeight.Bold)
            Text('/公里')
              .fontSize(FONT_SMALL)
              .fontColor($r('sys.color.font_tertiary'))
              .margin({ top: 12 })
          }
          .alignItems(VerticalAlign.Top)

          Text('最快配速')
            .fontSize(FONT_SMALL)
            .fontColor($r('sys.color.font_tertiary'))
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
      }
      .width('100%')

      Column({ space: 6 }) {
        Row({ space: 20 }) {
          Text('公里')
            .fontSize(FONT_SMALL)
            .fontColor($r('sys.color.font_tertiary'))
          Text('配速（/公里）')
            .fontSize(FONT_SMALL)
            .fontColor($r('sys.color.font_tertiary'))
        }
        .width('100%')

        ForEach(this.route?.kmPaceList ?? [], (item: KmPaceItem, index: number) => {
          Column({ space: 4 }) {
            this.buildPaceBarRow(item)
            if ((index + 1) % 5 === 0) {
              this.buildPaceSummaryRow(index + 1)
            }
          }
          .width('100%')
        }, (item: KmPaceItem) => `pace_${item.km}`)

        if (this.getRemainingDistance() > 0) {
          Row() {
            Text(`不足 1 公里用时 ${this.getRemainingPaceText()}`)
              .fontSize(FONT_BODY)
              .fontColor($r('app.color.summary_text'))
              .margin({ left: 10 })
            Blank()
          }
          .width('100%')
          .height(24)
          .borderRadius(RADIUS_XL)
          .backgroundColor($r('app.color.pace_bar_bg'))
        }
      }
      .width('100%')

      Row({ space: 8 }) {
        Text('收起')
          .fontSize(16)
          .fontColor($r('app.color.collapse_text'))
        Text('⌃')
          .fontSize(22)
          .fontColor($r('app.color.collapse_arrow'))
          .margin({ top: 2 })
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
    }
    .width('100%')
    .borderRadius(RADIUS_XXL)
    .padding({
      top: SPACE_XXL,
      right: SPACE_LG,
      bottom: SPACE_LG,
      left: SPACE_LG
    })
    .backgroundBlurStyle(BlurStyle.Thin, { colorMode: ThemeColorMode.SYSTEM })
  }

  @Builder
  buildOverviewMetric(value: string, unit: string, label: string) {
    Column({ space: SPACE_XS }) {
      Row({ space: 3 }) {
        Text(value)
          .fontSize(FONT_DISPLAY)
          .fontWeight(FontWeight.Bold)
        if (unit) {
          Text(unit)
            .fontSize(FONT_SMALL)
            .fontColor($r('sys.color.font_tertiary'))
            .margin({ top: 12 })
        }
      }
      .alignItems(VerticalAlign.Top)

      Text(label)
        .fontSize(FONT_SMALL)
        .fontColor($r('sys.color.font_tertiary'))
    }
    .alignItems(HorizontalAlign.Start)
    .width('50%')
    .padding({ bottom: SPACE_LG })
  }

  @Builder
  buildSportInsightBox() {
    Column() {
      Column({ space: SPACE_MD }) {
        Row() {
          Row({ space: 8 }) {
            this.buildInsightIcon()
            Text('运动解读')
              .fontSize(FONT_SUBTITLE)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.insight_title'))
          }
          .alignItems(VerticalAlign.Center)

          Blank()

          Text('⌄')
            .fontSize(24)
            .fontColor($r('app.color.insight_arrow'))
        }
        .width('100%')

        Text('本次越野跑顺利完成，血氧维持正常水平，整体节奏把控得当，展现了良好的中高强度运动适应能力。')
          .fontSize(FONT_BODY)
          .lineHeight(28)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.insight_text'))
      }
      .width('100%')
      .padding({
        top: 16,
        right: 16,
        bottom: SPACE_LG,
        left: 16
      })
      .borderRadius(RADIUS_XXL)
      .backgroundColor(Color.White)
    }
    .width('100%')
    .padding(1)
    .borderRadius(RADIUS_XXL)
    .linearGradient({
      direction: GradientDirection.Right,
      colors: [[$r('app.color.insight_gradient_start'), 0], [$r('app.color.insight_gradient_mid'), 0.45], [$r('app.color.insight_gradient_end'), 1]]
    })
  }

  @Builder
  buildInsightIcon() {
    Stack() {
      Text('♥')
        .fontSize(18)
        .fontColor($r('app.color.insight_heart_left'))
        .rotate({ angle: -8 })
        .offset({ x: -4, y: -1 })
      Text('♥')
        .fontSize(18)
        .fontColor($r('app.color.insight_heart_right'))
        .rotate({ angle: 8 })
        .offset({ x: 4, y: 1 })
      Text('+')
        .fontSize(10)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.insight_heart_right'))
        .offset({ x: 10, y: 8 })
    }
    .width(28)
    .height(24)
  }

  @Builder
  buildDataCell(value: string, unit: string, label: string) {
    GridItem() {
      Column({ space: 3 }) {
        Row({ space: 2 }) {
          Text(value)
            .fontSize(FONT_TITLE)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('sys.color.font_primary'))
          if (unit) {
            Text(unit)
              .fontSize(FONT_TINY)
              .fontColor($r('sys.color.font_tertiary'))
              .margin({ top: 7 })
          }
        }

        Text(label)
          .fontSize(FONT_TINY)
          .fontColor($r('sys.color.font_tertiary'))
      }
      .alignItems(HorizontalAlign.Start)
    }
  }

  @Builder
  buildTrainingPerformanceCard() {
    Column({ space: SPACE_MD }) {
      Text('训练表现')
        .fontSize(FONT_TITLE)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font_primary'))

      this.buildTrainingScoreRow('有氧训练压力', '5.0', '本次训练强度较高，注意充分恢复。')
      this.buildTrainingScoreRow('无氧训练压力', '5.0', '高强度爬升和变速路段较多。')
      this.buildTrainingScoreRow('恢复时间', '78 小时', '建议结合睡眠和疲劳状态安排下一次运动。')
    }
    .width('100%')
    .borderRadius(RADIUS_XL)
    .padding(16)
    .backgroundColor($r('sys.color.comp_background_primary'))
  }

  @Builder
  buildTrainingScoreRow(label: string, value: string, desc: string) {
    Column({ space: 5 }) {
      Row() {
        Column({ space: 2 }) {
          Text(label)
            .fontSize(FONT_SMALL)
            .fontColor($r('sys.color.font_secondary'))
          Text(value)
            .fontSize(FONT_TITLE)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('sys.color.font_primary'))
        }
        .layoutWeight(1)

        this.buildColoredScale()
      }

      Text(desc)
        .fontSize(FONT_TINY)
        .fontColor($r('sys.color.font_tertiary'))
    }
    .width('100%')
  }

  @Builder
  buildColoredScale() {
    Row({ space: 2 }) {
      Row().width(24).height(5).borderRadius(RADIUS_SM).backgroundColor($r('app.color.training_scale_1'))
      Row().width(24).height(5).borderRadius(RADIUS_SM).backgroundColor($r('app.color.training_scale_2'))
      Row().width(24).height(5).borderRadius(RADIUS_SM).backgroundColor($r('app.color.training_scale_3'))
      Row().width(24).height(5).borderRadius(RADIUS_SM).backgroundColor($r('app.color.training_scale_4'))
    }
  }

  @Builder
  buildPostureValue(value: string, label: string) {
    Column({ space: SPACE_XS }) {
      Text(value)
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('sys.color.font_primary'))
      Text(label)
        .fontSize(FONT_TINY)
        .fontColor($r('sys.color.font_tertiary'))
    }
    .alignItems(HorizontalAlign.Start)
    .layoutWeight(1)
  }

  @Builder
  buildProgressMetric(label: string, value: string, percent: number, color: string) {
    Column({ space: 6 }) {
      Row() {
        Text(label)
          .fontSize(FONT_SMALL)
          .fontColor($r('sys.color.font_secondary'))
          .layoutWeight(1)
        Text(value)
          .fontSize(FONT_CAPTION)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
      }

      Stack({ alignContent: Alignment.Start }) {
        Row()
          .width('100%')
          .height(5)
          .borderRadius(RADIUS_SM)
          .backgroundColor($r('sys.color.comp_background_secondary'))
        Row()
          .width(`${percent}%`)
          .height(5)
          .borderRadius(RADIUS_SM)
          .backgroundColor(color)
      }
      .width('100%')
      .height(5)
    }
  }

  @Builder
  buildPaceBarRow(item: KmPaceItem) {
    Stack({ alignContent: Alignment.Start }) {
      Row()
        .width('100%')
        .height(24)
        .borderRadius(RADIUS_XL)
        .backgroundColor($r('app.color.pace_bar_bg'))

      Row() {
        Text(`${item.km}`)
          .fontSize(FONT_BODY)
          .fontColor(Color.White)
          .width(34)
          .margin({ left: 10 })

        Blank()

        Text(this.formatPace(item.paceMinPerKm))
          .fontSize(FONT_BODY)
          .fontWeight(FontWeight.Medium)
          .fontColor(Color.White)
          .margin({ right: 10 })
      }
      .width(this.getPaceBarWidth(item.paceMinPerKm))
      .height(24)
      .borderRadius(RADIUS_XL)
      .linearGradient({
        direction: GradientDirection.Right,
        colors: [[this.getPaceBarStartColor(item.paceMinPerKm), 0], [this.getPaceBarEndColor(item.paceMinPerKm), 1]]
      })
    }
    .width('100%')
    .height(24)
  }

  @Builder
  buildPaceSummaryRow(count: number) {
    Row() {
      if (count > 5) {
        Text(`近 5 公里用时 ${this.formatDurationFromSeconds(this.getRecentPaceSeconds(count))}`)
          .fontSize(FONT_BODY)
          .fontColor($r('app.color.summary_text'))
          .margin({ left: 10 })

        Text('  ')
          .fontSize(FONT_BODY)
      }

      Text(`${count} 公里累计用时 ${this.formatDurationFromSeconds(this.getCumulativePaceSeconds(count))}`)
        .fontSize(FONT_BODY)
        .fontColor($r('app.color.summary_text'))
        .margin({ left: count === 5 ? 10 : 0 })
    }
    .width('100%')
    .height(28)
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  buildSplitTableCard() {
    Column({ space: SPACE_MD }) {
      Row() {
        Text('分段')
          .fontSize(FONT_TITLE)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
        Blank()
        SymbolGlyph($r('sys.symbol.chevron_right'))
          .fontSize(14)
          .fontColor([$r('sys.color.icon_secondary')])
      }
      .width('100%')

      Row() {
        this.buildTableText('公里', FONT_SMALL, FontWeight.Regular)
        this.buildTableText('配速', FONT_SMALL, FontWeight.Regular)
        this.buildTableText('累计上升', FONT_SMALL, FontWeight.Regular)
        this.buildTableText('累计下降', FONT_SMALL, FontWeight.Regular)
      }
      .width('100%')

      ForEach((this.route?.kmPaceList ?? []).slice(0, 12), (item: KmPaceItem) => {
        Row() {
          this.buildTableText(`${item.km}`, FONT_SMALL, FontWeight.Medium)
          this.buildTableText(this.formatPace(item.paceMinPerKm), FONT_SMALL, FontWeight.Regular)
          this.buildTableText(`${item.elevationGainMeters} m`, FONT_SMALL, FontWeight.Regular)
          this.buildTableText(`${item.elevationLossMeters} m`, FONT_SMALL, FontWeight.Regular)
        }
        .width('100%')
        .padding({ top: 4, bottom: 4 })
      }, (item: KmPaceItem) => `split_${item.km}`)
    }
    .width('100%')
    .borderRadius(RADIUS_XXL)
    .padding(16)
    .backgroundColor($r('sys.color.comp_background_primary'))
  }

  @Builder
  buildTableText(text: string, size: number, weight: FontWeight) {
    Text(text)
      .fontSize(size)
      .fontWeight(weight)
      .fontColor($r('sys.color.font_secondary'))
      .textAlign(TextAlign.Center)
      .layoutWeight(1)
  }

  @Builder
  buildLineChartCard(title: string, leftValue: string, rightValue: string, values: number[], color: string,
    ctx: CanvasRenderingContext2D, fillArea: boolean) {
    Column({ space: 12 }) {
      Row() {
        Text(title)
          .fontSize(FONT_TITLE)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
        Blank()
        SymbolGlyph($r('sys.symbol.chevron_right'))
          .fontSize(14)
          .fontColor([$r('sys.color.icon_secondary')])
      }
      .width('100%')

      Row() {
        this.buildChartSummary(leftValue, title === '实时配速' ? '平均配速' : '最小值')
        this.buildChartSummary(rightValue, title === '实时配速' ? '最快配速' : '最大值')
      }
      .width('100%')

      Canvas(ctx)
        .width('100%')
        .height(118)
        .onReady(() => {
          this.drawLineChart(ctx, values, color, fillArea);
        })
        .onAreaChange((oldValue: Area, newValue: Area) => {
          if (oldValue.width !== newValue.width || oldValue.height !== newValue.height) {
            this.drawLineChart(ctx, values, color, fillArea);
          }
        })

      this.buildChartLegend(color, title)
    }
    .width('100%')
    .borderRadius(RADIUS_XL)
    .padding({
      left: SPACE_LG,
      right: SPACE_LG,
      top: SPACE_LG,
      bottom: 12
    })
    .backgroundColor($r('sys.color.comp_background_primary'))
  }

  @Builder
  buildChartSummary(value: string, label: string) {
    Column({ space: 3 }) {
      Text(value)
        .fontSize(FONT_TITLE)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('sys.color.font_primary'))
      Text(label)
        .fontSize(11)
        .fontColor($r('sys.color.font_tertiary'))
    }
    .alignItems(HorizontalAlign.Start)
    .layoutWeight(1)
  }

  @Builder
  buildChartLegend(color: string, title: string) {
    Column({ space: 5 }) {
      Row({ space: 6 }) {
        Circle()
          .width(6)
          .height(6)
          .fill(color)
        Text(`${title} 趋势`)
          .fontSize(FONT_TINY)
          .fontColor($r('sys.color.font_tertiary'))
        Blank()
        Text(this.route?.durationDisplay ?? '')
          .fontSize(FONT_TINY)
          .fontColor($r('sys.color.font_tertiary'))
      }
      .width('100%')

      Row() {
        Text('0:00')
          .fontSize(FONT_TINY)
          .fontColor($r('sys.color.font_tertiary'))
        Blank()
        Text(this.formatDurationShort())
          .fontSize(FONT_TINY)
          .fontColor($r('sys.color.font_tertiary'))
      }
      .width('100%')
    }
  }

  @Builder
  buildStatItem(icon: Resource, value: string, unit: string, label: string) {
    Column({ space: SPACE_XS }) {
      SymbolGlyph(icon)
        .fontSize(FONT_TITLE)
        .fontColor([$r('sys.color.icon_secondary')])
      Row({ space: 2 }) {
        Text(value)
          .fontSize(FONT_TITLE)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('sys.color.font_primary'))
        if (unit) {
          Text(unit)
            .fontSize(FONT_SMALL)
            .fontColor($r('sys.color.font_tertiary'))
        }
      }

      Text(label)
        .fontSize(FONT_TINY)
        .fontColor($r('sys.color.font_tertiary'))
    }
    .alignItems(HorizontalAlign.Center)
    .layoutWeight(1)
  }
}
