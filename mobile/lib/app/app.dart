import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'router/app_router.dart';
import 'theme/app_colors.dart';
import 'theme/app_theme.dart';
import '../core/constants/app_constants.dart';

class CSEEduPortalApp extends StatefulWidget {
  final ValueNotifier<ThemeMode> themeModeNotifier;

  const CSEEduPortalApp({
    super.key,
    required this.themeModeNotifier,
  });

  @override
  State<CSEEduPortalApp> createState() => _CSEEduPortalAppState();
}

class _CSEEduPortalAppState extends State<CSEEduPortalApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _router = AppRouter.createRouter(themeModeNotifier: widget.themeModeNotifier);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: widget.themeModeNotifier,
      builder: (context, themeMode, _) {
        return MaterialApp.router(
          title: AppConstants.appName,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeMode,
          themeAnimationDuration: const Duration(milliseconds: 400),
          themeAnimationCurve: Curves.easeInOutCubic,
          routerConfig: _router,
          builder: (context, child) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final bg = isDark ? AppColors.surfaceDark : AppColors.surfaceLight;

            final overlayStyle = SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
              statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
              systemNavigationBarColor: bg,
              systemNavigationBarDividerColor: Colors.transparent,
              systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
            );

            SystemChrome.setSystemUIOverlayStyle(overlayStyle);

            return AnnotatedRegion<SystemUiOverlayStyle>(
              value: overlayStyle,
              child: Container(
                color: bg,
                child: SafeArea(
                  top: false,
                  bottom: true,
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
                    child: child,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
