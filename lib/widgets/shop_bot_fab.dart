import 'package:flutter/material.dart';

import '../app/routes/app_routes.dart';
import '../theme/colors.dart';
import '../utils/responsive.dart';

/// ShopBot Floating Action Button
/// A prominent, stylish floating AI assistant button that opens the ShopBot chat.
class ShopBotFab extends StatefulWidget {
  const ShopBotFab({
    super.key,
    this.heroTag = 'shopbot_fab',
    this.compact = false,
  });

  final String heroTag;
  final bool compact;

  @override
  State<ShopBotFab> createState() => _ShopBotFabState();
}

class _ShopBotFabState extends State<ShopBotFab>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animCtrl;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _scaleAnim = Tween<double>(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(parent: _animCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  void _openChat(BuildContext context) {
    Navigator.pushNamed(context, AppRoutes.chatbot);
  }

  @override
  Widget build(BuildContext context) {
    final isSmall = Responsive.isSmallMobile(context);
    final horizontalPad = widget.compact ? 12.0 : (isSmall ? 12.0 : 16.0);
    final verticalPad = isSmall ? 9.0 : 12.0;
    final iconSize = isSmall ? 20.0 : 24.0;

    return AnimatedBuilder(
      animation: _scaleAnim,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnim.value,
          child: child,
        );
      },
      child: Material(
        color: Colors.transparent,
        elevation: 6,
        shadowColor: ShopColors.primary.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(28),
        child: InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: () => _openChat(context),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: horizontalPad,
              vertical: verticalPad,
            ),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  ShopColors.primary,
                  Color(0xFFFF7028),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: ShopColors.primary.withValues(alpha: 0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(
                      Icons.smart_toy_rounded,
                      color: Colors.white,
                      size: iconSize,
                    ),
                    Positioned(
                      top: -2,
                      right: -3,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: Color(0xFF10B981), // active green dot
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 8,
                          minHeight: 8,
                        ),
                      ),
                    ),
                  ],
                ),
                if (!widget.compact) ...[
                  SizedBox(width: isSmall ? 6 : 8),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'ShopBot AI',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: isSmall ? 12 : 13,
                              letterSpacing: 0.2,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.auto_awesome,
                            color: Colors.amberAccent,
                            size: isSmall ? 11 : 13,
                          ),
                        ],
                      ),
                      Text(
                        isSmall ? 'AI Assistant' : 'Ask about orders & delivery',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: isSmall ? 9 : 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
