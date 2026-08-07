import 'package:flutter/material.dart';

// This is a common utility for responsive UI in Flutter.
// It helps in scaling sizes based on the screen dimensions.

typedef ResponsiveBuild = Widget Function(
  BuildContext context,
  Orientation orientation,
  DeviceType deviceType,
);

class Sizer extends StatelessWidget {
  const Sizer({
    Key? key,
    required this.builder,
  }) : super(key: key);

  final ResponsiveBuild builder;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      return OrientationBuilder(builder: (context, orientation) {
        SizeUtils.setScreenSize(constraints, orientation);
        return builder(context, orientation, SizeUtils.deviceType);
      });
    });
  }
}

class SizeUtils {
  static late BoxConstraints boxConstraints;
  static late Orientation orientation;
  static late DeviceType deviceType;
  static late double height;
  static late double width;

  static void setScreenSize(
    BoxConstraints constraints,
    Orientation currentOrientation,
  ) {
    boxConstraints = constraints;
    orientation = currentOrientation;

    if (orientation == Orientation.portrait) {
      width = boxConstraints.maxWidth;
      height = boxConstraints.maxHeight;
    } else {
      width = boxConstraints.maxHeight;
      height = boxConstraints.maxWidth;
    }

    deviceType = DeviceType.mobile;
  }
}

enum DeviceType { mobile, tablet, desktop }

extension ResponsiveExtension on num {
  // Use proportional scaling based on a standard design size (e.g., 375x812)
  double get h => (this * SizeUtils.height) / 812;
  double get w => (this * SizeUtils.width) / 375;
  double get fSize => (this * (SizeUtils.width / 375));
}
