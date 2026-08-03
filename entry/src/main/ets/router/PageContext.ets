import { PageEnum } from '../common/PageEnum';

export interface RouterParam {
  routerName: PageEnum;
  param?: object;
}

export class PageContext {
  private readonly pathStack: NavPathStack = new NavPathStack();

  public get navPathStack(): NavPathStack {
    return this.pathStack;
  }

  public replacePage(data: RouterParam, animated: boolean = true): void {
    try {
      this.pathStack.replacePath(new NavPathInfo(data.routerName, data.param), animated);
    } catch (err) {
      console.error(`Replace page failed: ${JSON.stringify(err)}`);
    }
  }

  public openPage(data: RouterParam, animated: boolean = true): void {
    try {
      this.pathStack.pushPath(new NavPathInfo(data.routerName, data.param), animated);
    } catch (err) {
      console.error(`Open page failed: ${JSON.stringify(err)}`);
    }
  }

  public popPage(animated: boolean = true): void {
    try {
      this.pathStack.pop(animated);
    } catch (err) {
      console.error(`Pop page failed: ${JSON.stringify(err)}`);
    }
  }
}
