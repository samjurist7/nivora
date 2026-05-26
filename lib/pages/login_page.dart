import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../services/user_service.dart';
import '../services/websocket_service.dart';
import '../theme/mechanical_theme.dart';
import 'choose_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _forgotEmailCtrl = TextEditingController();
  bool loading = false;
  bool isLoginMode = true; // true = login, false = register
  bool isForgotMode = false;
  bool isEmailSentMode = false;
  String _sentToEmail = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fillSavedCredentials();
    });
  }

  void _fillSavedCredentials() {
    final userService = Provider.of<UserService>(context, listen: false);
    if (userService.initialized) {
      if (userService.savedEmail != null) _emailCtrl.text = userService.savedEmail!;
      if (userService.savedPassword != null) _passCtrl.text = userService.savedPassword!;
    } else {
      // 还没加载完，等通知
      userService.addListener(_onUserServiceReady);
    }
  }

  void _onUserServiceReady() {
    final userService = Provider.of<UserService>(context, listen: false);
    if (userService.initialized) {
      userService.removeListener(_onUserServiceReady);
      if (userService.savedEmail != null) _emailCtrl.text = userService.savedEmail!;
      if (userService.savedPassword != null) _passCtrl.text = userService.savedPassword!;
    }
  }

  @override
  void dispose() {
    final userService = Provider.of<UserService>(context, listen: false);
    userService.removeListener(_onUserServiceReady);
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _nameCtrl.dispose();
    _forgotEmailCtrl.dispose();
    super.dispose();
  }

  void doLogin() async {
    final email = _emailCtrl.text.trim();
    final password = _passCtrl.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter email and password'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => loading = true);

    final api = Provider.of<ApiService>(context, listen: false);
    final userService = Provider.of<UserService>(context, listen: false);
    final wsService = Provider.of<WebSocketService>(context, listen: false);

    try {
      final result = await api.login(email, password);

      print('🔐 Login result: $result');

      setState(() => loading = false);

      if (result['success'] == true) {
        final token = result['token'] as String;
        print('✅ Login success, token: $token');

        // 先用 email 登录，再从服务器获取真实用户名，同时保存邮箱密码
        await userService.login(email, token: token, email: email, password: password);
        print('✅ User service login done');

        // 从服务器获取用户名
        final profile = await api.getProfile(token);
        if (profile['success'] == true && profile['name'] != null) {
          await userService.updateUsername(profile['name'] as String);
          print('✅ Username fetched: ${profile['name']}');
        }

        wsService.connect();
        print('✅ WebSocket connect called');

        if (!mounted) return;

        print('🚀 Navigating to ChoosePage...');
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => const ChoosePage(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 500),
          ),
        );
        print('✅ Navigation done');
      } else {
        final error = result['error'] ?? 'Login failed';
        print('❌ Login failed: $error');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error),
            backgroundColor: MechanicalTheme.warningRed,
          ),
        );
      }
    } catch (e) {
      print('💥 Login exception: $e');
      setState(() => loading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Login error: $e'),
          backgroundColor: MechanicalTheme.warningRed,
        ),
      );
    }
  }

  void doRegister() async {
    final email = _emailCtrl.text.trim();
    final password = _passCtrl.text.trim();
    final name = _nameCtrl.text.trim();

    if (email.isEmpty || password.isEmpty || name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all fields'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    if (!emailRegex.hasMatch(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid email address'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => loading = true);

    final api = Provider.of<ApiService>(context, listen: false);
    final result = await api.register(email, password, name: name);

    setState(() => loading = false);

    if (!mounted) return;

    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Activation email sent. Please check your inbox.'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 5),
        ),
      );
      // 停留在注册页，用户激活后再来登录
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['error'] ?? 'Registration failed'),
          backgroundColor: MechanicalTheme.warningRed,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 60),
                // Logo 区域
                _buildLogoSection(),
                const SizedBox(height: 50),
                // 表单容器
                _buildFormContainer(),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogoSection() {
    return Column(
      children: [
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Color(0xFFFF512F), Color(0xFFFF6B35)],
          ).createShader(bounds),
          child: const Text(
            'ShishaX',
            style: TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: 1,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: 50,
          height: 3,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFFF512F), Color(0xFFFF6B35)],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'UPGRADE YOUR SESSION',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: Colors.white.withOpacity(0.5),
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildFormContainer() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          if (isForgotMode) ...[
            if (isEmailSentMode) _buildEmailSentContent() else _buildForgotContent(),
          ] else ...[
            // Tab 切换
            _buildTabBar(),
            const SizedBox(height: 24),
            // 表单内容
            if (isLoginMode) _buildLoginForm() else _buildRegisterForm(),
          ],
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final tabWidth = constraints.maxWidth / 2;
        return Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      if (!isLoginMode) {
                        _nameCtrl.clear();
                        setState(() => isLoginMode = true);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'LOGIN',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.5,
                          color: isLoginMode ? Colors.white : Colors.white.withOpacity(0.5),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      if (isLoginMode) {
                        setState(() => isLoginMode = false);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'REGISTER',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.5,
                          color: !isLoginMode ? Colors.white : Colors.white.withOpacity(0.5),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            // 底部指示器线条
            Stack(
              children: [
                Container(
                  width: double.infinity,
                  height: 2,
                  color: Colors.white.withOpacity(0.2),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  margin: EdgeInsets.only(left: isLoginMode ? 0 : tabWidth),
                  width: tabWidth,
                  height: 2,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFFFF512F), Color(0xFFFF6B35)],
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildLoginForm() {
    return Column(
      children: [
        _buildTextField(
          controller: _emailCtrl,
          label: 'EMAIL',
          hint: 'your@email.com',
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _passCtrl,
          label: 'PASSWORD',
          hint: '••••••••',
          obscureText: true,
        ),
        const SizedBox(height: 24),
        _buildActionGradientButton(
          text: 'LOGIN',
          onTap: loading ? null : doLogin,
        ),
        const SizedBox(height: 16),
        _buildForgotPasswordLink(),
      ],
    );
  }

  Widget _buildRegisterForm() {
    return Column(
      children: [
        _buildTextField(
          controller: _nameCtrl,
          label: 'NAME',
          hint: 'Your name',
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _emailCtrl,
          label: 'EMAIL',
          hint: 'your@email.com',
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _passCtrl,
          label: 'PASSWORD',
          hint: '••••••••',
          obscureText: true,
        ),
        const SizedBox(height: 24),
        _buildActionGradientButton(
          text: 'CREATE ACCOUNT',
          onTap: loading ? null : doRegister,
        ),
        const SizedBox(height: 16),
        _buildForgotPasswordLink(),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    bool obscureText = false,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: Colors.white.withOpacity(0.5),
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        hintText: hint,
        hintStyle: TextStyle(
          color: Colors.white.withOpacity(0.3),
          fontSize: 14,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(25),
          borderSide: BorderSide(
            color: Colors.white.withOpacity(0.3),
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(25),
          borderSide: const BorderSide(
            color: Color(0xFFFF512F),
            width: 1.5,
          ),
        ),
        filled: true,
        fillColor: Colors.black,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ),
    );
  }

  Widget _buildActionGradientButton({
    required String text,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 45,
        decoration: BoxDecoration(
          gradient: onTap == null
              ? null
              : const LinearGradient(
                  colors: [Color(0xFFFF512F), Color(0xFFFF6B35)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
          color: onTap == null ? Colors.grey.shade800 : null,
          borderRadius: BorderRadius.circular(22),
        ),
        child: loading
            ? const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              )
            : Center(
                child: Text(
                  text,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1,
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildForgotContent() {
    return Column(
      children: [
        Text(
          'RESET PASSWORD',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          "Enter your email and we'll send you a link to reset your password.",
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            color: Colors.white.withOpacity(0.55),
            height: 1.5,
          ),
        ),
        const SizedBox(height: 24),
        _buildTextField(
          controller: _forgotEmailCtrl,
          label: 'EMAIL',
          hint: 'your@email.com',
        ),
        const SizedBox(height: 24),
        _buildActionGradientButton(
          text: 'SEND RESET LINK',
          onTap: loading ? null : doForgotPassword,
        ),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: () => setState(() => isForgotMode = false),
          child: Text(
            'Back to Login',
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmailSentContent() {
    return Column(
      children: [
        Text(
          'RESET PASSWORD',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 28),
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [Color(0xFFFF512F), Color(0xFFFF6B35)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: const Icon(Icons.email_outlined, color: Colors.white, size: 34),
        ),
        const SizedBox(height: 20),
        const Text(
          'CHECK YOUR EMAIL',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'We have sent a password reset link to:',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            color: Colors.white.withOpacity(0.55),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _sentToEmail,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 28),
        _buildActionGradientButton(
          text: 'BACK TO LOGIN',
          onTap: () => setState(() {
            isForgotMode = false;
            isEmailSentMode = false;
          }),
        ),
      ],
    );
  }

  void doForgotPassword() async {
    final email = _forgotEmailCtrl.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your email'), backgroundColor: Colors.orange),
      );
      return;
    }
    setState(() => loading = true);
    final api = Provider.of<ApiService>(context, listen: false);
    await api.forgotPassword(email);
    setState(() {
      loading = false;
      _sentToEmail = email;
      isEmailSentMode = true;
    });
  }

  Widget _buildForgotPasswordLink() {
    return GestureDetector(
      onTap: () {
        _forgotEmailCtrl.text = _emailCtrl.text; // 预填已输入的邮箱
        setState(() {
          isForgotMode = true;
          isEmailSentMode = false;
        });
      },
      child: Text(
        'Forgot password?',
        style: TextStyle(
          color: Colors.white.withOpacity(0.5),
          fontSize: 12,
        ),
      ),
    );
  }
}
