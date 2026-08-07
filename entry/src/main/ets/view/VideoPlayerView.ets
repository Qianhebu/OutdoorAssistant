import { AppStorageKeys } from '../constant/AppStorageKeys';

@Component
export struct VideoPlayerView {
  @Prop videoSrc: string = '';
  @Prop isMuted: boolean = true;
  @Prop @Watch('onShouldPlayChanged') shouldPlay: boolean = false;
  onMuteToggle: () => void = () => {
  };
  private videoController: VideoController = new VideoController();
  private hasPrepared: boolean = false;
  @StorageLink(AppStorageKeys.IS_FOREGROUND) @Watch('onForegroundChanged') isAppForeground: boolean = true;

  aboutToDisappear(): void {
    this.videoController.stop();
  }

  private onForegroundChanged(): void {
    if (this.isAppForeground && this.shouldPlay) {
      this.videoController.start();
    } else {
      this.videoController.pause();
    }
  }

  private onShouldPlayChanged(): void {
    if (this.shouldPlay && this.isAppForeground) {
      if (this.hasPrepared) {
        this.videoController.start();
      }
    } else {
      this.videoController.pause();
    }
  }


  build() {
    Stack() {
      Video({
        src: $rawfile(this.videoSrc),
        controller: this.videoController
      })
        .width('100%')
        .height('100%')
        .autoPlay(false)
        .loop(true)
        .muted(this.isMuted)
        .controls(false)
        .objectFit(ImageFit.Cover)
        .onPrepared(() => {
          this.hasPrepared = true;
          if (this.shouldPlay && this.isAppForeground) {
            this.videoController.start();
          }
        })

      Row({ space: 8 }) {
        Row() {
          SymbolGlyph(this.isMuted ? $r('sys.symbol.speaker_slash_fill') : $r('sys.symbol.speaker_wave_3_fill'))
            .fontSize(14)
            .fontColor([Color.White])
        }
        .width(28)
        .height(28)
        .borderRadius(14)
        .backgroundColor('rgba(0,0,0,0.5)')
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)
        .onClick(() => {
          this.onMuteToggle();
        })
      }
      .position({ x: 0, y: 0 })
      .width('100%')
      .padding({
        left: 12,
        right: 12,
        top: 8,
        bottom: 8
      })
      .justifyContent(FlexAlign.End)
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#000000')
    .clip(true)
  }
}
