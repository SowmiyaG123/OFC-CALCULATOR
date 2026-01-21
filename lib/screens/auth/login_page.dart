import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/auth_service.dart';
import '../../utils/constants.dart';
import 'register_page.dart';
import 'forgot_password_page.dart';
import '../main_app/main_dashboard.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  bool _isLoading = false;
  bool _rememberMe = false;
  bool _obscurePassword = true;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<Offset> _slideAnimation;

  final FocusNode _emailFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _checkExistingUser();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeInOut),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.4, 1.0, curve: Curves.easeOutBack),
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.2, 0.8, curve: Curves.easeOutCubic),
      ),
    );

    _animationController.forward();
  }

  void _checkExistingUser() async {
    final user = await _authService.getCurrentUser();
    if (user != null && mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainDashboard()),
      );
    }
  }

  void _login() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        final user = await _authService.login(
          _emailController.text.trim(),
          _passwordController.text,
        );

        if (user != null && mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const MainDashboard()),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Login failed: ${e.toString()}'),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              margin: const EdgeInsets.all(16),
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isLargeScreen = size.width > 600;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppConstants.primaryColor.withOpacity(0.03),
              AppConstants.primaryColor.withOpacity(0.08),
              Colors.white,
            ],
            stops: const [0.0, 0.3, 0.7],
          ),
        ),
        child: Stack(
          children: [
            // Background decorative elements
            Positioned(
              top: -100,
              right: -100,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      AppConstants.primaryColor.withOpacity(0.1),
                      AppConstants.primaryColor.withOpacity(0.05),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -150,
              left: -150,
              child: Container(
                width: 400,
                height: 400,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      AppConstants.primaryColor.withOpacity(0.08),
                      AppConstants.primaryColor.withOpacity(0.03),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: isLargeScreen ? 48 : 24,
                    vertical: 24,
                  ),
                  child: ScaleTransition(
                    scale: _scaleAnimation,
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: SlideTransition(
                        position: _slideAnimation,
                        child: Container(
                          constraints: BoxConstraints(
                            maxWidth: isLargeScreen ? 480 : double.infinity,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Logo and App Name Section
                              Container(
                                margin: const EdgeInsets.only(bottom: 40),
                                child: Column(
                                  children: [
                                    // Animated Logo Container
                                    Container(
                                      width: 100,
                                      height: 100,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            AppConstants.primaryColor,
                                            AppConstants.primaryColor
                                                .withOpacity(0.8),
                                          ],
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: AppConstants.primaryColor
                                                .withOpacity(0.3),
                                            blurRadius: 25,
                                            spreadRadius: 2,
                                            offset: const Offset(0, 10),
                                          ),
                                        ],
                                      ),
                                      child: ClipOval(
                                        child: Image.asset(
                                          'assets/logo_pic.png',
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 24),
                                    // App Name with Gradient Text
                                    ShaderMask(
                                      shaderCallback: (bounds) =>
                                          LinearGradient(
                                        colors: [
                                          AppConstants.primaryColor,
                                          AppConstants.primaryColor
                                              .withOpacity(0.8),
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ).createShader(bounds),
                                      child: Text(
                                        'NioRix FiberCalc',
                                        style: GoogleFonts.poppins(
                                          fontSize: 32,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.5,
                                          height: 1.2,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Industry Standard Fiber Optics Calculator',
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        color: Colors.grey.shade600,
                                        fontWeight: FontWeight.w400,
                                        letterSpacing: 0.3,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),

                              // Login Card
                              Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(24),
                                  color: Colors.white,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.08),
                                      blurRadius: 40,
                                      spreadRadius: 2,
                                      offset: const Offset(0, 20),
                                    ),
                                    BoxShadow(
                                      color: AppConstants.primaryColor
                                          .withOpacity(0.05),
                                      blurRadius: 60,
                                      spreadRadius: -10,
                                      offset: const Offset(0, 30),
                                    ),
                                  ],
                                  border: Border.all(
                                    color: Colors.grey.shade100,
                                    width: 1,
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(40),
                                  child: Column(
                                    children: [
                                      // Welcome Text
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Welcome Back',
                                            style: GoogleFonts.poppins(
                                              fontSize: 28,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.grey.shade900,
                                              height: 1.2,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            'Sign in to access your professional workspace',
                                            style: GoogleFonts.poppins(
                                              fontSize: 15,
                                              color: Colors.grey.shade600,
                                              fontWeight: FontWeight.w400,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 40),

                                      // Login Form
                                      Form(
                                        key: _formKey,
                                        child: Column(
                                          children: [
                                            // Email Field
                                            AnimatedContainer(
                                              duration: const Duration(
                                                  milliseconds: 300),
                                              decoration: BoxDecoration(
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                                border: Border.all(
                                                  color: _emailFocus.hasFocus
                                                      ? AppConstants
                                                          .primaryColor
                                                      : Colors.transparent,
                                                  width: 2,
                                                ),
                                              ),
                                              child: TextFormField(
                                                controller: _emailController,
                                                focusNode: _emailFocus,
                                                keyboardType:
                                                    TextInputType.emailAddress,
                                                style: GoogleFonts.poppins(
                                                  fontSize: 15,
                                                  color: Colors.grey.shade900,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                                decoration: InputDecoration(
                                                  labelText: 'Email Address',
                                                  labelStyle:
                                                      GoogleFonts.poppins(
                                                    color: _emailFocus.hasFocus
                                                        ? AppConstants
                                                            .primaryColor
                                                        : Colors.grey.shade600,
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                  hintText: 'you@gmail.com',
                                                  hintStyle:
                                                      GoogleFonts.poppins(
                                                    color: Colors.grey.shade400,
                                                    fontSize: 14,
                                                  ),
                                                  prefixIcon: Icon(
                                                    Icons.email_outlined,
                                                    color: _emailFocus.hasFocus
                                                        ? AppConstants
                                                            .primaryColor
                                                        : Colors.grey.shade500,
                                                  ),
                                                  filled: true,
                                                  fillColor:
                                                      Colors.grey.shade50,
                                                  border: OutlineInputBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            16),
                                                    borderSide: BorderSide.none,
                                                  ),
                                                  focusedBorder:
                                                      OutlineInputBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            16),
                                                    borderSide:
                                                        const BorderSide(
                                                      color: Colors.transparent,
                                                    ),
                                                  ),
                                                  contentPadding:
                                                      const EdgeInsets
                                                          .symmetric(
                                                    horizontal: 20,
                                                    vertical: 18,
                                                  ),
                                                ),
                                                validator: (value) {
                                                  if (value == null ||
                                                      value.isEmpty) {
                                                    return 'Please enter your email';
                                                  }
                                                  if (!RegExp(
                                                          r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                                                      .hasMatch(value)) {
                                                    return 'Please enter a valid email';
                                                  }
                                                  return null;
                                                },
                                              ),
                                            ),
                                            const SizedBox(height: 20),

                                            // Password Field
                                            AnimatedContainer(
                                              duration: const Duration(
                                                  milliseconds: 300),
                                              decoration: BoxDecoration(
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                                border: Border.all(
                                                  color: _passwordFocus.hasFocus
                                                      ? AppConstants
                                                          .primaryColor
                                                      : Colors.transparent,
                                                  width: 2,
                                                ),
                                              ),
                                              child: TextFormField(
                                                controller: _passwordController,
                                                focusNode: _passwordFocus,
                                                obscureText: _obscurePassword,
                                                style: GoogleFonts.poppins(
                                                  fontSize: 15,
                                                  color: Colors.grey.shade900,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                                decoration: InputDecoration(
                                                  labelText: 'Password',
                                                  labelStyle:
                                                      GoogleFonts.poppins(
                                                    color: _passwordFocus
                                                            .hasFocus
                                                        ? AppConstants
                                                            .primaryColor
                                                        : Colors.grey.shade600,
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                  hintText:
                                                      'Enter your password',
                                                  hintStyle:
                                                      GoogleFonts.poppins(
                                                    color: Colors.grey.shade400,
                                                    fontSize: 14,
                                                  ),
                                                  prefixIcon: Icon(
                                                    Icons.lock_outline,
                                                    color: _passwordFocus
                                                            .hasFocus
                                                        ? AppConstants
                                                            .primaryColor
                                                        : Colors.grey.shade500,
                                                  ),
                                                  suffixIcon: IconButton(
                                                    icon: Icon(
                                                      _obscurePassword
                                                          ? Icons
                                                              .visibility_outlined
                                                          : Icons
                                                              .visibility_off_outlined,
                                                      color:
                                                          Colors.grey.shade500,
                                                      size: 20,
                                                    ),
                                                    onPressed: () {
                                                      setState(() {
                                                        _obscurePassword =
                                                            !_obscurePassword;
                                                      });
                                                    },
                                                  ),
                                                  filled: true,
                                                  fillColor:
                                                      Colors.grey.shade50,
                                                  border: OutlineInputBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            16),
                                                    borderSide: BorderSide.none,
                                                  ),
                                                  focusedBorder:
                                                      OutlineInputBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            16),
                                                    borderSide:
                                                        const BorderSide(
                                                      color: Colors.transparent,
                                                    ),
                                                  ),
                                                  contentPadding:
                                                      const EdgeInsets
                                                          .symmetric(
                                                    horizontal: 20,
                                                    vertical: 18,
                                                  ),
                                                ),
                                                validator: (value) {
                                                  if (value == null ||
                                                      value.isEmpty) {
                                                    return 'Please enter your password';
                                                  }
                                                  if (value.length < 6) {
                                                    return 'Password must be at least 6 characters';
                                                  }
                                                  return null;
                                                },
                                              ),
                                            ),
                                            const SizedBox(height: 16),

                                            // Remember Me & Forgot Password
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                // Remember Me Checkbox
                                                Row(
                                                  children: [
                                                    Transform.scale(
                                                      scale: 0.9,
                                                      child: Checkbox(
                                                        value: _rememberMe,
                                                        onChanged: (value) {
                                                          setState(() {
                                                            _rememberMe =
                                                                value ?? false;
                                                          });
                                                        },
                                                        shape:
                                                            RoundedRectangleBorder(
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(6),
                                                        ),
                                                        side: BorderSide(
                                                          color: Colors
                                                              .grey.shade400,
                                                        ),
                                                        activeColor:
                                                            AppConstants
                                                                .primaryColor,
                                                      ),
                                                    ),
                                                    Text(
                                                      'Remember me',
                                                      style:
                                                          GoogleFonts.poppins(
                                                        fontSize: 14,
                                                        color: Colors
                                                            .grey.shade700,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                      ),
                                                    ),
                                                  ],
                                                ),

                                                // Forgot Password
                                                TextButton(
                                                  onPressed: () {
                                                    Navigator.push(
                                                      context,
                                                      MaterialPageRoute(
                                                        builder: (context) =>
                                                            const ForgotPasswordPage(),
                                                      ),
                                                    );
                                                  },
                                                  style: TextButton.styleFrom(
                                                    padding:
                                                        const EdgeInsets.all(8),
                                                  ),
                                                  child: Text(
                                                    'Forgot Password?',
                                                    style: GoogleFonts.poppins(
                                                      fontSize: 14,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: AppConstants
                                                          .primaryColor,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 32),

                                            // Sign In Button
                                            SizedBox(
                                              width: double.infinity,
                                              height: 56,
                                              child: ElevatedButton(
                                                onPressed:
                                                    _isLoading ? null : _login,
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor:
                                                      AppConstants.primaryColor,
                                                  foregroundColor: Colors.white,
                                                  disabledBackgroundColor:
                                                      AppConstants.primaryColor
                                                          .withOpacity(0.5),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            16),
                                                  ),
                                                  elevation: 0,
                                                  shadowColor:
                                                      Colors.transparent,
                                                ).copyWith(
                                                  overlayColor:
                                                      MaterialStateProperty.all(
                                                    Colors.white
                                                        .withOpacity(0.2),
                                                  ),
                                                  animationDuration:
                                                      const Duration(
                                                          milliseconds: 200),
                                                ),
                                                child: AnimatedSwitcher(
                                                  duration: const Duration(
                                                      milliseconds: 300),
                                                  child: _isLoading
                                                      ? const SizedBox(
                                                          width: 24,
                                                          height: 24,
                                                          child:
                                                              CircularProgressIndicator(
                                                            strokeWidth: 2.5,
                                                            valueColor:
                                                                AlwaysStoppedAnimation(
                                                                    Colors
                                                                        .white),
                                                          ),
                                                        )
                                                      : Row(
                                                          mainAxisAlignment:
                                                              MainAxisAlignment
                                                                  .center,
                                                          children: [
                                                            Text(
                                                              'Sign In',
                                                              style: GoogleFonts
                                                                  .poppins(
                                                                fontSize: 16,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                                letterSpacing:
                                                                    0.5,
                                                              ),
                                                            ),
                                                            const SizedBox(
                                                                width: 12),
                                                            const Icon(
                                                              Icons
                                                                  .arrow_forward_rounded,
                                                              size: 20,
                                                            ),
                                                          ],
                                                        ),
                                                ),
                                              ),
                                            ),

                                            const SizedBox(height: 32),

                                            // Divider with "OR"
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Divider(
                                                    color: Colors.grey.shade300,
                                                    thickness: 1,
                                                    height: 1,
                                                  ),
                                                ),
                                                Expanded(
                                                  child: Divider(
                                                    color: Colors.grey.shade300,
                                                    thickness: 1,
                                                    height: 1,
                                                  ),
                                                ),
                                              ],
                                            ),

                                            const SizedBox(height: 24),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              const SizedBox(height: 32),

                              // Sign Up Link
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    "Don't have an account? ",
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              const RegisterPage(),
                                        ),
                                      );
                                    },
                                    child: Container(
                                      decoration: BoxDecoration(
                                        border: Border(
                                          bottom: BorderSide(
                                            color: AppConstants.primaryColor,
                                            width: 1.5,
                                          ),
                                        ),
                                      ),
                                      child: Text(
                                        'Create account',
                                        style: GoogleFonts.poppins(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: AppConstants.primaryColor,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
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
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }
}
