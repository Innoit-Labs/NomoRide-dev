import 'package:flutter/material.dart';
import 'package:nomoride/core/network/api_exception.dart';
import 'package:nomoride/core/utils/custom_snack_bar.dart';
import 'package:nomoride/core/utils/size_utils.dart';
import 'package:nomoride/features/notifications/data/models/notification_model.dart';
import 'package:nomoride/features/notifications/data/notifications_repository.dart';
import 'package:nomoride/theme/theme_helper.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final NotificationsRepository _repository = NotificationsRepository();

  bool _isLoading = true;
  bool _isClearing = false;
  String? _errorMessage;
  List<NotificationModel> _notifications = [];

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications({bool isRefresh = false}) async {
    if (!isRefresh) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final list = await _repository.getNotifications();
      if (!mounted) return;
      setState(() {
        _notifications = list;
        _errorMessage = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error is ApiException ? error.message : error.toString();
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _clearAll() async {
    if (_isClearing || _notifications.isEmpty) return;
    setState(() => _isClearing = true);

    try {
      await _repository.clearAllNotifications();
      if (!mounted) return;
      setState(() {
        _notifications.clear();
      });
      CustomSnackBar.showSuccess(
        context,
        'All notifications cleared successfully',
      );
    } catch (error) {
      if (!mounted) return;
      final msg = error is ApiException ? error.message : error.toString();
      CustomSnackBar.showError(
        context,
        msg,
      );
    } finally {
      if (mounted) {
        setState(() => _isClearing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black87,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: const Color(0xFFE6C279).withValues(alpha: 0.35),
                  ),
                ),
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    behavior: HitTestBehavior.opaque,
                    child: const Icon(
                      Icons.arrow_back,
                      color: Color(0xFFE6C279),
                      size: 20,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'Notifications',
                      textAlign: TextAlign.center,
                      style: CustomTextStyles.openSansBold.copyWith(
                        fontSize: 16,
                        color: AppColours.primary,
                      ),
                    ),
                  ),
                  if (_isClearing)
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFFE6C279),
                      ),
                    )
                  else if (_notifications.isNotEmpty)
                    GestureDetector(
                      onTap: _clearAll,
                      behavior: HitTestBehavior.opaque,
                      child: Text(
                        'Clear All',
                        style: CustomTextStyles.openSansSemiBold.copyWith(
                          fontSize: 12,
                          color: const Color(0xFFE6C279),
                        ),
                      ),
                    )
                  else
                    SizedBox(width: 20.w),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                color: const Color(0xFFE6C279),
                backgroundColor: Colors.black87,
                onRefresh: () => _loadNotifications(isRefresh: true),
                child: _buildBody(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFFE6C279),
        ),
      );
    }

    if (_errorMessage != null && _notifications.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: 120.h),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: CustomTextStyles.openSansRegular.copyWith(
                    fontSize: 12,
                  ),
                ),
                SizedBox(height: 8.h),
                GestureDetector(
                  onTap: () => _loadNotifications(),
                  child: Text(
                    'Retry',
                    style: CustomTextStyles.openSansBold.copyWith(
                      fontSize: 12,
                      color: AppColours.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    if (_notifications.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: 140.h),
          Center(
            child: Text(
              'No notifications',
              style: CustomTextStyles.openSansRegular.copyWith(
                fontSize: 12,
                color: AppColours.grey,
              ),
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(12.w, 14.h, 12.w, 20.h),
      itemCount: _notifications.length,
      separatorBuilder: (_, __) => Divider(
        color: const Color(0xFFE6C279).withValues(alpha: 0.18),
        height: 20.h,
      ),
      itemBuilder: (_, index) {
        final item = _notifications[index];
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: CustomTextStyles.openSansSemiBold.copyWith(
                      fontSize: 14,
                      color: AppColours.primary,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    item.message,
                    style: CustomTextStyles.openSansRegular.copyWith(
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 10.w),
            Text(
              item.formattedTime,
              style: CustomTextStyles.openSansRegular.copyWith(
                fontSize: 12,
              ),
            ),
          ],
        );
      },
    );
  }
}
