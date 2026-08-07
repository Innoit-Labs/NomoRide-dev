class OtpSession {
  const OtpSession({
    required this.mobileNumber,
    required this.userToken,
    required this.partnerId,
  });

  final String mobileNumber;
  final String userToken;
  final String partnerId;

  factory OtpSession.fromArguments(Object? arguments) {
    if (arguments is OtpSession) return arguments;
    if (arguments is Map) {
      return OtpSession(
        mobileNumber: arguments['mobileNumber']?.toString() ?? '',
        userToken: arguments['userToken']?.toString() ?? '',
        partnerId: arguments['partnerId']?.toString() ?? '',
      );
    }
    return const OtpSession(
      mobileNumber: '',
      userToken: '',
      partnerId: '',
    );
  }

  Map<String, String> toArguments() => {
        'mobileNumber': mobileNumber,
        'userToken': userToken,
        'partnerId': partnerId,
      };
}
