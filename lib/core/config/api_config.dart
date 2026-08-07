class ApiConfig {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://nomowear-backend.onrender.com',
  );

  static const String _mobileDeliveryPartners = '/mobile/v1/delivery_partners';

  static Uri get createDeliveryPartnerUri =>
      Uri.parse('$baseUrl$_mobileDeliveryPartners');

  static Uri get loginUri =>
      Uri.parse('$baseUrl$_mobileDeliveryPartners/login');

  static Uri get verifyOtpUri =>
      Uri.parse('$baseUrl$_mobileDeliveryPartners/verify-otp');

  static Uri get resendOtpUri =>
      Uri.parse('$baseUrl$_mobileDeliveryPartners/resend-otp');

  static Uri get dashboardUri =>
      Uri.parse('$baseUrl$_mobileDeliveryPartners/getDashboardData');

  static Uri get dpOrdersUri =>
      Uri.parse('$baseUrl$_mobileDeliveryPartners/getDpOrders');

  static Uri get orderStatusUpdateUri =>
      Uri.parse('$baseUrl/mobile/v1/delivery_partners/order-status-update');

  static Uri get uploadUri => Uri.parse('$baseUrl/upload');

  static Uri get earningsUri =>
      Uri.parse('$baseUrl$_mobileDeliveryPartners/earnings');

  static Uri get withdrawalRequestsUri =>
      Uri.parse('$baseUrl$_mobileDeliveryPartners/withdrawal-requests');

  static Uri get profileUri =>
      Uri.parse('$baseUrl$_mobileDeliveryPartners/profile');

  static Uri get updateProfileUri =>
      Uri.parse('$baseUrl$_mobileDeliveryPartners/updateProfile');

  static Uri get updateBankAccountDetailsUri =>
      Uri.parse('$baseUrl$_mobileDeliveryPartners/updateBankAccountDetails');

  static Uri get myOrdersUri =>
      Uri.parse('$baseUrl$_mobileDeliveryPartners/myorders');

  static Uri contentKeyUri(String policyKey) =>
      Uri.parse('$baseUrl/policies/key/${Uri.encodeComponent(policyKey.trim())}');

  static Uri waitlistStatusUri(String idOrNumber) => Uri.parse(
        '$baseUrl/waitlist/status/${Uri.encodeComponent(idOrNumber.trim())}',
      );

  static Uri waitlistReuploadUri(String idOrNumber) => Uri.parse(
        '$baseUrl/waitlist/reupload/${Uri.encodeComponent(idOrNumber.trim())}',
      );

  static Uri get deleteAccountUri =>
      Uri.parse('$baseUrl/mobile/v1/delete-account');
}
