import { HomeListView } from './HomeListView';

@Component({ freezeWhenInactive: true })
export struct HomeTab {
  build() {
    HomeListView()
  }
}
