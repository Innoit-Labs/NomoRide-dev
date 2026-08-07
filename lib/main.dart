import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nomoride/core/services/auth_session.dart';
import 'package:nomoride/core/services/waitlist_session.dart';
import 'package:nomoride/routes/app_routes.dart';
import 'package:nomoride/theme/theme_helper.dart';

import 'core/utils/size_utils.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  await AuthSession.restore();
  await WaitlistSession.restore();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Sizer(
      builder: (context, orientation, deviceType) {
        return MaterialApp(
          theme: ThemeHelper.themeDataData,
          title: 'nomowear',
          debugShowCheckedModeBanner: false,
          initialRoute: AppRoutes.initialRoute,
          routes: AppRoutes.routes,
        );
      },
    );
  }
}
