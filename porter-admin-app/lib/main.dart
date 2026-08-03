import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'providers/admin_provider.dart';
import 'providers/theme_provider.dart';
import 'config/app_theme.dart';
import 'screens/login_screen.dart';
import 'screens/main_admin_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/driver_list_screen.dart';
import 'screens/admin_screens.dart';
import 'screens/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load .env before anything else
  await dotenv.load(fileName: '.env');

  runApp(MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => AdminProvider()),
      ChangeNotifierProvider(create: (_) => ThemeProvider()),
    ],
    child: const PorterAdminApp(),
  ));
}

class PorterAdminApp extends StatelessWidget {
  const PorterAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          themeProvider.initialize();
        });

        return MaterialApp(
          title: 'Porter Admin',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme(),
          darkTheme: AppTheme.darkTheme(),
          themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
          initialRoute: '/',
          onGenerateRoute: (settings) {
            Widget page;
            switch (settings.name) {
              case '/':     page = const SplashScreen(); break;
              case '/login': page = const LoginScreen(); break;
              case '/main':  page = const MainAdminScreen(); break;
              case '/dashboard': page = const DashboardScreen(); break;
              case '/drivers': page = const DriverListScreen(); break;
              case '/users': page = const UsersListScreen(); break;
              case '/orders': page = const ActiveOrdersScreen(); break;
              case '/tickets': page = const SupportTicketsScreen(); break;
              case '/payouts': page = const PayoutManagementScreen(); break;
              case '/disputes': page = const DisputesScreen(); break;
              case '/alerts': page = const EmergencyAlertsScreen(); break;
              case '/analytics': page = const AnalyticsScreen(); break;
              case '/batch': page = const BatchOperationsScreen(); break;
              default: page = const MainAdminScreen(); break;
            }
            return PageRouteBuilder(
              settings: settings,
              pageBuilder: (_, __, ___) => page,
              transitionDuration: const Duration(milliseconds: 260),
              transitionsBuilder: (_, anim, __, child) => FadeTransition(
                opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
                child: child,
              ),
            );
          },
        );
      },
    );
  }
}

