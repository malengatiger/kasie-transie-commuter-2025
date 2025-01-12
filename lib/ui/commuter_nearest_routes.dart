import 'dart:collection';

import 'package:badges/badges.dart' as bd;
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get_it/get_it.dart';
import 'package:kasie_transie_commuter_2025/commuter_sem_cache.dart';
import 'package:kasie_transie_commuter_2025/route_util.dart';
import 'package:kasie_transie_commuter_2025/ui/commuter_request_handler.dart';
import 'package:kasie_transie_library/bloc/list_api_dog.dart';
import 'package:kasie_transie_library/bloc/sem_cache.dart';
import 'package:kasie_transie_library/data/data_schemas.dart' as lib;
import 'package:kasie_transie_library/messaging/fcm_bloc.dart';
import 'package:kasie_transie_library/utils/device_location_bloc.dart';
import 'package:kasie_transie_library/utils/functions.dart';
import 'package:kasie_transie_library/utils/navigator_utils.dart';
import 'package:kasie_transie_library/utils/prefs.dart';
import 'package:kasie_transie_library/widgets/timer_widget.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;

class CommuterNearestRoutes extends StatefulWidget {
  const CommuterNearestRoutes({super.key});

  @override
  CommuterNearestRoutesState createState() => CommuterNearestRoutesState();
}

class CommuterNearestRoutesState extends State<CommuterNearestRoutes>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  DeviceLocationBloc dlb = GetIt.instance<DeviceLocationBloc>();
  ListApiDog listApiDog = GetIt.instance<ListApiDog>();
  FCMService fcmService = GetIt.instance<FCMService>();
  Prefs prefs = GetIt.instance<Prefs>();
  final CommuterSemCache commuterSemCache = CommuterSemCache();

  List<lib.Route> routes = [];
  bool busy = false;
  List<lib.RoutePoint> routePoints = [];

  @override
  void initState() {
    _controller = AnimationController(vsync: this);
    super.initState();

    _getCommuterRoutes();
  }

  List<lib.Route> commuterRoutes = [];

  _getCommuterRoutes() async {
    pp('$mm _getCommuterRoutes from prefs ...');
    setState(() {
      busy = true;
    });
    commuterRoutes = await prefs.getCommuterRoutes();
    pp('$mm _getCommuterRoutes from prefs : ${commuterRoutes.length}');
    setState(() {});
    _getNearestRoutes();
    setState(() {
      busy = false;
    });
  }

  _navigateToCommuterRequest(String routeId, String routeName) async {
    await NavigationUtils.navigateTo(
        context: context,
        widget: CommuterRequestHandler(
          routeId: routeId,
          routeName: routeName,
        ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<FilteredRouteDistance> nearestRoutes = [];
  FilteredRouteDistance? filteredRouteDistance;
  double radiusInKM = 5;
  RouteUtil routeUtil = RouteUtil();
  bool _showRoutes = false;

  Future _getNearestRoutes() async {
    pp('.$mm  ............................. signInWithEmailAndPassword and _getNearestRoutes ... ');
    setState(() {
      busy = true;
    });
    try {
      var c = prefs.getCommuter();
      await auth.FirebaseAuth.instance
          .signInWithEmailAndPassword(email: c!.email!, password: c.password!);
      var loc = await dlb.getLocation();
      nearestRoutes = await routeUtil.getNearestRoutes();
    } catch (e, s) {
      pp('$mm $e $s');
      if (mounted) {
        showErrorToast(message: '$e', context: context);
      }
    }
    setState(() {
      busy = false;
    });
  }

  static const mm = '💙💙💙💙CommuterNearestRoutes 💙';
  FilteredRouteDistance? routeDistance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text(
            'Nearest Taxi Routes',
            style: myTextStyle(),
          ),
          actions: [
            IconButton(
                onPressed: () {
                  _getNearestRoutes();
                },
                icon: FaIcon(FontAwesomeIcons.arrowsRotate))
          ],
        ),
        body: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  gapH32,
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Text('Routes within $radiusInKM km',
                            style: myTextStyle(
                                color: Colors.grey,
                                fontSize: 16,
                                weight: FontWeight.w900)),
                        DropdownButton<int>(
                            dropdownColor: Colors.white,
                            items: [
                              DropdownMenuItem<int>(
                                value: 1,
                                child: Text('1 km'),
                              ),
                              DropdownMenuItem<int>(
                                value: 2,
                                child: Text('2 km'),
                              ),
                              DropdownMenuItem<int>(
                                value: 3,
                                child: Text('3 km'),
                              ),
                              DropdownMenuItem<int>(
                                value: 4,
                                child: Text('4 km'),
                              ),
                              DropdownMenuItem<int>(
                                value: 5,
                                child: Text('5 km'),
                              ),
                              DropdownMenuItem<int>(
                                value: 6,
                                child: Text('6 km'),
                              ),
                              DropdownMenuItem<int>(
                                value: 7,
                                child: Text('7 km'),
                              ),
                              DropdownMenuItem<int>(
                                value: 8,
                                child: Text('8 km'),
                              ),
                              DropdownMenuItem<int>(
                                value: 9,
                                child: Text('9 km'),
                              ),
                              DropdownMenuItem<int>(
                                value: 10,
                                child: Text('10 km'),
                              ),
                            ],
                            onChanged: (number) {
                              if (number != null) {
                                setState(() {
                                  radiusInKM = number.toDouble();
                                });
                                _getNearestRoutes();
                              }
                            }),
                        gapW16,
                        Text(
                          '$radiusInKM',
                          style: myTextStyle(
                              weight: FontWeight.w900,
                              fontSize: 20,
                              color: Colors.red),
                        )
                      ],
                    ),
                  ),
                  gapH32,
                  Expanded(
                      child: bd.Badge(
                    position: bd.BadgePosition.topEnd(top: -36, end: 20),
                    badgeContent: Text(
                      '${nearestRoutes.length}',
                      style: myTextStyle(color: Colors.white),
                    ),
                    badgeStyle: bd.BadgeStyle(
                        elevation: 8,
                        badgeColor: Colors.pink,
                        padding: EdgeInsets.all(16)),
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: ListView.builder(
                          itemCount: nearestRoutes.length,
                          itemBuilder: (ctx, index) {
                            var frd = nearestRoutes[index];
                            return GestureDetector(
                                onTap: () async {
                                  setState(() {
                                    filteredRouteDistance = frd;
                                  });

                                  await prefs.addCommuterRoute(frd.route);

                                  _navigateToCommuterRequest(
                                      frd.route.routeId!, frd.route.name!);
                                },
                                child: Card(
                                    elevation: 8, color: Colors.yellow.shade50,
                                    child: Column(
                                      children: [
                                        Padding(
                                            padding: EdgeInsets.all(20),
                                            child: Row(
                                              children: [
                                                SizedBox(
                                                    width: 20,
                                                    child: Text(
                                                      '${index + 1}',
                                                      style: myTextStyle(
                                                          color: Colors.blue,
                                                          fontSize: 12,
                                                          weight:
                                                              FontWeight.w900),
                                                    )),
                                                Flexible(
                                                  child: Text(frd.route.name!,
                                                      style: myTextStyle(
                                                          fontSize: 15,
                                                          weight: FontWeight
                                                              .normal)),
                                                ),
                                              ],
                                            )),
                                      ],
                                    )));
                          }),
                    ),
                  )),
                ],
              ),
              commuterRoutes.isEmpty
                  ? gapW32
                  : Positioned(
                      child: Center(
                          child: CommuterRoutes(routes: commuterRoutes, onSearch: () {
                            setState(() {
                              commuterRoutes.clear();
                            });
                           // _getNearestRoutes();
                          }, onSelected: (route ) async {
                            await prefs.addCommuterRoute(route);
                            _navigateToCommuterRequest(route.routeId!, route.name!);
                          },))),
              busy
                  ? Positioned(
                      child: Center(
                          child: TimerWidget(
                      title: 'Finding nearest taxi routes ..',
                      isSmallSize: true,
                    )))
                  : gapW32
            ],
          ),
        ));
  }
}

class CommuterRoutes extends StatelessWidget {
  const CommuterRoutes({super.key, required this.routes, required this.onSearch, required this.onSelected});
  final List<lib.Route> routes;
  final Function() onSearch;
  final Function(lib.Route) onSelected;

  @override
  Widget build(BuildContext context) {
    Prefs prefs = GetIt.instance<Prefs>();

    return Scaffold(
        body: SafeArea(
            child: Stack(
      children: [
        Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'Tap to select a previous route',
                  style: myTextStyle(fontSize: 18, weight: FontWeight.w900),
                ),
                gapH32,
                gapH32,
                SizedBox(
                  height: 400,
                  child: ListView.builder(
                      itemCount: routes.length,
                      itemBuilder: (ctx, index) {
                        var route = routes[index];
                        return GestureDetector(
                          onTap: () {
                            prefs.addCommuterRoute(route);
                            onSelected(route);
                          },
                          child: Card(
                            elevation: 8,
                            child: Padding(
                                padding: EdgeInsets.all(16),
                                child: InkWell(
                                  child: Text('${route.name}'),
                                  onTap: () {
                                    prefs.addCommuterRoute(route);
                                   onSelected(route);
                                  },
                                )),
                          ),
                        );
                      }),
                )
              ],
            )),
        Positioned(
            bottom: 24,
            right: 16,
            child: SizedBox(
              width: 300,
              child: ElevatedButton(
                  style: ButtonStyle(
                      backgroundColor: WidgetStatePropertyAll(Colors.grey),
                      elevation: WidgetStatePropertyAll(4)),
                  onPressed: () {
                    onSearch();
                  },
                  child: Text(
                    'Search Nearest Routes',
                    style: myTextStyle(color: Colors.white),
                  )),
            )),
      ],
    )));
  }
}

class FilteredRouteDistance {
  final lib.Route route;
  final double distance;
  final lib.Position position;

  FilteredRouteDistance(
      {required this.route, required this.distance, required this.position});
}
