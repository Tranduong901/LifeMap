import 'package:flutter/material.dart';

import '../main_screen.dart';
import '../../services/auth_service.dart';

class AuthView extends StatefulWidget {
  const AuthView({super.key});

  @override
  State<AuthView> createState() => _AuthViewState();
}

class _AuthViewState extends State<AuthView> {
  static const Color _kLavender = Color(0xFF9575CD);
  static const Color _kSlate = Color(0xFF78909C);
  static const Color _kIndigoLight = Color(0xFF7986CB);
  static const Color _kPrimaryButton = Color(0xFF7E57C2);

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

  InputDecoration _buildInputDecoration({
    required String labelText,
    String? hintText,
  }) {
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      floatingLabelAlignment: FloatingLabelAlignment.start,
      hintStyle: TextStyle(color: _kSlate.withValues(alpha: 0.9)),
      filled: true,
      fillColor: const Color(0xFFF5F7FA),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(
          color: _kLavender.withValues(alpha: 0.22),
          width: 0.5,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(
          color: _kLavender.withValues(alpha: 0.22),
          width: 0.5,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: _kLavender, width: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: <Color>[
              const Color(0xFFF0F2F5),
              const Color(0xFFE8EAF6),
              const Color(0xFFF5F7FA),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Container(
                    key: ValueKey<bool>(_isLogin),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: const Color(
                            0xFF1F2937,
                          ).withValues(alpha: 0.14),
                          blurRadius: 30,
                          offset: const Offset(0, 16),
                        ),
                      ],
                      border: Border.all(color: Colors.white, width: 1.2),
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
                                Color(0xFF9575CD),
                                Color(0xFF7986CB),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Column(
                            children: <Widget>[
                              const Icon(
                                Icons.location_on_rounded,
                                size: 30,
                                color: Colors.white,
                              ),
                              const SizedBox(height: 20),
                              Text(
                                _isLogin
                                    ? 'Chào mừng bạn trở lại!'
                                    : 'Tạo tài khoản để lưu kỷ niệm của bạn',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.titleLarge?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _isLogin
                                    ? 'Đăng nhập nhanh để xem bản đồ và dòng thời gian kỷ niệm.'
                                    : 'Chỉ mất vài giây để bắt đầu lưu lại những nơi bạn đã đi qua.',
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
                            decoration: _buildInputDecoration(
                              labelText: 'Bạn muốn mình gọi là gì?',
                              hintText: 'Tên hiển thị trên bản đồ của bạn',
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        TextField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: _buildInputDecoration(
                            labelText: 'Email đăng nhập',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _passwordController,
                          obscureText: true,
                          decoration: _buildInputDecoration(
                            labelText: 'Mật khẩu của bạn',
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
                            backgroundColor: _kPrimaryButton,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 2,
                            shadowColor: _kPrimaryButton.withValues(
                              alpha: 0.24,
                            ),
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
                              loadingBuilder:
                                  (
                                    BuildContext context,
                                    Widget child,
                                    ImageChunkEvent? loadingProgress,
                                  ) {
                                    if (loadingProgress == null) {
                                      return child;
                                    }
                                    return const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: Center(
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    );
                                  },
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
                            side: BorderSide(color: const Color(0xFFE5E7EB)),
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF111827),
                            elevation: 0,
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
                                  ? 'Bạn chưa có tài khoản? Tạo mới ngay'
                                  : 'Bạn đã có tài khoản? Đăng nhập luôn',
                              style: const TextStyle(
                                color: _kIndigoLight,
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
