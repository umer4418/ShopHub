import 'package:flutter/material.dart';

/// Screen classification based on device width.
enum ScreenType {
  /// Extra small phones (iPhone SE 1st gen, older small Android devices < 360px).
  smallMobile,

  /// Standard modern phones (360px - 599px).
  mobile,

  /// Tablets, foldables unfolded, and small laptops (600px - 1023px).
  tablet,

  /// Desktops and wide displays (>= 1024px).
  desktop,
}

/// Central responsive utility and layout helper for ShopHub.
/// Provides device detection, proportional value calculations, adaptive grid
/// sizing, and responsive wrapper widgets.
class Responsive {
  Responsive._();

  // Standard Breakpoints
  static const double smallMobileBreakpoint = 360.0;
  static const double mobileBreakpoint = 600.0;
  static const double tabletBreakpoint = 1024.0;

  // Max Container Widths
  static const double maxMobileContentWidth = 600.0;
  static const double maxFormContentWidth = 460.0;
  static const double maxTabletContentWidth = 900.0;
  static const double maxDesktopContentWidth = 1200.0;

  /// Returns the screen width.
  static double width(BuildContext context) => MediaQuery.sizeOf(context).width;

  /// Returns the screen height.
  static double height(BuildContext context) => MediaQuery.sizeOf(context).height;

  /// Returns current [ScreenType] based on available width.
  static ScreenType screenType(BuildContext context) {
    final w = width(context);
    if (w < smallMobileBreakpoint) return ScreenType.smallMobile;
    if (w < mobileBreakpoint) return ScreenType.mobile;
    if (w < tabletBreakpoint) return ScreenType.tablet;
    return ScreenType.desktop;
  }

  /// Whether the screen is a small phone (< 360px).
  static bool isSmallMobile(BuildContext context) =>
      width(context) < smallMobileBreakpoint;

  /// Whether the screen is mobile form-factor (< 600px).
  static bool isMobile(BuildContext context) =>
      width(context) < mobileBreakpoint;

  /// Whether the screen is tablet/foldable form-factor (600px - 1023px).
  static bool isTablet(BuildContext context) {
    final w = width(context);
    return w >= mobileBreakpoint && w < tabletBreakpoint;
  }

  /// Whether the screen is desktop/wide form-factor (>= 1024px).
  static bool isDesktop(BuildContext context) =>
      width(context) >= tabletBreakpoint;

  /// Returns a responsive value based on current screen size.
  static T value<T>(
    BuildContext context, {
    required T mobile,
    T? smallMobile,
    T? tablet,
    T? desktop,
  }) {
    final type = screenType(context);
    switch (type) {
      case ScreenType.smallMobile:
        return smallMobile ?? mobile;
      case ScreenType.mobile:
        return mobile;
      case ScreenType.tablet:
        return tablet ?? mobile;
      case ScreenType.desktop:
        return desktop ?? tablet ?? mobile;
    }
  }

  /// Calculates a responsive font size with min and max bounds.
  static double fontSize(
    BuildContext context,
    double baseSize, {
    double min = 10.0,
    double max = 36.0,
  }) {
    final w = width(context);
    double scale = 1.0;
    if (w < smallMobileBreakpoint) {
      scale = 0.90;
    } else if (w < 400) {
      scale = 0.96;
    } else if (w >= tabletBreakpoint) {
      scale = 1.10;
    } else if (w >= mobileBreakpoint) {
      scale = 1.05;
    }
    final calculated = baseSize * scale;
    return calculated.clamp(min, max);
  }

  /// Calculates adaptive grid column counts.
  static int gridColumns(
    BuildContext context, {
    double minItemWidth = 160.0,
    int minColumns = 2,
    int maxColumns = 6,
  }) {
    final w = width(context);
    if (w >= 1200) return 5.clamp(minColumns, maxColumns);
    if (w >= 900) return 4.clamp(minColumns, maxColumns);
    if (w >= 600) return 3.clamp(minColumns, maxColumns);
    return minColumns;
  }

  /// Calculates a safe card aspect ratio for product cards to avoid overflows.
  static double cardAspectRatio(
    BuildContext context, {
    double smallMobile = 0.60,
    double mobile = 0.65,
    double tablet = 0.72,
    double desktop = 0.75,
  }) {
    return value<double>(
      context,
      smallMobile: smallMobile,
      mobile: mobile,
      tablet: tablet,
      desktop: desktop,
    );
  }

  /// Calculates adaptive horizontal and vertical screen padding.
  static EdgeInsets screenPadding(
    BuildContext context, {
    double horizontal = 16.0,
    double vertical = 16.0,
  }) {
    if (isSmallMobile(context)) {
      return EdgeInsets.symmetric(
        horizontal: (horizontal * 0.75).clamp(8.0, 24.0),
        vertical: (vertical * 0.75).clamp(8.0, 24.0),
      );
    }
    if (isTablet(context)) {
      return EdgeInsets.symmetric(
        horizontal: horizontal * 1.25,
        vertical: vertical * 1.1,
      );
    }
    if (isDesktop(context)) {
      return EdgeInsets.symmetric(
        horizontal: horizontal * 1.5,
        vertical: vertical * 1.2,
      );
    }
    return EdgeInsets.symmetric(
      horizontal: horizontal,
      vertical: vertical,
    );
  }
}

/// Extension on [BuildContext] for shorthand responsive access.
extension ResponsiveContextExtension on BuildContext {
  double get screenWidth => Responsive.width(this);
  double get screenHeight => Responsive.height(this);
  ScreenType get screenType => Responsive.screenType(this);

  bool get isSmallMobile => Responsive.isSmallMobile(this);
  bool get isMobile => Responsive.isMobile(this);
  bool get isTablet => Responsive.isTablet(this);
  bool get isDesktop => Responsive.isDesktop(this);

  T responsiveValue<T>({
    required T mobile,
    T? smallMobile,
    T? tablet,
    T? desktop,
  }) {
    return Responsive.value<T>(
      this,
      mobile: mobile,
      smallMobile: smallMobile,
      tablet: tablet,
      desktop: desktop,
    );
  }

  double responsiveFontSize(
    double baseSize, {
    double min = 10.0,
    double max = 36.0,
  }) {
    return Responsive.fontSize(this, baseSize, min: min, max: max);
  }

  EdgeInsets responsivePadding({
    double horizontal = 16.0,
    double vertical = 16.0,
  }) {
    return Responsive.screenPadding(
      this,
      horizontal: horizontal,
      vertical: vertical,
    );
  }
}

/// A widget builder that adapts to parent constraints and [ScreenType].
class ResponsiveBuilder extends StatelessWidget {
  const ResponsiveBuilder({
    super.key,
    required this.builder,
  });

  final Widget Function(
    BuildContext context,
    BoxConstraints constraints,
    ScreenType screenType,
  ) builder;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenType = constraints.maxWidth < Responsive.smallMobileBreakpoint
            ? ScreenType.smallMobile
            : constraints.maxWidth < Responsive.mobileBreakpoint
                ? ScreenType.mobile
                : constraints.maxWidth < Responsive.tabletBreakpoint
                    ? ScreenType.tablet
                    : ScreenType.desktop;
        return builder(context, constraints, screenType);
      },
    );
  }
}

/// Layout widget providing separate builders for Mobile, Tablet, and Desktop.
class ResponsiveLayout extends StatelessWidget {
  const ResponsiveLayout({
    super.key,
    required this.mobile,
    this.smallMobile,
    this.tablet,
    this.desktop,
  });

  final Widget mobile;
  final Widget? smallMobile;
  final Widget? tablet;
  final Widget? desktop;

  @override
  Widget build(BuildContext context) {
    final type = Responsive.screenType(context);
    switch (type) {
      case ScreenType.smallMobile:
        return smallMobile ?? mobile;
      case ScreenType.mobile:
        return mobile;
      case ScreenType.tablet:
        return tablet ?? mobile;
      case ScreenType.desktop:
        return desktop ?? tablet ?? mobile;
    }
  }
}

/// Centers content with a maximum constrained width and adaptive padding,
/// ensuring comfortable reading/viewing widths on large screens and preventing
/// awkward stretching.
class ResponsiveContainer extends StatelessWidget {
  const ResponsiveContainer({
    super.key,
    required this.child,
    this.maxWidth = Responsive.maxMobileContentWidth,
    this.padding,
    this.alignment = Alignment.topCenter,
    this.color,
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry? padding;
  final AlignmentGeometry alignment;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final effectivePadding = padding ??
        EdgeInsets.symmetric(
          horizontal: Responsive.value<double>(
            context,
            smallMobile: 12.0,
            mobile: 16.0,
            tablet: 24.0,
            desktop: 32.0,
          ),
        );

    return Align(
      alignment: alignment,
      child: Container(
        color: color,
        constraints: BoxConstraints(maxWidth: maxWidth),
        padding: effectivePadding,
        child: child,
      ),
    );
  }
}

/// Switches between a [Row] on wider viewports and a [Column] on narrow mobile.
class ResponsiveRowColumn extends StatelessWidget {
  const ResponsiveRowColumn({
    super.key,
    required this.children,
    this.breakpoint = Responsive.mobileBreakpoint,
    this.rowMainAxisAlignment = MainAxisAlignment.start,
    this.rowCrossAxisAlignment = CrossAxisAlignment.center,
    this.columnMainAxisAlignment = MainAxisAlignment.start,
    this.columnCrossAxisAlignment = CrossAxisAlignment.start,
    this.spacing = 12.0,
  });

  final List<Widget> children;
  final double breakpoint;
  final MainAxisAlignment rowMainAxisAlignment;
  final CrossAxisAlignment rowCrossAxisAlignment;
  final MainAxisAlignment columnMainAxisAlignment;
  final CrossAxisAlignment columnCrossAxisAlignment;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isRow = constraints.maxWidth >= breakpoint;
        if (isRow) {
          return Row(
            mainAxisAlignment: rowMainAxisAlignment,
            crossAxisAlignment: rowCrossAxisAlignment,
            children: _intersperse(children, SizedBox(width: spacing)).toList(),
          );
        } else {
          return Column(
            mainAxisAlignment: columnMainAxisAlignment,
            crossAxisAlignment: columnCrossAxisAlignment,
            children: _intersperse(children, SizedBox(height: spacing)).toList(),
          );
        }
      },
    );
  }

  Iterable<Widget> _intersperse(List<Widget> list, Widget separator) sync* {
    for (var i = 0; i < list.length; i++) {
      yield list[i];
      if (i < list.length - 1) {
        yield separator;
      }
    }
  }
}
