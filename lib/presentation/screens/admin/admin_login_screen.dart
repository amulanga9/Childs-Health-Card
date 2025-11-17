import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/admin_auth_provider.dart';
import '../../providers/admin_logs_provider.dart';

/// Экран входа в админку
class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _pinController = TextEditingController();
  bool _isObscure = true;
  bool _isLoading = false;
  bool _needsSecondFactor = false;

  @override
  void dispose() {
    _passwordController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    final adminAuth = context.read<AdminAuthProvider>();
    final adminLogs = context.read<AdminLogsProvider>();

    // Вход с опциональным PIN-кодом
    final result = await adminAuth.login(
      _passwordController.text,
      secondCode: _needsSecondFactor ? _pinController.text : null,
    );

    if (result == 'OK' && mounted) {
      // Логируем успешный вход
      await adminLogs.add(
        action: 'login',
        entityType: 'security',
        adminName: adminAuth.name,
      );

      // Переходим на панель администратора
      context.go('/admin');
    } else if (result == 'NEED_SECOND' && mounted) {
      // Нужен второй фактор
      setState(() {
        _isLoading = false;
        _needsSecondFactor = true;
      });
    } else if (mounted) {
      // Логируем неудачную попытку
      await adminLogs.add(
        action: 'failed_login',
        entityType: 'security',
        adminName: 'Unknown',
        entityName: result,
      );

      // Показываем ошибку
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result),
          backgroundColor: Colors.red,
        ),
      );

      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final adminAuth = context.watch<AdminAuthProvider>();

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              theme.colorScheme.primary,
              theme.colorScheme.primaryContainer,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Card(
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Иконка
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primaryContainer,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.admin_panel_settings,
                              size: 64,
                              color: theme.colorScheme.primary,
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Заголовок
                          Text(
                            _needsSecondFactor ? 'Второй фактор' : 'Вход в админку',
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          const SizedBox(height: 8),

                          Text(
                            _needsSecondFactor
                                ? 'Введите PIN-код'
                                : 'Введите пароль администратора',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: Colors.grey,
                            ),
                            textAlign: TextAlign.center,
                          ),

                          const SizedBox(height: 32),

                          // Rate limiting status
                          if (adminAuth.isLocked)
                            Container(
                              padding: const EdgeInsets.all(12),
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.red),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.lock, color: Colors.red),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'Заблокировано: ${adminAuth.lockTime}',
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        color: Colors.red[700],
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else if (!_needsSecondFactor && adminAuth.attemptsLeft < 5)
                            Container(
                              padding: const EdgeInsets.all(12),
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                color: Colors.orange.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.warning, color: Colors.orange),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Осталось попыток: ${adminAuth.attemptsLeft}',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: Colors.orange[700],
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          // Поле пароля или PIN
                          if (!_needsSecondFactor)
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _isObscure,
                              keyboardType: TextInputType.number,
                              maxLength: 20,
                              enabled: !adminAuth.isLocked,
                              decoration: InputDecoration(
                                labelText: 'Пароль',
                                prefixIcon: const Icon(Icons.lock),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _isObscure
                                        ? Icons.visibility
                                        : Icons.visibility_off,
                                  ),
                                  onPressed: () {
                                    setState(() => _isObscure = !_isObscure);
                                  },
                                ),
                                border: const OutlineInputBorder(),
                                counterText: '',
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Введите пароль';
                                }
                                return null;
                              },
                              onFieldSubmitted: (_) => _handleLogin(),
                            )
                          else
                            TextFormField(
                              controller: _pinController,
                              obscureText: true,
                              keyboardType: TextInputType.number,
                              maxLength: 6,
                              autofocus: true,
                              decoration: const InputDecoration(
                                labelText: 'PIN-код',
                                prefixIcon: Icon(Icons.pin),
                                border: OutlineInputBorder(),
                                counterText: '',
                                helperText: 'Введите 4-значный PIN или резервный код',
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Введите PIN-код';
                                }
                                return null;
                              },
                              onFieldSubmitted: (_) => _handleLogin(),
                            ),

                          const SizedBox(height: 24),

                          // Кнопка входа
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: FilledButton(
                              onPressed: (_isLoading || adminAuth.isLocked) ? null : _handleLogin,
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Text(_needsSecondFactor ? 'Подтвердить' : 'Войти'),
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Кнопка назад
                          if (_needsSecondFactor)
                            TextButton.icon(
                              onPressed: () {
                                setState(() {
                                  _needsSecondFactor = false;
                                  _pinController.clear();
                                });
                              },
                              icon: const Icon(Icons.arrow_back),
                              label: const Text('Назад к паролю'),
                            )
                          else
                            TextButton.icon(
                              onPressed: () => context.go('/home'),
                              icon: const Icon(Icons.arrow_back),
                              label: const Text('Вернуться в приложение'),
                            ),

                          const SizedBox(height: 24),

                          // Информация
                          if (!_needsSecondFactor)
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.info_outline,
                                    size: 20,
                                    color: Colors.blue,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'Пароль по умолчанию: 0000\nИзменить пароль можно в настройках',
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: Colors.blue[700],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
