import { componentUtils } from '@kit.ArkUI';
import { ComponentAttrUtils, RectInfoInPx } from './ComponentAttrUtils';
import { CardUtil } from './CardUtil';
import { WindowInfo } from './WindowInfo';
import { CustomTransition } from './CustomNavigationUtils';
import { BusinessError } from '@kit.BasicServicesKit';

@Observed
export class LongTakeAnimationProperties {
  public navDestinationBgColor: ResourceColor = '#00000000';
  public snapShotOpacity: number = 1;
  public postPageOpacity: number = 0;
  public translateX: number = 0;
  public translateY: number = 0;
  public scaleValue: number = 1;
  public clipWidth: Dimension = '100%';
  public clipHeight: Dimension = '100%';
  public radius: number = 0;
  public positionXValue: number = 0;
  public positionYValue: number = 0;
  public snapShotSize: SizeOptions = { width: '100%', height: '100%' };
  public snapShotPositionX: number = 0;
  public snapShotPositionY: number = 0;
  private animationCount: number = 0;
  private initScale: number = 1;
  private initTranslateX: number = 0;
  private initTranslateY: number = 0;
  private initClipWidth: Dimension = 0;
  private initClipHeight: Dimension = 0;
  private initPositionValueX: number = 0;
  private initPositionValueY: number = 0;
  private cardItemInfo_px: RectInfoInPx = new RectInfoInPx();
  private recoverPrePage: () => void = () => {
  };
  private clickedCardId: string = '';

  public init(prePageCardId: string, prePageOnFinish: () => void, uiContext: UIContext): void {
    this.clickedCardId = prePageCardId;
    this.recoverPrePage = prePageOnFinish;
    try {
      this.cardItemInfo_px = ComponentAttrUtils.getRectInfoById(uiContext, prePageCardId);
    } catch (err) {
      let error = err as BusinessError;
      console.error(`LongTakeAnimationProperties init failed. code=${error.code}, message=${error.message}`);
    }
  }

  private initParams(uiContext: UIContext): void {
    let postNodePositionX_vp: number = 0;
    let postNodePositionY_vp: number = 0;
    let postNodeWidth_px: number = 0;
    let postNodeHeight_px: number = 0;

    let postNode: FrameNode | null = null;
    try {
      postNode = uiContext.getFrameNodeById(CardUtil.getPostPageImageId(this.clickedCardId));
    } catch (err) {
      let error = err as BusinessError;
      console.error(`LongTakeAnimationProperties initParams failed. code=${error.code}, message=${error.message}`);
    }

    if (postNode) {
      postNodePositionX_vp = postNode.getPositionToWindowWithTransform().x;
      postNodePositionY_vp = postNode.getPositionToWindowWithTransform().y;
      postNodeWidth_px = postNode.getMeasuredSize().width;
      postNodeHeight_px = postNode.getMeasuredSize().height;
    }

    this.initPositionValueX = -postNodePositionX_vp;
    this.initPositionValueY = -postNodePositionY_vp;
    this.snapShotPositionY = postNodePositionY_vp - uiContext.px2vp(WindowInfo.topAvoidAreaHeight_px);
    this.snapShotPositionX = postNodePositionX_vp;

    this.initScale = this.cardItemInfo_px.width / postNodeWidth_px;
    this.initClipWidth = '100%';
    this.initClipHeight = uiContext.px2vp(this.cardItemInfo_px.height / this.initScale);
    this.initTranslateX = uiContext.px2vp(this.cardItemInfo_px.left -
      (WindowInfo.windowWidth_px - this.cardItemInfo_px.width) / 2);
    this.initTranslateY = uiContext.px2vp(this.cardItemInfo_px.top -
      ((uiContext.vp2px(this.initClipHeight as number) - uiContext.vp2px(this.initClipHeight as number) * this.initScale) /
        2));
    this.snapShotSize = { width: '100%' };
  }

  public doAnimation(transitionProxy: NavigationTransitionProxy, uiContext: UIContext): void {
    if (CustomTransition.getInstance().operation === NavigationOperation.PUSH) {
      this.initParams(uiContext);
      this.doEnterAnimation(transitionProxy, uiContext);
    } else if (CustomTransition.getInstance().operation === NavigationOperation.POP) {
      this.doBackAnimation(transitionProxy, uiContext);
    }
  }

  public doEnterAnimation(transitionProxy: NavigationTransitionProxy, uiContext: UIContext): void {
    this.scaleValue = this.initScale;
    this.translateX = this.initTranslateX;
    this.clipWidth = this.initClipWidth;
    this.clipHeight = this.initClipHeight;
    this.translateY = this.initTranslateY;
    this.positionYValue = this.initPositionValueY;
    this.positionXValue = this.initPositionValueX;

    let animationCount = ++this.animationCount;

    uiContext.animateTo({
      duration: 350,
      curve: Curve.EaseInOut,
      onFinish: () => {
        if (animationCount === this.animationCount) {
          this.radius = 0;
        }
        transitionProxy.finishTransition();
      }
    }, () => {
      this.scaleValue = 1.0;
      this.translateX = 0;
      this.translateY = 0;
      this.clipWidth = '100%';
      this.clipHeight = '100%';
      this.positionYValue = 0;
      this.positionXValue = 0;
      this.radius = 0;
      this.navDestinationBgColor = $r('app.color.start_window_background');
    });

    uiContext.animateTo({
      delay: 50,
      duration: 100,
      curve: Curve.Sharp
    }, () => {
      this.snapShotOpacity = 0;
    });

    uiContext.animateTo({
      duration: 100,
      curve: Curve.Sharp
    }, () => {
      this.postPageOpacity = 1.0;
    });
  }

  public doBackAnimation(transitionProxy: NavigationTransitionProxy, uiContext: UIContext): void {
    ++this.animationCount;

    uiContext.animateTo({
      duration: 350,
      curve: Curve.EaseInOut,
      onFinish: () => {
        this.recoverPrePage();
        transitionProxy.finishTransition();
      }
    }, () => {
      this.scaleValue = this.initScale;
      this.translateX = this.initTranslateX;
      this.clipWidth = this.initClipWidth;
      this.clipHeight = this.initClipHeight;
      this.translateY = this.initTranslateY;
      this.radius = 0;
      this.positionXValue = this.initPositionValueX;
      this.positionYValue = this.initPositionValueY;
      this.navDestinationBgColor = '#00000000';
    });

    uiContext.animateTo({
      duration: 50,
      delay: 150,
      curve: Curve.Friction
    }, () => {
      this.snapShotOpacity = 1;
    });

    uiContext.animateTo({
      duration: 50,
      delay: 200,
      curve: Curve.Friction
    }, () => {
      this.postPageOpacity = 0;
    });
  }

  public setFinalStatus(): void {
    this.navDestinationBgColor = $r('app.color.start_window_background');
    this.clipWidth = '100%';
    this.clipHeight = '100%';
    this.snapShotOpacity = 0;
    this.postPageOpacity = 1;
    this.radius = 0;
  }
}
