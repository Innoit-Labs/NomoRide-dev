import 'package:flutter/material.dart';
import 'package:nomoride/core/services/auth_session.dart';
import 'package:nomoride/core/services/socket_service.dart';
import 'package:nomoride/core/widgets/app_shimmer.dart';
import 'package:nomoride/routes/app_routes.dart';
import '../../../orders/presentation/screens/orders_screen.dart';
import '../../../profile/presentation/screens/profile_screen.dart';
import 'home_screen.dart';
import '../../../../theme/theme_helper.dart';
import '../../../../core/utils/size_utils.dart';

class MainContainer extends StatefulWidget {
  const MainContainer({super.key});

  @override
  State<MainContainer> createState() => _MainContainerState();
}

class _MainContainerState extends State<MainContainer> {
  int _selectedIndex = 0;
  final Set<int> _loadedTabs = {0};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureAuthenticated();
    });
  }

  Future<void> _ensureAuthenticated() async {
    await AuthSession.restore();
    if (!mounted) return;
    if (AuthSession.hasValidSession) {
      SocketService.instance.initAndConnect();
      return;
    }

    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.loginScreen,
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black87,
      // Keep activated tab screens alive without loading all tabs eagerly at startup.
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _loadedTabs.contains(0) ? const HomeScreen() : const SizedBox.shrink(),
          _loadedTabs.contains(1) ? const OrdersScreen() : const SizedBox.shrink(),
          _loadedTabs.contains(2) ? const ProfileScreen() : const SizedBox.shrink(),
        ],
      ),
      bottomNavigationBar: ValueListenableBuilder<bool>(
        valueListenable: HomeScreen.isHomeLoadingNotifier,
        builder: (context, isHomeLoading, _) {
          if (isHomeLoading && _selectedIndex == 0) {
            return const HomeBottomBarShimmer();
          }
          return Container(
            margin: EdgeInsets.all(24.w),
            height: 70.h,
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColours.primary.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(0, Icons.home_rounded, 'Home'),
                _buildNavItem(1, Icons.assignment_outlined, 'My Orders'),
                _buildNavItem(2, Icons.person_outline_rounded, 'Profile'),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    bool isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () {
        if (_selectedIndex != index) {
          setState(() {
            _selectedIndex = index;
            _loadedTabs.add(index);
          });
        }
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
        decoration: isSelected
            ? BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
              )
            : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? AppColours.primary : Colors.white24,
              size: 24.h,
            ),
            SizedBox(height: 4.h),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? AppColours.primary : Colors.white24,
                fontSize: 10.fSize,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
