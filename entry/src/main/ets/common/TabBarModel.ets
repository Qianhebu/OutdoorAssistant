export enum OutdoorTabType {
  HOME = 0,
  RECORD = 1,
  MINE = 2
}

export interface OutdoorTabData {
  id: OutdoorTabType;
  title: string;
  icon: Resource;
}

export const OUTDOOR_TABS_LIST: OutdoorTabData[] = [
  {
    id: OutdoorTabType.HOME,
    title: '首页',
    icon: $r('sys.symbol.mountain_2_fill')
  },
  {
    id: OutdoorTabType.RECORD,
    title: '记录',
    icon: $r('sys.symbol.outward_curvature_fill')
  },
  {
    id: OutdoorTabType.MINE,
    title: '我的',
    icon: $r('sys.symbol.leaf_2_fill')
  }
];
