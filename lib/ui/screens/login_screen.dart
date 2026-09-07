import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../providers/app_provider.dart';
import '../base/base_screen.dart';
import '../base/base_card.dart';
import '../components/blur_button.dart';
import '../components/loading_spinner.dart';
import '../components/validation_dialog.dart';

class LoginScreen extends BaseScreen {
  const LoginScreen({super.key});

  @override
  BaseScreenState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends BaseScreenState<LoginScreen> {
  bool isLogin = true;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

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
    FocusManager.instance.primaryFocus?.unfocus();
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
  Widget buildBody(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
        child: GlassCardWidget(
          borderRadius: 28.0,
          padding: const EdgeInsets.symmetric(horizontal: 26.0, vertical: 34.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Glowing Glass Emblem
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.08),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.25),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.10),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Icon(
                  isLogin ? Icons.lock_outline_rounded : Icons.person_add_outlined,
                  color: Colors.white,
                  size: 26,
                ),
              ),
              const SizedBox(height: 18),

              Text(
                isLogin ? "Welcome to Ducat" : "Create Account",
                style: AppTypography.screenTitle.copyWith(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                isLogin
                    ? "Enter your credentials to continue"
                    : "Track your finances with ease and elegance",
                style: GoogleFonts.castoro(
                  fontSize: 13,
                  color: Colors.white.withValues(alpha: 0.55),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),

              _buildTextField(
                hint: "Email address",
                controller: _emailController,
                prefixIcon: Icons.alternate_email_rounded,
                isPassword: false,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 14),

              _buildTextField(
                hint: "Password",
                controller: _passwordController,
                prefixIcon: Icons.lock_outline_rounded,
                isPassword: true,
                isObscure: _obscurePassword,
                onToggleObscure: () => setState(() => _obscurePassword = !_obscurePassword),
                textInputAction: isLogin ? TextInputAction.done : TextInputAction.next,
                onSubmitted: isLogin ? (_) => _submit() : null,
              ),

              if (!isLogin) ...[
                const SizedBox(height: 14),
                _buildTextField(
                  hint: "Confirm Password",
                  controller: _confirmPasswordController,
                  prefixIcon: Icons.verified_user_outlined,
                  isPassword: true,
                  isObscure: _obscureConfirmPassword,
                  onToggleObscure: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                ),
              ],
              const SizedBox(height: 26),

              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: SizedBox(
                    height: 50,
                    child: Center(
                      child: LoadingSpinner(size: 26),
                    ),
                  ),
                )
              else
                BlurButton(
                  text: isLogin ? "Sign In" : "Sign Up",
                  onPressed: _submit,
                ),
              const SizedBox(height: 18),

              // Elegant Glass Divider
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 1,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withValues(alpha: 0.0),
                            Colors.white.withValues(alpha: 0.18),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Text(
                      "or",
                      style: GoogleFonts.castoro(
                        color: Colors.white.withValues(alpha: 0.45),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      height: 1,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withValues(alpha: 0.18),
                            Colors.white.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

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
                child: Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: RichText(
                    text: TextSpan(
                      style: GoogleFonts.castoro(
                        fontSize: 13.5,
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                      children: [
                        TextSpan(
                          text: isLogin ? "Don't have an account? " : "Already have an account? ",
                        ),
                        TextSpan(
                          text: isLogin ? "Sign Up" : "Sign In",
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String hint,
    required TextEditingController controller,
    required IconData prefixIcon,
    required bool isPassword,
    bool isObscure = false,
    VoidCallback? onToggleObscure,
    TextInputType keyboardType = TextInputType.text,
    TextInputAction textInputAction = TextInputAction.done,
    ValueChanged<String>? onSubmitted,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.16),
          width: 1.0,
        ),
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword && isObscure,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        onSubmitted: onSubmitted,
        style: GoogleFonts.castoro(color: Colors.white, fontSize: 15),
        cursorColor: Colors.white,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.castoro(
            color: Colors.white.withValues(alpha: 0.35),
            fontSize: 14,
          ),
          prefixIcon: Icon(
            prefixIcon,
            color: Colors.white.withValues(alpha: 0.6),
            size: 20,
          ),
          suffixIcon: isPassword
              ? GestureDetector(
                  onTap: onToggleObscure,
                  child: Icon(
                    isObscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    color: Colors.white.withValues(alpha: 0.45),
                    size: 20,
                  ),
                )
              : null,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          border: InputBorder.none,
        ),
      ),
    );
  }
}
