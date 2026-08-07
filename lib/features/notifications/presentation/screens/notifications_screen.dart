
import 'package:nomoride/core/utils/size_utils.dart';

import '../../../../core/app_export.dart';
import '../../../../theme/theme_helper.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final notifications = <({String title, String subtitle, String time})>[
      (
        title: 'Order Shipped',
        subtitle: 'Your has been dispatched today',
        time: '2 hr ago',
      ),
      (
        title: 'Membership Expiring',
        subtitle: 'Your membership is expiring soon, explore all plans',
        time: '1 day ago',
      ),
      (
        title: 'Order Delivered',
        subtitle: 'Your has been delivered',
        time: '5 days ago',
      ),
      (
        title: 'Order Arriving',
        subtitle: 'Delivery partner is on the way',
        time: '13/03/2026',
      ),
      (
        title: 'Prime Membership',
        subtitle: 'Your membership purchase is successful, Explore benfits',
        time: '29/04/2026',
      ),
    ];

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
                    color: const Color(0xFFE6C279).withOpacity(0.35),
                  ),
                ),
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Icon(
                      Icons.arrow_back,
                      color: const Color(0xFFE6C279),
                      size: 20,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'Notifications',
                      textAlign: TextAlign.center,
                      style: CustomTextStyles.openSansBold.copyWith(fontSize: 16,color: AppColours.primary),
                    ),
                  ),
                  SizedBox(width: 20.w),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: EdgeInsets.fromLTRB(12.w, 14.h, 12.w, 20.h),
                itemCount: notifications.length,
                separatorBuilder: (_, __) => Divider(
                  color: const Color(0xFFE6C279).withOpacity(0.18),
                  height: 20.h,
                ),
                itemBuilder: (_, index) {
                  final item = notifications[index];
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              style: CustomTextStyles.openSansSemiBold.copyWith(fontSize: 14,color: AppColours.primary),
                            ),
                            SizedBox(height: 4.h),
                            Text(
                              item.subtitle,
                              style: CustomTextStyles.openSansRegular.copyWith(fontSize:12, ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 10.w),
                      Text(
                        item.time,
                        style: CustomTextStyles.openSansRegular.copyWith(fontSize:12, ),

                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
