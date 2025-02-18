import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get_it/get_it.dart';
import 'package:kasie_transie_commuter_2025/ui/commuter_nearest_routes.dart';
import 'package:kasie_transie_commuter_2025/ui/find_routes_by_city.dart';
import 'package:kasie_transie_library/bloc/list_api_dog.dart';
import 'package:kasie_transie_library/data/data_schemas.dart';
import 'package:kasie_transie_library/utils/functions.dart';
import 'package:kasie_transie_library/utils/navigator_utils.dart';
import 'package:kasie_transie_library/utils/prefs.dart';
import 'package:kasie_transie_library/widgets/dash_widgets/generic.dart';
import 'package:kasie_transie_library/widgets/qrcodes/qr_code_viewer.dart';

class CommuterDashboard extends StatefulWidget {
  const CommuterDashboard({super.key});

  @override
  CommuterDashboardState createState() => CommuterDashboardState();
}

class CommuterDashboardState extends State<CommuterDashboard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  static const mm = '🏀🏀🏀 CommuterDashboard 🏀 ';
  Prefs prefs = GetIt.instance<Prefs>();

  @override
  void initState() {
    _controller = AnimationController(vsync: this);
    super.initState();
    _getCommuter();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  _getCommuter() async {
    pp('$mm _getData');
    commuter = prefs.getCommuter();
    pp('$mm commuter:');
    myPrettyJsonPrint(commuter!.toJson());
    var creds = await auth.FirebaseAuth.instance.signInWithEmailAndPassword(
        email: commuter!.email!, password: commuter!.password!);
    if (creds.user != null) {
      pp('$mm commuter signed in: ${creds.user!.uid}');
    }
    _getCommuterData();
    setState(() {});
  }

  ListApiDog listApiDog = GetIt.instance<ListApiDog>();
  List<CommuterRequest> requests = [];
  bool busy = false;
  _getCommuterData() async {
    setState(() {
      busy = true;
    });

    requests = await listApiDog.getCommuterRequestsFromBackend(commuter!.commuterId!);

    setState(() {
      busy = false;
    });
  }
  _navigateToFindByCity() {
    pp('$mm _navigateToFindByCity');
    NavigationUtils.navigateTo(context: context, widget: FindRoutesByCity());
  }

  _navigateToNearestSearch() {
    pp('$mm _navigateToNearestSearch');
    NavigationUtils.navigateTo(
        context: context, widget: CommuterNearestRoutes());
  }

  bool showQRCode = false;
  Commuter? commuter;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: gapW32,
        title: Text(
          'Commuter',
          style: myTextStyle(),
        ),
        actions: [
          IconButton(
              onPressed: () {
                setState(() {
                  showQRCode = !showQRCode;
                });
              },
              icon: FaIcon(
                FontAwesomeIcons.qrcode,
                size: 24,
                color: Colors.blue,
              ))
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  gapH16,
                  gapH32,
                  Text(
                    'Commuter Dashboard',
                    style: myTextStyle(fontSize: 24, weight: FontWeight.w900),
                  ),
                  gapH32,
                  gapH32,
                  Expanded(
                    child: GridView(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2),
                      children: [
                        Card(
                          elevation: 2,
                          child: Center(
                            child: NumberAndCaption(
                              caption: "Requests",
                              number: requests.length,
                              fontSize: 18,
                            ),
                          ),
                        ),
                        Card(
                          elevation: 2,
                          child: Center(
                            child: NumberAndCaption(
                              caption: "Tickets", color: Colors.black,
                              number: 0,
                              fontSize: 18,
                            ),
                          ),
                        ),
                        Card(
                          elevation: 2,
                          child: Center(
                            child: NumberAndCaption(
                              caption: "Points",
                              number: 0, color: Colors.blue,
                              fontSize: 18,
                            ),
                          ),
                        ),
                        Card(
                          elevation: 2,
                          child: Center(
                            child: NumberAndCaption(
                              caption: "PickUps",
                              number: 0,
                              color: Colors.green,
                              fontSize: 18,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            showQRCode
                ? Positioned(
                    child: Center(
                        child: Column(
                      children: [
                        Text(
                          'Commuter QR Code',
                          style: myTextStyle(
                              weight: FontWeight.w900, fontSize: 24),
                        ),
                        gapH32,
                        Expanded(
                          child: QrCodeViewer(
                            qrCodeUrl: commuter!.qrCodeUrl!,
                          ),
                        )
                      ],
                    )),
                  )
                : gapW32,
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
          backgroundColor: Colors.white,
          elevation: 8,
          iconSize: 24,
          onTap: (index) {
            switch (index) {
              case 0:
                _navigateToFindByCity();
                break;
              case 1:
                _navigateToNearestSearch();
                break;
            }
          },
          items: [
            BottomNavigationBarItem(
                tooltip: 'Find Taxi Routes by City',
                icon: FaIcon(
                  FontAwesomeIcons.magnifyingGlass,
                  size: 36,
                  color: Colors.blue,
                ),
                label: 'Search Routes By City'),
            BottomNavigationBarItem(
                tooltip: 'Find Nearest Routes',
                icon: FaIcon(FontAwesomeIcons.locationCrosshairs,
                    color: Colors.red, size: 36),
                label: 'Find Nearest Routes'),
          ]),
    );
  }
}
