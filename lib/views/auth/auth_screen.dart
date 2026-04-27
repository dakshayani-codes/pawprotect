// lib/views/auth/auth_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/auth_viewmodel.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({Key? key}) : super(key: key);

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLogin = true;

  final _nameCtrl     = TextEditingController();
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscurePass   = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) return;
      setState(() => _isLogin = _tabController.index == 0);
      context.read<AuthViewModel>().clearError();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final authVM = context.read<AuthViewModel>();
    if (_isLogin) {
      await authVM.signIn(_emailCtrl.text, _passwordCtrl.text);
    } else {
      await authVM.signUp(
          _nameCtrl.text, _emailCtrl.text, _passwordCtrl.text);
      // Check if we should redirect to sign-in after successful signup
      if (!mounted) return;
      final vm = context.read<AuthViewModel>();
      if (vm.pendingAction == AuthAction.switchToSignIn) {
        vm.clearPendingAction();
        _tabController.animateTo(0);
        setState(() => _isLogin = true);
        _nameCtrl.clear();
        _passwordCtrl.clear();
        _showInfo(vm.infoMessage);
      }
    }
  }

  void _showInfo(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: Colors.black,
      behavior: SnackBarBehavior.floating,
    ));
  }

  Future<void> _forgotPassword() async {
    final authVM = context.read<AuthViewModel>();
    await authVM.sendForgotPassword(_emailCtrl.text);
    if (!mounted) return;
    if (authVM.pendingAction == AuthAction.showResetSent) {
      authVM.clearPendingAction();
      _showInfo(authVM.infoMessage);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authVM = context.watch<AuthViewModel>();

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              const SizedBox(height: 40),

              const Text('🐾', style: TextStyle(fontSize: 64)),
              const SizedBox(height: 8),
              Text('PAWPROTECT',
                  style: GoogleFonts.vt323(
                      fontSize: 36,
                      letterSpacing: 6,
                      fontWeight: FontWeight.bold)),
              Text('your phone habit, but make it cute',
                  style: TextStyle(color: Colors.grey[500], fontSize: 13)),

              const SizedBox(height: 36),

              // ── Tab selector ─────────────────────────────────────────────
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(50),
                ),
                child: TabBar(
                  controller: _tabController,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.black54,
                  indicator: BoxDecoration(
                      borderRadius: BorderRadius.circular(50),
                      color: Colors.black),
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  tabs: const [
                    Tab(text: 'SIGN IN'),
                    Tab(text: 'SIGN UP'),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // ── Name field (signup only) ──────────────────────────────────
              AnimatedCrossFade(
                duration: const Duration(milliseconds: 250),
                crossFadeState: _isLogin
                    ? CrossFadeState.showFirst
                    : CrossFadeState.showSecond,
                firstChild: const SizedBox.shrink(),
                secondChild: Column(
                  children: [
                    _buildField(
                        controller: _nameCtrl,
                        label: 'Your Name',
                        icon: Icons.person_outline),
                    const SizedBox(height: 12),
                  ],
                ),
              ),

              // ── Email ─────────────────────────────────────────────────────
              _buildField(
                  controller: _emailCtrl,
                  label: 'Email',
                  icon: Icons.mail_outline,
                  type: TextInputType.emailAddress),
              const SizedBox(height: 12),

              // ── Password ──────────────────────────────────────────────────
              _buildField(
                  controller: _passwordCtrl,
                  label: 'Password',
                  icon: Icons.lock_outline,
                  obscure: _obscurePass,
                  suffix: IconButton(
                    icon: Icon(
                        _obscurePass
                            ? Icons.visibility_off
                            : Icons.visibility,
                        size: 20,
                        color: Colors.grey),
                    onPressed: () =>
                        setState(() => _obscurePass = !_obscurePass),
                  )),

              // ── Forgot Password (sign-in only) ────────────────────────────
              if (_isLogin)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: authVM.isLoading ? null : _forgotPassword,
                    child: Text('forgot password?',
                        style: TextStyle(
                            color: Colors.grey[500], fontSize: 12)),
                  ),
                )
              else
                const SizedBox(height: 8),

              // ── Error ─────────────────────────────────────────────────────
              if (authVM.state == AuthState.error)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                      color: const Color(0xFFFFEEF2),
                      borderRadius: BorderRadius.circular(10)),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline,
                          color: Color(0xFFFF006E), size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(authVM.errorMessage,
                            style: const TextStyle(
                                color: Color(0xFFFF006E), fontSize: 13)),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 12),

              // ── Submit ────────────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: authVM.isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(50)),
                      elevation: 0),
                  child: authVM.isLoading
                      ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                      : Text(
                      _isLogin ? 'LET ME IN' : 'CREATE ACCOUNT',
                      style: GoogleFonts.vt323(
                          fontSize: 20, letterSpacing: 3)),
                ),
              ),

              const SizedBox(height: 12),

              // ── Divider ───────────────────────────────────────────────────
              Row(children: [
                Expanded(child: Divider(color: Colors.grey[200])),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text('or',
                      style: TextStyle(
                          color: Colors.grey[400], fontSize: 12)),
                ),
                Expanded(child: Divider(color: Colors.grey[200])),
              ]),

              const SizedBox(height: 12),

              // ── Google Sign-In ────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: authVM.isLoading
                      ? null
                      : () async {
                    await authVM.signInWithGoogle();
                    if (mounted && authVM.state == AuthState.error) {
                      _showInfo(authVM.errorMessage);
                      authVM.clearError();
                    }
                  },
                  icon: const Text('G',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.red)),
                  label: const Text('Continue with Google'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: BorderSide(color: Colors.grey[300]!),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(50)),
                  ),
                ),
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType type = TextInputType.text,
    bool obscure = false,
    Widget? suffix,
  }) {
    return TextField(
      controller: controller,
      keyboardType: type,
      obscureText: obscure,
      style: const TextStyle(fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20, color: Colors.grey),
        suffixIcon: suffix,
        filled: true,
        fillColor: Colors.grey[50],
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.grey[200]!)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.grey[200]!)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide:
            const BorderSide(color: Colors.black, width: 1.5)),
        contentPadding:
        const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
      ),
    );
  }
}
