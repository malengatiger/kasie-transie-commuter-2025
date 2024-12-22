import 'dart:async';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get_it/get_it.dart';
import 'package:intl/intl.dart';
import 'package:kasie_transie_library/bloc/list_api_dog.dart';
import 'package:kasie_transie_library/data/data_schemas.dart';
import 'package:kasie_transie_library/maps/map_viewer.dart';
import 'package:kasie_transie_library/messaging/fcm_bloc.dart';
import 'package:kasie_transie_library/utils/functions.dart';
import 'package:kasie_transie_library/utils/navigator_utils.dart';

import 'commuter_route_dispatches.dart';

class ResponseWidget extends StatefulWidget {
  const ResponseWidget({super.key, required this.commuterRequest});

  final CommuterRequest commuterRequest;

  @override
  ResponseWidgetState createState() => ResponseWidgetState();
}

class ResponseWidgetState extends State<ResponseWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  FCMService fcmService = GetIt.instance<FCMService>();
  late StreamSubscription<CommuterResponse> _commuterResponseSubscription;
  late StreamSubscription<DispatchRecord> _dispatchRecordSubscription;

  static const mm = '😎😎😎😎 ResponseWidget 😎';

  @override
  void initState() {
    _controller = AnimationController(vsync: this);
    super.initState();
    _listen();
  }

  String? initialResponse;
  List<DispatchRecord> dispatchRecords = [];

  _listen() {
    _commuterResponseSubscription =
        fcmService.commuterResponseStreamStream.listen((response) {
      pp('$mm ... commuterResponseStreamStream: ${response.toJson()}');
      initialResponse = response.message;
      if (mounted) {
        setState(() {});
      }
    });

    _dispatchRecordSubscription =
        fcmService.dispatchStream.listen((dRec) {
      pp('\n\n\n$mm ... dispatchStream: ${dRec.toJson()}');
      if (dRec.routeId == widget.commuterRequest.routeId) {
        pp('$mm a car ${dRec.vehicleReg} has been dispatched on your route: ${dRec.routeName}\n\n');
        if (mounted) {
          dispatchRecord = dRec;
          _navigateToCommuterRouteDispatchMonitor();
        }
        _dispatchRecordSubscription.cancel();
      }
    });
    _commuterResponseSubscription.resume();
    _dispatchRecordSubscription.resume();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String message = 'Awaiting response ...';

  String? timeToGo;

  DispatchRecord? dispatchRecord;

  _navigateToCommuterRouteDispatchMonitor() async {
      NavigationUtils.navigateTo(
          context: context,
          widget: CommuterRouteDispatchMonitor(
            dispatchRecord: dispatchRecord,
            onDispatchRecordSelected: (dRec) {},
            commuterRequest: widget.commuterRequest,
          ));

  }

  ListApiDog listApiDog = GetIt.instance<ListApiDog>();

  @override
  Widget build(BuildContext context) {
    var df = DateFormat('dd MMMM yyyy HH:mm');
    return Scaffold(
      appBar: AppBar(
          title: Text(
            'Commuter Request Response',
            style: myTextStyle(),
          ),
          actions: [
            IconButton(
                onPressed: () async {
                  var route = await listApiDog.getRoute(
                      routeId: widget.commuterRequest.routeId!, refresh: false);
                  if (route != null) {
                    if (mounted) {
                      NavigationUtils.navigateTo(
                          context: context,
                          widget: MapViewer(
                            route: route,
                          ));
                    }
                  }
                },
                icon: FaIcon(FontAwesomeIcons.mapLocation)),
          ]),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              // mainAxisAlignment: MainAxisAlignment.center,
              // crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                CommuterRequestWidget(commuterRequest: widget.commuterRequest),
                gapH32,
                ResponseCountdown(
                  date: DateTime.parse(widget.commuterRequest.dateNeeded!),
                  onDateError: () {
                    showErrorToast(
                        message:
                            'Date and Time should be later than the request',
                        context: context);
                  },
                ),
                gapH32,
                initialResponse == null
                    ? gapH32
                    : Flexible(
                        child: Text(
                        initialResponse!,
                        style:
                            myTextStyle(weight: FontWeight.w400, fontSize: 14),
                      )),
              ],
            ),
            Positioned(
              bottom: 16,
              right: 16,
              child: ElevatedButton(
                  style: ButtonStyle(
                    backgroundColor: WidgetStatePropertyAll(Colors.blue),
                    elevation: WidgetStatePropertyAll(8),
                    padding: WidgetStatePropertyAll(EdgeInsets.all(16)),
                  ),
                  onPressed: () {
                    _navigateToCommuterRouteDispatchMonitor();
                  },
                  child: Padding(
                      padding: EdgeInsets.all(0),
                      child: Text(
                        'Monitor Route Taxis',
                        style: myTextStyle(color: Colors.white),
                      ))),
            )
          ],
        ),
      ),
    );
  }
}

class ResponseCountdown extends StatefulWidget {
  const ResponseCountdown(
      {super.key, required this.date, required this.onDateError});

  final DateTime date;
  final Function() onDateError;

  @override
  State<ResponseCountdown> createState() => _ResponseCountdownState();
}

class _ResponseCountdownState extends State<ResponseCountdown> {
  late Timer timer;

  @override
  void initState() {
    super.initState();
    _start();
  }

  int seconds = 0;

  _start() async {
    var diff = widget.date.difference(DateTime.now());
    if (diff.inSeconds < 0) {
      widget.onDateError();
      return;
    }
    timer = Timer.periodic(Duration(seconds: 1), (timer) {
      var res = diff.inSeconds - timer.tick;
      if (res <= 0) {
        timer.cancel();
      }
      setState(() {
        seconds = res;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(formatDuration(seconds),
                style: myTextStyle(
                    color: Colors.red, fontSize: 28, weight: FontWeight.w900)),
            gapW16,
            Text(' remaining')
          ],
        ));
  }

  String formatDuration(int totalSeconds) {
    final hours = (totalSeconds / 3600).floor();
    final minutes = ((totalSeconds % 3600) / 60).floor();
    final seconds = totalSeconds % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}

class CommuterRequestWidget extends StatelessWidget {
  const CommuterRequestWidget({super.key, required this.commuterRequest});

  final CommuterRequest commuterRequest;

  @override
  Widget build(BuildContext context) {
    final DateFormat df = DateFormat('EEEE, dd MMM yyyy HH:mm');
    final date = DateTime.parse(commuterRequest.dateNeeded!).toLocal();
    return Padding(
        padding: EdgeInsets.all(16),
        child: Card(
          elevation: 8,
          child: SizedBox(
            height: 400,
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text('Commuter Taxi Request'),
                  gapH32,
                  Text(
                    commuterRequest.routeName!,
                    style: myTextStyle(
                        fontSize: 20,
                        weight: FontWeight.w900,
                        color: Colors.grey),
                  ),
                  gapH32,
                  Text(
                    df.format(date),
                    style: myTextStyle(weight: FontWeight.w900, fontSize: 20),
                  ),
                  gapH32,
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Passengers: '),
                      Text('${commuterRequest.numberOfPassengers!}',
                          style: myTextStyle(
                              weight: FontWeight.w900, fontSize: 24)),
                    ],
                  )
                ],
              ),
            ),
          ),
        ));
  }
}
