import 'dart:async';
import 'dart:collection';

import 'package:badges/badges.dart' as bd;
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get_it/get_it.dart';
import 'package:intl/intl.dart';
import 'package:kasie_transie_library/bloc/list_api_dog.dart';
import 'package:kasie_transie_library/data/data_schemas.dart' as lib;
import 'package:kasie_transie_library/maps/map_viewer.dart';
import 'package:kasie_transie_library/messaging/fcm_bloc.dart';
import 'package:kasie_transie_library/utils/functions.dart';
import 'package:kasie_transie_library/utils/navigator_utils.dart';

class CommuterRouteDispatchMonitor extends StatefulWidget {
  const CommuterRouteDispatchMonitor(
      {super.key,
      required this.commuterRequest,
      required this.onDispatchRecordSelected,
       this.dispatchRecord});

  final lib.CommuterRequest commuterRequest;
  final lib.DispatchRecord? dispatchRecord;

  final Function(lib.DispatchRecord) onDispatchRecordSelected;

  @override
  State<CommuterRouteDispatchMonitor> createState() =>
      _CommuterRouteDispatchMonitorState();
}

class _CommuterRouteDispatchMonitorState
    extends State<CommuterRouteDispatchMonitor> {
   List<lib.DispatchRecord> dispatchRecords = [];

  ListApiDog listApiDog = GetIt.instance<ListApiDog>();

  FCMService fcmService = GetIt.instance<FCMService>();
  late StreamSubscription<lib.CommuterResponse> _commuterResponseSubscription;
  late StreamSubscription<lib.DispatchRecord> _dispatchRecordSubscription;
  String? initialResponse;
  static const mm = '🌺🌺🌺🌺CommuterRouteDispatchMonitor 🌺';

  @override
  void initState() {
    super.initState();
    if (widget.dispatchRecord != null) {
      dispatchRecords.add(widget.dispatchRecord!);
    }
    _listen();
    _getLatestDispatches();
  }

  bool busy = false;
  _getLatestDispatches() async {
    setState(() {
      busy = true;
    });
    try {
      var date = DateTime.now().toUtc().subtract(const Duration(hours: 1));
      dispatchRecords = await listApiDog.getRouteDispatchRecords(routeId: widget.commuterRequest.routeId!,
               startDate: date.toIso8601String());

      dispatchRecords.sort((a,b) => b.created!.compareTo(a.created!));
      HashMap<String, lib.DispatchRecord> hash = HashMap();
     for (var dr in dispatchRecords) {
       if (hash[dr.vehicleId] == null) {
         hash[dr.vehicleId!] = dr;
       }
     }
     dispatchRecords = hash.values.toList();
     dispatchRecords.sort((a,b) => b.created!.compareTo(a.created!));
    } catch (e, s) {
      pp('$e $s');
    }
    setState(() {
      busy = false;
    });
  }

  _listen() async {
    _commuterResponseSubscription =
        fcmService.commuterResponseStreamStream.listen((response) {
      pp('$mm ... commuterResponseStreamStream: ${response.toJson()}');
      initialResponse = response.message;
      if (mounted) {
        setState(() {});
      }
    });
    _dispatchRecordSubscription =
        fcmService.dispatchStream.listen((dispatchRecord) {
      pp('\n\n\n$mm ... dispatchStream: ${dispatchRecord.toJson()}');
      if (dispatchRecord.routeId == widget.commuterRequest.routeId) {
        pp('$mm a car ${dispatchRecord.vehicleReg} has been dispatched on your route: ${dispatchRecord.routeName}\n\n');
        dispatchRecords.add(dispatchRecord);
        dispatchRecords.sort((a, b) => b.created!.compareTo(a.created!));
        if (mounted) {
          setState(() {});
        }
      }
    });

    _commuterResponseSubscription.resume();
    _dispatchRecordSubscription.resume();
    await Future.delayed(const Duration(milliseconds: 200));
    if (mounted) {
      showOKToast(
          toastGravity: ToastGravity.BOTTOM,
          message: 'Monitoring route ${widget.commuterRequest.routeName}',
          context: context);
    }
  }

  ListApiDog listApi = GetIt.instance<ListApiDog>();

  _navigateToMap() async {
    var route = await listApi.getRoute(routeId: widget.commuterRequest.routeId!, refresh: false);
    if (route != null) {
      pp('$mm _navigateToMap: ...route from routeId: ${route.name}');

      if (mounted) {
        NavigationUtils.navigateTo(
            context: context,
            widget: MapViewer(
              route: route,
              refresh: true,
            ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    var df = DateFormat('dd MMMM yyyy HH:mm');
    var dateReq = DateTime.parse(widget.commuterRequest.dateRequested!);
    var dateNed = DateTime.parse(widget.commuterRequest.dateNeeded!);

    return Scaffold(
        appBar: AppBar(
          title: Text(
            'Taxi Dispatch Monitor',
            style: myTextStyle(),
          ),
          actions: [
            IconButton(
                onPressed: () {
                  _navigateToMap();
                },
                icon: FaIcon(FontAwesomeIcons.mapLocation))
          ],
        ),
        body: SafeArea(
            child: Stack(
          children: [
            Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    'Commuter Request',
                    style: myTextStyle(weight: FontWeight.w900),
                  ),
                  gapH32,
                  Row(
                    children: [
                      SizedBox(
                        width: 100,
                        child: Text(
                          'Requested on',
                          style: myTextStyle(
                              color: Colors.grey, weight: FontWeight.w900),
                        ),
                      ),
                      gapW16,
                      Text(df.format(dateReq)),
                    ],
                  ),
                  gapH8,
                  Row(
                    children: [
                      SizedBox(
                        width: 100,
                        child: Text(
                          'Needed on',
                          style: myTextStyle(
                              color: Colors.grey, weight: FontWeight.w900),
                        ),
                      ),
                      gapW16,
                      Text(df.format(dateNed)),
                    ],
                  ),
                  gapH32,
                  Row(
                    children: [
                      SizedBox(
                        width: 160,
                        child: Text('Number of Passengers',
                            style: myTextStyle(
                                color: Colors.grey, weight: FontWeight.w900)),
                      ),
                      gapW16,
                      Text(
                        '${widget.commuterRequest.numberOfPassengers}',
                        style: myTextStyle(
                            weight: FontWeight.w900,
                            fontSize: 24,
                            color: Colors.pink),
                      ),
                    ],
                  ),
                  gapH32,
                  SizedBox(
                      height: 100,
                      child: Column(
                        children: [
                          Text('Taxis dispatched on requested route',
                              style: myTextStyle(fontSize: 17,
                                  color: Colors.grey, weight: FontWeight.w400)),
                          gapH8,
                          Flexible(
                            child: Text('${widget.commuterRequest.routeName}',
                                style: myTextStyle(
                                    color: Colors.blue, fontSize: 18,
                                    weight: FontWeight.w900)),
                          ),
                        ],
                      )),
                  Expanded(
                    child: bd.Badge(
                      badgeContent: Text(
                        '${dispatchRecords.length}',
                        style: myTextStyle(color: Colors.white),
                      ),
                      position: bd.BadgePosition.topEnd(top: -28, end: 8),
                      badgeStyle: bd.BadgeStyle(
                          elevation: 12,
                          padding: const EdgeInsets.all(16),
                          badgeColor: Colors.blue[700]!),
                      child: ListView.builder(
                          itemCount: dispatchRecords.length,
                          itemBuilder: (ctx, index) {
                            final rl = dispatchRecords.elementAt(index);
                            var date = DateTime.parse(rl.created!).toLocal();

                            return GestureDetector(
                              onTap: () {
                                widget.onDispatchRecordSelected(rl);
                                showToast(
                                    toastGravity: ToastGravity.BOTTOM,
                                    textStyle: myTextStyle(color: Colors.white),
                                    backgroundColor: Colors.pink,
                                    message: 'Pick Up under construction. Be here soon!', context: context);
                              },
                              child: Card(
                                  elevation: 8,
                                  child: Padding(
                                    padding: EdgeInsets.all(16),
                                    child: Row(
                                      children: [
                                        SizedBox(
                                          width: 24,
                                          child: Text('${index + 1}',
                                              style: myTextStyle(
                                                  weight: FontWeight.w900,
                                                  fontSize: 12)),
                                        ),
                                        Text(rl.vehicleReg!,
                                            style: myTextStyle(
                                                weight: FontWeight.w900,
                                                fontSize: 16,
                                                color: Colors.green)),
                                        gapW16,
                                        Text(df.format(date),
                                            style: myTextStyle(
                                                weight: FontWeight.w400,
                                                fontSize: 12)),
                                      ],
                                    ),
                                  )),
                            );
                          }),
                    ),
                  ),
                ],
              ),
            )
          ],
        )));
  }
}
