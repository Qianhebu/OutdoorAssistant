import {
  hdsMaterial,
  HdsNavDestination,
  ScrollEffectType
} from '@kit.UIDesignKit';
import { LengthMetrics } from '@kit.ArkUI';

@Component
export struct PrivacyPolicyPage {
  private scroller: Scroller = new Scroller();

  build() {
    HdsNavDestination() {
      Scroll(this.scroller) {
        Column({ space: 0 }) {
          this.buildIntro()
          this.buildH2('1', '我们如何收集和使用您的个人数据')
          this.buildP('个人数据是指单独使用或结合其他信息使用时能够确定个人身份的信息。此类数据会在您使用我们的网站、产品或服务，以及您与我们互动时由您直接提供给我们，例如：')
          this.buildH3('账号信息')
          this.buildP('当您注册华为账号或使用相关服务时，您提供的姓名、电子邮箱、手机号码等。')
          this.buildH3('设备与网络信息')
          this.buildP('设备型号、操作系统版本、IP地址、MAC地址、网络状态等。')
          this.buildH3('位置信息')
          this.buildP('当您使用 Outdoor 助手的路线导航、轨迹记录和户外运动功能时，我们会收集您的地理位置信息（GPS坐标），用于路线规划、运动轨迹记录和户外安全提醒。您可以在系统设置中随时关闭位置权限。')
          this.buildH3('健康与运动数据')
          this.buildP('当您授权后，我们会读取步数、心率、运动距离、海拔等健康数据，用于活动记录和户外运动分析。健康数据的访问需要您的明确授权，您可随时在系统设置中撤回授权。')
          this.buildH3('使用数据')
          this.buildP('您与我们的网站或软件交互时产生的日志信息、点击记录等。')
          this.buildP('我们出于以下目的使用您的个人数据：')
          this.buildLi('为您提供产品或服务，并处理您的订单或请求；')
          this.buildLi('记录您的户外运动轨迹和健康数据，提供运动分析和安全提醒；')
          this.buildLi('向您发送重要通知，例如操作系统更新或政策变更；')
          this.buildLi('开展内部审计、数据分析和研究，改善我们的产品与服务；')
          this.buildLi('在获得您明确同意的前提下，向您推送优惠活动或产品信息。')

          this.buildH2('2', '我们如何使用 Cookie 和同类技术')
          this.buildP('为确保网站正常运转，我们会在您的计算机或移动设备上存储名为 Cookie 的小数据文件。Cookie 通常包含标识符、站点名称以及一些数字和字符。我们不会将 Cookie 用于本声明所述目的之外的任何用途。您可以根据自己的偏好管理或删除 Cookie。')

          this.buildH2('3', '我们如何共享、转让、公开披露您的个人数据')
          this.buildH3('共享')
          this.buildP('我们不会与华为以外的公司、组织和个人共享您的个人数据，除非获得您的明确同意，或出于法律法规要求、履行合同所必需。在某些情况下，我们可能会与授权合作伙伴共享部分数据（如物流服务商）。')
          this.buildH3('转让')
          this.buildP('我们不会将您的个人数据转让给任何公司、组织或个人，但因合并、收购或破产清算等原因涉及数据转让的除外。')
          this.buildH3('公开披露')
          this.buildP('我们仅在法律、法律程序、诉讼或政府主管部门强制性要求的情况下，才会公开披露您的个人数据。')

          this.buildH2('4', '我们如何保护和留存您的个人数据')
          this.buildH3('安全措施')
          this.buildP('华为重视个人数据的安全。我们采用符合业界标准的安全防护措施（包括加密技术、访问控制、安全审计等）来保护您的个人数据，防止未授权访问、公开披露、修改或损坏。针对户外运动中的位置轨迹和健康数据，我们采用端到端加密存储，确保数据在传输和存储过程中的安全性。')
          this.buildH3('留存期限')
          this.buildP('我们仅在实现本声明所述目的所必需的最短期限内保留您的个人数据，法律法规另有规定的除外。')

          this.buildH2('5', '您的权利')
          this.buildP('您对于自己的个人数据享有以下权利：')
          this.buildLi('访问与更正：您有权查询、更正或更新您的个人数据。')
          this.buildLi('删除：在满足特定条件时，您可以请求我们删除您的个人数据。')
          this.buildLi('撤回同意：您可以随时撤回之前给予我们的授权同意。')
          this.buildLi('注销账号：您可以通过产品设置或联系客服注销您的华为账号。')
          this.buildLi('数据导出：您可以导出您的运动记录、轨迹数据和健康数据。')

          this.buildH2('6', '未成年人保护')
          this.buildP('我们的产品、网站和服务主要面向成年人。如果没有父母或监护人的同意，儿童（不满 14 周岁）不应创建自己的用户账号。如发现未经事先获得可证实的父母同意而收集了儿童的个人数据，我们会设法尽快删除相关数据。')

          this.buildH2('7', '本声明的更新')
          this.buildP('华为保留随时更新或修改本声明的权利。如果本声明发生重大变更，我们会在本网站发布更新后的版本，或通过应用内弹窗、邮件等形式向您发出通知。')

          this.buildH2('8', '联系我们')
          this.buildP('如果您对本隐私协议有任何疑问、意见或建议，可通过以下方式与我们联系：')
          this.buildLi('应用内「意见与反馈」功能')
          this.buildLi('华为官方客服热线')
          this.buildLi('华为官方隐私保护邮箱')
          this.buildP('我们将在收到您的反馈后尽快处理并回复。')
        }
        .alignItems(HorizontalAlign.Start)
        .padding({ left: 24, right: 24, top: 8, bottom: 40 })
      }
      .clip(false)
      .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
      .scrollBar(BarState.Auto)
      .width('100%')
      .height('100%')
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    }
    .titleBar({
      content: { title: { mainTitle: '隐私政策' } },
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
    .backgroundColor($r('app.color.start_window_background'))
    .width('100%')
    .height('100%')
  }

  @Builder
  buildIntro() {
    Column({ space: 12 }) {
      Text('关于华为隐私的声明')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('sys.color.ohos_id_color_text_primary'))
        .textAlign(TextAlign.Start)
        .width('100%')
      Text('华为技术有限公司及其全球的关联公司（下文简称"华为"、"我们"或"我们的"）深知隐私对您的重要性，并会尊重您的隐私。在向我们提交您的个人数据之前，请仔细阅读本《关于华为隐私的声明》（以下简称"本声明"）。本声明适用于显示或链接至本声明的华为网站、产品及服务。')
        .fontSize(14)
        .lineHeight(24)
        .fontColor($r('sys.color.ohos_id_color_text_secondary'))
        .textAlign(TextAlign.Start)
        .width('100%')
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .padding({ bottom: 20 })
    .border({ width: { bottom: 0.5 }, color: $r('sys.color.comp_divider') })
    .margin({ bottom: 20 })
  }

  @Builder
  buildH2(num: string, title: string) {
    Text(`${num}. ${title}`)
      .fontSize(16)
      .fontWeight(FontWeight.Bold)
      .fontColor($r('sys.color.ohos_id_color_text_primary'))
      .textAlign(TextAlign.Start)
      .width('100%')
      .margin({ top: 20, bottom: 10 })
  }

  @Builder
  buildH3(title: string) {
    Text(title)
      .fontSize(14)
      .fontWeight(FontWeight.Medium)
      .fontColor($r('sys.color.ohos_id_color_text_primary'))
      .textAlign(TextAlign.Start)
      .width('100%')
      .textIndent(28)
      .margin({ top: 8, bottom: 4 })
  }

  @Builder
  buildP(text: string) {
    Text(text)
      .fontSize(14)
      .lineHeight(24)
      .fontColor($r('sys.color.ohos_id_color_text_secondary'))
      .textAlign(TextAlign.Start)
      .width('100%')
      .textIndent(28)
      .margin({ bottom: 8 })
  }

  @Builder
  buildLi(text: string) {
    Row({ space: 6 }) {
      Text('•')
        .fontSize(14)
        .fontColor($r('sys.color.ohos_id_color_text_secondary'))
      Text(text)
        .fontSize(14)
        .lineHeight(24)
        .fontColor($r('sys.color.ohos_id_color_text_secondary'))
        .textAlign(TextAlign.Start)
        .layoutWeight(1)
    }
    .width('100%')
    .padding({ left: 36 })
    .margin({ bottom: 4 })
  }
}

@Builder
export function PrivacyPolicyBuilder() {
  PrivacyPolicyPage();
}
