import 'package:dots_indicator/dots_indicator.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:kasie_transie_library/auth/phone_auth_signin2.dart';
import 'package:kasie_transie_library/bloc/app_auth.dart';
import 'package:kasie_transie_library/bloc/data_api_dog.dart';
import 'package:kasie_transie_library/data/data_schemas.dart';
import 'package:kasie_transie_library/utils/emojis.dart';
import 'package:kasie_transie_library/utils/functions.dart';
import 'package:kasie_transie_library/utils/navigator_utils.dart';
import 'package:kasie_transie_library/utils/prefs.dart';
import 'package:kasie_transie_library/widgets/qrcodes/qr_code_generation.dart';
import 'package:uuid/uuid.dart';

import '../ui/dashboard.dart';
import 'intro_page_one.dart';

class KasieIntro extends StatefulWidget {
  const KasieIntro({
    super.key,
    // required this.listApiDog,
  });

  @override
  KasieIntroState createState() => KasieIntroState();
}

class KasieIntroState extends State<KasieIntro>
    with SingleTickerProviderStateMixin {
  final mm = '🍎🍎 KasieIntro 🍎🍎🍎🍎';
  late AnimationController _controller;
  bool authed = false;
  int currentIndexPage = 0;
  final PageController _pageController = PageController();
  fb.FirebaseAuth firebaseAuth = fb.FirebaseAuth.instance;
  Prefs prefs = GetIt.instance<Prefs>();
  final DataApiDog dataApiDog = GetIt.instance<DataApiDog>();
  AppAuth appAuth = GetIt.instance<AppAuth>();
  final QRGenerationService qrGeneration =
      GetIt.instance<QRGenerationService>();

  // mrm.User? user;
  String? signInFailed;
  Commuter? commuter;

  @override
  void initState() {
    _controller = AnimationController(vsync: this);
    super.initState();
    _getAuthenticationStatus();
  }

  void _getAuthenticationStatus() async {
    pp('\n\n$mm _getAuthenticationStatus ....... '
        'check both Firebase user and Kasie user');

    commuter = prefs.getCommuter();
    if (commuter != null ) {
      pp('$mm _getAuthenticationStatus .......  '
          '🥬🥬🥬auth is DEFINITELY authenticated and OK, will navigate to dashboard ...');
      authed = true;
      _navigateToDashboard();
    } else {
      pp('$mm _getAuthenticationStatus ....... NOT AUTHENTICATED! '
          '🌼🌼🌼 ... will clean house!!');
      authed = false;
      firebaseAuth.signOut();
      pp('$mm _getAuthenticationStatus .......  '
          '🔴🔴🔴🔴'
          'the device should be ready for sign in or registration');
    }
    pp('$mm ......... _getAuthenticationStatus ....... setting state, authed = $authed ');
    setState(() {});
  }

  _clearUser() async {
    await firebaseAuth.signOut();
    prefs.removeUser();
  }

  static const tag = 'commuter';
  static const pass = 'pass123';
 bool busy = false;
  onSignInWithEmail() async {
    pp('\n\n$mm ...  onSignInWithEmail, create and sign in commuter');
    var id = Uuid().v4().toString();
    var email = '${tag}_$id@$tag.com';
    setState(() {
      busy = true;
    });
    await firebaseAuth.createUserWithEmailAndPassword(
        email: email, password: pass);
    fb.UserCredential uc = await firebaseAuth.signInWithEmailAndPassword(
        email: email, password: pass);

    var token = await uc.user?.getIdToken();
    var c = Commuter(
        commuterId: uc.user?.uid,
        name: 'Commuter',
        countryId: null,
        dateRegistered: DateTime.now().toUtc().toIso8601String(),
        qrCodeUrl: null,
        email: email,
        fcmToken: token);


    try {
      var bucket = await qrGeneration.generateAndUploadQrCodeWithLogo(
          data: c.toJson(), associationId: null);
      c.qrCodeUrl = bucket?.qrCodeUrl;
      pp('$mm ...  onSignInWithEmail, commuter to create: ${c.toJson()}');
      var res = await dataApiDog.addCommuter(c);
      prefs.saveCommuter(res);
      pp('$mm ...  onSignInWithEmail, commuter: ${res.toJson()}');
      if (mounted) {
        showOKToast(message: 'Commuter signed in successfully. Welcome aboard!', context: context);
      }
      onSuccessfulSignIn();
    } catch (e, s) {
      pp('$mm $e $s');
    }
    setState(() {
      busy = false;
    });
  }

  onSignInWithPhone() async {
    pp('$mm ... onSignInWithPhone ....');
    _clearUser();
    NavigationUtils.navigateTo(
      context: context,
      widget: PhoneAuthSignin(
        onGoodSignIn: () {
          pp('$mm ................................'
              '... onGoodSignIn .... ');
          onSuccessfulSignIn();
        },
        onSignInError: () {
          pp('$mm ................................'
              '... onSignInError ${E.redDot} .... ');
          onFailedSignIn();
        },
      ),
    );
  }

  onRegister() {
    pp('$mm ... onRegister ....');
  }

  void onFailedSignIn() {
    pp('$mm ... onFailedSignIn ....');
  }

  void onSuccessfulSignIn() {
    pp('$mm ................................'
        '... onSuccessfulSignIn .... ');
    commuter = prefs.getCommuter();
    _navigateToDashboard();
  }

  void _onPageChanged(int value) {
    pp('$mm onPageChanged ... page: $value');
    setState(() {
      currentIndexPage = value;
    });
  }

  _navigateToDashboard() async {
    await Future.delayed(const Duration(milliseconds: 500));
    pp('$mm _navigateToMarshalDashboard ...');
    if (mounted) {
      NavigationUtils.navigateTo(
        context: context,
        widget: CommuterNearestRoutes(),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var brightness = MediaQuery.of(context).platformBrightness;
    bool isDarkMode = brightness == Brightness.dark;
    var color = getTextColorForBackground(Theme.of(context).primaryColor);

    if (isDarkMode) {
      color = Theme.of(context).primaryColor;
    }
    return SafeArea(
        child: Scaffold(
      appBar: AppBar(
        title: Text(
          'KasieTransie Commuter',
          style: myTextStyle(),
        ),
        bottom: PreferredSize(
            preferredSize: Size.fromHeight(authed ? 80 : 124),
            child: Column(
              children: [
                SizedBox(
                    width: 300,
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: ElevatedButton(
                         style: ButtonStyle(
                             elevation: WidgetStatePropertyAll(8),
                             backgroundColor: WidgetStatePropertyAll(Colors.blue)),
                          onPressed: () {
                            onSignInWithEmail();
                          },
                          child: Text(
                            'Sign In',
                            style: myTextStyle(fontSize: 20, color: Colors.white),
                          )),
                    )),
                gapH16,
              ],
            )),
      ),
      body: Stack(
        children: [
          PageView(
            controller: _pageController,
            onPageChanged: _onPageChanged,
            children: const [
              IntroPage(
                title: 'KasieTransie',
                assetPath: 'assets/intro/pic2.jpg',
                text: lorem,
              ),
              IntroPage(
                  title: 'Organizations',
                  assetPath: 'assets/intro/pic5.jpg',
                  text: lorem),
              IntroPage(
                  title: 'People',
                  assetPath: 'assets/intro/pic1.jpg',
                  text: lorem),
              IntroPage(
                title: 'Field Monitors',
                assetPath: 'assets/intro/pic5.jpg',
                text: lorem,
              ),
              IntroPage(
                title: 'Thank You',
                assetPath: 'assets/intro/pic3.webp',
                text: lorem,
              ),
            ],
          ),
          Positioned(
            bottom: 2,
            left: 48,
            right: 40,
            child: SizedBox(
              width: 200,
              height: 48,
              child: Card(
                color: Colors.black12,
                shape: getRoundedBorder(radius: 8),
                child: DotsIndicator(
                  dotsCount: 5,
                  position: currentIndexPage,
                  decorator: const DotsDecorator(
                    colors: [
                      Colors.grey,
                      Colors.grey,
                      Colors.grey,
                      Colors.grey,
                      Colors.grey,
                    ], // Inactive dot colors
                    activeColors: [
                      Colors.pink,
                      Colors.blue,
                      Colors.teal,
                      Colors.indigo,
                      Colors.deepOrange,
                    ], // Àctive dot colors
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ));
  }
}

class Header extends StatelessWidget {
  const Header(
      {super.key,
      required this.onSignInWithEmail,
      required this.onSignInWithPhone,
      required this.onRegister});

  final Function onSignInWithEmail, onSignInWithPhone, onRegister;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 8,
      child: DropdownButton<int>(
        hint: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'Please select the kind of sign in',
            style: myTextStyleMedium(context),
          ),
        ),
        items: const [
          DropdownMenuItem(
              value: 0,
              child: Row(
                children: [
                  Icon(Icons.phone),
                  SizedBox(
                    width: 20,
                  ),
                  Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text('Sign in with your phone'),
                  ),
                ],
              )),
          DropdownMenuItem(
              value: 1,
              child: Row(
                children: [
                  Icon(Icons.email),
                  SizedBox(
                    width: 20,
                  ),
                  Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text('Sign in with your email address'),
                  ),
                ],
              )),
          DropdownMenuItem(
              value: 2,
              child: Row(
                children: [
                  Icon(Icons.edit),
                  SizedBox(
                    width: 20,
                  ),
                  Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text('Register Your Association'),
                  ),
                ],
              )),
        ],
        onChanged: (index) {
          switch (index) {
            case 0:
              onSignInWithPhone();
              break;
            case 1:
              onSignInWithEmail();
              break;
            case 2:
              onRegister();
              break;
          }
        },
      ),
    );
  }
}