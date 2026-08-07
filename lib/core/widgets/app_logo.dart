import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import '../utils/image_constant.dart';

/// Renders the NOMORIDE brand logo.
///
/// SVG `<text>` is unreliable in flutter_svg, so typography is drawn with
/// Flutter while the icon/road artwork comes from [ImageConstant.imgLogoGraphic].
class AppLogo extends StatelessWidget {
  const AppLogo({
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
  });

  final double? width;
  final double? height;
  final BoxFit fit;

  static const Color _gold = Color(0xFFE5C179);

  static const double _viewWidth = 942.48;
  static const double _viewHeight = 554.4;

  @override
  Widget build(BuildContext context) {
    final logoWidth = width ?? 220;
    final logoHeight = height ?? logoWidth * (_viewHeight / _viewWidth);
    final scale = logoWidth / _viewWidth;

    final titleStyle = GoogleFonts.montserrat(
      fontSize: 152.76 * scale,
      fontWeight: FontWeight.w700,
      color: _gold,
      height: 1,
      letterSpacing: -1 * scale,
    );

    final taglineStyle = GoogleFonts.montserrat(
      fontSize: 56 * scale,
      fontWeight: FontWeight.w700,
      color: Colors.white,
      height: 1,
      letterSpacing: 2 * scale,
    );

    return SizedBox(
      width: logoWidth,
      height: logoHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: SvgPicture.asset(
              ImageConstant.imgLogoGraphic,
              fit: fit,
            ),
          ),
          Positioned(
            left: 0,
            top: logoHeight * 0.19,
            child: Text('NOM', style: titleStyle),
          ),
          Positioned(
            left: logoWidth * 0.66,
            top: logoHeight * 0.19,
            child: Text('RIDE', style: titleStyle),
          ),
          Positioned(
            left: logoWidth * 0.162,
            bottom: logoHeight * 0.025,
            child: Text(
              'MOBILITY    LOGISTICS',
              style: taglineStyle,
            ),
          ),
        ],
      ),
    );
  }
}
