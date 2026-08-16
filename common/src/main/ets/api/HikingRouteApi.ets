import { HikingRouteItem, HikingRouteResponse } from '../model/HikingRouteModel';
import { ApiResponse, mockRequest, readRawFileText } from './MockApi';

/** 徒步路线列表分页数据 */
export interface HikingRoutePageData {
  total: number;
  routes: HikingRouteItem[];
}

let routesCache: HikingRouteItem[] | undefined = undefined;

/** 从本地数据源加载全部路线（模拟服务端读取数据库） */
function loadAllRoutes(): HikingRouteItem[] {
  if (routesCache !== undefined) {
    return routesCache;
  }
  try {
    const jsonStr = readRawFileText('hiking_routes.json');
    const response: HikingRouteResponse = JSON.parse(jsonStr) as HikingRouteResponse;
    routesCache = (response.code === 0 && response.data) ? response.data.routes : [];
  } catch (err) {
    console.error(`[HikingRouteApi] load routes failed: ${JSON.stringify(err)}`);
    routesCache = [];
  }
  return routesCache;
}

/** 分页查询徒步路线列表 */
export function fetchHikingRoutes(page: number = 1, pageSize: number = 20): Promise<ApiResponse<HikingRoutePageData>> {
  const all = loadAllRoutes();
  const start = (page - 1) * pageSize;
  const end = Math.min(start + pageSize, all.length);
  const pageRoutes: HikingRouteItem[] = all.slice(start, end);
  return mockRequest<HikingRoutePageData>({ total: all.length, routes: pageRoutes }, 200);
}

/** 查询路线详情 */
export function fetchRouteDetail(routeId: string): Promise<ApiResponse<HikingRouteItem | null>> {
  const all = loadAllRoutes();
  let found: HikingRouteItem | null = null;
  for (let i = 0; i < all.length; i++) {
    if (all[i].id === routeId) {
      found = all[i];
      break;
    }
  }
  return mockRequest<HikingRouteItem | null>(found, 150);
}
