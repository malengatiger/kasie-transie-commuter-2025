import 'dart:collection';

import 'package:badges/badges.dart' as bd;
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get_it/get_it.dart';
import 'package:kasie_transie_commuter_2025/ui/commuter_request_handler.dart';
import 'package:kasie_transie_library/bloc/list_api_dog.dart';
import 'package:kasie_transie_library/data/data_schemas.dart' as lib;
import 'package:kasie_transie_library/utils/device_location_bloc.dart';
import 'package:kasie_transie_library/utils/functions.dart';
import 'package:kasie_transie_library/utils/navigator_utils.dart';
import 'package:kasie_transie_library/widgets/timer_widget.dart';
import 'package:kasie_transie_library/widgets/number_widget.dart';

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

  List<lib.Route> routes = [];
  bool busy = false;
  List<lib.RoutePoint>? routePoints = [];

  @override
  void initState() {
    _controller = AnimationController(vsync: this);
    super.initState();
    _getNearestRoutes();
  }

  _navigateToCommuterRequest() async {
    NavigationUtils.navigateTo(context: context,
        widget: CommuterRequestHandler(filteredRouteDistance: filteredRouteDistance!));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<FilteredRouteDistance> filteredRouteDistances = [];
  FilteredRouteDistance? filteredRouteDistance;
  double radiusInKM = 2;
  Future _getNearestRoutes() async {
    pp('... _getNearestRoutes ... ');

    setState(() {
      busy = true;
    });
    var loc = await dlb.getLocation();
    routePoints = await listApiDog.findRoutePointsByLocation(
        latitude: loc.latitude,
        longitude: loc.longitude,
        radiusInKM: radiusInKM);

    var distances = await dlb.getRoutePointDistances(routePoints: routePoints!);
    List<FilteredRouteDistance> frd = [];

    for (var bag in distances) {
      frd.add(FilteredRouteDistance(
          routeId: bag.routePoint.routeId!,
          routeName: bag.routePoint.routeName!,
          distance: bag.distance,
          position: bag.routePoint.position!));
    }
    pp('$mm ... filteredRouteDistances: ${frd.length} ');

    HashMap<String, FilteredRouteDistance> map = HashMap();
    for (var f in frd) {
      if (map[f.routeName] == null) {
        map[f.routeName] = f;
      }
    }
    filteredRouteDistances = map.values.toList();
    filteredRouteDistances.sort((a, b) => a.distance.compareTo(b.distance));
    pp('$mm ... filteredRouteDistances after re-filter: ${filteredRouteDistances.length} ');
    for (var f in filteredRouteDistances) {
      pp('$mm Route: ${f.distance} metres  🍎 ${f.routeName}');
    }
    setState(() {
      busy = false;
    });
  }

  static const mm = '💙💙💙💙Commuter Dashboard 💙';
  FilteredRouteDistance? routeDistance;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text(
            'Commuter Dashboard',
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
              filteredRouteDistances.isEmpty
                  ? Center(
                      child: const Text('There are no taxi routes within 5 km'),
                    )
                  : Column(
                      children: [
                        gapH32,
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Text('Routes within $radiusInKM km',
                                style: myTextStyle(
                                    fontSize: 20, weight: FontWeight.w900)),
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
                                ],
                                onChanged: (number) {
                                  if (number != null) {
                                    setState(() {
                                      radiusInKM = number.toDouble();
                                    });
                                    _getNearestRoutes();
                                  }
                                }),
                            Text(
                              '$radiusInKM',
                              style: myTextStyle(
                                  weight: FontWeight.w900, fontSize: 20, color: Colors.red),
                            )
                          ],
                        ),
                        gapH32,
                        gapH32,
                        Expanded(
                            child: bd.Badge(
                          position: bd.BadgePosition.topEnd(top: -48, end: 8),
                          badgeContent: Text(
                            '${filteredRouteDistances.length}',
                            style: myTextStyle(color: Colors.white),
                          ),
                          badgeStyle: bd.BadgeStyle(
                              elevation: 8,
                              badgeColor: Colors.green,
                              padding: EdgeInsets.all(16)),
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: ListView.builder(
                                itemCount: filteredRouteDistances.length,
                                itemBuilder: (ctx, index) {
                                  var frd = filteredRouteDistances[index];
                                  return GestureDetector(
                                    onTap: (){
                                      setState(() {
                                        filteredRouteDistance = frd;
                                      });
                                      _navigateToCommuterRequest();

                                    },
                                    child: Card(
                                        elevation: 8,
                                        child: Column(
                                          children: [
                                            Padding(
                                                padding: EdgeInsets.all(8),
                                                child: Row(
                                                  children: [
                                                    Flexible(
                                                      child: Text(frd.routeName,
                                                          style: myTextStyle(
                                                              fontSize: 16,
                                                              weight: FontWeight
                                                                  .normal)),
                                                    ),
                                                  ],
                                                )),
                                          ],
                                        ))
                                  );
                                }),
                          ),
                        )),
                      ],
                    ),
              busy
                  ? Positioned(
                      child: Center(
                          child: TimerWidget(
                      title: 'Finding nearest taxi routes ..',
                      isSmallSize: true,
                    )))
                  : gapW32,
            ],
          ),
        ));
  }
}

class FilteredRouteDistance {
  final String routeId, routeName;
  final double distance;
  final lib.Position position;

  FilteredRouteDistance(
      {required this.routeId,
      required this.routeName,
      required this.distance,
      required this.position});
}
