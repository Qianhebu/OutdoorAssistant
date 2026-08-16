import { ApiResponse, mockRequest } from './MockApi';

/** 首页 Banner 数据 */
export interface HomeBanner {
  id: number;
  title: string;
  subTitle: string;
  desc: string;
  mediaUrl: Resource;
  themeColor: ResourceColor;
  content: string;
}

/** 模拟服务端首页 Banner 数据源 */
const BANNER_DATA: HomeBanner[] = [
  {
    id: 5,
    title: '骑行城市绿道',
    subTitle: '鄞州绿道骑行',
    desc: '14.5km 休闲骑行，城市中的绿色氧吧',
    mediaUrl: $rawfile('image/banner/banner_arkui.png'),
    themeColor: $r('app.color.brand_green'),
    content: '鄞州绿道全长约 14.5 公里，沿河而建，路面平坦宽阔，非常适合休闲骑行。沿途绿树成荫，空气清新，是城市中难得的绿色氧吧。\n\n路线起点位于鄞州公园南门，途经宁南南路、首南东路、日丽中路，最终到达东部新城。全程约需 1-1.5 小时，适合各年龄段骑行爱好者。\n\n骑行装备建议：\n• 城市通勤车或山地车均可\n• 必备头盔和前后车灯\n• 随车携带简易维修工具\n• 夏季注意防晒和补水\n\n沿途设有多处休息驿站和饮水点，补给充足。周末和节假日人流较多，建议错峰出行，注意礼让行人。'
  },
  {
    id: 6,
    title: '装备速查宝典',
    subTitle: '一键选购',
    desc: '登山杖、徒步鞋、防晒衣，专业装备推荐',
    mediaUrl: $rawfile('image/banner/banner_enabling_kit.png'),
    themeColor: $r('app.color.theme_orange'),
    content: '户外装备是安全出行的基础。无论你是初入户外的新手，还是经验丰富的老驴，选对装备都能让你的旅途更加安全舒适。\n\n登山杖推荐：\n• 碳纤维超轻款：重量仅 185g，适合长距离徒步\n• 铝合金三节款：性价比高，耐用可靠\n• 折叠收纳款：便携性好，适合旅行携带\n\n徒步鞋选购要点：\n• 防水透气 GORE-TEX 面料为首选\n• Vibram 大底提供优秀抓地力\n• 中高帮设计保护脚踝\n• 建议买大半码，预留长途肿胀空间\n\n防晒装备清单：\n• UPF50+ 防晒衣：轻薄透气，阻挡 99% 紫外线\n• 宽沿防晒帽：保护面部和颈部\n• 运动防晒霜：SPF50+，防水防汗配方\n• UV400 偏光太阳镜：保护眼睛'
  },
  {
    id: 7,
    title: '新手入门攻略',
    subTitle: '从零开始',
    desc: '第一次户外？看这篇就够了',
    mediaUrl: $rawfile('image/banner/banner_quick_start.png'),
    themeColor: $r('app.color.theme_purple'),
    content: '第一次参加户外活动，既兴奋又紧张？别担心，这篇攻略帮你从零开始，安全踏上户外之旅。\n\n出发前准备：\n1. 选择合适的路线：新手建议从 5km 以内的平坦步道开始\n2. 查看天气预报：避免雨天和大风天出行\n3. 告知亲友行程：分享你的路线和预计返回时间\n4. 检查手机电量：充满电并携带充电宝\n\n必备物品清单：\n• 饮用水（至少 1L）和能量零食\n• 防晒霜、帽子和太阳镜\n• 轻便雨衣（以防突发降雨）\n• 基础急救包（创可贴、消毒棉、绷带）\n• 手电筒或头灯\n\n安全须知：\n• 不要独自前往陌生路线\n• 遇到危险及时拨打救援电话\n• 保持手机通讯畅通\n• 留意路标和指示牌，避免迷路\n• 量力而行，不要逞强\n\n记住：安全永远是第一位的。慢慢来，享受户外的美好！'
  }
];

/** 查询首页 Banner 列表 */
export function fetchHomeBanners(): Promise<ApiResponse<HomeBanner[]>> {
  return mockRequest<HomeBanner[]>(BANNER_DATA, 150);
}
