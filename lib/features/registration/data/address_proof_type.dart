class AddressProofOption {
  const AddressProofOption({
    required this.label,
    required this.apiValue,
  });

  final String label;
  final String apiValue;
}

class AddressProofTypes {
  AddressProofTypes._();

  static const options = [
    AddressProofOption(label: 'Aadhar Card', apiValue: 'aadhar_card'),
    AddressProofOption(label: 'Voter ID', apiValue: 'voterId'),
    AddressProofOption(label: 'Pan Card', apiValue: 'panCard'),
  ];

  static String labelFor(String apiValue) {
    for (final option in options) {
      if (option.apiValue == apiValue) return option.label;
    }
    return apiValue;
  }
}
