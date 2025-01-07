import 'package:flutter/foundation.dart';
import 'package:kasie_transie_library/data/data_schemas.dart';
import 'package:kasie_transie_library/utils/functions.dart';
import 'package:sembast/sembast_io.dart' as sp;
import 'package:sembast_web/sembast_web.dart' as sw;
import 'package:sembast_web/sembast_web.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class CommuterSemCache {
  late sp.Database dbPhone;
  late sw.Database dbWeb;
  static String dbPath = 'kasie.db';

  CommuterSemCache() {
    initializeDatabase();
  }

  static const mm = '👽👽👽👽👽👽 CommuterSemCache 👽👽👽';

  void initializeDatabase() async {
    pp('\n\n$mm initialize 🔵️ Local Database 🔵️: set up for platform ...');
    if (kIsWeb) {
      sw.DatabaseFactory dbFactoryWeb = sw.databaseFactoryWeb;
      dbWeb = await dbFactoryWeb.openDatabase(dbPath);
      pp('$mm cache database set up for web. (1)');
    } else {
      final dir = await getApplicationDocumentsDirectory();
      await dir.create(recursive: true);
      final dPath = p.join(dir.path, dbPath);
      dbPhone = await sp.databaseFactoryIo.openDatabase(dPath);
      pp('$mm cache database set up for phone');
    }
  }

  //
  Future getDb() async {
    if (kIsWeb) {
      sw.DatabaseFactory dbFactoryWeb = sw.databaseFactoryWeb;
      dbWeb = await dbFactoryWeb.openDatabase(dbPath);
      return dbWeb;
    } else {
      final dir = await getApplicationDocumentsDirectory();
      await dir.create(recursive: true);
      final dPath = p.join(dir.path, dbPath);
      dbPhone = await sp.databaseFactoryIo.openDatabase(dPath);

      return dbPhone;
    }
  }

  int dateToInt(String date) {
    final DateTime dt = DateTime.parse(date);
    return dt.microsecondsSinceEpoch;
  }

  int stringToInt(String str) {
    int hash = 5381;
    for (int i = 0; i < str.length; i++) {
      hash = ((hash << 5) + hash) + str.codeUnitAt(i);
    }
    return hash;
  }

  Future saveCommuterRoute(Route route) async {
    var store = intMapStoreFactory.store('commuterRoutes');
    store
        .record(dateToInt(route.created ?? DateTime.now().toIso8601String()))
        .put(await getDb(), route.toJson());

    pp('$mm commuterRoute added to cache: 🥦 ${route.name} 🥦');
  }
  Future<List<Route>> getCommuterRoutes() async {
    var store = intMapStoreFactory.store('commuterRoutes');
    var records = await store.find(await getDb());

    List<Route> routes = [];
    for (var rec in records) {
      var route = Route.fromJson(rec.value);
      routes.add(route);
    }
    pp('$mm commuter routes retrieved from cache: ${routes.length}');
    return routes;

  }
  Future saveRoute(Route route) async {
    var store = intMapStoreFactory.store('routes');
      var key = dateToInt(route.created!);
      store.record(key).put(await getDb(), route.toJson());
      pp('$mm 🖐🏾🖐🏾$key 🖐🏾 ${route.name}');

    pp('$mm route added to cache: 🎽 ${route.name} 🎽');
  }
  Future saveRoutes(List<Route> routes) async {
    var store = intMapStoreFactory.store('routes');
    // store.delete(await getDb());
    for (var route in routes) {
      var key = dateToInt(route.created!);
      store.record(key).put(await getDb(), route.toJson());
      pp('$mm 🖐🏾🖐🏾$key 🖐🏾 ${route.name}');
    }
    pp('$mm routes added to cache: 🎽 ${routes.length} 🎽');
  }
  Future<Route?> getRouteById(String routeId) async {
    var store = intMapStoreFactory.store('routes');
    var records = await store.find(await getDb());

    for (var rec in records) {
      var route = Route.fromJson(rec.value);
     if (route.routeId == routeId) {
       return route;
     }
    }
    return null;
  }

}
