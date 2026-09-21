import 'package:flutter/material.dart';

import '../theme/colors.dart';

class AppFooter extends StatelessWidget {
  const AppFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
      color: ShopColors.navy,
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ShopHub',
            style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800),
          ),
          SizedBox(height: 8),
          Text(
            'Browse. Bag. Delivered. A Daraz-style marketplace for everyday shopping.',
            style: TextStyle(color: Colors.white70, height: 1.4),
          ),
          SizedBox(height: 16),
          Text('Customer Care  •  Returns  •  About ShopHub',
              style: TextStyle(color: Colors.white54, fontSize: 12)),
          SizedBox(height: 8),
          Text('© 2026 ShopHub. All rights reserved.',
              style: TextStyle(color: Colors.white38, fontSize: 11)),
        ],
      ),
    );
  }
}
