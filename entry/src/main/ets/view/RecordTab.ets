import {
  hdsMaterial,
  HdsNavDestination,
  HdsNavDestinationTitleMode,
  HdsTabsController,
  ScrollEffectType,
  TitleBarStyleOptions
} from '@kit.UIDesignKit';
import { LengthMetrics, promptAction } from '@kit.ArkUI';
import { AppStorageKeys } from '../constant/AppStorageKeys';

interface RecordItem {
  title: string;
  subtitle: string;
  icon: Resource;
}

@Component({ freezeWhenInactive: true })
export struct RecordTab {
  @StorageLink(AppStorageKeys.TOP_INSET) topInset: number = 0;
  @StorageLink(AppStorageKeys.BOTTOM_INSET) bottomInset: number = 0;
  scroller: Scroller = new Scroller();
  homeTabController: HdsTabsController = new HdsTabsController();
  private records: RecordItem[] = [
    { title: '东钱湖轻徒步', subtitle: '6.2km · 1.5h · 湖景路线', icon: $r('sys.symbol.mountain_2_fill') },
    { title: '城市绿道骑行', subtitle: '14.5km · 1h · 休闲骑行', icon: $r('sys.symbol.route') },
    { title: '周末露营准备', subtitle: '装备清单 · 天气提醒', icon: $r('sys.symbol.leaf_2_fill') }
  ];
  private titleBarStyle: TitleBarStyleOptions = {
    systemMaterialEffect: {
      materialType: hdsMaterial.MaterialType.IMMERSIVE,
      materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
    },
    scrollEffectOpts: {
      enableScrollEffect: true,
      scrollEffectType: ScrollEffectType.IMMERSIVE_GRADIENT_BLUR,
      blurEffectiveStartOffset: LengthMetrics.vp(24),
      blurEffectiveEndOffset: LengthMetrics.vp(112)
    }
  };

  build() {
    HdsNavDestination() {
      Scroll(this.scroller) {
        Column({ space: 16 }) {
          this.buildSummary();
          ForEach(this.records, (item: RecordItem) => {
            this.buildRecordItem(item);
          }, (item: RecordItem) => item.title)
        }
        .width('100%')
        .margin({ top: this.topInset + 56 })
        .padding({ left: 16, right: 16, bottom: this.bottomInset + 104 })
      }
      .edgeEffect(EdgeEffect.Spring)
      .scrollBar(BarState.Off)
      .height('100%')
      .width('100%')
      .backgroundColor($r('app.color.start_window_background'))
    }
    .titleBar({
      avoidLayoutSafeArea: true,
      content: { title: { mainTitle: '记录' } },
      style: this.titleBarStyle
    })
    .bindToScrollable([this.scroller])
    .hideBackButton(true)
    .titleMode(HdsNavDestinationTitleMode.MINI)
    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
    .width('100%')
    .height('100%')
  }

  @Builder
  buildSummary() {
    Row({ space: 12 }) {
      this.buildSummaryItem('本月活动', '3 次');
      this.buildSummaryItem('累计距离', '33.5 km');
      this.buildSummaryItem('累计时长', '6.5 h');
    }
    .width('100%')
    .padding(16)
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(22)
  }

  @Builder
  buildSummaryItem(label: string, value: string) {
    Column({ space: 6 }) {
      Text(value).fontSize(19).fontWeight(FontWeight.Bold).fontColor($r('sys.color.ohos_id_color_text_primary'))
      Text(label).fontSize(12).fontColor($r('sys.color.ohos_id_color_text_secondary'))
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  buildRecordItem(item: RecordItem) {
    Row({ space: 12 }) {
      SymbolGlyph(item.icon).fontSize(24).fontColor(['#00A991'])
      Column({ space: 4 }) {
        Text(item.title).fontSize(16).fontWeight(FontWeight.Medium).fontColor($r('sys.color.ohos_id_color_text_primary'))
        Text(item.subtitle).fontSize(12).fontColor($r('sys.color.ohos_id_color_text_secondary'))
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(18).fontColor([$r('sys.color.ohos_id_color_text_secondary')])
    }
    .width('100%')
    .padding(16)
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(20)
    .onClick(() => promptAction.showToast({ message: item.title }))
  }
}
