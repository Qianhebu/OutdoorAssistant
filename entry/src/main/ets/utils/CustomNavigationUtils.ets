export interface AnimateCallback {
  onInteractiveFinish?: () => void;
  onInteractive?: () => void;
  timeout?: number;
  animation?: (transitionProxy: NavigationTransitionProxy) => void;
}

const customTransitionMap: Map<string, AnimateCallback> = new Map();

export class CustomTransition {
  static delegate: CustomTransition = new CustomTransition();
  isInteractive: boolean = false;
  proxy?: NavigationTransitionProxy = undefined;
  operation: NavigationOperation = NavigationOperation.PUSH;

  static getInstance(): CustomTransition {
    return CustomTransition.delegate;
  }

  registerNavParam(name: string,
    timeout: number,
    animation?: (transitionProxy: NavigationTransitionProxy) => void,
    onInteractiveFinish?: () => void,
    onInteractive?: () => void
  ): void {
    if (customTransitionMap.has(name)) {
      let param = customTransitionMap.get(name);
      if (param !== undefined) {
        param.animation = animation;
        param.timeout = timeout;
        param.onInteractiveFinish = onInteractiveFinish;
        param.onInteractive = onInteractive;
        return;
      }
    }
    let params: AnimateCallback = {
      animation: animation,
      timeout: timeout,
      onInteractiveFinish: onInteractiveFinish,
      onInteractive: onInteractive
    };
    customTransitionMap.set(name, params);
  }

  unRegisterNavParam(name: string): void {
    customTransitionMap.delete(name);
  }

  getAnimateParam(name: string): AnimateCallback {
    let result: AnimateCallback = {
      timeout: customTransitionMap.get(name)?.timeout,
      onInteractiveFinish: customTransitionMap.get(name)?.onInteractiveFinish,
      onInteractive: customTransitionMap.get(name)?.onInteractive,
      animation: customTransitionMap.get(name)?.animation
    };
    return result;
  }
}
