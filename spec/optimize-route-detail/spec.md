# Feature Specification: RouteDetailSheet 设计令牌统一

**Created**: 2026-08-20  
**Status**: Draft  
**Input**: 根据华为健康越野跑详情页设计令牌 JSON，统一 RouteDetailSheet 的颜色、字体、间距、圆角、阴影样式

## Overview

对 RouteDetailSheet 组件进行全面的设计令牌统一改造，将当前散落的硬编码样式值（颜色、字号、字重、间距、圆角、阴影）全部对齐到设计令牌体系。目标是在保持功能不变的前提下，使 UI 表现与华为健康越野跑详情页的设计规范完全一致，同时完善 color.json 资源定义以支持暗色模式。

## User Scenarios & Testing *(mandatory)*

### User Story 1 - 颜色令牌统一 (Priority: P1)

RouteDetailSheet 中仍有大量硬编码颜色字符串未使用设计令牌：配速条背景 `#ECECEC`、文本颜色 `#555555`/`#666666`/`#9A9A9A`、配速条渐变 `#F7A985`/`#FF4D13`/`#FF6B1F`、配速渐变条 `#56D978`/`#F7E94C`/`#FF9237`、最快最慢标签 `#37C96C`/`#E92323`、运动解读文字 `#FF816F`/`#111111`/`#333333`、训练表现色块 `#58D68D`/`#F7DC6F`/`#F5B041`/`#E74C3C`、心率图标 `#FF765F`/`#7AA6FF`、渐变边框 `#FFD35D`/`#F08BCA`/`#57DCE4` 等。需要将所有硬编码颜色替换为 `$r()` 资源引用，并在 color.json 中补充缺失的令牌定义。

**Why this priority**: 颜色是最基础的视觉属性，且直接决定暗色模式适配效果，必须首先统一。

**Independent Test**: 切换暗色模式后所有颜色自动适配，无残留硬编码颜色。

**Acceptance Scenarios**:

1. **Given** RouteDetailSheet 中所有颜色使用 `$r()` 引用，**When** 切换到暗色模式，**Then** 所有颜色自动适配暗色主题
2. **Given** color.json 中定义了完整的令牌体系，**When** 修改某个令牌值，**Then** 所有使用该令牌的 UI 元素同步更新
3. **Given** 代码中不存在硬编码颜色字符串，**When** 全文搜索 `#` 开头的颜色值，**Then** 仅剩 color.json 中的定义

---

### User Story 2 - 字号令牌对齐 (Priority: P1)

当前字号使用混乱：距离 40px、概览指标 26px、配速主值 24px、分段标题 20px（应为 title）、模块标题 18px（应为 title 20px）、导航标题 17px（应为 subtitle）、正文 16px（应为 body 14px 或 subtitle 17px）、配速行 15px、正文描述 14px、辅助 13px、标签 12px、图表标签 11px、图表坐标 10px、图表内 9px、拍立得日期 8px。需要严格按照设计令牌映射：hero(48)、display(32)、headline(24)、title(20)、subtitle(17)、body(14)、caption(13)、small(12)、tiny(11)。

**Why this priority**: 字号直接影响信息层级和视觉节奏，与颜色同等重要。

**Independent Test**: 各模块字号严格匹配设计令牌定义，核心数据使用 hero/display，次级数据使用 headline/title。

**Acceptance Scenarios**:

1. **Given** 距离数字使用 hero(48px)，**When** 查看概览卡片，**Then** 核心距离数值以 48px 显示
2. **Given** 概览指标数值使用 display(32px)，**When** 查看运动时间/配速等指标，**Then** 以 32px 显示
3. **Given** 模块标题使用 title(20px)，**When** 查看"配速"/"分段"/"实时配速"等标题，**Then** 以 20px 显示
4. **Given** 所有字号均可映射到设计令牌层级，**When** 审查代码，**Then** 无遗漏的任意字号值

---

### User Story 3 - 圆角令牌对齐 (Priority: P2)

当前圆角值混乱：概览卡片 26px、配速卡片 26px、运动解读 21px/22px、分段表 16px、折线图卡片 14px、配速条 14px、进度条 3px/6px。需要严格映射到设计令牌：xxl(16)、xl(12)、lg(10)、md(8)、sm(4)。

映射规则：26→xxl(16)、22→xxl(16)、21→xxl(16)、16→xxl(16)、14→xl(12)、6→md(8)、3→sm(4)。

**Why this priority**: 圆角一致性影响视觉统一感，但优先级低于颜色和字号。

**Independent Test**: 所有圆角值严格来自令牌体系，无自定义中间值。

**Acceptance Scenarios**:

1. **Given** 大卡片圆角使用 xxl(16px)，**When** 查看概览/配速/运动解读卡片，**Then** 圆角统一为 16px
2. **Given** 小卡片/按钮使用 xl(12px)，**When** 查看折线图卡片，**Then** 圆角为 12px
3. **Given** 进度条/小元素使用 md(8px) 或 sm(4px)，**When** 查看配速条/色块，**Then** 圆角对应令牌值

---

### User Story 4 - 间距令牌对齐 (Priority: P2)

当前间距值散落：padding 使用 1/3/4/6/8/10/12/14/16/18/20/22/26/28，Column space 使用 3/4/5/6/8/10/12/14/22/26。需要映射到设计令牌：xs(4)/sm(8)/md(12)/lg(16)/xl(20)/xxl(24)/xxxl(32)。

**Why this priority**: 间距影响布局节奏，但视觉冲击低于颜色和字号。

**Independent Test**: 所有间距值可映射到令牌体系，无任意中间值。

**Acceptance Scenarios**:

1. **Given** 卡片内边距使用 lg(16px) 或 xl(20px)，**When** 查看各卡片，**Then** padding 统一
2. **Given** 元素间距使用 sm(8px) 或 md(12px)，**When** 查看 Column space，**Then** 间距统一
3. **Given** 区块间距使用 xxl(24px) 或 xxxl(32px)，**When** 查看卡片之间，**Then** 间距统一

---

### User Story 5 - 字重令牌对齐 (Priority: P3)

当前字重仅使用 Bold/Medium/Regular，设计令牌要求 bold(700)/semibold(600)/medium(500)/regular(400)。部分本应使用 semibold 的场景（如模块标题、图表数值）使用了 Bold 或 Medium。

**Why this priority**: 字重差异细微，对视觉影响较小，但影响信息层级的精确表达。

**Independent Test**: 字重使用与设计令牌定义一致。

**Acceptance Scenarios**:

1. **Given** 核心数据使用 bold(700)，**When** 查看距离/配速等核心数值，**Then** 字重为 FontWeight.Bold
2. **Given** 模块标题使用 semibold(600)，**When** 查看"配速"/"心率"等标题，**Then** 字重为 FontWeight.Medium（600 在 ArkUI 中对应 MediumWeight，实际映射需验证）

---

### User Story 6 - 暗色模式完善 (Priority: P2)

当前 color.json dark 模式仅覆盖部分令牌的暗色值。新增的令牌（如 pace 渐变色、训练表现色块、运动解读渐变等）需要在 dark/color.json 中补充暗色适配值。

**Why this priority**: 暗色模式是用户体验的基本要求，需与亮色令牌同步完善。

**Independent Test**: 切换暗色模式后所有新增令牌颜色正确显示。

**Acceptance Scenarios**:

1. **Given** 所有新增令牌在 dark/color.json 中有对应定义，**When** 切换到暗色模式，**Then** 所有颜色自动适配
2. **Given** 暗色模式下文字与背景对比度足够，**When** 查看详情页，**Then** 所有文字清晰可读

---

### Edge Cases

- 配速条渐变色（`#FF6B1F`→`#FF4D13`）在暗色模式下是否需要调整？
- 运动解读渐变边框（`#FFD35D`→`#F08BCA`→`#57DCE4`）在暗色模式下的色值
- 训练表现色块（绿/黄/橙/红）在暗色模式下是否保持不变？
- 心率图标双心（`#FF765F`/`#7AA6FF`）暗色模式适配
- Canvas 绘制的图表颜色是否也需要令牌化（当前 drawLineChart 接收 string 类型 color 参数）？

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: 系统 MUST 将 RouteDetailSheet 中所有硬编码颜色字符串替换为 `$r()` 资源引用，包括但不限于：`#ECECEC`、`#555555`、`#666666`、`#9A9A9A`、`#F7A985`、`#FF4D13`、`#FF6B1F`、`#56D978`、`#F7E94C`、`#FF9237`、`#37C96C`、`#E92323`、`#FF816F`、`#111111`、`#333333`、`#58D68D`、`#F7DC6F`、`#F5B041`、`#E74C3C`、`#FF765F`、`#7AA6FF`、`#FFD35D`、`#F08BCA`、`#57DCE4`
- **FR-002**: 系统 MUST 在 color.json（base 和 dark）中补充所有缺失的设计令牌定义，确保令牌体系完整
- **FR-003**: 系统 MUST 将核心距离数字字号从 40px 对齐到 hero(48px)
- **FR-004**: 系统 MUST 将概览指标数值字号从 26px 对齐到 display(32px)
- **FR-005**: 系统 MUST 将模块标题字号从 18px 对齐到 title(20px)
- **FR-006**: 系统 MUST 将所有圆角值严格映射到设计令牌：xxl(16)/xl(12)/lg(10)/md(8)/sm(4)，消除 26/22/21/14 等非令牌值
- **FR-007**: 系统 MUST 将所有间距值映射到设计令牌：xs(4)/sm(8)/md(12)/lg(16)/xl(20)/xxl(24)/xxxl(32)，消除非令牌值
- **FR-008**: 系统 MUST 将字重对齐到设计令牌：bold(700)/semibold(600)/medium(500)/regular(400)
- **FR-009**: 系统 MUST 在 dark/color.json 中为所有新增令牌提供暗色适配值
- **FR-010**: 所有样式改造 MUST 严格保持现有功能行为不变，仅调整视觉参数
- **FR-011**: 系统 MUST 保持与设计令牌 JSON 中 chart.* 心率区间颜色的一致性（zone1-zone5）
- **FR-012**: 系统 MUST 保持与设计令牌 JSON 中 chart.paceIntensity* 配速强度颜色的一致性

### Key Entities

- **设计令牌体系**: 包含 color/font/spacing/borderRadius/shadow/opacity 六大类的完整令牌定义
- **RouteDetailSheet**: 底部详情面板组件，本次改造的核心目标
- **color.json**: HarmonyOS 颜色资源文件，base 和 dark 两套
- **HikingRouteItem**: 徒步路线数据模型，提供展示数据源

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: RouteDetailSheet 代码中零硬编码颜色字符串（`#` 开头的颜色值仅存在于 color.json）
- **SC-002**: 所有字号值均可映射到设计令牌层级（hero/display/headline/title/subtitle/body/caption/small/tiny）
- **SC-003**: 所有圆角值均来自设计令牌（xxl/xl/lg/md/sm），无非令牌值
- **SC-004**: 所有间距值均来自设计令牌（xs/sm/md/lg/xl/xxl/xxxl），无非令牌值
- **SC-005**: 项目成功编译，无编译错误
- **SC-006**: 暗色模式下 RouteDetailSheet 所有颜色正确显示，无遗漏
- **SC-007**: 页面功能行为与改造前完全一致

## Assumptions

- ArkUI 中 `FontWeight.Medium` 对应字重 500，`FontWeight.Bold` 对应 700，无直接 600 枚举值，semibold 需使用 `FontWeight.Medium` 或数字字重
- Canvas drawLineChart 接收 string 类型颜色参数，无法使用 `$r()` 引用，保留字符串但使用常量映射
- 设计令牌中的 `0.5px` 分割线在 ArkUI 中以 `vp` 单位实现
- 渐变色（配速条、运动解读边框）在 ArkUI 中需通过 `linearGradient` API 实现，颜色引用需在代码中解析
- 暗色模式下训练表现色块和心率区间色保持不变（功能性颜色）

## Open Questions

- [无关键开放问题 - 所有需求已在澄清阶段明确]
