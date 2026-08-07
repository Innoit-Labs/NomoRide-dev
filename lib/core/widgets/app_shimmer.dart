import 'package:flutter/material.dart';
import 'package:nomoride/core/utils/size_utils.dart';
import 'package:nomoride/theme/theme_helper.dart';
import 'package:shimmer/shimmer.dart';

class AppShimmer {
  AppShimmer._();

  static Widget wrap({required Widget child}) {
    return Shimmer.fromColors(
      baseColor: const Color(0xFF1A1A1A),
      highlightColor: AppColours.primary.withValues(alpha: 0.18),
      child: child,
    );
  }

  static Widget box({
    double? width,
    double? height,
    double borderRadius = 12,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}

class HomeStatsShimmer extends StatelessWidget {
  const HomeStatsShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return AppShimmer.wrap(
      child: Row(
        children: [
          Expanded(child: _statCard()),
          SizedBox(width: 16.w),
          Expanded(child: _statCard()),
        ],
      ),
    );
  }

  Widget _statCard() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 24.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          AppShimmer.box(width: 40.w, height: 28.h, borderRadius: 8),
          SizedBox(height: 8.h),
          AppShimmer.box(width: 64.w, height: 14.h, borderRadius: 6),
        ],
      ),
    );
  }
}

class HomeOrdersShimmer extends StatelessWidget {
  const HomeOrdersShimmer({super.key, this.itemCount = 2});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return AppShimmer.wrap(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          children: [
            for (var i = 0; i < itemCount; i++) ...[
              if (i > 0) SizedBox(height: 1, child: ColoredBox(color: Colors.black26)),
              _orderCard(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _orderCard() {
    return Padding(
      padding: EdgeInsets.all(20.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppShimmer.box(width: 20.w, height: 20.h, borderRadius: 10),
              SizedBox(width: 8.w),
              Expanded(
                child: AppShimmer.box(height: 18.h, borderRadius: 8),
              ),
              SizedBox(width: 12.w),
              AppShimmer.box(width: 72.w, height: 32.h, borderRadius: 20),
            ],
          ),
          SizedBox(height: 20.h),
          AppShimmer.box(width: 120.w, height: 12.h, borderRadius: 6),
          SizedBox(height: 8.h),
          AppShimmer.box(width: double.infinity, height: 36.h, borderRadius: 8),
          SizedBox(height: 16.h),
          AppShimmer.box(width: 110.w, height: 12.h, borderRadius: 6),
          SizedBox(height: 8.h),
          AppShimmer.box(width: double.infinity, height: 36.h, borderRadius: 8),
          SizedBox(height: 20.h),
          AppShimmer.box(width: double.infinity, height: 48.h, borderRadius: 12),
        ],
      ),
    );
  }
}
