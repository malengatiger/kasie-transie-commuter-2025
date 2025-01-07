import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get_it/get_it.dart';
import 'package:intl/intl.dart';
import 'package:kasie_transie_library/bloc/data_api_dog.dart';
import 'package:kasie_transie_library/bloc/list_api_dog.dart';
import 'package:kasie_transie_library/data/data_schemas.dart' as lib;
import 'package:kasie_transie_library/maps/map_viewer.dart';
import 'package:kasie_transie_library/messaging/fcm_bloc.dart';
import 'package:kasie_transie_library/utils/device_location_bloc.dart';
import 'package:kasie_transie_library/utils/functions.dart';
import 'package:kasie_transie_library/utils/navigator_utils.dart';
import 'package:kasie_transie_library/utils/prefs.dart';
import 'package:kasie_transie_library/widgets/timer_widget.dart';
import 'package:uuid/uuid.dart';
import 'package:badges/badges.dart' as bd;

class CommuterRequestHandler extends StatefulWidget {
  const CommuterRequestHandler({
    super.key,
    required this.routeId,
    required this.routeName,
  });

  final String routeId, routeName;

  @override
  CommuterRequestHandlerState createState() => CommuterRequestHandlerState();
}

class CommuterRequestHandlerState extends State<CommuterRequestHandler>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  static const mm = '💜💜💜💜CommuterRequestHandler 💜';
  DateFormat dateFormat = DateFormat.MMMMEEEEd();
  DataApiDog dataApiDog = GetIt.instance<DataApiDog>();
  ListApiDog listApiDog = GetIt.instance<ListApiDog>();
  Prefs prefs = GetIt.instance<Prefs>();
  DeviceLocationBloc dlb = GetIt.instance<DeviceLocationBloc>();
  FCMService fcm = GetIt.instance<FCMService>();

  FirebaseAuth firebaseAuth = FirebaseAuth.instance;
  FirebaseMessaging firebaseMessaging = FirebaseMessaging.instance;

  late StreamSubscription<lib.DispatchRecord> dispatchSub;

  @override
  void initState() {
    _controller = AnimationController(vsync: this);
    super.initState();
    _listen();
    _getDate();
    _getRoute();
    _startTimer();
  }

  List<lib.DispatchRecord> dispatches = [];
  DateFormat df = DateFormat.MMMMEEEEd();

  _listen() {
    dispatchSub = fcm.dispatchStream.listen((dispatchRecord) {
      pp('\n\n$mm ... routeDispatchStream delivered: ${dispatchRecord.toJson()}');
      dispatches.add(dispatchRecord);
      _filterDispatchRecords(dispatches);
      if (mounted) {
        showToast(
            backgroundColor: Colors.blue.shade600,
            textStyle: myTextStyle(
                color: Colors.white, fontSize: 16, weight: FontWeight.w900),
            padding: 20,
            duration: const Duration(seconds: 5),
            toastGravity: ToastGravity.BOTTOM,
            message:
                'Taxi ${dispatchRecord.vehicleReg} has been dispatched at ${df.format(DateTime.parse(dispatchRecord.created!))} on the route you requested',
            context: context);
      }
    });
  }

  late Timer timer;

  _startTimer() {
    timer = Timer.periodic(const Duration(seconds: 60), (timer) {
      pp('$mm _filterDispatchRecords: Timer tick #${timer.tick} ');
      if (mounted) {
        _filterDispatchRecords(dispatches);
      }
    });
  }

  List<lib.DispatchRecord> _filterDispatchRecords(
      List<lib.DispatchRecord> dispatchRecords) {
    pp('$mm _filterDispatchRecords : ${dispatchRecords.length}');

    List<lib.DispatchRecord> filtered = [];
    DateTime now = DateTime.now().toUtc();
    for (var r in dispatchRecords) {
      var date = DateTime.parse(r.created!!);
      var difference = now.difference(date);
      pp('$mm _filterDispatchRecords difference: $difference');

      if (difference <= const Duration(hours: 1)) {
        filtered.add(r);
      }
    }
    pp('$mm _filterDispatchRecord filtered: ${filtered.length}');
    filtered.sort((a, b) => b.created!.compareTo(a.created!),);
    setState(() {
      dispatches = filtered;
      showRouteDispatches = true;
    });
    return filtered;
  }

  _getRoute() async {
    route = await listApiDog.getRoute(routeId: widget.routeId, refresh: false);
    pp('$mm route from routeId: ${route!.name}');
    myPrettyJsonPrint(route!.toJson());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  DateTime? dateTime;
  TimeOfDay? timeOfDay;
  int numberOfPassengers = 1;
  lib.Commuter? commuter;
  lib.Route? route;

  _getDate() async {
    commuter = prefs.getCommuter();
    await Future.delayed(const Duration(milliseconds: 100));
    if (mounted) {
      dateTime = await showDatePicker(
        context: context,
        firstDate: DateTime.now(),
        lastDate: DateTime.now().add(Duration(days: 7)),
        barrierDismissible: false,
      );
      if (dateTime != null) {
        pp('$mm ... date: ${dateTime!.toUtc().toIso8601String()}');
        _getTime();
        setState(() {
          showSubmit = true;
        });
      }
    }
  }

  _getTime() async {
    await Future.delayed(const Duration(milliseconds: 100));
    if (mounted) {
      timeOfDay = await showTimePicker(
          barrierDismissible: false,
          context: context,
          initialTime: TimeOfDay.now());

      pp('$mm timeOfDay: ${timeOfDay!.hour}:${timeOfDay!.minute} ${timeOfDay}');
      var dateNow = DateTime.now();
      var dateNeeded = mergeDateTimeAndTimeOfDay(dateTime!, timeOfDay!)
          .toUtc()
          .toIso8601String();
      var dn = DateTime.parse(dateNeeded);
      if (dateNow.isAfter(dn)) {
        if (mounted) {
          showErrorToast(
              message:
                  'Date and Time needed should be later than the request time now',
              context: context);
        }
        _getDate();
        return;
      }

      setState(() {});
    }
  }

  bool busy = false;
  lib.CommuterRequest? commuterRequest;
  bool showSubmit = false;

  _submit() async {
    pp('\n\n$mm ... submit commuter request');
    setState(() {
      busy = true;
      showSubmit = false;
    });
    try {
      final fcmToken = await FirebaseMessaging.instance.getToken();
      pp('$mm fcm messaging token: $fcmToken');
      var loc = await dlb.getLocation();
      var currentPosition = lib.Position(
        type: 'Point',
        coordinates: [loc.longitude, loc.latitude],
        latitude: loc.latitude,
        longitude: loc.longitude,
      );
      var dateNeeded = mergeDateTimeAndTimeOfDay(dateTime!, timeOfDay!)
          .toUtc()
          .toIso8601String();

      commuterRequest = lib.CommuterRequest(
          commuterId: commuter!.commuterId,
          commuterRequestId: Uuid().v4().toString(),
          routeId: widget.routeId,
          routeName: widget.routeName,
          dateRequested: DateTime.now().toUtc().toIso8601String(),
          associationId: route!.associationId!,
          dateNeeded: dateNeeded,
          fcmToken: fcmToken!,
          currentPosition: currentPosition,
          numberOfPassengers: numberOfPassengers);

      pp('$mm ..... submit commuter request, check associationId}');
      myPrettyJsonPrint(commuterRequest!.toJson());
      pp('$mm ..... subscribe to route dispatch stream... route!d: ${route!.routeId!}');

      await fcm.subscribeForRouteDispatch(
          "Dispatch", commuterRequest!.routeId!);

      var res = await dataApiDog.addCommuterRequest(commuterRequest!);
      fcm.addCommuterRequest(commuterRequest!);
      pp('$mm 🥬🥬🥬 CommuterRequest added to database and subscribed to route dispatch topic  🥬🥬🥬 route!d: ${route!.routeId!}');

      if (mounted) {
        showOKToast(
            toastGravity: ToastGravity.BOTTOM,
            message: 'Taxi request has been sent successfully',
            context: context);
      }
    } catch (e, s) {
      pp('$e $s');
      if (mounted) {
        showErrorToast(message: '$e', context: context);
      }
    }
    setState(() {
      busy = false;
    });
  }

  DateTime mergeDateTimeAndTimeOfDay(DateTime date, TimeOfDay time) {
    return DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text(
            'Commuter Request',
            style: myTextStyle(),
          ),
          actions: [
            IconButton(
                onPressed: () {
                  if (route != null) {
                    NavigationUtils.navigateTo(
                        context: context,
                        widget: MapViewer(
                          route: route!,
                        ));
                  }
                },
                icon: FaIcon(FontAwesomeIcons.mapLocation)),
          ]),
      body: SafeArea(
          child: Stack(
        children: [
          Column(
            // mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text('Route'),
              Padding(
                padding: EdgeInsets.all(16),
                child: Card(
                    elevation: 8,
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(widget.routeName,
                          style: myTextStyle(
                              fontSize: 16, weight: FontWeight.w900)),
                    )),
              ),
              gapH32,
              dateTime == null
                  ? gapW32
                  : Text(
                      dateFormat.format(dateTime!),
                      style: myTextStyle(weight: FontWeight.bold, fontSize: 28),
                    ),
              gapH32,
              timeOfDay == null
                  ? gapW32
                  : Text(
                      '${timeOfDay!.hour}:${timeOfDay!.minute}  ${timeOfDay!.period.name.toUpperCase()}',
                      style: myTextStyle(
                          weight: FontWeight.w900,
                          fontSize: 48,
                          color: Colors.grey),
                    ),
              gapH16,
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  gapW16,
                  const Text('Number of Passengers'),
                  gapW16,
                  DropdownButton<int>(
                      dropdownColor: Colors.white,
                      items: [
                        DropdownMenuItem<int>(value: 1, child: Text('1')),
                        DropdownMenuItem<int>(value: 2, child: Text('2')),
                        DropdownMenuItem<int>(value: 3, child: Text('3')),
                        DropdownMenuItem<int>(value: 4, child: Text('4')),
                        DropdownMenuItem<int>(value: 5, child: Text('5')),
                        DropdownMenuItem<int>(value: 6, child: Text('6')),
                        DropdownMenuItem<int>(value: 7, child: Text('7')),
                        DropdownMenuItem<int>(value: 8, child: Text('8')),
                        DropdownMenuItem<int>(value: 9, child: Text('9')),
                        DropdownMenuItem<int>(value: 10, child: Text('10')),
                        DropdownMenuItem<int>(value: 11, child: Text('11')),
                        DropdownMenuItem<int>(value: 12, child: Text('12')),
                        DropdownMenuItem<int>(value: 13, child: Text('13')),
                        DropdownMenuItem<int>(value: 14, child: Text('14')),
                        DropdownMenuItem<int>(value: 15, child: Text('15')),
                        DropdownMenuItem<int>(value: 16, child: Text('16')),
                        DropdownMenuItem<int>(value: 17, child: Text('17')),
                        DropdownMenuItem<int>(value: 18, child: Text('18')),
                        DropdownMenuItem<int>(value: 19, child: Text('19')),
                        DropdownMenuItem<int>(value: 20, child: Text('20')),
                      ],
                      onChanged: (number) {
                        setState(() {
                          if (number != null) {
                            numberOfPassengers = number;
                          }
                        });
                      }),
                  gapW32,
                  Text('$numberOfPassengers',
                      style: myTextStyle(
                          fontSize: 36,
                          weight: FontWeight.w900,
                          color: Colors.red)),
                  gapW32,
                ],
              ),
              gapH32,
              showSubmit
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 300,
                          child: ElevatedButton(
                            style: ButtonStyle(
                              elevation: WidgetStatePropertyAll(4),
                              backgroundColor:
                                  WidgetStatePropertyAll(Colors.grey),
                            ),
                            onPressed: () {
                              _getDate();
                            },
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: Text(
                                'Set Request Date',
                                style: myTextStyle(
                                    fontSize: 16, color: Colors.white),
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  : gapW32,
              gapH32,
              showSubmit
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 300,
                          child: ElevatedButton(
                            style: ButtonStyle(
                              elevation: WidgetStatePropertyAll(8),
                              backgroundColor:
                                  WidgetStatePropertyAll(Colors.blue),
                            ),
                            onPressed: () {
                              _submit();
                            },
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: Text(
                                'Submit Taxi Request',
                                style: myTextStyle(
                                    fontSize: 20, color: Colors.white),
                              ),
                            ),
                          ),
                        )
                      ],
                    )
                  : gapW32,
            ],
          ),
          showRouteDispatches
              ? Positioned(
                  bottom: 16,
                  right: 8,
                  left: 8,
                  child: Card(
                    elevation: 8,
                    child: Padding(
                      padding: EdgeInsets.all(8),
                      child: RouteDispatches(
                        dispatches: dispatches,
                      ),
                    ),
                  ))
              : gapW32,
          busy
              ? Positioned(
                  child: Center(
                      child: TimerWidget(
                  title: 'Requesting taxi ...',
                  isSmallSize: true,
                )))
              : gapH32,
        ],
      )),
    );
  }

  bool showRouteDispatches = false;
}

class RouteDispatches extends StatelessWidget {
  const RouteDispatches({super.key, required this.dispatches});

  final List<lib.DispatchRecord> dispatches;

  @override
  Widget build(BuildContext context) {
    final DateFormat df = DateFormat.Hm();

    return SizedBox(
        height: 400,
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Text(
                  'Taxis dispatched in the last hour',
                  style:
                      myTextStyle(color: Colors.blue, weight: FontWeight.w900),
                ),
                bd.Badge(
                  badgeContent: Text(
                    '${dispatches.length}',
                    style: myTextStyle(color: Colors.white),
                  ),
                  badgeStyle: bd.BadgeStyle(
                      badgeColor: Colors.green.shade800,
                      padding: EdgeInsets.all(16)),
                )
              ],
            ),
            Expanded(
              child: ListView.builder(
                  itemCount: dispatches.length,
                  itemBuilder: (ctx, index) {
                    var d = dispatches[index];
                    var date = df.format(DateTime.parse(d.created!).toLocal());
                    return Card(
                        elevation: 8,
                        child: Padding(
                          padding: EdgeInsets.all(8),
                          child: Row(
                            children: [
                              Text(
                                '${d.vehicleReg}',
                                style: myTextStyle(
                                    weight: FontWeight.w900, fontSize: 18),
                              ),
                              gapW8,
                              Text('Dispatched at'),
                              gapW16,
                              Text(
                                date,
                                style: myTextStyle(
                                    color: Colors.blue,
                                    weight: FontWeight.w900,
                                    fontSize: 18),
                              ),
                            ],
                          ),
                        ));
                  }),
            )
          ],
        ));
  }
}
