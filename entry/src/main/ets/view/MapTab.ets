import { map, mapCommon, MapComponent } from '@kit.MapKit';
import { geoLocationManager } from '@kit.LocationKit';
import { AsyncCallback, BusinessError } from '@kit.BasicServicesKit';
import { AppStorageKeys } from '../constant/AppStorageKeys';

@ComponentV2({ freezeWhenInactive: true })
export struct MapTab {
  @Local mapOptions?: mapCommon.MapOptions = undefined;
  @Local currentLocation: mapCommon.LatLng = { latitude: 29.87, longitude: 121.55 };
  topInset: number = AppStorage.get<number>(AppStorageKeys.TOP_INSET) ?? 0;
  bottomInset: number = AppStorage.get<number>(AppStorageKeys.BOTTOM_INSET) ?? 0;
  private mapController?: map.MapComponentController = undefined;
  private mapCallback?: AsyncCallback<map.MapComponentController> = undefined;

  aboutToAppear(): void {
    this.initMap();
  }

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
      let myLocationStyle: mapCommon.MyLocationStyle = {
        anchorU: 0.5,
        anchorV: 0.5,
        radiusFillColor: 0x00000000,
        displayType: mapCommon.MyLocationDisplayType.FOLLOW
      };
      await this.mapController.setMyLocationStyle(myLocationStyle);
      this.mapController.setMyLocationEnabled(true);
      this.mapController.setBuildingEnabled(true);
      this.mapController.setTrafficEnabled(false);

      let locationRequest: geoLocationManager.LocationRequest = {
        priority: geoLocationManager.LocationRequestPriority.FIRST_FIX,
        scenario: geoLocationManager.LocationRequestScenario.UNSET,
        timeInterval: 1,
        distanceInterval: 0,
        maxAccuracy: 0
      };
      let locationChange = (location: geoLocationManager.Location): void => {
        this.mapController?.setMyLocation(location);
      };
      try {
        geoLocationManager.on('locationChange', locationRequest, locationChange);
      } catch (error) {
        console.error(`MapTab locationChange failed: ${(error as BusinessError).message}`);
      }
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
