import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'routes/app_router.dart';
import 'core/theme/app_theme.dart';
import 'data/database/database.dart';
import 'presentation/providers/home_provider.dart';

/// Точка входа в приложение
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Инициализация локализации дат (для календаря)
  await initializeDateFormatting('ru_RU', null);
  await initializeDateFormatting('uz_UZ', null);
  await initializeDateFormatting('en_US', null);

  // Инициализация базы данных Drift
  final database = AppDatabase();

  runApp(MyApp(database: database));
}

/// Корневой виджет приложения
class MyApp extends StatelessWidget {
  final AppDatabase database;

  const MyApp({
    super.key,
    required this.database,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Провайдер базы данных
        Provider<AppDatabase>.value(value: database),
        // Провайдер главного экрана
        ChangeNotifierProvider(
          create: (context) => HomeProvider(database),
        ),
      ],
      child: MaterialApp.router(
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
        locale: const Locale('ru', ''), // Язык по умолчанию

        // Маршрутизация
        routerConfig: AppRouter.router,
      ),
    );
  }
}
