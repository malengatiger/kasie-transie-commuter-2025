import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kasie_transie_library/data/data_schemas.dart';
import 'package:kasie_transie_library/utils/functions.dart';

class ResponseWidget extends StatefulWidget {
  const ResponseWidget({super.key, required this.commuterRequest});

  final CommuterRequest commuterRequest;

  @override
  ResponseWidgetState createState() => ResponseWidgetState();
}

class ResponseWidgetState extends State<ResponseWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    _controller = AnimationController(vsync: this);
    super.initState();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String message = 'Awaiting response ...';

  String? timeToGo;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Commuter Request Response',
          style: myTextStyle(),
        ),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text('Awaiting response for taxi request'),
                gapH32,
                CommuterRequestWidget(commuterRequest: widget.commuterRequest),
                gapH32,
                ResponseCountdown(
                    date: DateTime.parse(widget.commuterRequest.dateNeeded!)),
                gapH32,
                Expanded(
                  child: Flexible(
                      child: Text(timeToGo == null ? message : timeToGo!)),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}

class ResponseCountdown extends StatefulWidget {
  const ResponseCountdown(
      {super.key,  required this.date});
  final DateTime date;
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

    return Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Row(mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(formatDuration(seconds), style: myTextStyle(
            color: Colors.red,
            fontSize: 28, weight: FontWeight.w900)),
        gapW16,
        Text('seconds remaining')
      ],
    ));
  }
  String formatDuration(int totalSeconds) {
    final minutes = (totalSeconds / 60).floor();
    final seconds = totalSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}

class CommuterRequestWidget extends StatelessWidget {
  const CommuterRequestWidget({super.key, required this.commuterRequest});

  final CommuterRequest commuterRequest;

  @override
  Widget build(BuildContext context) {
    final DateFormat df = DateFormat('EEEE, dd MMM yyyy HH:mm');

    return Padding(
        padding: EdgeInsets.all(16),
        child: Card(
          elevation: 8,
          child: SizedBox(
            height: 260,
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text('Commuter Taxi Request'),
                  gapH8,
                  Text(
                    commuterRequest.routeName!,
                    style: myTextStyle(fontSize: 20, weight: FontWeight.w900, color: Colors.grey),
                  ),
                  gapH8,
                  Text(df.format(DateTime.parse(commuterRequest.dateNeeded!)),
                  style: myTextStyle(weight: FontWeight.w900, fontSize: 20),),
                  gapH32,
                  Row(mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Passengers: '),
                      Text('${commuterRequest.numberOfPassengers!}',
                          style: myTextStyle(weight: FontWeight.w900, fontSize: 24)),
                    ],
                  )
                ],
              ),
            ),
          ),
        ));
  }
}
