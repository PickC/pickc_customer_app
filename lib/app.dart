import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/constants/demo_mode.dart';
import 'core/theme/app_theme.dart';
import 'presentation/providers/router_provider.dart';

class PickCApp extends ConsumerWidget {
  const PickCApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Pick-C',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      routerConfig: router,
      builder: kDemoMode
          ? (context, child) => Banner(
                message: 'DEMO',
                location: BannerLocation.topEnd,
                color: Colors.redAccent,
                child: child ?? const SizedBox(),
              )
          : null,
    );
  }
}
