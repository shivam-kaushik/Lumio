import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:workmanager/workmanager.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

import 'core/services/notification_service.dart';
import 'core/services/permission_service.dart';
import 'core/services/trigger_engine.dart';
import 'core/services/smart_nudge_service.dart';
import 'data/database/database_helper.dart';
import 'data/repositories/reminder_repository.dart';
import 'data/repositories/growth_repository.dart';
import 'presentation/providers/reminder_provider.dart';
import 'presentation/providers/growth_provider.dart';
import 'presentation/providers/theme_provider.dart';
import 'presentation/providers/auth_provider.dart';
import 'presentation/theme/app_theme.dart';
import 'presentation/screens/splash_screen.dart';
import 'presentation/navigation/main_navigator.dart';

/// Background task callback for Workmanager
/// Executes context monitoring and reminder triggering in background
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      // Initialize services for background context
      await DatabaseHelper.instance.database;
      final notificationService = NotificationService();
      await notificationService.initialize();

      // Ensure timezone data is available in background isolate
      tz.initializeTimeZones();

      // Initialize repository and trigger engine to run background checks
      final reminderRepository = ReminderRepository();
      final triggerEngine = TriggerEngine(
        reminderRepository: reminderRepository,
        notificationService: notificationService,
      );

      await triggerEngine.runBackgroundChecks();

      // Check for streak protection nudges
      final smartNudgeService = SmartNudgeService();
      await smartNudgeService.checkAndSendStreakProtectionNudges();

      // Check context and trigger reminders
      // This will be implemented by the TriggerEngine
      debugPrint('Background task executed: $task');

      return Future.value(true);
    } catch (error) {
      debugPrint('Background task error: $error');
      return Future.value(false);
    }
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('✅ Firebase initialized successfully');
  } catch (e) {
    debugPrint('⚠️ Firebase initialization error: $e');
    debugPrint('⚠️ Make sure you have configured Firebase for your platform');
  }

  // Load environment variables
  try {
    await dotenv.load(fileName: '.env');
    debugPrint('✅ .env file loaded successfully');
  } catch (e) {
    debugPrint('⚠️ .env file not found or error loading: $e');
  }

  // Initialize timezone data for scheduled notifications
  tz.initializeTimeZones();

  // Initialize background task manager
  await Workmanager().initialize(callbackDispatcher, isInDebugMode: false);

  // Register periodic context monitoring task (every 15 minutes)
  await Workmanager().registerPeriodicTask(
    'context_monitor',
    'contextMonitorTask',
    frequency: const Duration(minutes: 15),
    constraints: Constraints(
      networkType: NetworkType.not_required,
      requiresBatteryNotLow: true,
    ),
  );

  // Initialize notification service
  final notificationService = NotificationService();
  await notificationService.initialize();

  // Request notification permission (Android 13+ / iOS)
  final permissionService = PermissionService();
  await permissionService.requestNotificationPermission();

  // Request exact alarm permission (Android 12+) - critical for reliable scheduling
  final hasExactAlarm = await permissionService.hasExactAlarmPermission();
  debugPrint('📱 Exact alarm permission: $hasExactAlarm');
  if (!hasExactAlarm) {
    debugPrint(
        '⚠️ Exact alarm permission not granted. Notifications may not be reliable.',);
  }

  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(const LumioApp());
}

/// Main application widget
class LumioApp extends StatefulWidget {
  const LumioApp({super.key});

  @override
  State<LumioApp> createState() => _LumioAppState();
}

class _LumioAppState extends State<LumioApp> {
  TriggerEngine? _triggerEngine;

  @override
  void initState() {
    super.initState();
    _initializeTriggerEngine();
  }

  Future<void> _initializeTriggerEngine() async {
    final reminderRepository = ReminderRepository();
    final notificationService = NotificationService();
    await notificationService.initialize();

    _triggerEngine = TriggerEngine(
      reminderRepository: reminderRepository,
      notificationService: notificationService,
    );

    // Start monitoring location and WiFi changes
    await _triggerEngine!.startMonitoring();
    debugPrint('🎯 TriggerEngine started in main app');
  }

  @override
  void dispose() {
    _triggerEngine?.stopMonitoring();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Repositories
        Provider<ReminderRepository>(create: (_) => ReminderRepository()),
        Provider<GrowthRepository>(create: (_) => GrowthRepository()), // MVP

        // Services
        Provider<NotificationService>(create: (_) => NotificationService()),
        Provider<PermissionService>(create: (_) => PermissionService()),

        // State Management
        ChangeNotifierProvider<ThemeProvider>(
          create: (_) => ThemeProvider(),
        ),
        ChangeNotifierProvider<AuthProvider>(
          create: (_) => AuthProvider(),
        ),
        ChangeNotifierProvider<ReminderProvider>(
          create: (context) => ReminderProvider(
            reminderRepository: context.read<ReminderRepository>(),
          )..loadReminders(),
        ),
        ChangeNotifierProvider<GrowthProvider>( // MVP
          create: (context) => GrowthProvider(
            repository: context.read<GrowthRepository>(),
          )..loadGrowthData(),
        ),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          // Optionally wrap with DevicePreview for UI testing
          // To enable, set USE_DEVICE_PREVIEW = true and uncomment below
          const useDevicePreview = false;
          
          final app = MaterialApp(
            title: 'Lumio',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.themeMode,
            home: const SplashScreen(),
            routes: {
              '/home': (context) => const MainNavigator(),
            },
          );

          // Enable DevicePreview in debug mode for UI preview
          // Note: This is for UI layout testing only, not actual iOS runtime
          if (kDebugMode && useDevicePreview) {
            // Uncomment these lines to enable DevicePreview:
            /*
            return DevicePreview(
              enabled: kDebugMode,
              builder: (context) => app,
            );
            */
            return app;
          }
          
          return app;
        },
      ),
    );
  }
}
