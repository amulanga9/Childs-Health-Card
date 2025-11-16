import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';

/// Календарь со свайпом и отображением событий здоровья
class HealthCalendar extends StatefulWidget {
  final DateTime focusedDay;
  final Map<DateTime, List<dynamic>> events;
  final Function(DateTime) onMonthChanged;
  final Function(DateTime)? onDaySelected;

  const HealthCalendar({
    super.key,
    required this.focusedDay,
    required this.events,
    required this.onMonthChanged,
    this.onDaySelected,
  });

  @override
  State<HealthCalendar> createState() => _HealthCalendarState();
}

class _HealthCalendarState extends State<HealthCalendar>
    with SingleTickerProviderStateMixin {
  late DateTime _selectedDay;
  late DateTime _focusedDay;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime.now();
    _focusedDay = widget.focusedDay;
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(HealthCalendar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusedDay != widget.focusedDay) {
      setState(() {
        _focusedDay = widget.focusedDay;
      });
    }
  }

  List<dynamic> _getEventsForDay(DateTime day) {
    final normalizedDay = DateTime(day.year, day.month, day.day);
    return widget.events[normalizedDay] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return FadeTransition(
      opacity: _animationController,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: theme.shadowColor.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            // Заголовок с месяцем и годом
            _buildHeader(theme),
            // Календарь
            TableCalendar(
              firstDay: DateTime(2020, 1, 1),
              lastDay: DateTime(2030, 12, 31),
              focusedDay: _focusedDay,
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              eventLoader: _getEventsForDay,
              calendarFormat: CalendarFormat.month,
              startingDayOfWeek: StartingDayOfWeek.monday,
              locale: 'ru_RU',
              // Стилизация
              calendarStyle: CalendarStyle(
                outsideDaysVisible: false,
                weekendTextStyle: TextStyle(color: theme.colorScheme.error),
                holidayTextStyle: TextStyle(color: theme.colorScheme.error),
                selectedDecoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  shape: BoxShape.circle,
                ),
                todayDecoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
                markerDecoration: BoxDecoration(
                  color: theme.colorScheme.secondary,
                  shape: BoxShape.circle,
                ),
                markersMaxCount: 3,
                canMarkersOverflow: false,
              ),
              headerVisible: false, // Скрываем стандартный заголовок
              daysOfWeekStyle: DaysOfWeekStyle(
                weekdayStyle: theme.textTheme.bodySmall!.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                weekendStyle: theme.textTheme.bodySmall!.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.error,
                ),
              ),
              // Обработчики событий
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                });
                widget.onDaySelected?.call(selectedDay);
              },
              onPageChanged: (focusedDay) {
                setState(() {
                  _focusedDay = focusedDay;
                });
                widget.onMonthChanged(focusedDay);
              },
              // Анимации
              calendarBuilders: CalendarBuilders(
                markerBuilder: (context, day, events) {
                  if (events.isEmpty) return null;

                  return Positioned(
                    bottom: 4,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: events.take(3).map((event) {
                        return Container(
                          width: 6,
                          height: 6,
                          margin: const EdgeInsets.symmetric(horizontal: 1),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: theme.colorScheme.secondary,
                          ),
                        );
                      }).toList(),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Заголовок календаря с месяцем и кнопками навигации
  Widget _buildHeader(ThemeData theme) {
    final monthName = DateFormat('LLLL yyyy', 'ru_RU').format(_focusedDay);
    final capitalizedMonth = monthName[0].toUpperCase() + monthName.substring(1);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Кнопка "предыдущий месяц"
          IconButton(
            icon: Icon(
              Icons.chevron_left,
              color: theme.colorScheme.primary,
            ),
            onPressed: () {
              final previousMonth = DateTime(
                _focusedDay.year,
                _focusedDay.month - 1,
              );
              setState(() {
                _focusedDay = previousMonth;
              });
              widget.onMonthChanged(previousMonth);
            },
          ),
          // Название месяца и года
          Text(
            capitalizedMonth,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          // Кнопка "следующий месяц"
          IconButton(
            icon: Icon(
              Icons.chevron_right,
              color: theme.colorScheme.primary,
            ),
            onPressed: () {
              final nextMonth = DateTime(
                _focusedDay.year,
                _focusedDay.month + 1,
              );
              setState(() {
                _focusedDay = nextMonth;
              });
              widget.onMonthChanged(nextMonth);
            },
          ),
        ],
      ),
    );
  }
}
