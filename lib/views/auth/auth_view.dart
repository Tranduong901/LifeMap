import 'package:flutter/material.dart';

import '../main_screen.dart';
import '../../services/auth_service.dart';

class AuthView extends StatefulWidget {
  const AuthView({super.key});

  @override
  State<AuthView> createState() => _AuthViewState();
}

class _AuthViewState extends State<AuthView> {
  final AuthService _authService = AuthService();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _isLogin = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signInWithEmail() async {
    final String email = _emailController.text.trim();
    final String password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      _showMessage('Vui lòng nhập đầy đủ email và mật khẩu.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _authService.signInWithEmailPassword(
        email: email,
        password: password,
      );
      _showMessage('Đăng nhập thành công.');
    } catch (e) {
      _showMessage(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _signUpWithEmail() async {
    final String name = _nameController.text.trim();
    final String email = _emailController.text.trim();
    final String password = _passwordController.text;

    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      _showMessage('Vui lòng nhập đầy đủ tên, email và mật khẩu.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _authService.signUpWithEmail(
        email: email,
        password: password,
        name: name,
      );
      _showMessage('Đăng ký thành công.');
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(builder: (_) => const MainScreen()),
        );
      }
    } catch (e) {
      _showMessage(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);

    try {
      debugPrint('Đang mở cửa sổ chọn tài khoản Google...');
      await _authService.signInWithGoogle();
      _showMessage('Đăng nhập Google thành công.');
    } catch (e) {
      _showMessage(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: <Color>[
              Color(0xFF312E81),
              Color(0xFF4F46E5),
              Color(0xFF818CF8),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Container(
                    key: ValueKey<bool>(_isLogin),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF111827) : Colors.white,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.18),
                          blurRadius: 28,
                          offset: const Offset(0, 18),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: <Color>[
                                Color(0xFF4F46E5),
                                Color(0xFF7C3AED),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Column(
                            children: <Widget>[
                              const Icon(
                                Icons.location_on_rounded,
                                size: 36,
                                color: Colors.white,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _isLogin
                                    ? 'Chào mừng quay lại'
                                    : 'Tạo tài khoản LifeMap',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _isLogin
                                    ? 'Đăng nhập để tiếp tục sử dụng ứng dụng'
                                    : 'Đăng ký để bắt đầu hành trình của bạn',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.9),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        if (!_isLogin) ...<Widget>[
                          TextField(
                            controller: _nameController,
                            decoration: InputDecoration(
                              labelText: 'Họ tên',
                              filled: true,
                              fillColor: isDark
                                  ? const Color(0xFF1F2937)
                                  : const Color(0xFFF8FAFC),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        TextField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            labelText: 'Email',
                            filled: true,
                            fillColor: isDark
                                ? const Color(0xFF1F2937)
                                : const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _passwordController,
                          obscureText: true,
                          decoration: InputDecoration(
                            labelText: 'Mật khẩu',
                            filled: true,
                            fillColor: isDark
                                ? const Color(0xFF1F2937)
                                : const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _isLoading
                              ? null
                              : (_isLogin
                                    ? _signInWithEmail
                                    : _signUpWithEmail),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4F46E5),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 8,
                            shadowColor: const Color(
                              0xFF4F46E5,
                            ).withValues(alpha: 0.35),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(_isLogin ? 'Đăng nhập' : 'Đăng ký'),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: _isLoading ? null : _signInWithGoogle,
                          icon: Container(
                            width: 22,
                            height: 22,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                            ),
                            child: Image.network(
                              'https://www.gstatic.com/firebasejs/ui/2.0.0/images/auth/google.svg',
                              errorBuilder: (context, error, stackTrace) =>
                                  const Icon(Icons.g_mobiledata),
                            ),
                          ),
                          label: const Text('Đăng nhập với Google'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            side: BorderSide(
                              color: const Color(
                                0xFF4F46E5,
                              ).withValues(alpha: 0.3),
                            ),
                            backgroundColor: isDark
                                ? const Color(0xFF111827)
                                : Colors.white,
                            foregroundColor: const Color(0xFF111827),
                            elevation: 4,
                            shadowColor: Colors.black.withValues(alpha: 0.12),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Center(
                          child: TextButton(
                            onPressed: _isLoading
                                ? null
                                : () => setState(() {
                                    _isLogin = !_isLogin;
                                    _nameController.clear();
                                    _emailController.clear();
                                    _passwordController.clear();
                                  }),
                            child: Text(
                              _isLogin
                                  ? 'Chưa có tài khoản? Đăng ký ngay'
                                  : 'Đã có tài khoản? Đăng nhập',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
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
    );
  }
}
