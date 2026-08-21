# Implementation Plan: RouteDetailSheet 设计令牌统一

**Input**: Feature specification from `spec/optimize-route-detail/spec.md`

## Summary

对 RouteDetailSheet 组件进行设计令牌全面统一改造，将散落的硬编码样式值（25+ 颜色、9 级字号、7 种圆角、15+ 间距值、字重）对齐到华为健康越野跑详情页设计令牌体系。涉及 6 个用户故事：颜色令牌统一(P1)、字号令牌对齐(P1)、圆角令牌对齐(P2)、间距令牌对齐(P2)、字重令牌对齐(P3)、暗色模式完善(P2)。严格保持功能行为不变。

## Technical Context

**Language/Version**: ArkTS (HarmonyOS, API 10+)  
**Primary Dependencies**: @kit.ArkUI, @kit.ImageKit, @kit.AbilityKit, @kit.BasicServicesKit  
**State Management**: State Management V1 (@State, @Prop, @Provide/@Consume, @StorageLink, @StorageProp) — 遵循项目现有模式  
**Storage**: AppStorage (全局状态), color.json (颜色资源)  
**Testing**: 编译检查 + 视觉验证  
**Target Platform**: HarmonyOS 6.1.0 (API 23) 手机  
**Project Type**: 移动应用 (多模块 HAR 架构)  
**Performance Goals**: 无性能退化，Canvas 绘制性能不受影响  
**Constraints**: 功能行为不变；仅修改视觉参数；颜色使用 $r() 资源引用  
**Scale/Scope**: 1 个核心 .ets 文件 + 2 个资源文件

## Project Structure

### Documentation (this feature)

```text
spec/optimize-route-detail/
├── spec.md              # Feature specification
├── plan.md              # This file
└── tasks.md             # Task breakdown (Phase 3)
```

### Source Code (repository root)

```text
features/home/src/main/ets/
└── view/
    └── RouteDetailSheet.ets        # [MODIFY] 颜色/字号/圆角/间距/字重令牌统一

features/home/src/main/resources/
├── base/element/color.json         # [MODIFY] 新增 20+ 颜色令牌
└── dark/element/color.json         # [MODIFY] 新增暗色模式令牌值
```

**Structure Decision**: 遵循项目现有架构（多模块 HAR + features/home），不引入新目录或文件，仅修改已有文件。颜色令牌统一属于纯视觉改造，无需新增组件或模块。

## Complexity Tracking

> 无违规需记录。

## Research & Decisions

### Decision 1: 颜色令牌命名规范

- **Decision**: 采用 `{语义域}_{用途}` 命名规范，与设计令牌 JSON 保持一致
- **Rationale**: 设计 JSON 定义了 brand/semantic/neutral/chart 四大语义域，命名需反映语义而非视觉值
- **Alternatives considered**: 使用 `color_xxx` 前缀 — 不符合现有 color.json 命名风格（现有如 `brand_primary`、`neutral_text_primary`）
- **命名映射表**:

| 设计令牌路径 | 资源名 | 基础色值 | 暗色色值 |
|-------------|--------|---------|---------|
| brand.primary | `brand_primary` | #FF6B35 | #FF8F5A |
| brand.primaryLight | `brand_primary_light` | #FF8F5A | #FFB088 |
| brand.success | `brand_success` | #4CD964 | #4CD964 |
| brand.info | `brand_info` | #34AADC | #34AADC |
| brand.accent | `brand_accent` | #AF52DE | #AF52DE |
| semantic.danger | `brand_danger` | #FF3B30 | #FF453A |
| semantic.warning | `brand_warning` | #FFCC00 | #FFD60A |
| semantic.safe | `semantic_safe` | #4CD964 | #4CD964 |
| neutral.bgPage | `neutral_bg_page` | #F5F5F7 | #1C1C1E |
| neutral.bgCard | `neutral_bg_card` | #FFFFFF | #2C2C2E |
| neutral.bgSecondary | `neutral_bg_secondary` | #F2F2F7 | #3A3A3C |
| neutral.textPrimary | `neutral_text_primary` | #1C1C1E | #F5F5F7 |
| neutral.textSecondary | `neutral_text_secondary` | #3A3A3C | #C7C7CC |
| neutral.textTertiary | `neutral_text_tertiary` | #8E8E93 | #8E8E93 |
| neutral.divider | `neutral_divider` | #E5E5EA | #3A3A3C |
| neutral.border | `neutral_border` | #C7C7CC | #545454 |
| chart.heartRateZone5 | `chart_hr_zone5` | #FF3B30 | #FF453A |
| chart.heartRateZone4 | `chart_hr_zone4` | #FF6B35 | #FF8F5A |
| chart.heartRateZone3 | `chart_hr_zone3` | #FFCC00 | #FFD60A |
| chart.heartRateZone2 | `chart_hr_zone2` | #4CD964 | #4CD964 |
| chart.heartRateZone1 | `chart_hr_zone1` | #34AADC | #5AC8FA |
| chart.paceIntensityHigh | `chart_pace_high` | #FF3B30 | #FF453A |
| chart.paceIntensityMedium | `chart_pace_medium` | #FF6B35 | #FF8F5A |
| chart.paceIntensityLow | `chart_pace_low` | #FFCC00 | #FFD60A |

### Decision 2: Canvas 图表颜色处理

- **Decision**: Canvas drawLineChart 方法保留 string 类型颜色参数，但通过组件内常量映射到设计令牌值。在 aboutToAppear 中读取 $r() 资源并缓存为 string，供 Canvas 绘制使用
- **Rationale**: CanvasRenderingContext2D 不支持 Resource/ResourceColor 类型，仅接受 string 颜色值。$r() 返回的 Resource 类型无法直接传入 Canvas API
- **Alternatives considered**: (1) 直接使用硬编码 string — 违反令牌统一原则；(2) 放弃 Canvas 改用 Polyline 组件 — 工程量过大且功能可能受限

### Decision 3: 渐变色处理

- **Decision**: 配速条渐变和运动解读边框渐变中的颜色点，统一引用设计令牌资源名，在 linearGradient API 的 colors 数组中使用 $r() 引用
- **Rationale**: ArkUI 的 linearGradient.colors 接受 `[ResourceColor, number][]` 类型，$r() 返回的 Resource 类型属于 ResourceColor 联合类型
- **Alternatives considered**: 保留硬编码渐变色值 — 违反令牌统一原则

### Decision 4: 字号令牌映射

- **Decision**: 严格按设计令牌层级映射，具体映射表如下

| 设计令牌名 | 值(px) | 当前使用场景 | 当前值 | 目标场景 |
|-----------|--------|-------------|--------|---------|
| hero | 48 | 距离数字 | 40 | 核心距离数值 |
| display | 32 | 概览指标 | 26 | 运动时间/配速/热量等指标数值 |
| headline | 24 | 配速主值 | 24 | 配速/最快配速数值（不变） |
| title | 20 | 模块标题 | 18 | 配速/分段/心率等模块标题 |
| subtitle | 17 | 导航标题 | 17 | 用户昵称（不变） |
| body | 14 | 正文 | 14/15/16 | 正文描述、配速行文字 |
| caption | 13 | 辅助 | 13 | 时间范围、辅助说明（不变） |
| small | 12 | 标签 | 12 | 单位、标签、列标题（不变） |
| tiny | 11 | 坐标轴 | 11/10/9 | 图表标签、最小文字 |

### Decision 5: 圆角令牌映射

- **Decision**: 严格按令牌值映射，消除所有非令牌圆角值

| 令牌名 | 值(px) | 当前值 → 目标 |
|--------|--------|-------------|
| xxl | 16 | 26→16, 22→16, 21→16 (大卡片/面板) |
| xl | 12 | 14→12 (小卡片/折线图卡片/配速条) |
| lg | 10 | (新增可用值) |
| md | 8 | 6→8 (拍立得内边距圆角、进度条) |
| sm | 4 | 3→4 (色块圆角) |

### Decision 6: 间距令牌映射

- **Decision**: 将所有间距值就近映射到令牌值

| 令牌名 | 值(px) | 当前值 → 目标 |
|--------|--------|-------------|
| xs | 4 | 3→4, 4不变 |
| sm | 8 | 6→8, 8不变 |
| md | 12 | 10→12, 12不变 |
| lg | 16 | 14→16, 16不变, 18→16 |
| xl | 20 | 20不变, 22→20 |
| xxl | 24 | 26→24, 28→24 |
| xxxl | 32 | (新增可用值) |

### Decision 7: 字重令牌映射

- **Decision**: ArkUI FontWeight 枚举不包含 600 (semibold)，使用 FontWeight.Medium (500) 替代 semibold 场景。在需要精确控制处使用数字字重

| 设计令牌 | 值 | ArkUI 映射 |
|---------|-----|-----------|
| bold | 700 | FontWeight.Bold |
| semibold | 600 | FontWeight.Medium (最接近的枚举值) |
| medium | 500 | FontWeight.Medium |
| regular | 400 | FontWeight.Regular |

- **Rationale**: ArkUI FontWeight 枚举仅提供 Lighter/Regular/Medium/Bold/Bolder，无 600 对应值。Medium(500) 是最接近 600 的可用选项
- **Alternatives considered**: 使用字符串字重 '600' — ArkUI 不支持字符串字重值

### Decision 8: 暗色模式颜色适配策略

- **Decision**: 功能性颜色（训练表现色块、心率区间色）在暗色模式下保持不变；语义颜色（文字、背景、分割线）适配暗色值；品牌色和图表色适度提亮
- **Rationale**: 心率区间和训练强度色块是功能性语义色，用户对其有固定认知，暗色模式下改变可能导致误读。文字/背景色必须适配以保证对比度
- **Alternatives considered**: 所有颜色暗色模式全部调整 — 过度调整功能性颜色会破坏用户认知

### Decision 9: 新增 color.json 条目完整性

- **Decision**: 新增约 30 个颜色令牌到 base/element/color.json，其中约 15 个需要 dark/element/color.json 暗色值。现有令牌已有对应 dark 值的不再重复添加
- **Rationale**: 当前 color.json base 有 62 个条目，dark 有 14 个条目。需新增的令牌覆盖：配速渐变色、训练表现色、运动解读渐变色、图表心率区间色、pace 强度色、语义安全色等

## Data Model

### 颜色资源扩展

新增颜色令牌定义（在 base/element/color.json 和 dark/element/color.json 中）：

| 资源名 | 基础色值 | 暗色色值 | 用途 |
|--------|---------|---------|------|
| `pace_bar_bg` | #ECECEC | #3A3A3C | 配速条背景 |
| `pace_bar_start_fast` | #FF6B1F | #FF8F5A | 配速条渐变起点(最快) |
| `pace_bar_end_fast` | #FF4D13 | #FF6B35 | 配速条渐变终点(最快) |
| `pace_bar_start_normal` | #F7A985 | #FFBFA8 | 配速条渐变起点(正常) |
| `pace_bar_end_normal` | #F7A985 | #FFBFA8 | 配速条渐变终点(正常) |
| `pace_gradient_start` | #56D978 | #4CD964 | 配速渐变条起点(绿) |
| `pace_gradient_mid` | #F7E94C | #FFD60A | 配速渐变条中点(黄) |
| `pace_gradient_end` | #FF9237 | #FF8F5A | 配速渐变条终点(橙) |
| `pace_label_fast` | #37C96C | #4CD964 | 最快配速标签 |
| `pace_label_slow` | #E92323 | #FF453A | 最慢配速标签 |
| `insight_title` | #FF816F | #FF9F92 | 运动解读标题 |
| `insight_text` | #111111 | #F5F5F7 | 运动解读正文 |
| `insight_arrow` | #333333 | #C7C7CC | 运动解读展开箭头 |
| `insight_gradient_start` | #FFD35D | #FFD60A | 运动解读渐变边框起点 |
| `insight_gradient_mid` | #F08BCA | #E88ABF | 运动解读渐变边框中点 |
| `insight_gradient_end` | #57DCE4 | #5AC8FA | 运动解读渐变边框终点 |
| `training_scale_1` | #58D68D | #58D68D | 训练表现色块1(绿) |
| `training_scale_2` | #F7DC6F | #F7DC6F | 训练表现色块2(黄) |
| `training_scale_3` | #F5B041 | #F5B041 | 训练表现色块3(橙) |
| `training_scale_4` | #E74C3C | #E74C3C | 训练表现色块4(红) |
| `insight_heart_left` | #FF765F | #FF9F92 | 心率图标左心 |
| `insight_heart_right` | #7AA6FF | #7AA6FF | 心率图标右心 |
| `semantic_safe` | #4CD964 | #4CD964 | 安全绿 |
| `chart_hr_zone5` | #FF3B30 | #FF453A | 心率区间5(极限) |
| `chart_hr_zone4` | #FF6B35 | #FF8F5A | 心率区间4(无氧) |
| `chart_hr_zone3` | #FFCC00 | #FFD60A | 心率区间3(有氧) |
| `chart_hr_zone2` | #4CD964 | #4CD964 | 心率区间2(燃脂) |
| `chart_hr_zone1` | #34AADC | #5AC8FA | 心率区间1(热身) |
| `chart_pace_high` | #FF3B30 | #FF453A | 配速高强度 |
| `chart_pace_medium` | #FF6B35 | #FF8F5A | 配速中强度 |
| `chart_pace_low` | #FFCC00 | #FFD60A | 配速低强度 |
| `summary_text` | #555555 | #C7C7CC | 汇总行文字 |
| `collapse_text` | #666666 | #C7C7CC | 收起按钮文字 |
| `collapse_arrow` | #9A9A9A | #8E8E93 | 收起箭头 |
| `shadow_card` | #0A000000 | #0AFFFFFF | 卡片阴影（已有） |
| `shadow_elevated` | #14000000 | #14FFFFFF | 浮层阴影 |

### 字号常量映射

由于 ArkUI 不支持在资源文件中定义字号常量（float.json 仅支持 float 类型，不支持语义命名分组），字号令牌通过代码内常量或直接值使用。建议在组件内定义私有常量组：

| 常量名 | 值 | 用途 |
|--------|-----|------|
| FONT_HERO | 48 | 核心距离 |
| FONT_DISPLAY | 32 | 概览指标数值 |
| FONT_HEADLINE | 24 | 次级核心数据 |
| FONT_TITLE | 20 | 模块大标题 |
| FONT_SUBTITLE | 17 | 模块标题/导航 |
| FONT_BODY | 14 | 正文描述 |
| FONT_CAPTION | 13 | 辅助说明 |
| FONT_SMALL | 12 | 标签/单位 |
| FONT_TINY | 11 | 最小标签 |

### 圆角/间距常量映射

同理，圆角和间距也通过代码内常量使用：

| 常量名 | 值 | 用途 |
|--------|-----|------|
| RADIUS_SM | 4 | 小标签/色块 |
| RADIUS_MD | 8 | 进度条/拍立得 |
| RADIUS_LG | 10 | 次级卡片 |
| RADIUS_XL | 12 | 小卡片/折线图 |
| RADIUS_XXL | 16 | 大卡片/面板 |

| 常量名 | 值 | 用途 |
|--------|-----|------|
| SPACE_XS | 4 | 紧凑间距 |
| SPACE_SM | 8 | 元素间距 |
| SPACE_MD | 12 | 模块间距 |
| SPACE_LG | 16 | 卡片内边距 |
| SPACE_XL | 20 | 大模块间距 |
| SPACE_XXL | 24 | 区块间距 |
| SPACE_XXXL | 32 | 大区块间距 |

## Contracts & Interfaces

### RouteDetailSheet 变更清单

**颜色变更** (所有硬编码颜色 → $r() 引用):
- `#ECECEC` → `$r('app.color.pace_bar_bg')`
- `#555555` → `$r('app.color.summary_text')`
- `#666666` → `$r('app.color.collapse_text')`
- `#9A9A9A` → `$r('app.color.collapse_arrow')`
- `#F7A985` → `$r('app.color.pace_bar_start_normal')` / `$r('app.color.pace_bar_end_normal')`
- `#FF4D13` → `$r('app.color.pace_bar_end_fast')`
- `#FF6B1F` → `$r('app.color.pace_bar_start_fast')`
- `#56D978` → `$r('app.color.pace_gradient_start')`
- `#F7E94C` → `$r('app.color.pace_gradient_mid')`
- `#FF9237` → `$r('app.color.pace_gradient_end')`
- `#37C96C` → `$r('app.color.pace_label_fast')`
- `#E92323` → `$r('app.color.pace_label_slow')`
- `#FF816F` → `$r('app.color.insight_title')`
- `#111111` → `$r('app.color.insight_text')`
- `#333333` → `$r('app.color.insight_arrow')`
- `#FFD35D` → `$r('app.color.insight_gradient_start')`
- `#F08BCA` → `$r('app.color.insight_gradient_mid')`
- `#57DCE4` → `$r('app.color.insight_gradient_end')`
- `#58D68D` → `$r('app.color.training_scale_1')`
- `#F7DC6F` → `$r('app.color.training_scale_2')`
- `#F5B041` → `$r('app.color.training_scale_3')`
- `#E74C3C` → `$r('app.color.training_scale_4')`
- `#FF765F` → `$r('app.color.insight_heart_left')`
- `#7AA6FF` → `$r('app.color.insight_heart_right')`

**字号变更**:
- `.fontSize(40)` → `.fontSize(48)` (hero)
- `.fontSize(26)` → `.fontSize(32)` (display)
- `.fontSize(18)` → `.fontSize(20)` (title - 配速/分段/训练表现标题)
- `.fontSize(15)` → `.fontSize(14)` (body - 配速行/汇总文字)
- `.fontSize(10)` → `.fontSize(11)` (tiny - 最快最慢标签/图表时间)
- `.fontSize(9)` → `.fontSize(11)` (tiny - 图表坐标)
- `.fontSize(8)` → `.fontSize(11)` (tiny - 拍立得日期)

**圆角变更**:
- `.borderRadius(26)` → `.borderRadius(16)` (xxl - 概览卡片/配速卡片)
- `.borderRadius(22)` → `.borderRadius(16)` (xxl - 运动解读外层)
- `.borderRadius(21)` → `.borderRadius(16)` (xxl - 运动解读内层)
- `.borderRadius(16)` → `.borderRadius(16)` (xxl - 分段表 不变)
- `.borderRadius(14)` → `.borderRadius(12)` (xl - 折线图卡片/配速条)
- `.borderRadius(6)` → `.borderRadius(8)` (md - 配速渐变条)
- `.borderRadius(3)` → `.borderRadius(4)` (sm - 训练色块)

**间距变更** (主要):
- 概览卡片 padding: `top:20,right:18,bottom:20,left:18` → `top:20,right:16,bottom:20,left:16`
- 配速卡片 padding: `top:28,right:18,bottom:18,left:18` → `top:24,right:16,bottom:16,left:16`
- 运动解读 padding: `top:16,right:16,bottom:18,left:16` → `top:16,right:16,bottom:16,left:16`
- Column space: `26` → `24`, `22` → `20`, `14` → `12`, `10` → `12`
- 概览指标 padding bottom: `20` → `20` (不变)

**字重变更**:
- 配速标题/分段标题: `FontWeight.Bold` → `FontWeight.Medium` (对应 semibold 场景)

### color.json 变更接口

在 `features/home/src/main/resources/base/element/color.json` 新增约 35 个颜色条目。
在 `features/home/src/main/resources/dark/element/color.json` 新增约 35 个暗色条目。

## Changelog

| 时间 | 修改内容 | 原因 |
|------|---------|------|
| 2026-08-20 | 全面重写 plan.md | 从"代码规范化优化"升级为"设计令牌统一"，范围从 6 文件扩展到颜色/字号/圆角/间距/字重/暗色模式全覆盖 |
