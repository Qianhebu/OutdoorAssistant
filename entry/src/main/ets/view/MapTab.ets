import { map, mapCommon, MapComponent } from '@kit.MapKit';
import { geoLocationManager } from '@kit.LocationKit';
import { AsyncCallback, BusinessError } from '@kit.BasicServicesKit';
import { abilityAccessCtrl, common, PermissionRequestResult, Permissions } from '@kit.AbilityKit';
import { AppStorageKeys } from '../constant/AppStorageKeys';
import { getStoredLocation, StoredLocation, saveCurrentLocation } from '../utils/LocationStore';

@ComponentV2({ freezeWhenInactive: true })
export struct MapTab {
  @Local mapOptions?: mapCommon.MapOptions = undefined;
  @Local currentLocation: mapCommon.LatLng = { latitude: 29.87, longitude: 121.55 };
  topInset: number = AppStorage.get<number>(AppStorageKeys.TOP_INSET) ?? 0;
  bottomInset: number = AppStorage.get<number>(AppStorageKeys.BOTTOM_INSET) ?? 0;
  private mapController?: map.MapComponentController = undefined;
  private mapCallback?: AsyncCallback<map.MapComponentController> = undefined;
  private locationPermissions: Array<Permissions> =
    ['ohos.permission.APPROXIMATELY_LOCATION', 'ohos.permission.LOCATION'];
  private isPermissionGranted: boolean = false;
  private isLocationTrackingStarted: boolean = false;

  aboutToAppear(): void {
    this.applyStoredLocation();
    this.initMap();
    this.requestLocationPermission();
  }

  aboutToDisappear(): void {
    this.stopLocationTracking();
  }

  /** 从首页共享的定位中读取坐标作为地图初始中心 */
  private applyStoredLocation(): void {
    const stored: StoredLocation | undefined = getStoredLocation();
    if (stored) {
      this.currentLocation = { latitude: stored.latitude, longitude: stored.longitude };
    }
  }

  /** 请求定位权限，授权后启动定位追踪 */
  private async requestLocationPermission(): Promise<void> {
    try {
      const atManager: abilityAccessCtrl.AtManager = abilityAccessCtrl.createAtManager();
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const result: PermissionRequestResult =
        await atManager.requestPermissionsFromUser(context, this.locationPermissions);
      const granted = result.authResults.every((status: number) => status === 0);
      this.isPermissionGranted = granted;
      if (granted) {
        this.startLocationTracking();
      }
    } catch (err) {
      console.error(`MapTab request location permission failed: ${JSON.stringify(err)}`);
    }
  }

  /** 启动定位追踪：启用地图定位图层 + 注册连续定位监听 + 立即获取一次定位 */
  private startLocationTracking(): void {
    if (!this.isPermissionGranted || this.isLocationTrackingStarted) {
      return;
    }
    this.isLocationTrackingStarted = true;
    this.enableMyLocationLayer();
    // 地图控制器可能尚未就绪，延迟重试启用定位图层
    setTimeout(() => {
      this.enableMyLocationLayer();
    }, 800);
    let locationRequest: geoLocationManager.LocationRequest = {
      priority: geoLocationManager.LocationRequestPriority.FIRST_FIX,
      scenario: geoLocationManager.LocationRequestScenario.UNSET,
      timeInterval: 1,
      distanceInterval: 0,
      maxAccuracy: 0
    };
    try {
      geoLocationManager.on('locationChange', locationRequest, this.locationChangeCb);
    } catch (error) {
      console.error(`MapTab locationChange failed: ${(error as BusinessError).message}`);
    }
    this.requestCurrentLocation();
  }

  /** 停止定位追踪 */
  private stopLocationTracking(): void {
    if (!this.isLocationTrackingStarted) {
      return;
    }
    this.isLocationTrackingStarted = false;
    try {
      geoLocationManager.off('locationChange', this.locationChangeCb);
    } catch (err) {
      console.info(`MapTab off locationChange: ${JSON.stringify(err)}`);
    }
  }

  /** 立即获取一次当前定位，更新蓝点并写入共享定位 */
  private requestCurrentLocation(): void {
    const request: geoLocationManager.SingleLocationRequest = {
      locatingPriority: 0x502,
      locatingTimeoutMs: 10000
    };
    geoLocationManager.getCurrentLocation(request).then((location: geoLocationManager.Location) => {
      this.mapController?.setMyLocation(location);
      saveCurrentLocation(location.latitude, location.longitude);
    }).catch((err: BusinessError) => {
      console.error(`MapTab get current location failed: ${JSON.stringify(err)}`);
    });
  }

  /** 启用地图定位图层（需权限已授予且地图控制器就绪） */
  private enableMyLocationLayer(): void {
    if (!this.isPermissionGranted || this.mapController === undefined) {
      return;
    }
    try {
      this.mapController.setMyLocationEnabled(true);
    } catch (err) {
      console.error(`MapTab enable my location failed: ${JSON.stringify(err)}`);
    }
  }

  private locationChangeCb: (location: geoLocationManager.Location) => void =
    (location: geoLocationManager.Location) => {
      this.mapController?.setMyLocation(location);
      saveCurrentLocation(location.latitude, location.longitude);
    };

  private initMap(): void {
    this.mapOptions = {
      mapType: mapCommon.MapType.STANDARD,
      position: {
        target: this.currentLocation,
        zoom: 15,
        tilt: 0,
        bearing: 0
      },
      rotateGesturesEnabled: true,
      scrollGesturesEnabled: true,
      zoomGesturesEnabled: true,
      tiltGesturesEnabled: true,
      zoomControlsEnabled: true,
      myLocationControlsEnabled: true,
      compassControlsEnabled: true,
      scaleControlsEnabled: true,
      dayNightMode: mapCommon.DayNightMode.AUTO
    };
    this.mapCallback = async (err: BusinessError | undefined, controller: map.MapComponentController) => {
      if (err) {
        console.error(`MapTab map init failed: ${err.message}`);
        return;
      }
      this.mapController = controller;
      // 若共享定位已就绪，将相机移动到该位置
      const stored: StoredLocation | undefined = getStoredLocation();
      if (stored) {
        const latLng: mapCommon.LatLng = { latitude: stored.latitude, longitude: stored.longitude };
        this.mapController.animateCamera(map.newLatLng(latLng, 15), 500);
      }
      let myLocationStyle: mapCommon.MyLocationStyle = {
        anchorU: 0.5,
        anchorV: 0.5,
        radiusFillColor: 0x8F7570FF,
        displayType: mapCommon.MyLocationDisplayType.FOLLOW
      };
      try {
        await this.mapController.setMyLocationStyle(myLocationStyle);
      } catch (styleErr) {
        console.error(`MapTab setMyLocationStyle failed: ${JSON.stringify(styleErr)}`);
      }
      this.enableMyLocationLayer();
      this.mapController.setBuildingEnabled(true);
      this.mapController.setTrafficEnabled(false);
      this.startLocationTracking();
    };
  }

  build() {
    Stack() {
      if (this.mapOptions && this.mapCallback) {
        MapComponent({ mapOptions: this.mapOptions, mapCallback: this.mapCallback })
          .width('100%')
          .height('100%')
      }
    }
    .width('100%')
    .height('100%')
  }
}
