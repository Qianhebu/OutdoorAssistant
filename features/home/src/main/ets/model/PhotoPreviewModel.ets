import { matrix4 } from '@kit.ArkUI';

@Observed
export class PhotoPreviewModel {
  matrix: matrix4.Matrix4Transit = matrix4.identity().copy();
  curScale: number = 1;
  lastScale: number = 1;
  curOffsetX: number = 0;
  curOffsetY: number = 0;
  lastOffsetX: number = 0;
  lastOffsetY: number = 0;
  maxOffsetX: number = 999;
  minOffsetX: number = -999;
  maxOffsetY: number = 999;
  minOffsetY: number = -999;
  centerX: number = 0.5;
  centerY: number = 0.5;
  imageWidth: number = 100;
  imageHeight: number = 100;
  componentWidth: number = 360;
  componentHeight: number = 800;
  minScale: number = 0.5;
  maxScale: number = 3;
  defaultScale: number = 1;
  isDisableSwipe: boolean = false;
  isArriveBoundary: boolean = false;

  pictureScaling(scale: number): void {
    this.matrix = matrix4.identity().scale({ x: scale, y: scale }).copy();
  }

  evaluateOffsetRange(): void {
    const scaledW: number = this.imageWidth * this.curScale;
    const scaledH: number = this.imageHeight * this.curScale;
    if (scaledW > this.componentWidth) {
      const maxX: number = (scaledW - this.componentWidth) / 2;
      this.maxOffsetX = maxX;
      this.minOffsetX = -maxX;
    } else {
      this.maxOffsetX = 0;
      this.minOffsetX = 0;
    }
    if (scaledH > this.componentHeight) {
      const maxY: number = (scaledH - this.componentHeight) / 2;
      this.maxOffsetY = maxY;
      this.minOffsetY = -maxY;
    } else {
      this.maxOffsetY = 0;
      this.minOffsetY = 0;
    }
  }

  evaluateCenter(cx: number, cy: number): number[] {
    const imgW: number = this.imageWidth * this.lastScale;
    const imgH: number = this.imageHeight * this.lastScale;
    const imgX: number = (this.componentWidth - imgW) / 2 + this.lastOffsetX;
    const imgY: number = (this.componentHeight - imgH) / 2 + this.lastOffsetY;
    const rx: number = Math.max((cx - imgX) / imgW, 0);
    const ry: number = Math.max((cy - imgY) / imgH, 0);
    return [rx, ry];
  }

  pictureBoundaryRestriction(): void {
    if (this.curOffsetX > this.maxOffsetX) {
      this.curOffsetX = this.maxOffsetX;
      this.isDisableSwipe = false;
      this.isArriveBoundary = true;
    } else if (this.curOffsetX < this.minOffsetX) {
      this.curOffsetX = this.minOffsetX;
      this.isDisableSwipe = false;
      this.isArriveBoundary = true;
    }
    if (this.curOffsetY > this.maxOffsetY) {
      this.curOffsetY = this.maxOffsetY;
    } else if (this.curOffsetY < this.minOffsetY) {
      this.curOffsetY = this.minOffsetY;
    }
    const scaledW: number = this.imageWidth * this.curScale;
    const scaledH: number = this.imageHeight * this.curScale;
    if (scaledW <= this.componentWidth) {
      this.curOffsetX = 0;
    }
    if (scaledH <= this.componentHeight) {
      this.curOffsetY = 0;
    }
  }

  onScale(scale: number, offX: number, offY: number): void {
    if (this.lastScale * scale > this.maxScale) {
      this.curScale = this.maxScale;
    } else if (this.lastScale * scale < this.minScale) {
      this.curScale = this.minScale;
    } else {
      this.curScale = this.lastScale * scale;
    }
    this.evaluateOffsetRange();
    if (this.curScale < this.maxScale) {
      this.curOffsetY = (this.lastOffsetY + offY) + (0.5 - this.centerY) * this.imageHeight * (1 - scale) * this.lastScale;
      this.curOffsetX = (this.lastOffsetX + offX) + (0.5 - this.centerX) * this.imageWidth * (1 - scale) * this.lastScale;
    }
    this.isArriveBoundary = false;
    if (!this.isArriveBoundary) {
      this.isDisableSwipe = true;
    }
  }

  gestureEnd(): void {
    this.lastScale = this.curScale;
    this.lastOffsetX = this.curOffsetX;
    this.lastOffsetY = this.curOffsetY;
  }

  offsetReset(): void {
    this.curOffsetX = 0;
    this.curOffsetY = 0;
    this.lastOffsetX = 0;
    this.lastOffsetY = 0;
  }

  imageReset(): void {
    setTimeout(() => {
      this.pictureScaling(this.defaultScale);
      this.lastScale = this.defaultScale;
      this.offsetReset();
    }, 200);
  }

  /** 重置缩放和平移到初始状态 */
  reset(): void {
    this.pictureScaling(this.defaultScale);
    this.lastScale = this.defaultScale;
    this.curScale = this.defaultScale;
    this.offsetReset();
    this.isDisableSwipe = false;
    this.isArriveBoundary = false;
  }

  pinchGestureStart(event: GestureEvent): void {
    const center: number[] = this.evaluateCenter(event.pinchCenterX, event.pinchCenterY);
    this.centerX = 1 - center[0];
    this.centerY = 1 - center[1];
  }

  pinchGestureUpdate(event: GestureEvent): boolean {
    this.onScale(event.scale, event.offsetX, event.offsetY);
    this.pictureScaling(this.curScale);
    if (this.curScale > this.defaultScale) {
      this.isDisableSwipe = true;
    }
    this.pictureBoundaryRestriction();
    return this.isDisableSwipe;
  }

  pinchGestureEnd(): void {
    if (this.curScale <= this.defaultScale) {
      this.pictureScaling(this.defaultScale);
      this.imageReset();
      this.isDisableSwipe = false;
    }
    this.gestureEnd();
  }

  panGestureUpdate(event: GestureEvent): boolean {
    this.onScale(event.scale, event.offsetX, event.offsetY);
    this.pictureBoundaryRestriction();
    return this.isDisableSwipe;
  }

  doubleTapGesture(event: GestureEvent): boolean {
    const center: number[] = this.evaluateCenter(event.fingerList[0].displayX, event.fingerList[0].displayY);
    this.centerX = 1 - center[0];
    this.centerY = 1 - center[1];
    let curRatio: number = 1;
    if (this.lastScale > this.defaultScale) {
      this.pictureScaling(this.defaultScale);
      this.offsetReset();
      curRatio = this.defaultScale;
      this.isDisableSwipe = false;
    } else {
      this.onScale(event.scale, event.offsetX, event.offsetY);
      this.pictureScaling(this.maxScale);
      this.offsetReset();
      curRatio = this.maxScale;
      this.isDisableSwipe = true;
    }
    this.lastScale = curRatio;
    return this.isDisableSwipe;
  }
}
