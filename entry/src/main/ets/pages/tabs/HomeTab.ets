import { HdsNavigation, HdsNavigationTitleMode, HdsTabsController } from '@kit.UIDesignKit';
import { PageEnum } from '../../common/PageEnum';
import { StorageKey } from '../../common/StorageKey';
import { PageContext, RouterParam } from '../../router/PageContext';
import { HomeListView } from './HomeListView';

interface HomeListRouteParam {
  scroller: Scroller;
  homeTabController: HdsTabsController;
}

@Component({ freezeWhenInactive: true })
export struct HomeTab {
  @StorageLink(StorageKey.HOME_TAB_PAGE_CONTEXT) homeTabPageContext: PageContext =
    AppStorage.get<PageContext>(StorageKey.HOME_TAB_PAGE_CONTEXT) ?? new PageContext();
  scroller: Scroller = new Scroller();
  homeTabController: HdsTabsController = new HdsTabsController();

  aboutToAppear(): void {
    if (this.homeTabPageContext.navPathStack.size() === 0) {
      const homeListParam: HomeListRouteParam = {
        scroller: this.scroller,
        homeTabController: this.homeTabController
      };
      const routerParam: RouterParam = {
        routerName: PageEnum.HOME_LIST_VIEW,
        param: homeListParam
      };
      this.homeTabPageContext.openPage(routerParam, false);
    }
  }

  build() {
    HdsNavigation(this.homeTabPageContext.navPathStack) {
      HomeListView()
    }
    .mode(NavigationMode.Stack)
    .hideBackButton(true)
    .hideTitleBar(true)
    .titleMode(HdsNavigationTitleMode.MINI)
    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
    .width('100%')
    .height('100%')
  }
}
