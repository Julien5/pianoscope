import 'package:flutter/material.dart';

/// Single source of truth for every visual decision in the app.
///
/// Widgets must not hardcode a colour, radius, spacing value or shadow. They
/// read it from here, either directly (`AppSpacing.md`) or indirectly through
/// the [AppTheme] that `AppTheme.lightTheme` installs on MaterialApp.
///
/// Scale: 4pt grid, radii 8-16, one indigo accent plus a teal for hardware
/// affordances.
abstract class AppColors {
  /// Filled buttons, active states, selection indicators.
  ///
  /// Carries white label text, so its lightness is capped by legibility, not
  /// taste: the lightest value still clearing WCAG AA (4.5:1) at 14px.
  static const Color primary = Colors.black;

  /// Tinted accent background for icon chips and selected tiles.
  static const Color primaryContainer = Color(0xFFE7ECFC);

  /// Text/icon colour on top of [primaryContainer].
  static const Color onPrimaryContainer = Color(0xFF1F3A8F);

  /// Foreground on top of [primary].
  static const Color onPrimary = Colors.black;

  /// Teal, for hardware / connector affordances (USB, ports).
  static const Color secondary = Color(0xFF0D9488);

  static const Color secondaryContainer = Color(0xFFD3F4EF);

  static const Color error = Color(0xFFDC2626);

  static const Color errorContainer = Color(0xFFFEE2E2);

  /// Off-white so white [surface] cards read as raised rather than floating on
  /// the same colour.
  static const Color background = Color.fromARGB(255, 200, 200, 225);

  /// Cards, dialogs, drawer, app bar.
  static const Color surface = Colors.white;

  /// Sunken areas: input fills, meter tracks, disabled backgrounds.
  static const Color surfaceMuted = Color(0xFFEDEFF4);

  static const Color border = Color(0xFFE2E4EC);

  /// Emphasised border: unfocused inputs, dividers on [surface].
  static const Color borderStrong = Color(0xFFCDD1DC);

  static const Color text = Color(0xFF16181D);

  /// Secondary text: subtitles, helper copy.
  static const Color textSecondary = Color(0xFF6B7280);

  /// Disabled foregrounds and decorative text. Below 4.5:1 on [surface], so
  /// never use it for meaningful copy.
  static const Color textTertiary = Color(0xFF8A92A1);

  static const Color shadow = Color(0xFF101828);
}

/// 4pt spacing scale. Use these instead of inline `EdgeInsets` literals.
abstract class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
}

abstract class AppRadii {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;

  static const BorderRadius small = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius medium = BorderRadius.all(Radius.circular(md));
  static const BorderRadius large = BorderRadius.all(Radius.circular(lg));
}

/// Shadow colours and elevations. Deliberately faint: this app renders a staff
/// on a near-white page, and heavy shadows would compete with the ink.
abstract class AppShadows {
  static const Color cardColor = Color(0x14101828);

  /// Derived rather than hand-copied so it cannot drift from the accent.
  static Color get buttonColor => AppColors.primary.withValues(alpha: 0.20);

  static const double cardElevation = 1;
  static const double buttonElevation = 2;
}

/// Minimum touch target heights.
abstract class AppHeights {
  static const double button = 44;
  static const double chip = 36;
  static const double appBar = 56;
}

abstract class AppTextStyles {
  static const TextStyle title = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.text,
  );

  static const TextStyle header = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.text,
  );

  static const TextStyle normal = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.text,
  );

  static const TextStyle subtitle = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );

  static const TextStyle small = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );

  /// Same as [header] today, kept apart so button copy can diverge later
  /// without touching every heading.
  static const TextStyle button = header;

  static const TextStyle noteName = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w800,
    color: AppColors.text,
  );
}

/// Geometry and colours for [KeyboardWidget]. The widget's constructor
/// defaults point at these, so call sites only override what is genuinely
/// layout-specific (compact vs landscape key size).
abstract class AppKeyboardStyle {
  static const double whiteWidth = 55;
  static const double whiteHeight = 200;

  /// Compact variant, used by the portrait layouts.
  static const double compactWhiteWidth = 40;
  static const double compactWhiteHeight = 150;

  /// Variant used by the landscape layout.
  static const double landscapeWhiteWidth = 50;
  static const double landscapeWhiteHeight = whiteHeight;

  static const double blackWidthRatio = 0.6;
  static const double blackHeightRatio = 0.65;
  static const double whiteSpace = 2;
  static const double blackKeyRadius = 2;

  /// Distance from the bottom of a key to the centre of its pressed dot.
  static const double pressedDotOffset = 20;
  static const double pressedDotRadius = 5;
  static const Color pressedDotColor = AppColors.primary;

  static const Color whiteKeyFill = Colors.white;
  static const Color whiteKeyStroke = Color(0x1F16181D);
  static const Color blackKeyFill = AppColors.text;
}

/// Geometry and colours for the velocity meter, which is always vertical: it
/// sits right of the staff, or right of the keyboard in the tight layout, and
/// reads bottom-up in both.
abstract class AppMeterStyle {
  static const double length = 150;
  static const double thickness = 10;

  static const Color trackColor = AppColors.surfaceMuted;
  static const Color trackBorderColor = AppColors.borderStrong;
  static const BorderRadius borderRadius = BorderRadius.all(Radius.circular(3));

  static const LinearGradient fillGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF7B98FF), AppColors.primary],
  );
}

abstract class AppDrawerStyle {
  static const List<Color> headerGradient = [
    AppColors.background,
    Color(0xFF6E8CEC),
  ];

  /// Height of the collapsed header variant used in landscape.
  static const double smallHeaderHeight = 80;

  static const TextStyle brandTextStyle = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: AppColors.onPrimary,
  );
}

/// Layout constants for the clef / key-signature picker.
abstract class AppClefStyle {
  static const int portraitColumns = 2;
  static const int landscapeColumns = 3;

  static const double gridSpacing = AppSpacing.md;
  static const double childAspectRatio = 1.7;

  /// Width of the vertical tab rail in landscape.
  static const double tabRailWidth = 68;

  /// Intrinsic size of the little staff tile used as each button's child.
  static const double keyTileHeight = 100;
  static const double keyTileWidth = 120;
}

abstract class AppTheme {
  /// Without an explicit scheme Flutter falls back to its built-in M3 purple
  /// (#6750A4), which is why unthemed widgets -- FAB, spinner, TabBar,
  /// checkbox, input focus ring -- used to clash with the hand-picked accent.
  /// Seeding keeps every generated role on-brand.
  ///
  /// `surfaceTint: transparent` opts out of the M3 behaviour of tinting
  /// elevated surfaces with `primary`, which would wash the white cards
  /// lavender. It also makes the per-component `surfaceTintColor` overrides
  /// below unnecessary, since they all resolve from this.
  static final ColorScheme _colorScheme =
      ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.light,
      ).copyWith(
        primary: AppColors.primary,
        onPrimary: AppColors.onPrimary,
        primaryContainer: AppColors.primaryContainer,
        onPrimaryContainer: AppColors.onPrimaryContainer,
        secondary: AppColors.secondary,
        secondaryContainer: AppColors.secondaryContainer,
        error: AppColors.error,
        errorContainer: AppColors.errorContainer,
        surface: AppColors.surface,
        onSurface: AppColors.text,
        surfaceContainerLowest: AppColors.surface,
        surfaceContainerLow: AppColors.background,
        surfaceContainer: AppColors.surfaceMuted,
        surfaceContainerHigh: AppColors.surfaceMuted,
        surfaceContainerHighest: AppColors.surfaceMuted,
        onSurfaceVariant: AppColors.textSecondary,
        outline: AppColors.borderStrong,
        outlineVariant: AppColors.border,
        shadow: AppColors.shadow,
        surfaceTint: Colors.transparent,
      );

  /// The rounded rectangle behind cards, tiles and buttons. Omit [border] for
  /// a borderless shape, which still clips Material's ink splash.
  static OutlinedBorder _shape({Color? border, double width = 1}) {
    return RoundedRectangleBorder(
      borderRadius: AppRadii.medium,
      side: border == null
          ? BorderSide.none
          : BorderSide(color: border, width: width),
    );
  }

  static const double _selectedBorderWidth = 2;

  /// The shared shape of the three elevated button variants. They differ only
  /// in fill, border and elevation, all of which are arguments here.
  static ButtonStyle _elevatedButton({
    required Color background,
    required Color foreground,
    required OutlinedBorder shape,
    required Color? shadowColor,
    double elevation = AppShadows.buttonElevation,
  }) {
    return ElevatedButton.styleFrom(
      elevation: elevation,
      shadowColor: shadowColor,
      backgroundColor: background,
      foregroundColor: foreground,
      disabledBackgroundColor: AppColors.surfaceMuted,
      disabledForegroundColor: AppColors.textTertiary,
      minimumSize: const Size(0, AppHeights.button),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.md,
      ),
      shape: shape,
      textStyle: AppTextStyles.button,
    );
  }

  /// Default button: white surface, hairline border, soft shadow. Icon buttons
  /// and the key-signature tiles -- secondary controls, not primary actions.
  static ButtonStyle get tonalButtonStyle => _elevatedButton(
    background: AppColors.surface,
    foreground: AppColors.text,
    shadowColor: AppShadows.cardColor,
    shape: _shape(border: AppColors.border),
  );

  /// Primary action: filled accent. Not the theme default, so opt in per
  /// button with `ElevatedButton(style: AppTheme.filledButtonStyle, ...)`.
  static ButtonStyle get filledButtonStyle => _elevatedButton(
    background: AppColors.background,
    foreground: AppColors.onPrimary,
    shadowColor: AppShadows.buttonColor,
    shape: _shape(),
  );

  /// Selected item in a picker.
  static ButtonStyle get selectedButtonStyle => _elevatedButton(
    background: AppColors.primaryContainer,
    foreground: AppColors.onPrimaryContainer,
    shadowColor: null,
    elevation: 0,
    shape: _shape(border: AppColors.primary, width: _selectedBorderWidth),
  );

  /// Flat, borderless text button (dialog dismissals). Previously this reused
  /// the elevated style, so dialog "Cancel" buttons rendered as white boxes.
  static ButtonStyle get flatButtonStyle => TextButton.styleFrom(
    foregroundColor: AppColors.primary,
    disabledForegroundColor: AppColors.textTertiary,
    minimumSize: const Size(0, AppHeights.button),
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.lg,
      vertical: AppSpacing.sm,
    ),
    shape: const RoundedRectangleBorder(borderRadius: AppRadii.small),
    textStyle: AppTextStyles.button,
  );

  /// Borderless icon button matching the AppBar's leading [DrawerButton]. The
  /// landscape `/note` layout drops the AppBar to give the staff the full
  /// height, so its drawer toggle is positioned over the body instead; this
  /// keeps that overlay identical to the menu the other orientations show.
  ///
  /// Pair with an [AppHeights.appBar] square at the top left of the body to
  /// line the icon up with the AppBar's leading slot.
  static ButtonStyle get overlayIconButtonStyle => IconButton.styleFrom(
    foregroundColor: AppColors.onPrimary,
    backgroundColor: AppColors.primaryContainer,
    iconSize: 24,
    shape: const RoundedRectangleBorder(borderRadius: AppRadii.small),
  );

  static OutlineInputBorder _inputBorder(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: AppRadii.small,
      borderSide: BorderSide(color: color, width: width),
    );
  }

  /// Re-evaluated on every hot reload.
  static ThemeData get lightTheme => ThemeData(
    useMaterial3: true,
    colorScheme: _colorScheme,
    scaffoldBackgroundColor: AppColors.background,

    appBarTheme: AppBarThemeData(
      backgroundColor: AppColors.surface,
      foregroundColor: AppColors.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      toolbarHeight: AppHeights.appBar,
      centerTitle: true,
      titleTextStyle: AppTextStyles.title,
      iconTheme: const IconThemeData(color: AppColors.textSecondary),
      shape: const Border(bottom: BorderSide(color: AppColors.border)),
    ),

    cardTheme: CardThemeData(
      shape: _shape(border: AppColors.border),
      color: AppColors.surface,
      elevation: AppShadows.cardElevation,
      shadowColor: AppShadows.cardColor,
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm / 2,
      ),
    ),

    listTileTheme: ListTileThemeData(
      // Borderless: tiles usually sit inside a [Card] that already draws the
      // border, and a second outline inside a drawer reads as clutter.
      shape: _shape(),
      titleTextStyle: AppTextStyles.header,
      subtitleTextStyle: AppTextStyles.subtitle,
      iconColor: AppColors.textSecondary,
      selectedColor: AppColors.primary,
      selectedTileColor: AppColors.primaryContainer,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(style: tonalButtonStyle),
    textButtonTheme: TextButtonThemeData(style: flatButtonStyle),

    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.primary,
      foregroundColor: AppColors.onPrimary,
      elevation: 2,
      focusElevation: 2,
      hoverElevation: 3,
      highlightElevation: 4,
      extendedTextStyle: AppTextStyles.button,
      shape: RoundedRectangleBorder(borderRadius: AppRadii.medium),
    ),

    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.surface,
      elevation: 8,
      shadowColor: AppColors.shadow,
      shape: const RoundedRectangleBorder(borderRadius: AppRadii.large),
      titleTextStyle: AppTextStyles.title,
      contentTextStyle: AppTextStyles.normal,
    ),

    drawerTheme: const DrawerThemeData(
      backgroundColor: AppColors.surface,
      scrimColor: Color(0x6616181D),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(
          right: Radius.circular(AppRadii.lg),
        ),
      ),
    ),

    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.background,
      contentTextStyle: AppTextStyles.normal.copyWith(
        color: AppColors.onPrimary,
      ),
      actionTextColor: const Color(0xFFB4C5FF),
      behavior: SnackBarBehavior.floating,
      elevation: 6,
      shape: const RoundedRectangleBorder(borderRadius: AppRadii.small),
      insetPadding: const EdgeInsets.all(AppSpacing.lg),
    ),

    tabBarTheme: TabBarThemeData(
      labelColor: AppColors.primary,
      unselectedLabelColor: AppColors.textSecondary,
      indicatorColor: AppColors.primary,
      dividerColor: AppColors.border,
      labelStyle: AppTextStyles.header,
      unselectedLabelStyle: AppTextStyles.normal,
      indicatorSize: TabBarIndicatorSize.tab,
    ),

    checkboxTheme: CheckboxThemeData(
      shape: const RoundedRectangleBorder(borderRadius: AppRadii.small),
      side: WidgetStateBorderSide.resolveWith(
        (states) => const BorderSide(color: AppColors.onPrimary, width: 1.3),
      ),
      fillColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? AppColors.background
            : AppColors.surface,
      ),
      checkColor: WidgetStateProperty.all(AppColors.onPrimary),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      hintStyle: AppTextStyles.subtitle,
      labelStyle: AppTextStyles.subtitle,
      floatingLabelStyle: AppTextStyles.header.copyWith(
        color: AppColors.primary,
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      border: _inputBorder(AppColors.borderStrong),
      enabledBorder: _inputBorder(AppColors.borderStrong),
      focusedBorder: _inputBorder(AppColors.primary, width: 2),
      errorBorder: _inputBorder(AppColors.error),
      focusedErrorBorder: _inputBorder(AppColors.error, width: 2),
      disabledBorder: _inputBorder(AppColors.border),
    ),

    iconTheme: const IconThemeData(color: AppColors.textSecondary, size: 22),
    dividerTheme: const DividerThemeData(
      color: AppColors.border,
      thickness: 1,
      space: 1,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.primary,
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: AppRadii.small,
      ),
      textStyle: AppTextStyles.small.copyWith(color: AppColors.text),
    ),
  );
}
