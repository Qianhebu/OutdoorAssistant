import { ApiResponse, mockRequest } from './MockApi';

/** 热门搜索词 */
export interface HotSearchItem {
  title: string;
  heat: number;
}

/** 搜索结果条目 */
export interface SearchResultItem {
  title: string;
  subtitle: string;
  tag: string;
}

/** 模拟服务端搜索数据源 */
const HOT_SEARCH_DATA: HotSearchItem[] = [
  { title: '东钱湖环湖步道', heat: 98 },
  { title: '四明山森林线', heat: 92 },
  { title: '鄞州城市绿道', heat: 85 },
  { title: '登山杖推荐', heat: 78 },
  { title: '户外急救指南', heat: 75 },
  { title: '防晒装备', heat: 68 },
  { title: '徒步鞋测评', heat: 62 },
  { title: '露营帐篷', heat: 58 }
];

const ALL_SEARCH_DATA: SearchResultItem[] = [
  { title: '东钱湖环湖步道', subtitle: '轻松 · 6.2km · 约 1.5 小时', tag: '湖景' },
  { title: '东钱湖骑行路线', subtitle: '休闲 · 14km · 约 2 小时', tag: '骑行' },
  { title: '四明山森林线', subtitle: '进阶 · 12.8km · 约 4 小时', tag: '森林' },
  { title: '四明山古道穿越', subtitle: '挑战 · 18km · 约 6 小时', tag: '古道' },
  { title: '鄞州城市绿道', subtitle: '休闲 · 14.5km · 约 1 小时', tag: '骑行' },
  { title: '登山杖推荐：碳纤维超轻款', subtitle: '装备 · 重量 185g', tag: '装备' },
  { title: '户外急救指南：野外生存手册', subtitle: '安全 · 必备知识', tag: '安全' },
  { title: '防晒装备清单', subtitle: '装备 · 防晒霜/帽/衣', tag: '装备' },
  { title: '徒步鞋测评：防水透气对比', subtitle: '装备 · 5 款对比', tag: '装备' },
  { title: '露营帐篷选购指南', subtitle: '装备 · 3 季/4 季款', tag: '装备' }
];

/** 查询热门搜索词 */
export function fetchHotSearches(): Promise<ApiResponse<HotSearchItem[]>> {
  return mockRequest<HotSearchItem[]>(HOT_SEARCH_DATA, 150);
}

/** 按关键字搜索路线/装备 */
export function searchRoutes(keyword: string): Promise<ApiResponse<SearchResultItem[]>> {
  const query = keyword.trim();
  const result: SearchResultItem[] = ALL_SEARCH_DATA.filter((item: SearchResultItem) =>
    item.title.indexOf(query) >= 0 || item.tag.indexOf(query) >= 0
  );
  return mockRequest<SearchResultItem[]>(result, 100);
}
