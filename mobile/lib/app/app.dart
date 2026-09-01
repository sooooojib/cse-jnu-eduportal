import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'router/app_router.dart';
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
            return GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
              child: child,
            );
          },
        );
      },
    );
  }
}
