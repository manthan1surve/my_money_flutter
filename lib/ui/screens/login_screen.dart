import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../components/app_background.dart';
import '../components/glass_card.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../components/blur_button.dart';
import '../components/validation_dialog.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool isLogin = true;
  bool _isLoading = false;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      showValidationDialog(context, 'Please fill in all fields.');
      return;
    }

    if (!isLogin && password != confirmPassword) {
      showValidationDialog(context, 'Passwords do not match.');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final provider = Provider.of<AppProvider>(context, listen: false);
      if (isLogin) {
        await provider.signInWithEmailAndPassword(email, password);
      } else {
        await provider.signUpWithEmailAndPassword(email, password);
      }
    } catch (e) {
      if (!mounted) return;
      showValidationDialog(context, isLogin ? 'Login failed: $e' : 'Registration failed: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: GlassCard(
                padding: const EdgeInsets.all(30.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isLogin ? "Welcome to Ducat" : "Create Account",
                      style: AppTypography.screenTitle,
                    ),
                    const SizedBox(height: 30),
                    _buildTextField("Email", _emailController, false),
                    const SizedBox(height: 15),
                    _buildTextField("Password", _passwordController, true),
                    if (!isLogin) ...[
                      const SizedBox(height: 15),
                      _buildTextField("Confirm Password", _confirmPasswordController, true),
                    ],
                    const SizedBox(height: 30),
                    if (_isLoading)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 10),
                          child: CircularProgressIndicator(color: AppColors.accent),
                        ),
                      )
                    else
                      BlurButton(
                        text: isLogin ? "Sign In" : "Sign Up",
                        onPressed: _submit,
                      ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.15))),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Text("or", style: TextStyle(color: Colors.white.withValues(alpha: 0.4))),
                        ),
                        Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.15))),
                      ],
                    ),
                    const SizedBox(height: 20),
                    BlurButton(
                      text: "Continue with Google",
                      imagePath: 'assets/google.png',
                      onPressed: () async {
                        try {
                          await Provider.of<AppProvider>(context, listen: false).signInWithGoogle();
                        } catch (e) {
                          if (!context.mounted) return;
                          showValidationDialog(context, 'Login failed: $e');
                        }
                      },
                    ),
                    const SizedBox(height: 20),
                    GestureDetector(
                      onTap: () => setState(() => isLogin = !isLogin),
                      child: Text(
                        isLogin ? "Don't have an account? Sign Up" : "Already have an account? Sign In",
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          decoration: TextDecoration.underline,
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
    );
  }

  Widget _buildTextField(String hint, TextEditingController controller, bool isPassword) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(10.0),
        border: Border.all(color: const Color(0xFF333333)),
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          border: InputBorder.none,
        ),
      ),
    );
  }
}
