import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'core/constants/app_colors.dart';
import 'core/providers/genieacs_provider.dart';
import 'core/providers/server_config_provider.dart';
import 'core/theme/app_theme.dart';
import 'features/splash/splash_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Set system UI navigation and status bar style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppColors.backgroundCard,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const AlijayaNetSuiteApp());
}

class AlijayaNetSuiteApp extends StatelessWidget {
  const AlijayaNetSuiteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ServerConfigProvider>(
          create: (_) => ServerConfigProvider(),
        ),
        ChangeNotifierProxyProvider<ServerConfigProvider, GenieAcsProvider>(
          create: (ctx) => GenieAcsProvider(ctx.read<ServerConfigProvider>()),
          update: (ctx, config, previous) => previous ?? GenieAcsProvider(config),
        ),
      ],
      child: MaterialApp(
        title: 'Alijaya NetSuite',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: const SplashScreen(),
      ),
    );
  }
}
