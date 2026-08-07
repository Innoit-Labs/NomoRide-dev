import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../features/auth/presentation/screens/login_screen.dart';
import '../features/auth/presentation/screens/otp_screen.dart';
import '../features/auth/presentation/screens/splash_screen.dart';
import '../features/auth/presentation/screens/success_screen.dart';
import '../features/home/presentation/screens/main_container.dart';
import '../features/notifications/presentation/screens/notifications_screen.dart';
import '../features/orders/presentation/screens/delivery_success_screen.dart';
import '../features/orders/presentation/screens/order_details_screen.dart';
import '../features/orders/presentation/screens/orders_screen.dart';
import '../features/profile/presentation/screens/content_key_screen.dart';
import '../features/profile/data/content_keys.dart';
import '../features/profile/presentation/screens/bank_account_screen.dart';
import '../features/profile/presentation/screens/earnings_screen.dart';
import '../features/profile/presentation/screens/help_support_screen.dart';
import '../features/profile/presentation/screens/profile_screen.dart';
import '../features/registration/presentation/bloc/waitlist_cubit.dart';
import '../features/registration/presentation/screens/registration_screen.dart';
import '../features/registration/presentation/screens/rejected_screen.dart';
import '../features/registration/presentation/screens/success_screen.dart' as registration;
import '../features/registration/presentation/screens/welcome_screen.dart';







class AppRoutes {
  static const String splashScreen = '/splash_screen';
  static const String loginScreen = '/login_screen';
  static const String otpScreen = '/otp_screen';
  static const String successScreen = '/success_screen';
  static const String welcomeScreen = '/welcome_screen';
  static const String registrationScreen = '/registration_screen';
  static const String registrationSuccessScreen = '/registration_success_screen';
  static const String rejectedScreen = '/rejected_screen';
  static const String notificationsScreen = '/notifications_screen';







  static const String mainContainer = '/main_container';
  static const String orderDetailsScreen = '/order_details_screen';
  static const String deliverySuccessScreen = '/delivery_success_screen';
  static const String ordersScreen = '/orders_screen';
  static const String aboutUsScreen = '/about_us_screen';
  static const String privacyPolicyScreen = '/privacy_policy_screen';
  static const String helpSupportScreen = '/help_support_screen';
  static const String termsConditionsScreen = '/terms_conditions_screen';
  static const String profileScreen = '/profile_screen';
  static const String earningsScreen = '/earnings_screen';
  static const String editProfileScreen = '/edit_profile_screen';
  static const String bankAccountScreen = '/bank_account_screen';

  static const String initialRoute = splashScreen;

  static Map<String, WidgetBuilder> routes = {
  splashScreen: (context) => const SplashScreen(),
  loginScreen: (context) => const LoginScreen(),
  otpScreen: (context) => const OtpScreen(),
  successScreen: (context) => const SuccessScreen(),
  mainContainer: (context) => const MainContainer(),
  orderDetailsScreen: (context) => const OrderDetailsScreen(),
  deliverySuccessScreen: (context) => const DeliverySuccessScreen(),
  ordersScreen: (context) => const OrdersScreen(),
  aboutUsScreen: (context) => const ContentKeyScreen(
        contentKey: ContentKeys.aboutUs,
        title: 'About us',
      ),
  privacyPolicyScreen: (context) => const ContentKeyScreen(
        contentKey: ContentKeys.privacyPolicy,
        title: 'Privacy Policy',
      ),
  helpSupportScreen: (context) => const HelpSupportScreen(),
  termsConditionsScreen: (context) => const ContentKeyScreen(
        contentKey: ContentKeys.terms,
        title: 'Terms & Conditions',
      ),
  profileScreen: (context) => const ProfileScreen(),
  earningsScreen: (context) => const EarningsScreen(),
  editProfileScreen: (context) => const RegistrationScreen(isEditing: true),
  bankAccountScreen: (context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    final forWithdrawSetup =
        args is Map && args['forWithdrawSetup'] == true;
    return BankAccountScreen(forWithdrawSetup: forWithdrawSetup);
  },
  welcomeScreen: (context) => const WelcomeScreen(),
  registrationScreen: (context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    final restoreDraft = args is Map && args['restoreDraft'] == true;
    return RegistrationScreen(restoreDraft: restoreDraft);
  },
  registrationSuccessScreen: (context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) {
      final fromWaitlistCheck = args['fromWaitlistCheck'] == true;
      final underReview = args['underReview'] == true;
      final screen = registration.SuccessScreen(
        waitlisted: args['waitlisted'] == true,
        underReview: underReview,
        fromWaitlistCheck: fromWaitlistCheck,
        message: args['message'] as String?,
        waitlistNumber: args['waitlistNumber'] as String?,
        referenceId: args['referenceId'] as String?,
      );

      if (fromWaitlistCheck && underReview) {
        return BlocProvider(
          create: (_) => WaitlistCubit(),
          child: screen,
        );
      }
      return screen;
    }
    return const registration.SuccessScreen();
  },
  rejectedScreen: (context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) {
      final reasons = args['reasons'];
      return RejectedScreen(
        reasons: reasons is List<String> && reasons.isNotEmpty
            ? reasons
            : reasons is List
                ? reasons.map((item) => item.toString()).toList()
                : const ['Aadhar Verification Failed'],
        restoreDraft: args['restoreDraft'] == true,
      );
    }
    if (args is List<String> && args.isNotEmpty) {
      return RejectedScreen(reasons: args);
    }
    return const RejectedScreen();
  },
  notificationsScreen: (context) => const NotificationsScreen(),




};
}
