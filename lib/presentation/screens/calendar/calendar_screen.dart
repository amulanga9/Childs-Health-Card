import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

/// Экран календаря событий
/// Показывает:
/// - Календарь с отметками важных событий
/// - Визиты к врачу
/// - Приём лекарств
/// - Процедуры
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  CalendarFormat _calendarFormat = CalendarFormat.month;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.calendar),
      ),
      body: Column(
        children: [
          // Календарь
          TableCalendar(
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            calendarFormat: _calendarFormat,
            selectedDayPredicate: (day) {
              return isSameDay(_selectedDay, day);
            },
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
            },
            onFormatChanged: (format) {
              setState(() {
                _calendarFormat = format;
              });
            },
            onPageChanged: (focusedDay) {
              _focusedDay = focusedDay;
            },
            // TODO: Добавить события на календаре
            eventLoader: (day) {
              // Заглушка для событий
              return [];
            },
          ),
          const Divider(),
          // События выбранного дня
          Expanded(
            child: _buildEventsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildEventsList() {
    if (_selectedDay == null) {
      return const Center(
        child: Text('Выберите день для просмотра событий'),
      );
    }

    // TODO: Получить события из Provider
    return ListView(
      children: [
        // Пример события - визит к врачу
        _EventCard(
          icon: Icons.local_hospital,
          title: 'Визит к педиатру',
          time: '10:00',
          subtitle: 'Иванов И.И.',
          color: Colors.blue,
        ),
        // Пример события - приём лекарства
        _EventCard(
          icon: Icons.medication,
          title: 'Принять Парацетамол',
          time: '12:00',
          subtitle: '500 мг',
          color: Colors.green,
        ),
        // Пример события - процедура
        _EventCard(
          icon: Icons.healing,
          title: 'Ингаляция',
          time: '18:00',
          subtitle: 'Поликлиника №5',
          color: Colors.orange,
        ),
      ],
    );
  }
}

/// Карточка события в календаре
class _EventCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String time;
  final String subtitle;
  final Color color;

  const _EventCard({
    required this.icon,
    required this.title,
    required this.time,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.2),
          child: Icon(icon, color: color),
        ),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: Text(
          time,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
      ),
    );
  }
}
