import 'package:nomoride/core/services/waitlist_session.dart';
import 'package:nomoride/features/registration/data/models/waitlist_status.dart';
import 'package:nomoride/features/registration/data/models/waitlist_status_model.dart';
import 'package:nomoride/routes/app_routes.dart';

class WaitlistNavigation {
  WaitlistNavigation._();

  static String routeForStatus(WaitlistStatusModel model) {
    switch (model.status) {
      case WaitlistStatus.underReview:
        return AppRoutes.registrationSuccessScreen;
      case WaitlistStatus.approved:
        return AppRoutes.welcomeScreen;
      case WaitlistStatus.rejected:
        return AppRoutes.rejectedScreen;
      case WaitlistStatus.unknown:
        return AppRoutes.welcomeScreen;
    }
  }

  static Object? argumentsForStatus(WaitlistStatusModel model) {
    switch (model.status) {
      case WaitlistStatus.underReview:
        return {
          'waitlisted': false,
          'underReview': true,
          'fromWaitlistCheck': true,
          'message': model.message ??
              'Already submitted. Your request is under review.',
          'waitlistNumber': model.waitlistNumber ?? WaitlistSession.waitlistNumber,
          'referenceId': model.referenceId ?? WaitlistSession.referenceId,
        };
      case WaitlistStatus.approved:
        return null;
      case WaitlistStatus.rejected:
        final reasons = model.remarks.isNotEmpty
            ? model.remarks
            : [
                model.message?.trim().isNotEmpty == true
                    ? model.message!.trim()
                    : 'Verification request rejected.',
              ];
        return {
          'reasons': reasons,
          'restoreDraft': true,
        };
      case WaitlistStatus.unknown:
        return null;
    }
  }
}
