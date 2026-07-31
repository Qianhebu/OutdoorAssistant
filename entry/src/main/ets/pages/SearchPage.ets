import { BackgroundDots } from '../common/BackgroundDots';

@Entry
@Component
struct SearchPage {
  @StorageLink('topInset') topInset: number = 0
  @StorageLink('bottomInset') bottomInset: number = 0
  @State searchText: string = '';
  private scroller: Scroller = new Scroller();

  aboutToAppear(): void {
    // 进入页面时自动聚焦输入框
  }

  build() {
    Stack({ alignContent: Alignment.Top }) {
      // 背景点阵
      BackgroundDots()

      Text('顶部搜索栏')
    }
    .width('100%')
    .height('100%')
    .padding({ top: this.topInset })


    // Column() {
    //   // 顶部搜索栏
    //   Row() {
    //     // 返回按钮
    //     Button({ type: ButtonType.Normal }) {
    //       Text('←')
    //         .fontSize(24)
    //         .fontColor('#000000')
    //     }
    //     .width(40)
    //     .height(40)
    //     .backgroundColor('transparent')
    //     .onClick(() => {
    //       router.back();
    //     })
    //
    //     // 搜索输入框（与 Index 页面的搜索图标共享转场）
    //     Search({ placeholder: '搜索地点、活动、装备...' })
    //       .layoutWeight(1)
    //       .height(40)
    //       .margin({ left: 8, right: 16 })
    //       .backgroundColor('#F5F5F5')
    //       .borderRadius(20)
    //       .sharedTransition('searchIcon', {
    //         duration: 300,
    //         curve: Curve.EaseInOut,
    //         type: SharedTransitionEffectType.Exchange
    //       })
    //       .onChange((value: string) => {
    //         this.searchText = value;
    //       })
    //   }
    //   .width('100%')
    //   .padding({ left: 16, right: 16, top: 12, bottom: 12 })
    //   .backgroundColor('#FFFFFF')
    //
    //   // 搜索内容区域
    //   Scroll(this.scroller) {
    //     Column() {
    //       Text('搜索结果将显示在这里')
    //         .fontSize(14)
    //         .fontColor('#999999')
    //         .margin({ top: 40 })
    //     }
    //     .width('100%')
    //     .padding(16)
    //   }
    //   .layoutWeight(1)
    //   .scrollBar(BarState.Off)
    //   .backgroundColor('#F5F7FA')
    // }
    // .width('100%')
    // .height('100%')
  }

  pageTransition() {
    // 渐入渐出效果
    PageTransitionEnter({
      type: RouteType.None,
      duration: 350,
      curve: Curve.FastOutSlowIn  // 流畅的缓动曲线
    })
      .opacity(0) // 从透明渐入到不透明

    PageTransitionExit({
      type: RouteType.None,
      duration: 350,
      curve: Curve.FastOutSlowIn
    })
      .opacity(0) // 从不透明渐出到透明
  }
}