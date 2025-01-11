import 'dart:collection';

import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:geolocator_platform_interface/src/models/position.dart';
import 'package:get_it/get_it.dart';
import 'package:kasie_transie_commuter_2025/ui/commuter_nearest_routes.dart';
import 'package:kasie_transie_library/bloc/list_api_dog.dart';
import 'package:kasie_transie_library/data/data_schemas.dart' as lib;
import 'package:kasie_transie_library/messaging/fcm_bloc.dart';
import 'package:kasie_transie_library/utils/device_location_bloc.dart';
import 'package:kasie_transie_library/utils/functions.dart';
import 'package:kasie_transie_library/utils/prefs.dart';

import 'commuter_sem_cache.dart';

class RouteUtil {
  List<lib.RoutePoint> routePoints = [];
  DeviceLocationBloc dlb = GetIt.instance<DeviceLocationBloc>();
  ListApiDog listApiDog = GetIt.instance<ListApiDog>();
  FCMService fcmService = GetIt.instance<FCMService>();
  Prefs prefs = GetIt.instance<Prefs>();
  final CommuterSemCache commuterSemCache = CommuterSemCache();

  static const mm = '❤️❤️❤️RouteUtil ❤️❤️';
  FilteredRouteDistance? routeDistance;
  List<FilteredRouteDistance> filteredRoutes = [];
  FilteredRouteDistance? filteredRouteDistance;
  double radiusInKM = 5.0;

  Future<List<FilteredRouteDistance>> getNearestRoutes() async {
    pp('\n\n\n$mm ... ...................... _getNearestRoutes ... ');

    var loc = await dlb.getLocation();
    routePoints = await commuterSemCache.getAllRoutePoints();

    if (routePoints.isEmpty) {
      await _handleRoutePoints(loc);
    } else {
      var distanceFromPrevious = await _getDistanceFromSavedPosition();
      if (distanceFromPrevious > (radiusInKM * 1000)) {
        await _handleRoutePoints(loc);
      }
    }

    var distances =
        await dlb.getRoutePointDistances(routePoints: routePoints);
    List<FilteredRouteDistance> frd = [];
    HashMap<String, lib.Route> map = HashMap();
    for (var f in distances) {
      if (map[f.routePoint.routeId] == null) {
        var routeData =
            await commuterSemCache.getRouteData(f.routePoint.routeId!);
        if (routeData != null) {
          map[f.routePoint.routeId!] = routeData.route!;
        }
      }
    }

    for (var bag in distances) {
      var route = map[bag.routePoint.routeId!];
      if (route != null) {
        frd.add(FilteredRouteDistance(
            route: route,
            distance: bag.distance,
            position: bag.routePoint.position!));
      }
    }
    pp('$mm ... filteredRouteDistances: ${frd.length} ');

    HashMap<String, FilteredRouteDistance> map2 = HashMap();
    for (var f in frd) {
      if (map2[f.route.name] == null) {
        map2[f.route.name!] = f;
      }
    }
    filteredRoutes = map2.values.toList();
    filteredRoutes.sort((a, b) => a.distance.compareTo(b.distance));
    pp('$mm ... filteredRouteDistances after re-filter: ${filteredRoutes.length} ');

    for (var f in filteredRoutes) {
      pp('$mm Route distance:: ${f.distance.toStringAsFixed(1)} metres  🍎 ${f.route.name}');
    }
    return filteredRoutes;
  }

  Future _handleRoutePoints(Position loc) async {
    pp('$mm ... _handleRoutePoints for position:: ${loc.toJson()} ');

    routePoints = await listApiDog.findRoutePointsByLocation(
        latitude: loc.latitude,
        longitude: loc.longitude,
        radiusInKM: radiusInKM);

    commuterSemCache.saveRoutePoints(routePoints);
    pp('$mm ... _handleRoutePoints found by location and cached: ${routePoints.length} ');

    HashMap<String, String> map0 = HashMap();
    for (var rp in routePoints) {
      if (rp.associationId != null) {
        if (map0[rp.associationId!] == null) {
          map0[rp.associationId!] = rp.associationId!;
        }
      }
    }
    pp('$mm ... _getAssociationRouteData for : ${map0.length}  associations');

    for (var associationId in map0.values) {
      var routeData =
          await listApiDog.getAssociationRouteData(associationId, true);
      if (routeData != null) {
        for (var rd in routeData!.routeDataList) {
          await commuterSemCache.saveRouteData(rd);
        }
      }
    }
    return routePoints;
  }

  Future<double> _getDistanceFromSavedPosition() async {
    lib.Position? pos = prefs.getPosition();
    if (pos == null) {
      var current = await dlb.getLocation();
      pos = lib.Position(coordinates: [current.longitude, current.latitude]);
      prefs.savePosition(pos);
    }
    var dist = dlb.getDistanceFromCurrentPosition(
        latitude: pos.coordinates[1], longitude: pos.coordinates[0]);
    pp('$mm _getDistanceFromSavedPosition: $dist metres');
    return dist;
  }
}
