import 'package:flutter/material.dart';
import 'package:nomoride/core/network/session_guard.dart';
import 'package:nomoride/core/utils/size_utils.dart';
import 'package:nomoride/theme/theme_helper.dart';

enum SnackBarType {
  error,
  warning,
  success,
  info,
}

class CustomSnackBar {
  CustomSnackBar._();

  static void showError(
    BuildContext? context,
    String message, {
    String? title,
    Duration? duration,
  }) {
    show(
      context: context,
      message: message,
      title: title,
      type: SnackBarType.error,
      duration: duration,
    );
  }

  static void showWarning(
    BuildContext? context,
    String message, {
    String? title,
    Duration? duration,
  }) {
    show(
      context: context,
      message: message,
      title: title,
      type: SnackBarType.warning,
      duration: duration,
    );
  }

  static void showSuccess(
    BuildContext? context,
    String message, {
    String? title,
    Duration? duration,
  }) {
    show(
      context: context,
      message: message,
      title: title,
      type: SnackBarType.success,
      duration: duration,
    );
  }

  static void showInfo(
    BuildContext? context,
    String message, {
    String? title,
    Duration? duration,
  }) {
    show(
      context: context,
      message: message,
      title: title,
      type: SnackBarType.info,
      duration: duration,
    );
  }

  static void show({
    BuildContext? context,
    required String message,
    String? title,
    SnackBarType type = SnackBarType.info,
    Duration? duration,
  }) {
    final effectiveContext =
        context ?? SessionGuard.navigatorKey.currentContext;
    if (effectiveContext == null) return;

    final messenger = ScaffoldMessenger.maybeOf(effectiveContext);
    if (messenger == null) return;

    // Parse potential title from message if not provided
    String displayTitle = title ?? '';
    String displayBody = message.trim();

    if (displayTitle.isEmpty) {
      final colonIndex = displayBody.indexOf(':');
      if (colonIndex > 0 && colonIndex <= 30) {
        final candidate = displayBody.substring(0, colonIndex).trim();
        final lower = candidate.toLowerCase();
        if (lower.contains('blocked') ||
            lower.contains('error') ||
            lower.contains('warning') ||
            lower.contains('notice') ||
            lower.contains('failed') ||
            lower.contains('success') ||
            lower.contains('alert') ||
            lower.contains('dispatch')) {
          displayTitle = candidate;
          displayBody = displayBody.substring(colonIndex + 1).trim();
        }
      }
    }

    if (displayTitle.isEmpty) {
      switch (type) {
        case SnackBarType.error:
          displayTitle = 'Error';
          break;
        case SnackBarType.warning:
          displayTitle = 'Warning';
          break;
        case SnackBarType.success:
          displayTitle = 'Success';
          break;
        case SnackBarType.info:
          displayTitle = 'Notice';
          break;
      }
    }

    final accentColor = _getAccentColor(type);
    final iconData = _getIconData(type, displayTitle);

    final effectiveDuration = duration ??
        (displayBody.length > 60
            ? const Duration(seconds: 6)
            : const Duration(seconds: 4));

    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        behavior: SnackBarBehavior.floating,
        padding: EdgeInsets.zero,
        margin: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
        duration: effectiveDuration,
        content: Container(
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
          decoration: BoxDecoration(
            color: const Color(0xFF161622),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: accentColor.withValues(alpha: 0.65),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.85),
                blurRadius: 18,
                offset: const Offset(0, 5),
              ),
              BoxShadow(
                color: accentColor.withValues(alpha: 0.2),
                blurRadius: 12,
                spreadRadius: 0.5,
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon Badge
              Container(
                padding: EdgeInsets.all(7.w),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: accentColor.withValues(alpha: 0.4),
                  ),
                ),
                child: Icon(
                  iconData,
                  color: accentColor,
                  size: 18.fSize,
                ),
              ),
              SizedBox(width: 10.w),

              // Title & Message Content
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayTitle,
                      style: CustomTextStyles.openSansBold.copyWith(
                        fontSize: 13.fSize,
                        color: accentColor,
                        letterSpacing: 0.3,
                      ),
                    ),
                    SizedBox(height: 3.h),
                    Text(
                      displayBody,
                      style: CustomTextStyles.openSansMedium.copyWith(
                        fontSize: 12.fSize,
                        color: AppColours.secondary,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(width: 6.w),

              // Dismiss button
              GestureDetector(
                onTap: () {
                  messenger.hideCurrentSnackBar();
                },
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: EdgeInsets.only(top: 2.h, left: 4.w),
                  child: Icon(
                    Icons.close,
                    color: AppColours.grey,
                    size: 16.fSize,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Color _getAccentColor(SnackBarType type) {
    switch (type) {
      case SnackBarType.error:
        return const Color(0xFFFF5252);
      case SnackBarType.warning:
        return AppColours.primary;
      case SnackBarType.success:
        return AppColours.success;
      case SnackBarType.info:
        return AppColours.secondary;
    }
  }

  static IconData _getIconData(SnackBarType type, String title) {
    final lowerTitle = title.toLowerCase();
    if (lowerTitle.contains('blocked')) {
      return Icons.block_flipped;
    }

    switch (type) {
      case SnackBarType.error:
        return Icons.error_outline_rounded;
      case SnackBarType.warning:
        return Icons.warning_amber_rounded;
      case SnackBarType.success:
        return Icons.check_circle_outline_rounded;
      case SnackBarType.info:
        return Icons.info_outline_rounded;
    }
  }
}
