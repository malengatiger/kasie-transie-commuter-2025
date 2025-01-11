import 'package:badges/badges.dart' as bd;
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:kasie_transie_commuter_2025/ui/commuter_request_handler.dart';
import 'package:kasie_transie_library/bloc/list_api_dog.dart';
import 'package:kasie_transie_library/data/data_schemas.dart' as lib;
import 'package:kasie_transie_library/isolates/local_finder.dart';
import 'package:kasie_transie_library/utils/device_location_bloc.dart';
import 'package:kasie_transie_library/utils/functions.dart';
import 'package:kasie_transie_library/utils/navigator_utils.dart';
import 'package:kasie_transie_library/widgets/city_selection.dart';
import 'package:kasie_transie_library/widgets/timer_widget.dart';

class FindRoutesByCity extends StatefulWidget {
  const FindRoutesByCity({Key? key}) : super(key: key);

  @override
  FindRoutesByCityState createState() => FindRoutesByCityState();
}

class FindRoutesByCityState extends State<FindRoutesByCity>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  ListApiDog listApiDog = GetIt.instance<ListApiDog>();
  DeviceLocationBloc dlb = GetIt.instance<DeviceLocationBloc>();

  List<lib.City> cities = [];
  bool busy = false;

  @override
  void initState() {
    _controller = AnimationController(vsync: this);
    super.initState();
    _getCities();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  static const mm = '🔋🔋🔋 FindRoutesByCity 🔋  ';

  void _getCities() async {
    setState(() {
      busy = true;
    });
    var loc = await dlb.getLocation();
    try {
      cities = await listApiDog.findCitiesByLocation(LocationFinderParameter(
          associationId: '',
          latitude: loc.latitude,
          limit: 1000,
          longitude: loc.longitude,
          radiusInKM: 10));

      pp('$mm cities found by location: ${loc.latitude} ${loc.longitude} - ${cities.length} cities');
    } catch (e) {
      pp(e);
    }
    setState(() {
      busy = false;
    });
  }

  bool showRoutesFound = false;

  List<lib.Route> routes = [];
  lib.City? city;

  _findRoutesByCity(lib.City city) async {
    this.city = city;
    routes = await listApiDog.findRoutesByLocation(LocationFinderParameter(
        associationId: '',
        latitude: city.position!.coordinates[1],
        limit: 1000,
        longitude: city.position!.coordinates[0],
        radiusInKM: 10));
    pp('$mm routes found by this city: ${city.name}  🍎 ${routes.length} routes');
    for (var r in routes) {
      pp('$mm route found : 🍎  ${r.name}  🍎 ');
    }
    if (routes.isEmpty) {
      if (mounted) {
        showErrorToast(
            duration: const Duration(seconds: 2),
            message: 'No routes were found. Check bak later!', context: context);
        return;
      }
    }
    setState(() {
      showRoutesFound = true;
    });
  }
  _handleSelectedRoute(lib.Route route) async {
    pp('$mm _handleSelectedRoute: route: ${route.name}');
    Navigator.of(context).pop(route);
    NavigationUtils.navigateTo(context: context, widget: CommuterRequestHandler(
        routeId: route.routeId!, routeName: route.name!));
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          leading: gapW32,
          title: Text('Find Routes By City', style: myTextStyle(fontSize: 14))),
      body: SafeArea(
        child: Stack(
          children: [
            showRoutesFound
                ? Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        city == null
                            ? gapW32
                            : Text('${city!.name}',
                                style: myTextStyle(fontSize: 24)),
                        gapH16,
                        Text(
                          'Routes found',
                          style: myTextStyle(
                              weight: FontWeight.w900,
                              fontSize: 20,
                              color: Colors.grey),
                        ),
                        gapH32,
                        Expanded(
                          child: bd.Badge(
                            position: bd.BadgePosition.topEnd(top: -36, end: 8),
                            badgeContent: Text('${routes.length}',
                                style: myTextStyle(color: Colors.white)),
                            badgeStyle: bd.BadgeStyle(
                                elevation: 8,
                                badgeColor: Colors.green,
                                padding: EdgeInsets.all(16)),
                            child: ListView.builder(
                              itemBuilder: (context, index) {
                                var r = routes[index];
                                return GestureDetector(
                                  onTap: () {
                                    pp('$mm route tapped: ${r.name}');
                                    _handleSelectedRoute(r);
                                  },
                                  child: Card(
                                    elevation: 8,
                                    color: Colors.yellow.shade100,
                                    child: Padding(
                                        padding: EdgeInsets.all(16),
                                        child: Text('${r.name}')),
                                  ),
                                );
                              },
                              itemCount: routes.length,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 160,
                          child: ElevatedButton(
                              style: ButtonStyle(
                                  elevation: WidgetStatePropertyAll(8),
                                  backgroundColor:
                                  WidgetStatePropertyAll(Colors.amber)),
                              onPressed: () {
                                setState(() {
                                  showRoutesFound = false;
                                });
                              },
                              child: const Text('Find Routes')),
                        ),
                      ],
                    ))
                : Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      children: [
                        cities.isEmpty
                            ? gapW32
                            : Expanded(
                                child: CitySearch(
                                  cities: cities,
                                  title: '',
                                  onCityAdded: (c) {},
                                  onCitySelected: (c) {
                                    pp('$mm City selected: ${c.name}');
                                    _findRoutesByCity(c);
                                  },
                                ),
                              ),
                        SizedBox(
                          width: 100,
                          child: ElevatedButton(
                              style: ButtonStyle(
                                backgroundColor: WidgetStatePropertyAll(Colors.grey),
                                elevation: WidgetStatePropertyAll(8),
                              ),
                              onPressed: () {
                                Navigator.of(context).pop();
                              },
                              child: Text(
                                'Done',
                                style: myTextStyle(color: Colors.white),
                              )),
                        ),
                      ],
                    ),
                  ),
            // routes.isNotEmpty
            //     ? Positioned(
            //         right: 4,
            //         bottom: 4,
            //         child: SizedBox(
            //           width: 160,
            //           child: ElevatedButton(
            //               style: ButtonStyle(
            //                   elevation: WidgetStatePropertyAll(8),
            //                   backgroundColor:
            //                       WidgetStatePropertyAll(Colors.amber)),
            //               onPressed: () {
            //                 setState(() {
            //                   showRoutesFound = false;
            //                 });
            //               },
            //               child: const Text('Find Routes')),
            //         ),
            //       )
            //     : gapW32,
            busy
                ? Positioned(
                    child: Center(
                        child: TimerWidget(
                    title: 'Loading cities',
                    isSmallSize: true,
                  )))
                : gapW32
          ],
        ),
      ),
    );
  }
}
