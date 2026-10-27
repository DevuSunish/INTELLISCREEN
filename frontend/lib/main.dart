import 'package:flutter/material.dart';
import 'models/child_record.dart';
import 'screens/children_screen.dart';
import 'services/api_client.dart';
import 'services/auth_api_service.dart';

void main() {
  runApp(const MyApp());
}

/// Root application widget configuring themes and initial routes.
/// Returns to the sign-in screen whenever the backend rejects the session.
class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  final GlobalKey<ScaffoldMessengerState> _messengerKey =
      GlobalKey<ScaffoldMessengerState>();

  @override
  void initState() {
    super.initState();
    AuthSession.instance.addListener(_onSessionChanged);
  }

  @override
  void dispose() {
    AuthSession.instance.removeListener(_onSessionChanged);
    super.dispose();
  }

  void _onSessionChanged() {
    if (!AuthSession.instance.expired) return;
    childrenStore.clear();
    _navigatorKey.currentState?.popUntil((route) => route.isFirst);
    _messengerKey.currentState?.showSnackBar(
      const SnackBar(content: Text('Your session has expired. Please sign in again.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Soft teal & serene blue palette for a calm, professional, child-friendly look.
    const Color primaryTeal = Color(0xFF0D9488); // Serene teal
    const Color lightTeal = Color(0xFFF0FDFA);
    const Color softBlue = Color(0xFF0284C7);

    return MaterialApp(
      navigatorKey: _navigatorKey,
      scaffoldMessengerKey: _messengerKey,
      title: 'INTELLISCREEN',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryTeal,
          primary: primaryTeal,
          secondary: softBlue,
          surface: Colors.white,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: lightTeal,
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF8FAFC),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: primaryTeal, width: 2),
          ),
          labelStyle: const TextStyle(color: Color(0xFF64748B)),
          hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryTeal,
            foregroundColor: Colors.white,
            elevation: 0,
            minimumSize: const Size.fromHeight(50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
      home: const WelcomeLoginScreen(),
    );
  }
}

/// Available user roles for the INTELLISCREEN platform.
enum UserRole {
  parent,
  teacher,
}

/// Main welcome and login screen for INTELLISCREEN.
/// Designed to be responsive across web (Chrome) and mobile devices.
class WelcomeLoginScreen extends StatefulWidget {
  const WelcomeLoginScreen({super.key});

  @override
  State<WelcomeLoginScreen> createState() => _WelcomeLoginScreenState();
}

class _WelcomeLoginScreenState extends State<WelcomeLoginScreen> {
  // Form key for simple field validation.
  final _formKey = GlobalKey<FormState>();

  // Text editing controllers for user inputs.
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  // State variables for role selection and password visibility.
  UserRole _selectedRole = UserRole.parent;
  bool _isPasswordVisible = false;
  bool _isAuthenticating = false;
  final AuthApiService _authService = AuthApiService();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Signs in against the backend before opening the dashboard.
  Future<void> _handleLogin() => _authenticate(
        () => _authService.login(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        ),
      );

  /// Creates an account on the backend, which also signs the user in.
  Future<void> _registerAccount() => _authenticate(
        () => _authService.register(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          role: _selectedRole == UserRole.teacher ? 'teacher' : 'parent',
        ),
      );

  Future<void> _authenticate(Future<AuthUser> Function() request) async {
    if (_isAuthenticating) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _isAuthenticating = true);

    final AuthUser user;
    try {
      user = await request();
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message)),
        );
      }
      return;
    } finally {
      if (mounted) setState(() => _isAuthenticating = false);
    }

    if (!mounted) return;
    _passwordController.clear();
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => DashboardScreen(
          role: user.role == 'teacher' ? UserRole.teacher : UserRole.parent,
          email: user.email,
        ),
      ),
    );

    // However the dashboard was closed, the session ends with it.
    _authService.logout();
    childrenStore.clear();
  }

  /// Displays help information explaining demo access and assistance.
  void _showHelpDialog() {
    showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.help_outline_rounded, color: Color(0xFF0284C7)),
              SizedBox(width: 10),
              Text(
                'Sign-In Help',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'How to use this prototype:',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              SizedBox(height: 8),
              Text(
                '• New here? Choose Parent or Teacher, enter your email and a password of at least 8 characters, then tap "Create an account".\n'
                '• Returning? Enter the email and password you registered with and tap "Sign In".\n'
                '• Your role comes from your account.\n'
                '• The INTELLISCREEN backend must be running for sign-in to work.',
                style: TextStyle(fontSize: 13, height: 1.5, color: Color(0xFF334155)),
              ),
              SizedBox(height: 12),
              Text(
                'You will need to sign in again after restarting the app.',
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B), fontStyle: FontStyle.italic),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Got it'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Responsive layout wrapper
    return Scaffold(
      body: Container(
        // Subtle gradient background: soft teal to gentle sky blue
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFE6FFFA), // Soft mint / teal
              Color(0xFFF0F9FF), // Soft sky blue
              Color(0xFFFFFFFF), // Crisp white
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: ConstrainedBox(
                // Max width constraint ensures optimal appearance on web/desktop (Chrome)
                constraints: const BoxConstraints(maxWidth: 460),
                child: Form(
                  key: _formKey,
                  child: Card(
                    elevation: 3,
                    shadowColor: const Color(0x14000000),
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // App Icon / Logo Badge
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: const Color(0xFFCCFBF1),
                              shape: BoxShape.circle,
                              border: Border.all(color: const Color(0xFF99F6E4), width: 1.5),
                            ),
                            child: const Icon(
                              Icons.auto_stories_rounded,
                              size: 34,
                              color: Color(0xFF0F766E),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // App Title
                          const Text(
                            'INTELLISCREEN',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.5,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 6),

                          // Subtitle
                          const Text(
                            'Academic Screening & Progress Monitoring',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF475569),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Non-diagnostic badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE0F2FE),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.verified_outlined, size: 14, color: Color(0xFF0369A1)),
                                SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    'Screening & Monitoring Tool • Non-Diagnostic',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF0369A1),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 28),

                          // Role Selector Label
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Select your role',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF334155),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Parent / Teacher Role Toggle
                          SegmentedButton<UserRole>(
                            segments: const [
                              ButtonSegment<UserRole>(
                                value: UserRole.parent,
                                label: Text('Parent'),
                                icon: Icon(Icons.family_restroom_rounded, size: 18),
                              ),
                              ButtonSegment<UserRole>(
                                value: UserRole.teacher,
                                label: Text('Teacher'),
                                icon: Icon(Icons.school_rounded, size: 18),
                              ),
                            ],
                            selected: {_selectedRole},
                            onSelectionChanged: (Set<UserRole> newSelection) {
                              setState(() {
                                _selectedRole = newSelection.first;
                              });
                            },
                            style: ButtonStyle(
                              visualDensity: VisualDensity.comfortable,
                              shape: WidgetStateProperty.all(
                                RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Role Context Helper Text
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              _selectedRole == UserRole.parent
                                  ? 'View early signs, home screenings & child milestones.'
                                  : 'Access classroom screening tools & student growth metrics.',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Email Input Field
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            autocorrect: false,
                            decoration: InputDecoration(
                              labelText: 'Email Address',
                              hintText: _selectedRole == UserRole.parent
                                  ? 'parent@example.com'
                                  : 'educator@school.org',
                              prefixIcon: const Icon(Icons.mail_outline_rounded, size: 20),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter your email';
                              }
                              if (!value.contains('@') || !value.contains('.')) {
                                return 'Please enter a valid email';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Password Input Field with Show/Hide Control
                          TextFormField(
                            controller: _passwordController,
                            obscureText: !_isPasswordVisible,
                            decoration: InputDecoration(
                              labelText: 'Password',
                              hintText: 'Enter your password',
                              prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _isPasswordVisible
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  size: 20,
                                  color: const Color(0xFF64748B),
                                ),
                                onPressed: () {
                                  setState(() {
                                    _isPasswordVisible = !_isPasswordVisible;
                                  });
                                },
                                tooltip: _isPasswordVisible ? 'Hide password' : 'Show password',
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter your password';
                              }
                              if (value.length < 8) {
                                return 'Password must be at least 8 characters';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 24),

                          // Login Button
                          ElevatedButton(
                            onPressed: _isAuthenticating ? null : _handleLogin,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Sign In as ${_selectedRole == UserRole.parent ? 'Parent' : 'Teacher'}',
                                ),
                                const SizedBox(width: 8),
                                const Icon(Icons.arrow_forward_rounded, size: 18),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),

                          TextButton(
                            onPressed: _isAuthenticating ? null : _registerAccount,
                            child: const Text('Create an account'),
                          ),

                          // Help Signing In Link
                          TextButton(
                            onPressed: _showHelpDialog,
                            child: const Text(
                              'Need help signing in?',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF0284C7),
                              ),
                            ),
                          ),
                          const Divider(height: 28, color: Color(0xFFE2E8F0)),

                          // Child-Friendly & Supportive Footer Note
                          const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.spa_outlined, size: 16, color: Color(0xFF0D9488)),
                              SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  'Supporting early dyslexia & dysgraphia screening',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF64748B),
                                    fontWeight: FontWeight.w500,
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
      ),
    );
  }
}

// ============================================================================
// STAGE 2: DASHBOARD IMPLEMENTATION
// ============================================================================

/// Dashboard screen displaying academic screening overview and quick access
/// to learner profiles, screening sessions, results, and progress monitoring.
class DashboardScreen extends StatefulWidget {
  final UserRole role;
  final String email;

  const DashboardScreen({
    super.key,
    required this.role,
    required this.email,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  UserRole get role => widget.role;
  String get email => widget.email;

  @override
  void initState() {
    super.initState();
    childrenStore.load();
  }

  void _openChildren() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const ChildrenScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryTeal = Color(0xFF0D9488);
    final String roleTitle = role == UserRole.parent ? 'Parent / Caregiver' : 'Teacher / Educator';
    final String greetingName = role == UserRole.parent ? 'Parent' : 'Educator';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A)),
          tooltip: 'Return to Sign In',
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFFCCFBF1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.auto_stories_rounded, size: 20, color: primaryTeal),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'INTELLISCREEN',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                    color: Color(0xFF0F172A),
                  ),
                ),
                Text(
                  'Screening Dashboard',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          // Sign Out button
          TextButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.logout_rounded, size: 16, color: Color(0xFF64748B)),
            label: const Text(
              'Sign Out',
              style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ListenableBuilder(
            listenable: childrenStore,
            builder: (context, _) {
              final bool loaded = childrenStore.state == LoadState.ready;
              final String totalChildrenValue = !loaded
                  ? '—'
                  : role == UserRole.parent
                      ? '${childrenStore.count} Children'
                      : '${childrenStore.count} Students';
              final String assessmentsDoneValue =
                  loaded ? '${childrenStore.completedAssessmentCount} Completed' : '—';
              final String inProgressValue =
                  loaded ? '${childrenStore.inProgressAssessmentCount} Open' : '—';

              return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: ConstrainedBox(
              // Responsive constraint for web preview in Chrome & tablet/desktop
              constraints: const BoxConstraints(maxWidth: 600),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Welcome Banner Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0D9488), Color(0xFF0284C7)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x1F0D9488),
                          blurRadius: 12,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                roleTitle,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const Spacer(),
                            const Icon(Icons.verified_outlined, color: Colors.white70, size: 16),
                            const SizedBox(width: 4),
                            const Text(
                              'Demo Mode',
                              style: TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Welcome back, $greetingName!',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          email,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.info_outline_rounded, size: 16, color: Colors.white),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Screening & progress monitoring tool. Not a clinical diagnostic application.',
                                  style: TextStyle(fontSize: 11, color: Colors.white, height: 1.3),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Section Header: Summary Statistics
                  const Row(
                    children: [
                      Text(
                        'Screening Overview',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      SizedBox(width: 8),
                      Text(
                        '(Saved Data)',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Summary Cards Row (Responsive 3-stat overview)
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final bool isCompact = constraints.maxWidth < 420;
                      return isCompact
                          ? Column(
                              children: [
                                _SummaryStatCard(
                                  title: 'Total Children',
                                  value: totalChildrenValue,
                                  subtitle: 'Registered profiles',
                                  icon: Icons.child_care_rounded,
                                  accentColor: const Color(0xFF0D9488),
                                  bgColor: const Color(0xFFF0FDFA),
                                ),
                                const SizedBox(height: 8),
                                _SummaryStatCard(
                                  title: 'Assessments',
                                  value: assessmentsDoneValue,
                                  subtitle: 'Completed sessions',
                                  icon: Icons.check_circle_outline_rounded,
                                  accentColor: const Color(0xFF0284C7),
                                  bgColor: const Color(0xFFF0F9FF),
                                ),
                                const SizedBox(height: 8),
                                _SummaryStatCard(
                                  title: 'In Progress',
                                  value: inProgressValue,
                                  subtitle: 'Unfinished sessions',
                                  icon: Icons.pending_outlined,
                                  accentColor: const Color(0xFFD97706),
                                  bgColor: const Color(0xFFFFFBEB),
                                ),
                              ],
                            )
                          : Row(
                              children: [
                                Expanded(
                                  child: _SummaryStatCard(
                                    title: 'Total Children',
                                    value: totalChildrenValue,
                                    subtitle: 'Profiles',
                                    icon: Icons.child_care_rounded,
                                    accentColor: const Color(0xFF0D9488),
                                    bgColor: const Color(0xFFF0FDFA),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _SummaryStatCard(
                                    title: 'Assessments',
                                    value: assessmentsDoneValue,
                                    subtitle: 'Completed',
                                    icon: Icons.check_circle_outline_rounded,
                                    accentColor: const Color(0xFF0284C7),
                                    bgColor: const Color(0xFFF0F9FF),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _SummaryStatCard(
                                    title: 'In Progress',
                                    value: inProgressValue,
                                    subtitle: 'Unfinished',
                                    icon: Icons.pending_outlined,
                                    accentColor: const Color(0xFFD97706),
                                    bgColor: const Color(0xFFFFFBEB),
                                  ),
                                ),
                              ],
                            );
                    },
                  ),
                  if (childrenStore.state == LoadState.error) ...[
                    const SizedBox(height: 12),
                    LoadErrorCard(
                      title: 'Could not load saved data',
                      message: childrenStore.error ?? 'Unknown error',
                      onRetry: childrenStore.load,
                    ),
                  ],
                  const SizedBox(height: 28),

                  // Section Header: Core Tools & Actions
                  const Row(
                    children: [
                      Text(
                        'Screening Modules',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Tap any card to preview',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // 1. Child Profiles Card
                  _SectionNavCard(
                    title: 'Child Profiles',
                    description: role == UserRole.parent
                        ? 'Manage your child’s profile, grade level, and observational notes.'
                        : 'Review registered student rosters, grade levels, and individual notes.',
                    icon: Icons.people_alt_rounded,
                    accentColor: const Color(0xFF0D9488),
                    badgeText: loaded ? '${childrenStore.count} Profiles (Demo)' : 'Loading…',
                    onTap: _openChildren,
                  ),
                  const SizedBox(height: 12),

                  // 2. New Assessment Card
                  _SectionNavCard(
                    title: 'New Assessment',
                    description:
                        'Choose a demo child to start or resume a structured screening session.',
                    icon: Icons.add_task_rounded,
                    accentColor: const Color(0xFF0284C7),
                    badgeText: 'Start Screening',
                    onTap: _openChildren,
                  ),
                  const SizedBox(height: 12),

                  // 3. Assessment Results Card
                  _SectionNavCard(
                    title: 'Assessment Results',
                    description:
                        'Examine completed screening rubrics, risk indicator flags, and observation logs.',
                    icon: Icons.fact_check_outlined,
                    accentColor: const Color(0xFF0F766E),
                    badgeText: loaded ? '${childrenStore.resultCount} Saved Results' : 'Loading…',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const FeaturePlaceholderScreen(
                            featureTitle: 'Assessment Results',
                            featureIcon: Icons.fact_check_outlined,
                            accentColor: Color(0xFF0F766E),
                            description:
                                'The Assessment Results module presents structured scoring summaries and observational feedback to help educators and parents determine next instructional steps.',
                            upcomingHighlights: [
                              'Objective screening rubrics for reading decoding and handwriting motor skills',
                              'Clear, non-diagnostic indicator tiers (On Track, Monitor, Needs Support)',
                              'Actionable instructional guidance and classroom accommodations',
                              'Downloadable PDF summaries for parent-teacher conferences',
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),

                  // 4. Progress Tracking Card
                  _SectionNavCard(
                    title: 'Progress Tracking',
                    description:
                        'Monitor longitudinal progress curves across reading speed and writing legibility.',
                    icon: Icons.timeline_rounded,
                    accentColor: const Color(0xFF0284C7),
                    badgeText: 'Longitudinal View',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const FeaturePlaceholderScreen(
                            featureTitle: 'Progress Tracking',
                            featureIcon: Icons.timeline_rounded,
                            accentColor: Color(0xFF0284C7),
                            description:
                                'The Progress Tracking module provides longitudinal progress monitoring to evaluate how a child responds to targeted reading and writing interventions over time.',
                            upcomingHighlights: [
                              'Periodic benchmark comparison charts (beginning, middle, and end of year)',
                              'Intervention response tracking across specific phonics and motor goals',
                              'Visual progress milestones designed to celebrate student growth',
                              'Collaborative notes between home and classroom teachers',
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 28),

                  // Return to Welcome screen card
                  Center(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF64748B),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back_rounded, size: 16),
                      label: const Text('Return to Sign In Screen'),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          );
        },
      ),
    ),
  ),
);
  }
}

/// Reusable widget for summary metrics on the dashboard.
class _SummaryStatCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final Color bgColor;

  const _SummaryStatCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 18, color: accentColor),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'DEMO',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF64748B),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }
}

/// Reusable interactive card for navigating to dashboard sections.
class _SectionNavCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final Color accentColor;
  final String badgeText;
  final VoidCallback onTap;

  const _SectionNavCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.accentColor,
    required this.badgeText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shadowColor: const Color(0x0D000000),
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Module Icon
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: accentColor, size: 24),
              ),
              const SizedBox(width: 14),

              // Title and Description
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            badgeText,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF475569),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      description,
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Trailing arrow icon
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF94A3B8),
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// STAGE 2: PLACEHOLDER SCREEN FOR FUTURE MODULES
// ============================================================================

/// Clean placeholder screen displaying a feature preview for modules under development.
/// Clearly communicates demo status and offers simple navigation back to the dashboard.
class FeaturePlaceholderScreen extends StatelessWidget {
  final String featureTitle;
  final IconData featureIcon;
  final Color accentColor;
  final String description;
  final List<String> upcomingHighlights;

  const FeaturePlaceholderScreen({
    super.key,
    required this.featureTitle,
    required this.featureIcon,
    required this.accentColor,
    required this.description,
    required this.upcomingHighlights,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A)),
          tooltip: 'Return to Dashboard',
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          featureTitle,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0F172A),
          ),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Card(
                elevation: 2,
                shadowColor: const Color(0x0D000000),
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Icon badge
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(featureIcon, size: 32, color: accentColor),
                      ),
                      const SizedBox(height: 16),

                      // Title
                      Text(
                        featureTitle,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Status pill
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE0F2FE),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.construction_rounded, size: 13, color: Color(0xFF0284C7)),
                            SizedBox(width: 6),
                            Text(
                              'Feature in Development • Demo Preview',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF0284C7),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Description
                      Text(
                        description,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.5,
                          color: Color(0xFF475569),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Planned Features Box
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Planned Capabilities:',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                            const SizedBox(height: 10),
                            ...upcomingHighlights.map(
                              (highlight) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(
                                      Icons.check_circle_rounded,
                                      size: 16,
                                      color: Color(0xFF0D9488),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        highlight,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          height: 1.4,
                                          color: Color(0xFF334155),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Transparent non-diagnostic notice
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFBBF7D0)),
                        ),
                        child: const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFF166534)),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Note: INTELLISCREEN is an academic screening and progress monitoring tool. It is not intended to make medical or formal diagnostic claims.',
                                style: TextStyle(
                                  fontSize: 11,
                                  height: 1.4,
                                  color: Color(0xFF166534),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Return to Dashboard Button
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF0D9488),
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.arrow_back_rounded, size: 18),
                        label: const Text('Return to Dashboard'),
                      ),
                    ],
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
