import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/settings_provider.dart';

class LanguageSection extends StatelessWidget {
  const LanguageSection({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Consumer<SettingsProvider>(
      builder: (context, settings, _) {
        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.colorScheme.outline.withOpacity(0.2)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.language, color: theme.colorScheme.primary, size: 24),
                    const SizedBox(width: 12),
                    Text('Язык', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              const Divider(height: 1),
              RadioListTile<String>(
                title: const Text('Русский'),
                value: 'ru',
                groupValue: settings.languageCode,
                onChanged: (value) => settings.setLanguage(value!),
              ),
              RadioListTile<String>(
                title: const Text('Oʻzbekcha'),
                value: 'uz',
                groupValue: settings.languageCode,
                onChanged: (value) => settings.setLanguage(value!),
              ),
              RadioListTile<String>(
                title: const Text('English'),
                value: 'en',
                groupValue: settings.languageCode,
                onChanged: (value) => settings.setLanguage(value!),
              ),
            ],
          ),
        );
      },
    );
  }
}
