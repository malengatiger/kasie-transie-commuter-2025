import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get_it/get_it.dart';
import 'package:intl/intl.dart';
import 'package:kasie_transie_commuter_2025/ui/dashboard.dart';
import 'package:kasie_transie_commuter_2025/ui/response_widget.dart';
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

class CommuterRequestHandler extends StatefulWidget {
  const CommuterRequestHandler(
      {super.key, required this.filteredRouteDistance});

  final FilteredRouteDistance filteredRouteDistance;

  @override
  CommuterRequestHandlerState createState() => CommuterRequestHandlerState();
}

class CommuterRequestHandlerState extends State<CommuterRequestHandler>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  static const mm = '';
  DateFormat dateFormat = DateFormat.MMMMEEEEd();

  DataApiDog dataApiDog = GetIt.instance<DataApiDog>();
  ListApiDog listApiDog = GetIt.instance<ListApiDog>();
  Prefs prefs = GetIt.instance<Prefs>();
  DeviceLocationBloc dlb = GetIt.instance<DeviceLocationBloc>();
  FCMService fcm = GetIt.instance<FCMService>();

  FirebaseAuth firebaseAuth = FirebaseAuth.instance;
  FirebaseMessaging firebaseMessaging = FirebaseMessaging.instance;

  @override
  void initState() {
    _controller = AnimationController(vsync: this);
    super.initState();
    _getDate();
    _getRoute();
  }

  _getRoute() async {
    route = await listApiDog.getRoute(widget.filteredRouteDistance.routeId);
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
        setState(() {});
        _getTime();
      }
    }
  }

  _getTime() async {
    await Future.delayed(const Duration(milliseconds: 100));
    if (mounted) {
      timeOfDay =
          await showTimePicker(context: context, initialTime: TimeOfDay.now());
      pp('$mm timeOfDay: ${timeOfDay.toString}');
      setState(() {});
    }
  }

  bool busy = false;

  _submit() async {
    pp('$mm ... submit commuter request');
    setState(() {
      busy = true;
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
      var cr = lib.CommuterRequest(
          commuterId: commuter!.commuterId,
          commuterRequestId: Uuid().v4().toString(),
          routeId: widget.filteredRouteDistance.routeId,
          routeName: widget.filteredRouteDistance.routeName,
          dateRequested: DateTime.now().toUtc().toIso8601String(),
          associationId: route!.associationId!,
          dateNeeded: dateNeeded,
          fcmToken: fcmToken!,
          currentPosition: currentPosition,
          numberOfPassengers: numberOfPassengers);

      pp('$mm ..... submit commuter request: ${cr.toJson()}');

      var res = await dataApiDog.addCommuterRequest(cr);
      fcm.addCommuterRequest(cr);
      if (mounted) {
        showOKToast(
            message: 'Taxi request has been sent successfully',
            context: context);
      }
      if (mounted) {
        Navigator.of(context).pop();
        NavigationUtils.navigateTo(context: context, widget: ResponseWidget(
          commuterRequest: cr,));
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
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text('Route'),
              Padding(
                padding: EdgeInsets.all(16),
                child: Card(
                    elevation: 8,
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(widget.filteredRouteDistance.routeName,
                          style: myTextStyle(fontSize: 20)),
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
                          fontSize: 40,
                          color: Colors.grey),
                    ),
              gapH32,
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  gapW32,
                  const Text('Number of Passengers'),
                  gapW32,
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
              gapH32,
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 300,
                    child: ElevatedButton(
                      style: ButtonStyle(
                        elevation: WidgetStatePropertyAll(4),
                        backgroundColor: WidgetStatePropertyAll(Colors.grey),
                      ),
                      onPressed: () {
                        _getDate();
                      },
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'Set Request Date',
                          style: myTextStyle(fontSize: 16, color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              gapH32,
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 300,
                    child: ElevatedButton(
                      style: ButtonStyle(
                        elevation: WidgetStatePropertyAll(8),
                        backgroundColor: WidgetStatePropertyAll(Colors.blue),
                      ),
                      onPressed: () {
                        _submit();
                      },
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'Submit Taxi Request',
                          style: myTextStyle(fontSize: 20, color: Colors.white),
                        ),
                      ),
                    ),
                  )
                ],
              )
            ],
          ),
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
}
