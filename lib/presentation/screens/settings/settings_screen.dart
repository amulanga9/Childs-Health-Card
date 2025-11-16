import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

/// Экран настроек приложения
/// Управление:
/// - Профилями детей (до 5 детей)
/// - Языком интерфейса (RU/UZ/EN)
/// - PIN-кодом для защиты
/// - Облачной синхронизацией
/// - Резервным копированием
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _pinEnabled = false;
  bool _cloudSyncEnabled = false;
  String _selectedLanguage = 'ru'; // TODO: Получить из настроек

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settings),
      ),
      body: ListView(
        children: [
          // Секция "Дети"
          _buildSectionHeader(context, l10n.children),
          _ChildrenList(),
          const Divider(),

          // Секция "Язык"
          _buildSectionHeader(context, l10n.language),
          ListTile(
            leading: const Icon(Icons.language),
            title: Text(l10n.language),
            subtitle: Text(_getLanguageName(_selectedLanguage)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showLanguageDialog(context),
          ),
          const Divider(),

          // Секция "Безопасность"
          _buildSectionHeader(context, 'Безопасность'),
          SwitchListTile(
            secondary: const Icon(Icons.lock),
            title: Text(l10n.enablePin),
            subtitle: const Text('Защита данных PIN-кодом'),
            value: _pinEnabled,
            onChanged: (value) {
              setState(() {
                _pinEnabled = value;
              });
              if (value) {
                // TODO: Показать диалог настройки PIN
              }
            },
          ),
          const Divider(),

          // Секция "Облако и резервное копирование"
          _buildSectionHeader(context, 'Облако и резервное копирование'),
          SwitchListTile(
            secondary: const Icon(Icons.cloud),
            title: Text(l10n.cloudSync),
            subtitle: const Text('Автоматическая синхронизация данных'),
            value: _cloudSyncEnabled,
            onChanged: (value) {
              setState(() {
                _cloudSyncEnabled = value;
              });
              // TODO: Настроить облачную синхронизацию
            },
          ),
          ListTile(
            leading: const Icon(Icons.backup),
            title: Text(l10n.backup),
            subtitle: const Text('Создать резервную копию данных'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // TODO: Создать резервную копию
            },
          ),
          ListTile(
            leading: const Icon(Icons.restore),
            title: Text(l10n.restore),
            subtitle: const Text('Восстановить данные из резервной копии'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // TODO: Восстановить данные
            },
          ),
          const Divider(),

          // Секция "О приложении"
          _buildSectionHeader(context, 'О приложении'),
          ListTile(
            leading: const Icon(Icons.info),
            title: const Text('Версия'),
            subtitle: const Text('1.0.0'),
          ),
          ListTile(
            leading: const Icon(Icons.description),
            title: const Text('Лицензия'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // TODO: Показать лицензию
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }

  String _getLanguageName(String code) {
    switch (code) {
      case 'ru':
        return 'Русский';
      case 'uz':
        return 'O\'zbekcha';
      case 'en':
        return 'English';
      default:
        return 'Русский';
    }
  }

  void _showLanguageDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Выберите язык'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String>(
              title: const Text('Русский'),
              value: 'ru',
              groupValue: _selectedLanguage,
              onChanged: (value) {
                setState(() {
                  _selectedLanguage = value!;
                });
                Navigator.pop(context);
                // TODO: Изменить язык приложения
              },
            ),
            RadioListTile<String>(
              title: const Text('O\'zbekcha'),
              value: 'uz',
              groupValue: _selectedLanguage,
              onChanged: (value) {
                setState(() {
                  _selectedLanguage = value!;
                });
                Navigator.pop(context);
                // TODO: Изменить язык приложения
              },
            ),
            RadioListTile<String>(
              title: const Text('English'),
              value: 'en',
              groupValue: _selectedLanguage,
              onChanged: (value) {
                setState(() {
                  _selectedLanguage = value!;
                });
                Navigator.pop(context);
                // TODO: Изменить язык приложения
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Список детей с возможностью добавления/удаления
class _ChildrenList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    // TODO: Заменить на реальные данные из Provider
    final children = [
      {'name': 'Ребёнок 1', 'age': '5 лет'},
      {'name': 'Ребёнок 2', 'age': '3 года'},
    ];

    return Column(
      children: [
        ...children.map((child) {
          return ListTile(
            leading: const CircleAvatar(
              child: Icon(Icons.child_care),
            ),
            title: Text(child['name']!),
            subtitle: Text(child['age']!),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () {
                    // TODO: Редактировать профиль ребёнка
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () {
                    // TODO: Удалить профиль ребёнка
                  },
                ),
              ],
            ),
          );
        }),
        // Кнопка добавления ребёнка (если меньше 5)
        if (children.length < 5)
          ListTile(
            leading: const CircleAvatar(
              child: Icon(Icons.add),
            ),
            title: Text(l10n.addChild),
            onTap: () {
              // TODO: Показать форму добавления ребёнка
            },
          ),
        if (children.length >= 5)
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Достигнут лимит детей (5)',
              style: TextStyle(color: Colors.grey),
            ),
          ),
      ],
    );
  }
}
