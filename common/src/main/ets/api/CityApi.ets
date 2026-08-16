import { ApiResponse, mockRequest } from './MockApi';

/** 城市分组 */
export interface CityGroup {
  letter: string;
  cities: string[];
}

/** 城市列表数据 */
export interface CityListData {
  hotCities: string[];
  groups: CityGroup[];
}

/** 模拟服务端城市数据源 */
const HOT_CITIES: string[] = [
  '北京', '上海', '广州', '深圳', '杭州', '成都', '重庆', '武汉',
  '南京', '西安', '长沙', '青岛', '厦门', '昆明', '大连', '苏州'
];

const CITY_GROUPS: CityGroup[] = [
  { letter: 'A', cities: ['安庆', '安阳', '鞍山', '安康'] },
  { letter: 'B', cities: ['北京', '保定', '包头', '蚌埠', '滨州'] },
  { letter: 'C', cities: ['成都', '重庆', '长沙', '常州', '沧州', '承德'] },
  { letter: 'D', cities: ['大连', '东莞', '大同', '德州', '东营'] },
  { letter: 'F', cities: ['福州', '佛山', '抚顺', '阜阳'] },
  { letter: 'G', cities: ['广州', '贵阳', '桂林', '赣州'] },
  { letter: 'H', cities: ['杭州', '合肥', '海口', '惠州', '呼和浩特', '哈尔滨', '湖州', '菏泽'] },
  { letter: 'J', cities: ['济南', '金华', '嘉兴', '江门', '荆州', '吉林'] },
  { letter: 'K', cities: ['昆明', '开封', '喀什'] },
  { letter: 'L', cities: ['兰州', '洛阳', '连云港', '临沂', '柳州', '泸州'] },
  { letter: 'M', cities: ['绵阳', '牡丹江', '茂名'] },
  { letter: 'N', cities: ['南京', '南昌', '南宁', '宁波', '南通', '南阳'] },
  { letter: 'Q', cities: ['青岛', '泉州', '秦皇岛', '齐齐哈尔'] },
  { letter: 'S', cities: ['上海', '深圳', '苏州', '沈阳', '石家庄', '绍兴', '汕头'] },
  { letter: 'T', cities: ['天津', '太原', '唐山', '台州', '泰安'] },
  { letter: 'W', cities: ['武汉', '无锡', '温州', '乌鲁木齐', '潍坊', '威海', '芜湖'] },
  { letter: 'X', cities: ['西安', '厦门', '徐州', '襄阳', '新乡', '湘潭', '咸阳'] },
  { letter: 'Y', cities: ['烟台', '扬州', '银川', '宜昌', '岳阳', '盐城'] },
  { letter: 'Z', cities: ['郑州', '珠海', '中山', '张家界', '遵义', '淄博', '漳州'] }
];

/** 查询城市列表（热门城市 + 按字母分组） */
export function fetchCityList(): Promise<ApiResponse<CityListData>> {
  return mockRequest<CityListData>({ hotCities: HOT_CITIES, groups: CITY_GROUPS }, 200);
}

/** 按关键字搜索城市 */
export function searchCities(keyword: string): Promise<ApiResponse<string[]>> {
  const query = keyword.trim();
  const result: string[] = [];
  if (query.length > 0) {
    for (let i = 0; i < CITY_GROUPS.length; i++) {
      const cities = CITY_GROUPS[i].cities;
      for (let j = 0; j < cities.length; j++) {
        if (cities[j].indexOf(query) >= 0) {
          result.push(cities[j]);
        }
      }
    }
  }
  return mockRequest<string[]>(result, 100);
}
