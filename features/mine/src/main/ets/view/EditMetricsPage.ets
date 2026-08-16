import { AppStorageKeys } from '@ohos/common';
import { StorageKey } from '@ohos/common';
import { PageContext } from '@ohos/common';
import {
  ALL_RECORD_METRICS,
  RecordMetric,
  RecordMetricStore,
  getRecordMetricStore
} from '@ohos/common';
import {
  hdsMaterial,
  HdsNavDestination,
  ScrollEffectType
} from '@kit.UIDesignKit';
import { LengthMetrics, promptAction } from '@kit.ArkUI';

/** 编辑数据指标页：点击切换记录页展示的指标，保存后生效 */
@Component
export struct EditMetricsPage {
  @StorageLink(AppStorageKeys.TOP_INSET) topInset: number = 0;
  @StorageLink(AppStorageKeys.BOTTOM_INSET) bottomInset: number = 0;
  @StorageLink(StorageKey.HOME_PAGE_CONTEXT) appPageContext: PageContext =
    AppStorage.get<PageContext>(StorageKey.HOME_PAGE_CONTEXT) ?? new PageContext();
  @State selectedKeys: string[] = [];
  private metricStore: RecordMetricStore = getRecordMetricStore();
  private scroller: Scroller = new Scroller();

  aboutToAppear(): void {
    this.selectedKeys = this.metricStore.visibleKeys.slice();
  }

  private isSelected(key: string): boolean {
    return this.selectedKeys.indexOf(key) >= 0;
  }

  private toggleMetric(key: string): void {
    const index: number = this.selectedKeys.indexOf(key);
    if (index >= 0) {
      const next: string[] = [];
      for (let i = 0; i < this.selectedKeys.length; i++) {
        if (this.selectedKeys[i] !== key) {
          next.push(this.selectedKeys[i]);
        }
      }
      this.selectedKeys = next;
    } else {
      this.selectedKeys = this.selectedKeys.concat(key);
    }
  }

  private saveMetrics(): void {
    if (this.selectedKeys.length === 0) {
      promptAction.showToast({ message: '至少保留一个指标' });
      return;
    }
    this.metricStore.visibleKeys = this.selectedKeys.slice();
    promptAction.showToast({ message: '已保存数据指标' });
    this.appPageContext.popPage();
  }

  build() {
    HdsNavDestination() {
      Scroll(this.scroller) {
        Column() {
          Text('点击切换显示的数据指标')
            .fontSize(13)
            .fontColor($r('sys.color.ohos_id_color_text_secondary'))
            .width('100%')
            .margin({ top: 4, bottom: 12 })

          Grid() {
            ForEach(ALL_RECORD_METRICS, (metric: RecordMetric) => {
              GridItem() {
                this.buildMetricCell(metric)
              }
            }, (metric: RecordMetric) => metric.key)
          }
          .columnsTemplate('1fr 1fr')
          .columnsGap(12)
          .rowsGap(12)
          .width('100%')
        }
        .width('100%')
        .padding({ left: 16, right: 16, bottom: this.bottomInset + 16 })
      }
      .clip(false)
      .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
      .scrollBar(BarState.Off)
      .width('100%')
      .height('100%')
    }
    .titleBar({
      content: {
        title: { mainTitle: '编辑数据' },
        stackBuilder: (): void => this.buildSaveBar()
      },
      style: {
        systemMaterialEffect: {
          materialType: hdsMaterial.MaterialType.ADAPTIVE,
          materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
        },
        scrollEffectOpts: {
          enableScrollEffect: true,
          scrollEffectType: ScrollEffectType.GRADIENT_BLUR,
          blurEffectiveStartOffset: LengthMetrics.vp(0),
          blurEffectiveEndOffset: LengthMetrics.vp(20)
        }
      },
      enableComponentSafeArea: true
    })
    .bindToScrollable([this.scroller])
    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
    .backgroundColor($r('app.color.start_window_background'))
    .width('100%')
    .height('100%')
  }

  @Builder
  buildSaveBar() {
    Row() {
      Blank()
      Text('保存')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.brand_green'))
        .padding({ left: 20, right: 20 })
        .onClick(() => {
          this.saveMetrics();
        })
    }
    .width('100%')
    .height(56)
    .padding({ left: 64, right: 4 })
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  buildMetricCell(metric: RecordMetric) {
    Row({ space: 10 }) {
      Column() {
        SymbolGlyph(metric.icon)
          .fontSize(20)
          .fontColor([this.isSelected(metric.key) ? $r('app.color.brand_green') : $r('app.color.text_disabled')])
      }
      .width(40)
      .height(40)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .backgroundColor(this.isSelected(metric.key) ? 'rgba(0,169,145,0.12)' : $r('sys.color.comp_background_tertiary'))
      .borderRadius(12)

      Column({ space: 2 }) {
        Text(metric.title)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.ohos_id_color_text_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Text(metric.unit.length > 0 ? `单位：${metric.unit}` : ' ')
          .fontSize(11)
          .fontColor($r('sys.color.ohos_id_color_text_tertiary'))
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      if (this.isSelected(metric.key)) {
        Column() {
          Text('✓')
            .fontSize(14)
            .fontColor(Color.White)
            .fontWeight(FontWeight.Bold)
        }
        .width(20)
        .height(20)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .backgroundColor($r('app.color.brand_green'))
        .borderRadius(10)
      }
    }
    .width('100%')
    .height(64)
    .padding({ left: 12, right: 12 })
    .alignItems(VerticalAlign.Center)
    .backgroundColor(this.isSelected(metric.key) ? 'rgba(0,169,145,0.06)' : $r('sys.color.comp_background_primary'))
    .borderRadius(16)
    .border({
      width: 1,
      color: this.isSelected(metric.key) ? $r('app.color.brand_green') : $r('sys.color.comp_divider')
    })
    .onClick(() => {
      this.toggleMetric(metric.key);
    })
  }
}

@Builder
export function EditMetricsPageBuilder() {
  EditMetricsPage()
}
