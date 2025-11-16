import 'package:flutter/material.dart';

/// Анимированный чекбокс с эффектом для отметки приёма лекарств
class AnimatedCheckBox extends StatefulWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final Color? activeColor;
  final Color? checkColor;
  final double size;

  const AnimatedCheckBox({
    super.key,
    required this.value,
    required this.onChanged,
    this.activeColor,
    this.checkColor,
    this.size = 24,
  });

  @override
  State<AnimatedCheckBox> createState() => _AnimatedCheckBoxState();
}

class _AnimatedCheckBoxState extends State<AnimatedCheckBox>
    with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late AnimationController _checkController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _checkAnimation;

  @override
  void initState() {
    super.initState();

    // Анимация масштабирования при клике
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.9).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeInOut),
    );

    // Анимация появления галочки
    _checkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _checkAnimation = CurvedAnimation(
      parent: _checkController,
      curve: Curves.elasticOut,
    );

    if (widget.value) {
      _checkController.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(AnimatedCheckBox oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value) {
      if (widget.value) {
        _checkController.forward();
      } else {
        _checkController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _checkController.dispose();
    super.dispose();
  }

  void _handleTap() {
    _scaleController.forward().then((_) {
      _scaleController.reverse();
    });

    widget.onChanged(!widget.value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeColor = widget.activeColor ?? theme.colorScheme.primary;
    final checkColor = widget.checkColor ?? Colors.white;

    return GestureDetector(
      onTap: _handleTap,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: widget.value ? activeColor : Colors.transparent,
            border: Border.all(
              color: widget.value ? activeColor : theme.colorScheme.outline,
              width: 2,
            ),
            borderRadius: BorderRadius.circular(6),
          ),
          child: widget.value
              ? ScaleTransition(
                  scale: _checkAnimation,
                  child: Icon(
                    Icons.check,
                    size: widget.size * 0.7,
                    color: checkColor,
                  ),
                )
              : null,
        ),
      ),
    );
  }
}

/// Чекбокс с трёмя состояниями: Принял / Пропустил / Не отмечено
class TriStateCheckBox extends StatefulWidget {
  /// 0 - не отмечено, 1 - принял, 2 - пропустил
  final int value;
  final ValueChanged<int> onChanged;
  final double size;

  const TriStateCheckBox({
    super.key,
    required this.value,
    required this.onChanged,
    this.size = 24,
  });

  @override
  State<TriStateCheckBox> createState() => _TriStateCheckBoxState();
}

class _TriStateCheckBoxState extends State<TriStateCheckBox>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.85).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    _controller.forward().then((_) {
      _controller.reverse();
    });

    // Циклическое переключение: не отмечено -> принял -> пропустил -> не отмечено
    final nextValue = (widget.value + 1) % 3;
    widget.onChanged(nextValue);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Color getColor() {
      switch (widget.value) {
        case 1: // Принял
          return Colors.green;
        case 2: // Пропустил
          return Colors.orange;
        default: // Не отмечено
          return theme.colorScheme.outline;
      }
    }

    IconData getIcon() {
      switch (widget.value) {
        case 1: // Принял
          return Icons.check_circle;
        case 2: // Пропустил
          return Icons.cancel;
        default: // Не отмечено
          return Icons.radio_button_unchecked;
      }
    }

    return GestureDetector(
      onTap: _handleTap,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          child: Icon(
            getIcon(),
            size: widget.size,
            color: getColor(),
          ),
        ),
      ),
    );
  }
}
