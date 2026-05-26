import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'services/bluetooth_service.dart';
import 'services/api_service.dart';
import 'services/user_service.dart';
import 'services/websocket_service.dart';
import 'theme/mechanical_theme.dart';
import 'theme/app_theme.dart';
import 'theme/app_colors.dart';
import 'pages/login_page.dart';
import 'pages/choose_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set status bar style - dynamically adjust based on theme
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
    ),
  );

  runApp(const NivoraApp());
}

class NivoraApp extends StatelessWidget {
  const NivoraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider(create: (_) => ApiService()),
        ChangeNotifierProvider(create: (_) => BluetoothService()),
        ChangeNotifierProvider(create: (_) => UserService()),
        ChangeNotifierProvider(create: (_) => WebSocketService()),
      ],
      child: MaterialApp(
        title: 'Nivora',
        debugShowCheckedModeBanner: false,
        // Use new modern theme, supports dark/light mode
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.system, // Follow system settings
        home: const _AppHome(),
      ),
    );
  }
}

class _AppHome extends StatelessWidget {
  const _AppHome();

  @override
  Widget build(BuildContext context) {
    final userService = Provider.of<UserService>(context);
    if (!userService.initialized) {
      return const Scaffold(backgroundColor: Colors.black);
    }
    return userService.hasValidToken() ? const ChoosePage() : const LoginPage();
  }
}
