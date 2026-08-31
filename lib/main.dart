import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nkg/platform/local_app_launcher.dart';
import 'package:nkg/workspaces/nkg_workspace.dart';
part 'workspaces/role_management_workspace.dart';
part 'workspaces/staff_management_workspace.dart';
part 'workspaces/app_management_workspace.dart';

const _supabaseUrl = String.fromEnvironment(
  'SUPABASE_URL',
  defaultValue: 'https://qjjzzqbxuodornqojegj.supabase.co',
);
const _supabaseAnonKey = String.fromEnvironment(
  'SUPABASE_ANON_KEY',
  defaultValue: 'sb_publishable__xgnpfIhiCnTrsyQcJVAcg_iPGJFmnx',
);
const _companyEmailDomain = '@nirwanakharisma.com';
final ValueNotifier<ThemeMode> _themeMode = ValueNotifier(ThemeMode.light);
final ValueNotifier<Locale> _locale = ValueNotifier(const Locale('en'));

String _text(BuildContext context, String english, String indonesian) {
  return Localizations.localeOf(context).languageCode == 'id'
      ? indonesian
      : english;
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (_supabaseUrl.isNotEmpty && _supabaseAnonKey.isNotEmpty) {
    await Supabase.initialize(
      url: _supabaseUrl,
      publishableKey: _supabaseAnonKey,
    );
  }
  runApp(const NkgLauncherApp());
}

class NkgLauncherApp extends StatelessWidget {
  const NkgLauncherApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Locale>(
      valueListenable: _locale,
      builder: (context, locale, child) => ValueListenableBuilder<ThemeMode>(
        valueListenable: _themeMode,
        builder: (context, mode, child) => MaterialApp(
          title: 'NKG',
          locale: locale,
          supportedLocales: const [Locale('en'), Locale('id')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          debugShowCheckedModeBanner: false,
          theme: _buildTheme(Brightness.light),
          darkTheme: _buildTheme(Brightness.dark),
          themeMode: mode,
          home: _supabaseUrl.isEmpty || _supabaseAnonKey.isEmpty
              ? const DemoGate()
              : const AuthGate(),
        ),
      ),
    );
  }
}

ThemeData _buildTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xff123b64),
    brightness: brightness,
  );
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    fontFamily: 'Roboto',
    scaffoldBackgroundColor: dark
        ? const Color(0xff0b1220)
        : const Color(0xfff4f6fa),
    cardTheme: CardThemeData(
      color: dark ? const Color(0xff141f31) : Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark ? const Color(0xff19263a) : const Color(0xfff7f8fb),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xffe21d2a), width: 1.5),
      ),
    ),
  );
}

void _toggleTheme() {
  _themeMode.value = _themeMode.value == ThemeMode.dark
      ? ThemeMode.light
      : ThemeMode.dark;
}

void _setLanguage(String languageCode) {
  _locale.value = Locale(languageCode);
}

class _LanguageSwitcher extends StatelessWidget {
  const _LanguageSwitcher();

  @override
  Widget build(BuildContext context) {
    final language = Localizations.localeOf(context).languageCode;
    final indonesian = language == 'id';
    return Semantics(
      button: true,
      label: indonesian ? 'Switch to English' : 'Beralih ke Bahasa Indonesia',
      child: GestureDetector(
        onTap: () => _setLanguage(indonesian ? 'en' : 'id'),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          width: 66,
          height: 34,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: indonesian
                ? const Color(0xff0f8b9d)
                : const Color(0xff1f6fb2),
            borderRadius: BorderRadius.circular(20),
          ),
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            alignment: indonesian
                ? Alignment.centerLeft
                : Alignment.centerRight,
            child: Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: Text(
                indonesian ? 'ID' : 'EN',
                style: TextStyle(
                  color: indonesian
                      ? const Color(0xff0f8b9d)
                      : const Color(0xff1f6fb2),
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final client = Supabase.instance.client;
    return StreamBuilder<AuthState>(
      stream: client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = snapshot.data?.session ?? client.auth.currentSession;
        return session == null ? const LoginPage() : const LauncherPage();
      },
    );
  }
}

class DemoGate extends StatefulWidget {
  const DemoGate({super.key});

  @override
  State<DemoGate> createState() => _DemoGateState();
}

class _DemoGateState extends State<DemoGate> {
  bool _signedIn = false;

  @override
  Widget build(BuildContext context) {
    return _signedIn
        ? LauncherPage(
            demoMode: true,
            onDemoSignOut: () => setState(() => _signedIn = false),
          )
        : LoginPage(
            demoMode: true,
            onDemoLogin: () => setState(() => _signedIn = true),
          );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, this.demoMode = false, this.onDemoLogin});

  final bool demoMode;
  final VoidCallback? onDemoLogin;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (widget.demoMode) {
        await Future<void>.delayed(const Duration(milliseconds: 350));
        if (_email.text.trim().toLowerCase() != 'admin' ||
            _password.text != 'admin') {
          throw const AuthException('Use admin / admin for the local preview.');
        }
        widget.onDemoLogin?.call();
        return;
      }
      final enteredEmail = _email.text.trim();
      if (enteredEmail.isEmpty) {
        throw const AuthException('Enter your company email username.');
      }
      final email = enteredEmail.contains('@')
          ? enteredEmail
          : '$enteredEmail$_companyEmailDomain';
      await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: _password.text,
      );
    } on AuthException catch (error) {
      setState(() => _error = error.message);
    } catch (_) {
      setState(() => _error = 'Unable to sign in. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final navy = const Color(0xff102f52);
    final blue = const Color(0xff1f6fb2);
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 860;
          final dark = Theme.of(context).brightness == Brightness.dark;
          return Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage(
                  dark
                      ? 'assets/branding/nkg_auth_background_dark.png'
                      : 'assets/branding/nkg_auth_background_light.png',
                ),
                fit: BoxFit.cover,
              ),
              gradient: LinearGradient(
                colors: dark
                    ? [
                        navy.withValues(alpha: .90),
                        const Color(0xff1f6fb2).withValues(alpha: .74),
                      ]
                    : [
                        Colors.white.withValues(alpha: .93),
                        const Color(0xffdce9f6).withValues(alpha: .90),
                      ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: Card(
                  margin: const EdgeInsets.all(24),
                  elevation: 18,
                  clipBehavior: Clip.antiAlias,
                  child: wide
                      ? Row(
                          children: [
                            Expanded(
                              child: Container(
                                height: 590,
                                padding: const EdgeInsets.all(48),
                                decoration: BoxDecoration(
                                  color: dark ? null : const Color(0xffeaf2fb),
                                  gradient: dark
                                      ? LinearGradient(
                                          colors: [navy, blue],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        )
                                      : null,
                                ),
                                child: _LoginWelcomePanel(isDark: dark),
                              ),
                            ),
                            Expanded(child: _LoginForm(this)),
                          ],
                        )
                      : _LoginForm(this),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _LoginWelcomePanel extends StatelessWidget {
  const _LoginWelcomePanel({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 440,
          height: 172,
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(18),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.asset(
              'assets/branding/company_logo_transparent.png',
              fit: BoxFit.contain,
            ),
          ),
        ),
      ],
    );
  }
}

class _LoginForm extends StatelessWidget {
  const _LoginForm(this.state);

  final _LoginPageState state;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _text(context, 'Welcome back', 'Selamat datang kembali'),
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ),
                const _LanguageSwitcher(),
                IconButton(
                  tooltip: _text(context, 'Toggle theme', 'Ganti tema'),
                  onPressed: _toggleTheme,
                  icon: Icon(
                    Theme.of(context).brightness == Brightness.dark
                        ? Icons.light_mode_outlined
                        : Icons.dark_mode_outlined,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _text(
                context,
                'Use your company email to sign in.',
                'Gunakan email perusahaan untuk masuk.',
              ),
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 32),
            TextField(
              controller: state._email,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: _text(context, 'Company email', 'Email perusahaan'),
                hintText: 'your.name',
                suffixText: _companyEmailDomain,
                suffixStyle: TextStyle(
                  color: Color(0xff218739),
                  fontWeight: FontWeight.w700,
                ),
                prefixIcon: Icon(Icons.mail_outline),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: state._password,
              obscureText: true,
              onSubmitted: (_) => state._login(),
              decoration: InputDecoration(
                labelText: _text(context, 'Password', 'Kata sandi'),
                prefixIcon: const Icon(Icons.lock_outline),
              ),
            ),
            if (state.widget.demoMode)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  'Preview access: admin / admin',
                  textAlign: TextAlign.right,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
              ),
            if (state._error != null) ...[
              const SizedBox(height: 16),
              Text(state._error!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 28),
            FilledButton(
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed: state._loading ? null : state._login,
              child: Text(
                state._loading
                    ? _text(context, 'Signing in...', 'Sedang masuk...')
                    : _text(context, 'Sign in', 'Masuk'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class LauncherApp {
  const LauncherApp({
    required this.id,
    required this.name,
    required this.description,
    required this.launchUrl,
    required this.status,
    required this.permissions,
  });

  final String id;
  final String name;
  final String description;
  final String launchUrl;
  final String status;
  final List<String> permissions;

  factory LauncherApp.fromJson(Map<String, dynamic> json) {
    return LauncherApp(
      id: json['app_id'] as String,
      name: json['app_name'] as String,
      description: (json['description'] as String?) ?? '',
      launchUrl: json['launch_url'] as String,
      status: (json['status'] as String?) ?? 'active',
      permissions: ((json['permissions'] as List<dynamic>?) ?? [])
          .map((permission) => permission.toString())
          .toList(),
    );
  }
}

class StaffMember {
  const StaffMember({
    required this.userId,
    required this.email,
    required this.createdAt,
    required this.roles,
    required this.roleIds,
  });

  final String userId;
  final String email;
  final DateTime createdAt;
  final List<String> roles;
  final List<String> roleIds;

  factory StaffMember.fromJson(Map<String, dynamic> json) {
    final rawRoles = json['roles'];
    final roleRows = rawRoles is List<dynamic> ? rawRoles : <dynamic>[];
    final rawCreatedAt = json['created_at'];
    return StaffMember(
      userId: json['user_id'] as String,
      email: (json['email'] as String?) ?? 'No email',
      createdAt: rawCreatedAt is DateTime
          ? rawCreatedAt
          : DateTime.parse(rawCreatedAt.toString()),
      roles: roleRows.map((row) {
        final role = row as Map<String, dynamic>;
        final app = role['app_name'] as String?;
        final name = role['role_name'] as String? ?? 'Unassigned';
        return app == null ? name : '$app · $name';
      }).toList(),
      roleIds: roleRows
          .map((row) => (row as Map<String, dynamic>)['role_id'].toString())
          .toList(),
    );
  }
}

class StaffRole {
  const StaffRole({
    required this.id,
    required this.appName,
    required this.name,
    required this.description,
    required this.appAccess,
    required this.permissionKeys,
  });

  final String id;
  final String? appName;
  final String name;
  final String description;
  final String appAccess;
  final List<String> permissionKeys;

  factory StaffRole.fromJson(Map<String, dynamic> json) {
    return StaffRole(
      id: json['role_id'] as String,
      appName: json['app_name'] as String?,
      name: json['role_name'] as String,
      description: (json['description'] as String?) ?? '',
      appAccess: (json['app_access'] as String?) ?? 'No app access',
      permissionKeys: ((json['permission_keys'] as List<dynamic>?) ?? [])
          .map((permission) => permission.toString())
          .toList(),
    );
  }
}

const _staffRoleSectionOrder = [
  'NKG App',
  'NKG Logistics',
  'Waterpark',
  'GOR',
  'Finance',
  'HR',
];

String _staffRoleSectionDescription(BuildContext context, String section) {
  switch (section) {
    case 'NKG App':
      return _text(
        context,
        'Identity, launcher, and platform administration',
        'Identitas, launcher, dan administrasi platform',
      );
    case 'NKG Logistics':
      return _text(
        context,
        'Inventory, purchasing, logistics, and work orders',
        'Inventaris, pembelian, logistik, dan work order',
      );
    case 'Waterpark':
      return _text(
        context,
        'Tickets, sales, QR scanning, staff, and reports',
        'Tiket, penjualan, pemindaian QR, staf, dan laporan',
      );
    case 'GOR':
      return _text(
        context,
        'General operations and company-wide workflows',
        'Operasional umum dan alur kerja perusahaan',
      );
    case 'Finance':
      return _text(
        context,
        'Financial operations, approvals, and reporting',
        'Operasional keuangan, persetujuan, dan pelaporan',
      );
    case 'HR':
      return _text(
        context,
        'People, attendance, leave, and HR administration',
        'Karyawan, kehadiran, cuti, dan administrasi HR',
      );
    default:
      return '';
  }
}

class NotificationItem {
  const NotificationItem({
    required this.id,
    required this.title,
    required this.body,
    required this.read,
    required this.createdAt,
  });

  final String id;
  final String title;
  final String body;
  final bool read;
  final DateTime createdAt;

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      id: json['id'] as String,
      title: json['title'] as String,
      body: (json['body'] as String?) ?? '',
      read: json['read_at'] != null,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class BugReport {
  const BugReport({
    required this.id,
    required this.reporterEmail,
    required this.appName,
    required this.title,
    required this.description,
    required this.priority,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String reporterEmail;
  final String? appName;
  final String title;
  final String description;
  final String priority;
  final String status;
  final DateTime createdAt;

  factory BugReport.fromJson(Map<String, dynamic> json) {
    return BugReport(
      id: json['id'] as String,
      reporterEmail: (json['reporter_email'] as String?) ?? 'Unknown user',
      appName: json['app_name'] as String?,
      title: json['title'] as String,
      description: json['description'] as String,
      priority: json['priority'] as String,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class _LauncherSidebar extends StatelessWidget {
  const _LauncherSidebar({
    required this.onApplications,
    required this.onProfile,
    required this.onHelp,
    required this.onStaffManagement,
    required this.onAppManagement,
    required this.onRoleManagement,
    required this.roleWorkspaceActive,
  });

  final VoidCallback onApplications;
  final VoidCallback onProfile;
  final VoidCallback onHelp;
  final VoidCallback onStaffManagement;
  final VoidCallback onAppManagement;
  final VoidCallback onRoleManagement;
  final bool roleWorkspaceActive;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250,
      decoration: const BoxDecoration(
        color: Color(0xff0b1628),
        border: Border(right: BorderSide(color: Color(0xff1d2d45))),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 68,
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Image.asset(
                'assets/branding/company_logo_transparent.png',
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 36),
            Text(
              _text(context, 'WORKSPACE', 'RUANG KERJA'),
              style: TextStyle(
                color: Color(0xff8291a8),
                fontSize: 11,
                letterSpacing: 1.4,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            _SidebarItem(
              icon: Icons.grid_view_rounded,
              label: _text(context, 'Applications', 'Aplikasi'),
              selected: !roleWorkspaceActive,
              onTap: onApplications,
            ),
            _SidebarItem(
              icon: Icons.groups_2_outlined,
              label: _text(context, 'Staff management', 'Manajemen staf'),
              onTap: onStaffManagement,
            ),
            _SidebarItem(
              icon: Icons.tune_rounded,
              label: _text(context, 'App management', 'Manajemen aplikasi'),
              onTap: onAppManagement,
            ),
            _SidebarItem(
              icon: Icons.account_tree_outlined,
              label: _text(context, 'Role Management', 'Manajemen Peran'),
              selected: roleWorkspaceActive,
              onTap: onRoleManagement,
            ),
            _SidebarItem(
              icon: Icons.person_outline_rounded,
              label: _text(context, 'My profile', 'Profil saya'),
              onTap: onProfile,
            ),
            _SidebarItem(
              icon: Icons.help_outline_rounded,
              label: _text(context, 'Help centre', 'Pusat bantuan'),
              onTap: onHelp,
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.icon,
    required this.label,
    this.selected = false,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: selected ? const Color(0xffe21d2a) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        onTap: onTap,
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        leading: Icon(
          icon,
          size: 20,
          color: selected ? Colors.white : const Color(0xff9eacc0),
        ),
        title: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : const Color(0xffb9c4d3),
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

class _WelcomeDateTime extends StatefulWidget {
  const _WelcomeDateTime({this.email});

  final String? email;

  @override
  State<_WelcomeDateTime> createState() => _WelcomeDateTimeState();
}

class _WelcomeDateTimeState extends State<_WelcomeDateTime> {
  late DateTime _now;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final email = widget.email ?? 'Administrator';
    final name = email.contains('@') ? email.split('@').first : email;
    final date = MaterialLocalizations.of(context).formatFullDate(_now);
    final time = MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay.fromDateTime(_now),
      alwaysUse24HourFormat: true,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _text(context, 'Welcome, $name', 'Selamat datang, $name'),
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 3),
        Text('$date • $time', style: TextStyle(color: Colors.grey.shade600)),
      ],
    );
  }
}

class LauncherPage extends StatefulWidget {
  const LauncherPage({super.key, this.demoMode = false, this.onDemoSignOut});

  final bool demoMode;
  final VoidCallback? onDemoSignOut;

  @override
  State<LauncherPage> createState() => _LauncherPageState();
}

class _LauncherPageState extends State<LauncherPage> {
  late Future<List<LauncherApp>> _apps;
  Future<List<StaffRole>>? _workspaceRoles;
  bool _roleWorkspaceActive = false;
  String _roleFilter = 'All applications';
  String _roleSearch = '';
  int _unreadNotifications = 0;

  @override
  void initState() {
    super.initState();
    _apps = _loadApps();
    _workspaceRoles = widget.demoMode
        ? Future.value(const <StaffRole>[])
        : _loadAllRolesForAdmin();
    _refreshNotificationCount();
  }

  Future<List<NotificationItem>> _loadNotifications() async {
    if (widget.demoMode) return const [];
    final response = await Supabase.instance.client.rpc('get_my_notifications');
    return (response as List<dynamic>)
        .map((row) => NotificationItem.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  Future<void> _refreshNotificationCount() async {
    try {
      final notifications = await _loadNotifications();
      if (mounted) {
        setState(() {
          _unreadNotifications = notifications
              .where((item) => !item.read)
              .length;
        });
      }
    } catch (_) {}
  }

  Future<void> _showNotifications() async {
    var notificationsFuture = _loadNotifications();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(_text(dialogContext, 'Notifications', 'Notifikasi')),
          content: SizedBox(
            width: 520,
            height: 420,
            child: FutureBuilder<List<NotificationItem>>(
              future: notificationsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text(snapshot.error.toString()));
                }
                final notifications = snapshot.data ?? [];
                if (notifications.isEmpty) {
                  return Center(
                    child: Text(
                      _text(
                        context,
                        'You are all caught up.',
                        'Semua notifikasi sudah dibaca.',
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  itemCount: notifications.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final notification = notifications[index];
                    return ListTile(
                      leading: Icon(
                        notification.read
                            ? Icons.notifications_none
                            : Icons.notifications_active,
                      ),
                      title: Text(notification.title),
                      subtitle: Text(notification.body),
                      trailing: notification.read
                          ? null
                          : TextButton(
                              onPressed: () async {
                                await Supabase.instance.client.rpc(
                                  'mark_notification_read',
                                  params: {
                                    'p_notification_id': notification.id,
                                  },
                                );
                                setDialogState(() {
                                  notifications[index] = NotificationItem(
                                    id: notification.id,
                                    title: notification.title,
                                    body: notification.body,
                                    read: true,
                                    createdAt: notification.createdAt,
                                  );
                                });
                                _refreshNotificationCount();
                              },
                              child: Text(_text(context, 'Read', 'Baca')),
                            ),
                    );
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(_text(dialogContext, 'Close', 'Tutup')),
            ),
          ],
        ),
      ),
    );
    _refreshNotificationCount();
  }

  Future<List<LauncherApp>> _loadApps() async {
    if (widget.demoMode) {
      return const [
        LauncherApp(
          id: 'logistics',
          name: 'NKG Logistics',
          description: 'Logistics, inventory, purchasing, and work orders.',
          launchUrl: 'https://logistics.nkg.app',
          status: 'active',
          permissions: ['logistics.access'],
        ),
        LauncherApp(
          id: 'waterpark',
          name: 'Waterpark',
          description: 'Tickets, sales, QR scanning, staff, and reports.',
          launchUrl: 'https://waterpark.nkg.app',
          status: 'active',
          permissions: ['waterpark.access'],
        ),
        LauncherApp(
          id: 'gor',
          name: 'GOR',
          description: 'General operations and company-wide workflows.',
          launchUrl: 'https://gor.nkg.app',
          status: 'active',
          permissions: ['gor.access'],
        ),
        LauncherApp(
          id: 'finance',
          name: 'Finance',
          description: 'Financial operations, approvals, and reporting.',
          launchUrl: 'https://finance.nkg.app',
          status: 'active',
          permissions: ['finance.access'],
        ),
        LauncherApp(
          id: 'hr',
          name: 'HR',
          description: 'People, attendance, leave, and HR administration.',
          launchUrl: 'https://hr.nkg.app',
          status: 'active',
          permissions: ['hr.access'],
        ),
        LauncherApp(
          id: 'marketing',
          name: 'Marketing',
          description: 'Campaigns, content, brand, and marketing operations.',
          launchUrl: 'https://marketing.nkg.app',
          status: 'active',
          permissions: ['marketing.access'],
        ),
        LauncherApp(
          id: 'report',
          name: 'Report',
          description: 'Cross-application reporting and business insights.',
          launchUrl: 'https://report.nkg.app',
          status: 'active',
          permissions: ['report.access'],
        ),
        LauncherApp(
          id: 'legal',
          name: 'Legal',
          description: 'Contracts, compliance, cases, and legal workflows.',
          launchUrl: 'https://legal.nkg.app',
          status: 'active',
          permissions: ['legal.access'],
        ),
      ];
    }
    final response = await Supabase.instance.client.rpc('get_my_launcher_apps');
    return (response as List<dynamic>)
        .map((row) => LauncherApp.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  void _openRoleWorkspace() {
    if (_roleWorkspaceActive) return;
    setState(() {
      _roleWorkspaceActive = true;
      _roleFilter = 'All applications';
      _roleSearch = '';
    });
    Navigator.of(context)
        .push(
          MaterialPageRoute<void>(
            builder: (_) => FutureBuilder<List<LauncherApp>>(
              future: _apps,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snapshot.hasError) {
                  return Scaffold(
                    appBar: AppBar(title: const Text('Role Management')),
                    body: Center(child: Text(snapshot.error.toString())),
                  );
                }
                return RoleManagementWorkspace(
                  apps: snapshot.data ?? const [],
                  loadRoles: _loadAllRolesForAdmin,
                  initialRoles: _workspaceRoles,
                  onCreateRole: () =>
                      _createRoleFromWorkspace(snapshot.data ?? const []),
                  onEditPermissions: _showRolePermissionEditor,
                );
              },
            ),
          ),
        )
        .then((_) {
          if (mounted) setState(() => _roleWorkspaceActive = false);
        });
  }

  void _refreshLauncherApps(Future<List<LauncherApp>> apps) {
    if (mounted) setState(() => _apps = apps);
  }

  Future<void> _createRoleFromWorkspace(List<LauncherApp> apps) async {
    final app = await showDialog<LauncherApp>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: Text(
          _text(dialogContext, 'Choose application', 'Pilih aplikasi'),
        ),
        children: apps
            .map(
              (app) => SimpleDialogOption(
                onPressed: () => Navigator.pop(dialogContext, app),
                child: Text(app.name),
              ),
            )
            .toList(),
      ),
    );
    if (app == null || !mounted) return;
    final created = await _showCreateCustomRole(app);
    if (created && mounted) {
      setState(() => _workspaceRoles = _loadAllRolesForAdmin());
    }
  }

  Widget _buildRoleManagementWorkspace(List<LauncherApp> apps) {
    return FutureBuilder<List<StaffRole>>(
      future: _workspaceRoles,
      builder: (context, snapshot) {
        final allRoles = snapshot.data ?? const <StaffRole>[];
        final roles = allRoles.where((role) {
          final matchesApp =
              _roleFilter == 'All applications' ||
              (role.appName ?? 'NKG App') == _roleFilter;
          final query = _roleSearch.trim().toLowerCase();
          final matchesSearch =
              query.isEmpty ||
              role.name.toLowerCase().contains(query) ||
              role.description.toLowerCase().contains(query) ||
              (role.appName ?? 'NKG App').toLowerCase().contains(query);
          return matchesApp && matchesSearch;
        }).toList();
        final appNames = <String>[
          'All applications',
          ...{...allRoles.map((role) => role.appName ?? 'NKG App')},
        ];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 28, 32, 18),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _text(context, 'Role Management', 'Manajemen Peran'),
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _text(
                            context,
                            'Define what each role can do across every application.',
                            'Tentukan akses setiap peran di seluruh aplikasi.',
                          ),
                        ),
                      ],
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: apps.isEmpty
                        ? null
                        : () => _createRoleFromWorkspace(apps),
                    icon: const Icon(Icons.add),
                    label: Text(_text(context, 'Custom role', 'Peran khusus')),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    onPressed: () => setState(
                      () => _workspaceRoles = _loadAllRolesForAdmin(),
                    ),
                    icon: const Icon(Icons.refresh),
                    label: Text(_text(context, 'Refresh', 'Muat ulang')),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Row(
                children: [
                  _RoleMetric(
                    label: _text(context, 'Total roles', 'Total peran'),
                    value: '${allRoles.length}',
                    icon: Icons.badge_outlined,
                  ),
                  const SizedBox(width: 12),
                  _RoleMetric(
                    label: _text(context, 'Applications', 'Aplikasi'),
                    value: '${appNames.length - 1}',
                    icon: Icons.apps_outlined,
                  ),
                  const SizedBox(width: 12),
                  _RoleMetric(
                    label: _text(context, 'Custom roles', 'Peran khusus'),
                    value:
                        '${allRoles.where((role) => role.name.toLowerCase().contains('custom')).length}',
                    icon: Icons.tune_outlined,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 20, 32, 16),
              child: Row(
                children: [
                  SizedBox(
                    width: 300,
                    child: TextField(
                      onChanged: (value) => setState(() => _roleSearch = value),
                      decoration: InputDecoration(
                        hintText: _text(context, 'Search roles', 'Cari peran'),
                        prefixIcon: const Icon(Icons.search),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  DropdownButton<String>(
                    value: appNames.contains(_roleFilter)
                        ? _roleFilter
                        : 'All applications',
                    items: appNames
                        .map(
                          (name) =>
                              DropdownMenuItem(value: name, child: Text(name)),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) setState(() => _roleFilter = value);
                    },
                  ),
                  const Spacer(),
                  Text(
                    _text(
                      context,
                      '${roles.length} roles shown',
                      '${roles.length} peran ditampilkan',
                    ),
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ],
              ),
            ),
            Expanded(
              child: snapshot.connectionState == ConnectionState.waiting
                  ? const Center(child: CircularProgressIndicator())
                  : snapshot.hasError
                  ? Center(child: Text(snapshot.error.toString()))
                  : Card(
                      margin: const EdgeInsets.fromLTRB(32, 0, 32, 32),
                      clipBehavior: Clip.antiAlias,
                      child: ListView(
                        children: [
                          DataTable(
                            headingRowColor: WidgetStatePropertyAll(
                              Theme.of(
                                context,
                              ).colorScheme.surfaceContainerHighest,
                            ),
                            columns: [
                              DataColumn(
                                label: Text(
                                  _text(context, 'Application', 'Aplikasi'),
                                ),
                              ),
                              DataColumn(
                                label: Text(_text(context, 'Role', 'Peran')),
                              ),
                              DataColumn(
                                label: Text(
                                  _text(
                                    context,
                                    'What they can do',
                                    'Yang dapat dilakukan',
                                  ),
                                ),
                              ),
                              DataColumn(
                                label: Text(_text(context, 'Actions', 'Aksi')),
                              ),
                            ],
                            rows: roles.map((role) {
                              final app = apps
                                  .where((item) => item.name == role.appName)
                                  .firstOrNull;
                              return DataRow(
                                cells: [
                                  DataCell(Text(role.appName ?? 'NKG App')),
                                  DataCell(
                                    Text(
                                      role.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      role.description.isEmpty
                                          ? role.appAccess
                                          : role.description,
                                    ),
                                  ),
                                  DataCell(
                                    OutlinedButton(
                                      onPressed: app == null
                                          ? null
                                          : () async {
                                              await _showRolePermissionEditor(
                                                app,
                                                role,
                                              );
                                              if (mounted) {
                                                setState(
                                                  () => _workspaceRoles =
                                                      _loadAllRolesForAdmin(),
                                                );
                                              }
                                            },
                                      child: Text(
                                        _text(
                                          context,
                                          'Edit permissions',
                                          'Edit izin',
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                          if (roles.isEmpty)
                            Padding(
                              padding: const EdgeInsets.all(32),
                              child: Text(
                                _text(
                                  context,
                                  'No roles configured yet.',
                                  'Belum ada peran.',
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openApp(LauncherApp app) async {
    if (!await launchLocalApp(appId: app.id, webUrl: app.launchUrl)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('The application could not be opened.')),
        );
      }
    }
  }

  void _showProfile() {
    final user = widget.demoMode
        ? null
        : Supabase.instance.client.auth.currentUser;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(_text(dialogContext, 'My profile', 'Profil saya')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _text(dialogContext, 'Email address', 'Alamat email'),
              style: Theme.of(dialogContext).textTheme.labelMedium,
            ),
            const SizedBox(height: 4),
            Text(user?.email ?? 'admin'),
            const SizedBox(height: 16),
            Text(
              _text(dialogContext, 'Account status', 'Status akun'),
              style: Theme.of(dialogContext).textTheme.labelMedium,
            ),
            const SizedBox(height: 4),
            Text(_text(dialogContext, 'Active', 'Aktif')),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(_text(dialogContext, 'Close', 'Tutup')),
          ),
        ],
      ),
    );
  }

  void _showHelp() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(_text(dialogContext, 'Help centre', 'Pusat bantuan')),
        content: Text(
          _text(
            dialogContext,
            'Find answers or report a problem to the Master team.',
            'Temukan jawaban atau laporkan masalah kepada tim Master.',
          ),
        ),
        actions: [
          OutlinedButton.icon(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _showBugReport();
            },
            icon: const Icon(Icons.bug_report_outlined),
            label: Text(_text(dialogContext, 'Report a bug', 'Laporkan bug')),
          ),
          if (!widget.demoMode)
            OutlinedButton.icon(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _showBugInbox();
              },
              icon: const Icon(Icons.inbox_outlined),
              label: Text(_text(dialogContext, 'Bug inbox', 'Kotak bug')),
            ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(_text(dialogContext, 'Close', 'Tutup')),
          ),
        ],
      ),
    );
  }

  Future<void> _showBugReport() async {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    String? selectedAppId;
    String priority = 'normal';
    List<LauncherApp> apps = [];
    try {
      apps = await _apps;
    } catch (_) {}
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(_text(dialogContext, 'Report a bug', 'Laporkan bug')),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: InputDecoration(
                      labelText: _text(dialogContext, 'Summary', 'Ringkasan'),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String?>(
                    initialValue: selectedAppId,
                    decoration: InputDecoration(
                      labelText: _text(
                        dialogContext,
                        'Application',
                        'Aplikasi',
                      ),
                      border: const OutlineInputBorder(),
                    ),
                    items: [
                      DropdownMenuItem<String?>(
                        value: null,
                        child: Text(_text(dialogContext, 'General', 'Umum')),
                      ),
                      ...apps.map(
                        (app) => DropdownMenuItem<String?>(
                          value: app.id,
                          child: Text(app.name),
                        ),
                      ),
                    ],
                    onChanged: (value) => setDialogState(() {
                      selectedAppId = value;
                    }),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: priority,
                    decoration: InputDecoration(
                      labelText: _text(dialogContext, 'Priority', 'Prioritas'),
                      border: const OutlineInputBorder(),
                    ),
                    items: ['low', 'normal', 'high', 'critical']
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(value.toUpperCase()),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setDialogState(() {
                      priority = value ?? 'normal';
                    }),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: descriptionController,
                    minLines: 5,
                    maxLines: 8,
                    decoration: InputDecoration(
                      labelText: _text(
                        dialogContext,
                        'What happened?',
                        'Apa yang terjadi?',
                      ),
                      alignLabelWithHint: true,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(_text(dialogContext, 'Cancel', 'Batal')),
            ),
            FilledButton.icon(
              onPressed: () async {
                try {
                  await Supabase.instance.client.rpc(
                    'create_bug_report',
                    params: {
                      'p_title': titleController.text,
                      'p_description': descriptionController.text,
                      'p_app_id': selectedAppId,
                      'p_priority': priority,
                    },
                  );
                  if (mounted && dialogContext.mounted) {
                    Navigator.of(dialogContext).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          _text(
                            context,
                            'Bug report sent to the Master team.',
                            'Laporan bug dikirim ke tim Master.',
                          ),
                        ),
                      ),
                    );
                  }
                } catch (error) {
                  if (dialogContext.mounted) {
                    ScaffoldMessenger.of(
                      dialogContext,
                    ).showSnackBar(SnackBar(content: Text(error.toString())));
                  }
                }
              },
              icon: const Icon(Icons.send_outlined),
              label: Text(_text(dialogContext, 'Send report', 'Kirim laporan')),
            ),
          ],
        ),
      ),
    );
    titleController.dispose();
    descriptionController.dispose();
  }

  Future<void> _showBugInbox() async {
    var reportsFuture = _loadBugReports();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(_text(dialogContext, 'Bug inbox', 'Kotak bug')),
          content: SizedBox(
            width: 720,
            height: 520,
            child: FutureBuilder<List<BugReport>>(
              future: reportsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text(snapshot.error.toString()));
                }
                final reports = snapshot.data ?? [];
                if (reports.isEmpty) {
                  return Center(
                    child: Text(
                      _text(
                        context,
                        'No bug reports yet.',
                        'Belum ada laporan bug.',
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  itemCount: reports.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final report = reports[index];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      leading: CircleAvatar(
                        child: Icon(
                          report.priority == 'critical'
                              ? Icons.priority_high
                              : Icons.bug_report_outlined,
                        ),
                      ),
                      title: Text(report.title),
                      subtitle: Text(
                        '${report.reporterEmail} · ${report.appName ?? 'General'}\n${report.description}',
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: DropdownButton<String>(
                        value: report.status,
                        items: const [
                          DropdownMenuItem(value: 'open', child: Text('Open')),
                          DropdownMenuItem(
                            value: 'in_progress',
                            child: Text('In progress'),
                          ),
                          DropdownMenuItem(
                            value: 'resolved',
                            child: Text('Resolved'),
                          ),
                        ],
                        onChanged: (status) async {
                          if (status == null) return;
                          try {
                            await Supabase.instance.client.rpc(
                              'update_bug_report_status',
                              params: {
                                'p_bug_id': report.id,
                                'p_status': status,
                              },
                            );
                            setDialogState(() {
                              reportsFuture = _loadBugReports();
                            });
                          } catch (error) {
                            if (dialogContext.mounted) {
                              ScaffoldMessenger.of(dialogContext).showSnackBar(
                                SnackBar(content: Text(error.toString())),
                              );
                            }
                          }
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(_text(dialogContext, 'Close', 'Tutup')),
            ),
          ],
        ),
      ),
    );
  }

  Future<List<BugReport>> _loadBugReports() async {
    final response = await Supabase.instance.client.rpc(
      'get_bug_reports_for_master',
    );
    return (response as List<dynamic>)
        .map((row) => BugReport.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.demoMode
        ? null
        : Supabase.instance.client.auth.currentUser;
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 900;
            return Row(
              children: [
                if (wide)
                  _LauncherSidebar(
                    onApplications: () =>
                        setState(() => _roleWorkspaceActive = false),
                    onProfile: _showProfile,
                    onHelp: _showHelp,
                    onStaffManagement: _showStaffManagement,
                    onAppManagement: _showAppManagement,
                    onRoleManagement: _openRoleWorkspace,
                    roleWorkspaceActive: _roleWorkspaceActive,
                  ),
                Expanded(
                  child: FutureBuilder<List<LauncherApp>>(
                    future: _apps,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        return Center(
                          child: Text(
                            'Unable to load applications: ${snapshot.error}',
                          ),
                        );
                      }
                      final apps = snapshot.data ?? [];
                      if (apps.isEmpty) {
                        return const Center(
                          child: Text(
                            'No applications have been assigned to you.',
                          ),
                        );
                      }
                      return RefreshIndicator(
                        onRefresh: () async =>
                            setState(() => _apps = _loadApps()),
                        child: CustomScrollView(
                          slivers: [
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  28,
                                  22,
                                  28,
                                  8,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          _WelcomeDateTime(email: user?.email),
                                        ],
                                      ),
                                    ),
                                    const _LanguageSwitcher(),
                                    Stack(
                                      clipBehavior: Clip.none,
                                      children: [
                                        IconButton(
                                          tooltip: _text(
                                            context,
                                            'Notifications',
                                            'Notifikasi',
                                          ),
                                          onPressed: widget.demoMode
                                              ? null
                                              : _showNotifications,
                                          icon: const Icon(
                                            Icons.notifications_none_outlined,
                                          ),
                                        ),
                                        if (_unreadNotifications > 0)
                                          Positioned(
                                            right: 4,
                                            top: 4,
                                            child: Container(
                                              padding: const EdgeInsets.all(4),
                                              decoration: const BoxDecoration(
                                                color: Color(0xffe21d2a),
                                                shape: BoxShape.circle,
                                              ),
                                              child: Text(
                                                _unreadNotifications > 9
                                                    ? '9+'
                                                    : '$_unreadNotifications',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    IconButton(
                                      tooltip: _text(
                                        context,
                                        'Toggle theme',
                                        'Ganti tema',
                                      ),
                                      onPressed: _toggleTheme,
                                      icon: Icon(
                                        Theme.of(context).brightness ==
                                                Brightness.dark
                                            ? Icons.light_mode_outlined
                                            : Icons.dark_mode_outlined,
                                      ),
                                    ),
                                    if (widget.demoMode)
                                      const SizedBox.shrink()
                                    else ...[
                                      CircleAvatar(
                                        backgroundColor: const Color(
                                          0xffdbeafe,
                                        ),
                                        child: Text(
                                          (user?.email ?? 'U')
                                              .substring(0, 1)
                                              .toUpperCase(),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      IconButton(
                                        tooltip: _text(
                                          context,
                                          'Sign out',
                                          'Keluar',
                                        ),
                                        onPressed: () => Supabase
                                            .instance
                                            .client
                                            .auth
                                            .signOut(),
                                        icon: const Icon(Icons.logout),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: EdgeInsets.fromLTRB(28, 28, 28, 18),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _text(
                                        context,
                                        'Applications',
                                        'Aplikasi',
                                      ),
                                      style: TextStyle(
                                        fontSize: 30,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            SliverPadding(
                              padding: const EdgeInsets.fromLTRB(28, 0, 28, 28),
                              sliver: SliverGrid.builder(
                                gridDelegate:
                                    const SliverGridDelegateWithMaxCrossAxisExtent(
                                      maxCrossAxisExtent: 390,
                                      mainAxisExtent: 235,
                                      crossAxisSpacing: 18,
                                      mainAxisSpacing: 18,
                                    ),
                                itemCount: apps.length,
                                itemBuilder: (context, index) {
                                  final app = apps[index];
                                  final paused = app.status != 'active';
                                  final waterpark = app.id == 'waterpark';
                                  final color = waterpark
                                      ? const Color(0xff0f8b9d)
                                      : const Color(0xff1f6fb2);
                                  final logo = waterpark
                                      ? 'assets/branding/waterpark_logo.png'
                                      : 'assets/branding/company_logo_transparent.png';
                                  return Card(
                                    elevation: 1,
                                    clipBehavior: Clip.antiAlias,
                                    child: InkWell(
                                      onTap: paused
                                          ? null
                                          : () => _openApp(app),
                                      child: Padding(
                                        padding: const EdgeInsets.all(22),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Container(
                                                  width: 54,
                                                  height: 54,
                                                  decoration: BoxDecoration(
                                                    color: color.withValues(
                                                      alpha: .12,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          16,
                                                        ),
                                                  ),
                                                  child: Padding(
                                                    padding:
                                                        const EdgeInsets.all(8),
                                                    child: Image.asset(
                                                      logo,
                                                      fit: BoxFit.contain,
                                                    ),
                                                  ),
                                                ),
                                                const Spacer(),
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 10,
                                                        vertical: 5,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: paused
                                                        ? Colors.orange.shade50
                                                        : Colors.green.shade50,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          20,
                                                        ),
                                                  ),
                                                  child: Text(
                                                    paused
                                                        ? _text(
                                                            context,
                                                            'Paused',
                                                            'Dijeda',
                                                          )
                                                        : _text(
                                                            context,
                                                            'Available',
                                                            'Tersedia',
                                                          ),
                                                    style: TextStyle(
                                                      color: paused
                                                          ? Colors
                                                                .orange
                                                                .shade800
                                                          : Colors
                                                                .green
                                                                .shade800,
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 18),
                                            Text(
                                              app.name,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .titleLarge
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                            ),
                                            const SizedBox(height: 6),
                                            Expanded(
                                              child: Text(
                                                app.description,
                                                style: TextStyle(
                                                  color: Colors.grey.shade700,
                                                  height: 1.35,
                                                ),
                                              ),
                                            ),
                                            Row(
                                              children: [
                                                Text(
                                                  paused
                                                      ? _text(
                                                          context,
                                                          'Maintenance in progress',
                                                          'Sedang dalam pemeliharaan',
                                                        )
                                                      : _text(
                                                          context,
                                                          'Open app',
                                                          'Buka aplikasi',
                                                        ),
                                                  style: TextStyle(
                                                    color: color,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                                const Spacer(),
                                                Icon(
                                                  paused
                                                      ? Icons.lock_outline
                                                      : Icons
                                                            .arrow_forward_rounded,
                                                  color: color,
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
