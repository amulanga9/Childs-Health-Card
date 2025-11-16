import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'routes/app_router.dart';
import 'core/theme/app_theme.dart';
import 'data/database/database.dart';
import 'presentation/providers/home_provider.dart';
import 'presentation/providers/qr_provider.dart';
import 'presentation/providers/sync_provider.dart';
import 'presentation/providers/settings_provider.dart';
import 'services/api_service.dart';

/// Точка входа в приложение
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Инициализация локализации дат (для календаря)
  await initializeDateFormatting('ru_RU', null);
  await initializeDateFormatting('uz_UZ', null);
  await initializeDateFormatting('en_US', null);

  // Инициализация базы данных Drift
  final database = AppDatabase();

  // Инициализация SharedPreferences
  final prefs = await SharedPreferences.getInstance();

  // Инициализация API сервиса
  // TODO: Изменить baseUrl на production URL
  final apiService = ApiService(
    baseUrl: 'http://localhost:8000',
  );

  runApp(MyApp(
    database: database,
    apiService: apiService,
    prefs: prefs,
  ));
}

/// Корневой виджет приложения
class MyApp extends StatelessWidget {
  final AppDatabase database;
  final ApiService apiService;
  final SharedPreferences prefs;

  const MyApp({
    super.key,
    required this.database,
    required this.apiService,
    required this.prefs,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Провайдер базы данных
        Provider<AppDatabase>.value(value: database),
        // Провайдер API сервиса
        Provider<ApiService>.value(value: apiService),
        // Провайдер настроек
        ChangeNotifierProvider(
          create: (context) => SettingsProvider(
            database: database,
            prefs: prefs,
          ),
        ),
        // Провайдер главного экрана
        ChangeNotifierProvider(
          create: (context) => HomeProvider(database),
        ),
        // Провайдер QR генерации
        ChangeNotifierProvider(
          create: (context) => QRProvider(
            database: database,
            apiService: apiService,
          ),
        ),
        // Провайдер синхронизации
        ChangeNotifierProvider(
          create: (context) => SyncProvider(
            database: database,
            apiService: apiService,
          ),
        ),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, settings, _) {
          return MaterialApp.router(
            title: 'Карта здоровья ребёнка',
            debugShowCheckedModeBanner: false,

            // Тема приложения
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: ThemeMode.system,

            // Локализация
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [
              Locale('ru', ''), // Русский
              Locale('uz', ''), // Узбекский
              Locale('en', ''), // Английский
            ],
            locale: settings.locale, // Динамический язык из настроек

            // Маршрутизация
            routerConfig: AppRouter.router,
          );
        },
      ),
    );
  }
}
