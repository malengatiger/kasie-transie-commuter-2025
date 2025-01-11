import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:kasie_transie_commuter_2025/ui/commuter_nearest_routes.dart';
import 'package:kasie_transie_commuter_2025/ui/find_routes_by_city.dart';
import 'package:kasie_transie_library/utils/functions.dart';
import 'package:kasie_transie_library/utils/navigator_utils.dart';
import 'package:kasie_transie_library/widgets/dash_widgets/generic.dart';

class CommuterDashboard extends StatefulWidget {
  const CommuterDashboard({super.key});

  @override
  CommuterDashboardState createState() => CommuterDashboardState();
}

class CommuterDashboardState extends State<CommuterDashboard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  static const mm = '🏀🏀🏀 CommuterDashboard 🏀 ';

  @override
  void initState() {
    _controller = AnimationController(vsync: this);
    super.initState();
    _getData();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  _getData() async {
    pp('$mm _getData');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: gapW32,
        title: Text('Commuter', style: myTextStyle(),),
      ),
      body: SafeArea(
          child: Stack(children: [
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
              gapH32, gapH32,
              Expanded(
                child: GridView(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2),
                  children: [
                    Card(
                      elevation: 8,
                      child: Center(
                        child: NumberAndCaption(
                          caption: "Requests",
                          number: 0,
                          fontSize: 28,
                        ),
                      ),
                    ),
                    Card(
                      elevation: 8,
                      child: Center(
                        child: NumberAndCaption(
                          caption: "Tickets",
                          number: 0,
                          fontSize: 28,
                        ),
                      ),
                    ),
                    Card(
                      elevation: 8,
                      child: Center(
                        child: NumberAndCaption(
                          caption: "Points",
                          number: 0,
                          fontSize: 28,
                        ),
                      ),
                    ),
                    Card(
                      elevation: 8,
                      child: Center(
                        child: NumberAndCaption(
                          caption: "PickUps",
                          number: 0,
                          fontSize: 28,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        )
      ])),
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
                  FontAwesomeIcons.magnifyingGlass, size: 36,
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
