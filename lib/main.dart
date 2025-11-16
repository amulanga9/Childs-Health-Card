import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';

import 'routes/app_router.dart';
import 'core/theme/app_theme.dart';
import 'data/models/child.dart';
import 'data/models/illness.dart';
import 'data/models/doctor_visit.dart';
import 'data/models/medical_test.dart';
import 'data/models/procedure.dart';
import 'data/models/medication.dart';

/// Точка входа в приложение
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Инициализация Hive для локального хранения данных
  await Hive.initFlutter();

  // Регистрация адаптеров Hive для моделей данных
  // TODO: Раскомментировать после генерации адаптеров через build_runner
  // Hive.registerAdapter(ChildAdapter());
  // Hive.registerAdapter(GenderAdapter());
  // Hive.registerAdapter(IllnessAdapter());
  // Hive.registerAdapter(IllnessStatusAdapter());
  // Hive.registerAdapter(DoctorVisitAdapter());
  // Hive.registerAdapter(MedicalTestAdapter());
  // Hive.registerAdapter(MedicalProcedureAdapter());
  // Hive.registerAdapter(MedicationAdapter());

  // Открытие боксов для хранения данных
  // await Hive.openBox<Child>('children');
  // await Hive.openBox<Illness>('illnesses');
  // await Hive.openBox<DoctorVisit>('visits');
  // await Hive.openBox<MedicalTest>('tests');
  // await Hive.openBox<MedicalProcedure>('procedures');
  // await Hive.openBox<Medication>('medications');

  runApp(const MyApp());
}

/// Корневой виджет приложения
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // TODO: Добавить провайдеры для управления состоянием
        // ChangeNotifierProvider(create: (_) => ChildrenProvider()),
        // ChangeNotifierProvider(create: (_) => IllnessProvider()),
        // ChangeNotifierProvider(create: (_) => SettingsProvider()),
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
