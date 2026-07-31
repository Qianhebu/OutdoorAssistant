import { ConfigurationConstant } from '@kit.AbilityKit';

/**
 * 背景点阵组件
 * 
 * 用于在页面背景绘制点阵图案，支持深色/浅色模式自动切换
 * 
 * @param dotSpacing - 点阵间距，默认 12
 * @param dotRadius - 点阵半径，默认 1
 * 
 * @example
 * ```arkts
 * BackgroundDots()
 *   .dotSpacing(16)
 *   .dotRadius(1.5)
 * ```
 */
@Component
export struct BackgroundDots {
  // 点阵配置参数
  @Prop dotSpacing: number = 12
  @Prop dotRadius: number = 1
  
  // 内部状态
  @State dotColor: string = '#E5E7EB'
  @StorageProp('colorMode') @Watch('onColorModeChange') colorMode: number =
    ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT
  
  // Canvas 上下文
  private settings: RenderingContextSettings = new RenderingContextSettings(true)
  private context: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings)
  
  /**
   * 监听深色模式变化
   */
  onColorModeChange() {
    this.updateDotColor()
  }
  
  /**
   * 根据深色/浅色模式更新点阵颜色
   */
  private updateDotColor() {
    try {
      let context = this.getUIContext().getHostContext();
      if (context) {
        let colorResourceId = this.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK
          ? $r('app.color.dot_color_dark').id
          : $r('app.color.dot_color_light').id;

        // 使用 resourceManager 获取颜色资源的实际值
        let colorValue: number = context.resourceManager.getColorSync(colorResourceId);
        // 将十进制数字转换为十六进制颜色字符串
        this.dotColor = '#' + colorValue.toString(16).padStart(6, '0');
        this.drawDots()
      }
    } catch (error) {
      console.error('BackgroundDots updateDotColor error:', error)
    }
  }
  
  /**
   * 绘制背景点阵
   */
  private drawDots() {
    const width = this.context.width
    const height = this.context.height

    this.context.clearRect(0, 0, width, height)
    this.context.fillStyle = this.dotColor

    for (let x = this.dotSpacing / 2; x < width; x += this.dotSpacing) {
      for (let y = this.dotSpacing / 2; y < height; y += this.dotSpacing) {
        this.context.beginPath()
        this.context.arc(x, y, this.dotRadius, 0, Math.PI * 2)
        this.context.fill()
      }
    }
  }
  
  build() {
    Canvas(this.context)
      .width('100%')
      .height('100%')
      .onReady(() => {
        this.drawDots()
      })
      .onAreaChange(() => {
        this.drawDots()
      })
  }
}
