import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'phone_number.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
    runApp(const WalkerApp());
  } catch (error) {
    runApp(MaterialApp(
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Firebase setup is incomplete. Configure FlutterFire and add native Firebase files.\n\n$error'),
          ),
        ),
      ),
    ));
  }
}

class WalkerApp extends StatelessWidget {
  const WalkerApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'DOJO WALK Walker',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFFF28C28),
        primary: const Color(0xFFF28C28),
        secondary: const Color(0xFF174A78),
        surface: const Color(0xFFFFFDF9),
      ),
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xFFF6F8FB),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFFFFDF9),
        foregroundColor: Color(0xFF174A78),
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 3,
        shadowColor: Color(0x24174A78),
        margin: const EdgeInsets.symmetric(vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFFE8EDF3)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFDCE4ED)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFDCE4ED)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFF28C28), width: 1.8),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 52),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
          elevation: 3,
          shadowColor: const Color(0x55F28C28),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          side: const BorderSide(color: Color(0xFF174A78), width: 1.2),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    home: const WalkerAuthGate(),
  );
}

class WalkerAuthGate extends StatelessWidget {
  const WalkerAuthGate({super.key});

  @override
  Widget build(BuildContext context) => StreamBuilder<User?>(
    stream: FirebaseAuth.instance.authStateChanges(),
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      final user = snapshot.data;
      if (user == null || user.phoneNumber == null) return const WalkerSignInScreen();
      return WalkerPortal(key: ValueKey(user.uid));
    },
  );
}


class WalkerSignInScreen extends StatefulWidget {
  const WalkerSignInScreen({super.key});
  @override
  State<WalkerSignInScreen> createState() => _WalkerSignInScreenState();
}

class _WalkerSignInScreenState extends State<WalkerSignInScreen> {
  final _phone = TextEditingController();
  final _otp = TextEditingController();
  bool _busy = false;
  bool _codeSent = false;
  bool _finishing = false;
  String? _verificationId;
  int? _resendToken;
  Timer? _resendTimer;
  int _resendSeconds = 0;

  void _startResendCountdown() {
    _resendTimer?.cancel();
    setState(() => _resendSeconds = 60);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendSeconds <= 1) {
        timer.cancel();
        _resendTimer = null;
        setState(() => _resendSeconds = 0);
      } else {
        setState(() => _resendSeconds--);
      }
    });
  }

  void _resetResendCountdown() {
    _resendTimer?.cancel();
    _resendTimer = null;
    _resendSeconds = 0;
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _phone.dispose();
    _otp.dispose();
    super.dispose();
  }

  String? _e164Phone() => normalizeIndianMobileNumber(_phone.text);

  void _message(String value) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }

  Future<void> _requestOtp({bool resend = false}) async {
    final phone = _e164Phone();
    if (phone == null) {
      _message('Enter a valid 10-digit Indian mobile number.');
      return;
    }
    setState(() => _busy = true);
    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phone,
        timeout: const Duration(seconds: 60),
        forceResendingToken: resend ? _resendToken : null,
        verificationCompleted: (credential) async {
          // Android may verify the SMS automatically; no manual OTP entry is needed.
          await _finishCredential(credential);
        },
        verificationFailed: (error) {
          _message(error.message ?? 'Could not send OTP. Please try again.');
        },
        codeSent: (verificationId, resendToken) {
          if (!mounted) return;
          setState(() {
            _verificationId = verificationId;
            _resendToken = resendToken;
            _codeSent = true;
          });
          _startResendCountdown();
        },
        codeAutoRetrievalTimeout: (verificationId) {
          _verificationId = verificationId;
        },
      );
    } on FirebaseAuthException catch (error) {
      _message(error.message ?? 'Authentication failed. Please try again.');
    } catch (_) {
      _message('Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _finishCredential(PhoneAuthCredential credential) async {
    if (_finishing) return;
    _finishing = true;
    if (mounted) setState(() => _busy = true);
    try {
      // Firebase resolves an existing phone account to its original UID;
      // a first-time phone number receives a new Auth account automatically.
      await FirebaseAuth.instance.signInWithCredential(credential);
      if (!mounted) return;
      setState(() {
        _codeSent = false;
        _verificationId = null;
        _otp.clear();
      });
      _message('Mobile number verified. Welcome to DOJO WALK Walker.');
    } on FirebaseAuthException catch (error) {
      _message(error.message ?? 'Could not verify this mobile number.');
    } catch (_) {
      _message('Could not complete mobile verification. Please try again.');
    } finally {
      _finishing = false;
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verifyOtp() async {
    final verificationId = _verificationId;
    final code = _otp.text.trim();
    if (verificationId == null || !RegExp(r'^\d{6}$').hasMatch(code)) {
      _message('Enter the 6-digit OTP.');
      return;
    }
    await _finishCredential(PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: code,
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (_codeSent) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Verify mobile number'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _busy ? null : () => setState(() {
              _resetResendCountdown();
              _codeSent = false;
              _verificationId = null;
              _otp.clear();
            }),
          ),
        ),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.mark_email_read_outlined, size: 54),
                  const SizedBox(height: 18),
                  Text('Enter OTP', style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  Text('6-digit code sent to +91 ${_phone.text.trim()}'),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _otp,
                    keyboardType: TextInputType.number,
                    autofillHints: const [AutofillHints.oneTimeCode],
                    textInputAction: TextInputAction.done,
                    maxLength: 6,
                    decoration: const InputDecoration(labelText: '6-digit OTP', counterText: ''),
                    onSubmitted: (_) => _busy ? null : _verifyOtp(),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _busy ? null : _verifyOtp,
                    child: _busy
                      ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Verify & Continue'),
                  ),
                  TextButton(
                    onPressed: _busy || _resendSeconds > 0
                        ? null
                        : () => _requestOtp(resend: true),
                    child: Text(
                      _resendSeconds > 0
                          ? 'Resend OTP in ${(_resendSeconds ~/ 60).toString().padLeft(2, '0')}:${(_resendSeconds % 60).toString().padLeft(2, '0')}'
                          : 'Resend OTP',
                    ),
                  ),
                  TextButton(
                    onPressed: _busy ? null : () => setState(() {
                      _resetResendCountdown();
                      _codeSent = false;
                      _verificationId = null;
                      _otp.clear();
                    }),
                    child: const Text('Change mobile number'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('DOJO WALK • Walker')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.pets, size: 58),
                const SizedBox(height: 14),
                Text('Welcome to DOJO WALK', style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 8),
                const Text('Walker account में आगे बढ़ने के लिए मोबाइल नंबर डालें।'),
                const SizedBox(height: 24),
                TextField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  maxLength: 10,
                  decoration: const InputDecoration(
                    labelText: 'Mobile number',
                    prefixText: '+91 ',
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: _busy ? null : () => _requestOtp(),
                  child: _busy
                    ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Continue'),
                ),
                const SizedBox(height: 12),
                const Text(
                  'By continuing, you agree to receive an OTP for mobile verification.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class WalkerPortal extends StatefulWidget {
  const WalkerPortal({super.key});

  @override
  State<WalkerPortal> createState() => _WalkerPortalState();
}

class _WalkerPortalState extends State<WalkerPortal> {
  late Future<Map<String, dynamic>> _application;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _application = FirebaseFunctions.instance
      .httpsCallable('getWalkerApplication')
      .call()
      .then((result) => Map<String, dynamic>.from(result.data as Map));
  }

  Future<void> _refresh() async {
    setState(_load);
    try {
      await _application;
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>>(
    future: _application,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      if (snapshot.hasError) {
        return Scaffold(
          appBar: AppBar(title: const Text('DOJO WALK • Walker'), actions: [
            IconButton(onPressed: () => FirebaseAuth.instance.signOut(), icon: const Icon(Icons.logout)),
          ]),
          body: Center(child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('Could not load your walker profile.'),
              const SizedBox(height: 12),
              FilledButton(onPressed: _refresh, child: const Text('Retry')),
            ]),
          )),
        );
      }
      final data = snapshot.data!;
      final status = data['status'] as String? ?? 'not_submitted';
      if (status == 'approved' && data['active'] == true) {
        return WalkerDashboard(name: data['displayName'] as String? ?? 'Walker');
      }
      if (status == 'migration_required') {
        return const WalkerMigrationScreen();
      }
      if (status == 'pending') {
        return WalkerPendingScreen(
          name: data['displayName'] as String? ?? 'Walker',
          city: data['city'] as String? ?? '',
          pincode: data['pincode'] as String? ?? '',
          onRefresh: _refresh,
        );
      }
      return WalkerApplicationScreen(
        initialName: data['displayName'] as String? ?? '',
        initialPhone: (FirebaseAuth.instance.currentUser?.phoneNumber ?? data['phone'] as String? ?? '').replaceAll(RegExp(r'\D'), '').replaceFirst(RegExp(r'^91'), ''),
        initialEmail: data['email'] as String? ?? '',
        onSubmitted: _refresh,
        rejected: status == 'rejected',
      );
    },
  );
}

class WalkerMigrationScreen extends StatelessWidget {
  const WalkerMigrationScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('DOJO WALK • Walker')),
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.support_agent, size: 56),
            const SizedBox(height: 16),
            Text('Existing worker account found',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center),
            const SizedBox(height: 12),
            const Text(
              'Your verified mobile number matches an older DOJO WALK worker record. '
              'To protect your work history, we will not create a duplicate account. '
              'Please contact DOJO WALK support to securely migrate your existing account.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            OutlinedButton(
              onPressed: () => FirebaseAuth.instance.signOut(),
              child: const Text('Sign out'),
            ),
          ],
        ),
      ),
    ),
  );
}

class WalkerApplicationScreen extends StatefulWidget {
  const WalkerApplicationScreen({
    required this.initialName,
    required this.initialPhone,
    required this.initialEmail,
    required this.onSubmitted,
    required this.rejected,
    super.key,
  });

  final String initialName;
  final String initialPhone;
  final String initialEmail;
  final Future<void> Function() onSubmitted;
  final bool rejected;

  @override
  State<WalkerApplicationScreen> createState() => _WalkerApplicationScreenState();
}

class _WalkerApplicationScreenState extends State<WalkerApplicationScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name = TextEditingController(text: widget.initialName);
  late final TextEditingController _phone = TextEditingController(text: widget.initialPhone);
  late final _email = TextEditingController(text: widget.initialEmail);
  final _pincode = TextEditingController();
  String _city = 'Noida';
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _pincode.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await FirebaseFunctions.instance.httpsCallable('submitWalkerApplication').call({
        'displayName': _name.text.trim(),
        'phone': _phone.text.trim(),
        'email': _email.text.trim(),
        'city': _city,
        'pincode': _pincode.text.trim(),
      });
      await widget.onSubmitted();
    } on FirebaseFunctionsException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message ?? 'Application could not be submitted.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Application could not be submitted. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Walker application'), actions: [
      IconButton(onPressed: () => FirebaseAuth.instance.signOut(), icon: const Icon(Icons.logout)),
    ]),
    body: Center(child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Form(
          key: _formKey,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(widget.rejected ? 'Update your application' : 'Apply to become a walker',
              style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            const Text('Your account will remain inactive until the DOJO WALK admin team approves your details and service area.'),
            const SizedBox(height: 20),
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Full name'),
              validator: (v) => v == null || v.trim().length < 2 ? 'Enter your full name' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _phone,
              readOnly: true,
              decoration: const InputDecoration(labelText: 'Verified mobile number', prefixText: '+91 '),
              validator: (v) => v == null || !RegExp(r'^[6-9][0-9]{9}$').hasMatch(v.trim())
                ? 'Enter a valid 10-digit Indian mobile number' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email address (optional)'),
              validator: (v) {
                final value = v?.trim() ?? '';
                if (value.isEmpty) return null;
                return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value)
                    ? null : 'Enter a valid email address or leave it blank';
              },
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              value: _city,
              decoration: const InputDecoration(labelText: 'Preferred city'),
              items: const ['Noida', 'Greater Noida', 'Ghaziabad']
                .map((city) => DropdownMenuItem(value: city, child: Text(city))).toList(),
              onChanged: _busy ? null : (v) { if (v != null) setState(() => _city = v); },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _pincode,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: const InputDecoration(labelText: 'Service area pincode'),
              validator: (v) => v == null || !RegExp(r'^[0-9]{6}$').hasMatch(v.trim())
                ? 'Enter a valid 6-digit pincode' : null,
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: _busy ? const CircularProgressIndicator() : const Text('Submit for approval'),
            ),
          ]),
        ),
      ),
    )),
  );
}

class WalkerPendingScreen extends StatelessWidget {
  const WalkerPendingScreen({
    required this.name,
    required this.city,
    required this.pincode,
    required this.onRefresh,
    super.key,
  });

  final String name;
  final String city;
  final String pincode;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('DOJO WALK • Walker'), actions: [
      IconButton(onPressed: () => FirebaseAuth.instance.signOut(), icon: const Icon(Icons.logout)),
    ]),
    body: Center(child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.hourglass_top, size: 56, color: Color(0xFFFF7900)),
        const SizedBox(height: 16),
        Text('Application under review', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text('Thank you, $name. Your application for $city ($pincode) is awaiting admin approval.',
          textAlign: TextAlign.center),
        const SizedBox(height: 20),
        OutlinedButton(onPressed: onRefresh, child: const Text('Check approval status')),
      ]),
    )),
  );
}

class _WalkerDashboardMetric extends StatelessWidget {
  const _WalkerDashboardMetric({
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 145,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, color: accent, size: 19),
            ),
            const SizedBox(height: 12),
            Text(value, style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: const Color(0xFF174A78),
            )),
            const SizedBox(height: 2),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    ),
  );
}

class WalkerDashboard extends StatefulWidget {
  const WalkerDashboard({required this.name, super.key});
  final String name;

  @override
  State<WalkerDashboard> createState() => _WalkerDashboardState();
}

class _WalkerDashboardState extends State<WalkerDashboard> {
  late Future<Map<String, dynamic>> _dashboard;
  bool _saving = false;
  bool _statusBusy = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _dashboard = FirebaseFunctions.instance.httpsCallable('getWalkerDashboard')
      .call().then((result) => Map<String, dynamic>.from(result.data as Map));
  }

  Future<void> _refresh() async {
    setState(_reload);
    try { await _dashboard; } catch (_) {}
  }

  Future<TimeOfDay?> _pickTime(BuildContext context, TimeOfDay initial) {
    return showTimePicker(context: context, initialTime: initial);
  }

  Future<void> _addAvailability() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 30)),
    );
    if (date == null || !mounted) return;
    final startTime = await _pickTime(context, const TimeOfDay(hour: 9, minute: 0));
    if (startTime == null || !mounted) return;
    final endTime = await _pickTime(context, const TimeOfDay(hour: 17, minute: 0));
    if (endTime == null || !mounted) return;
    final start = DateTime(date.year, date.month, date.day, startTime.hour, startTime.minute);
    final end = DateTime(date.year, date.month, date.day, endTime.hour, endTime.minute);
    if (!start.isAfter(DateTime.now()) || !end.isAfter(start)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose a future start time and a later end time.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await FirebaseFunctions.instance.httpsCallable('saveWalkerAvailability').call({
        'windows': [{'startAt': start.toUtc().toIso8601String(), 'endAt': end.toUtc().toIso8601String()}],
      });
      await _refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Availability saved successfully.')),
        );
      }
    } on FirebaseFunctionsException catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message ?? 'Could not save availability.')),
      );
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save availability. Please try again.')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _updateBookingStatus(String bookingId, String action) async {
    if (_statusBusy) return;
    setState(() => _statusBusy = true);
    try {
      await FirebaseFunctions.instance.httpsCallable('updateWalkerBookingStatus').call({
        'bookingId': bookingId,
        'action': action,
      });
      await _refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(action == 'start' ? 'Walk started.' : 'Walk marked as completed.')),
        );
      }
    } on FirebaseFunctionsException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message ?? 'Could not update this walk.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not update this walk. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _statusBusy = false);
    }
  }

  String _formatDate(dynamic value) {
    if (value is! String) return 'Time not available';
    final parsed = DateTime.tryParse(value)?.toLocal();
    if (parsed == null) return 'Time not available';
    return '${parsed.day.toString().padLeft(2, '0')}/${parsed.month.toString().padLeft(2, '0')}/${parsed.year}  ${TimeOfDay.fromDateTime(parsed).format(context)}';
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>>(
    future: _dashboard,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      if (snapshot.hasError) {
        return Scaffold(
          appBar: AppBar(title: const Text('DOJO WALK • Walker'), actions: [
            IconButton(onPressed: () => FirebaseAuth.instance.signOut(), icon: const Icon(Icons.logout)),
          ]),
          body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Could not load your dashboard.'),
            const SizedBox(height: 12),
            FilledButton(onPressed: _refresh, child: const Text('Retry')),
          ])),
        );
      }
      final data = snapshot.data!;
      final bookings = (data['bookings'] as List<dynamic>? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map)).toList();
      final windows = (data['availability'] as List<dynamic>? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map)).toList();
      final inProgressCount = bookings.where((booking) => booking['status'] == 'in_progress').length;
      final sortedBookings = [...bookings]..sort((a, b) {
        final aDate = DateTime.tryParse(a['scheduledAt']?.toString() ?? '');
        final bDate = DateTime.tryParse(b['scheduledAt']?.toString() ?? '');
        if (aDate == null) return bDate == null ? 0 : 1;
        if (bDate == null) return -1;
        return aDate.compareTo(bDate);
      });
      return Scaffold(
        appBar: AppBar(title: const Text('DOJO WALK • Walker'), actions: [
          IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh)),
          IconButton(onPressed: () => FirebaseAuth.instance.signOut(), icon: const Icon(Icons.logout)),
        ]),
        body: RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF174A78), Color(0xFF2876AD)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF174A78).withValues(alpha: 0.20),
                      blurRadius: 22,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Welcome, ${widget.name}',
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            )),
                          const SizedBox(height: 8),
                          const Text(
                            'Your walker account is approved and active. Ready for a great walk?',
                            style: TextStyle(color: Colors.white, height: 1.35),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
                      ),
                      child: const Icon(Icons.directions_walk, color: Colors.white, size: 36),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _WalkerDashboardMetric(
                    label: 'Assigned walks',
                    value: bookings.length.toString(),
                    icon: Icons.pets,
                    accent: const Color(0xFFF28C28),
                  ),
                  _WalkerDashboardMetric(
                    label: 'In progress',
                    value: inProgressCount.toString(),
                    icon: Icons.directions_walk,
                    accent: const Color(0xFF174A78),
                  ),
                  _WalkerDashboardMetric(
                    label: 'Availability slots',
                    value: windows.length.toString(),
                    icon: Icons.calendar_month,
                    accent: const Color(0xFF2876AD),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('My availability', style: Theme.of(context).textTheme.titleLarge),
                FilledButton.icon(
                  onPressed: _saving ? null : _addAvailability,
                  icon: const Icon(Icons.add),
                  label: const Text('Add time'),
                ),
              ]),
              const SizedBox(height: 8),
              if (windows.isEmpty)
                const Card(child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No future availability added. Add the dates and hours when you can accept walks.'),
                ))
              else
                ...windows.map((window) => Card(child: ListTile(
                  leading: const Icon(Icons.schedule),
                  title: Text(_formatDate(window['startAt'])),
                  subtitle: Text('Until ${_formatDate(window['endAt'])}'),
                ))),
              const SizedBox(height: 24),
              Text('Assigned walks', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              if (bookings.isEmpty)
                const Card(child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No confirmed upcoming walks assigned yet. New confirmed bookings will appear here.'),
                ))
              else
                ...sortedBookings.map((booking) => Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(booking['petName'] as String? ?? 'Pet walk',
                        style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 6),
                      Text(_formatDate(booking['scheduledAt'])),
                      Text('${booking['durationMinutes']} minute walk'),
                      Text('${booking['address']}, ${booking['city']} ${booking['pincode']}'),
                      const SizedBox(height: 6),
                      Text(
                        booking['status'] == 'in_progress' ? 'Walk in progress' : 'Payment confirmed',
                        style: TextStyle(
                          color: booking['status'] == 'in_progress' ? Colors.orange.shade800 : Colors.green,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (booking['status'] == 'in_progress')
                        FilledButton.icon(
                          onPressed: _statusBusy
                            ? null
                            : () => _updateBookingStatus(booking['bookingId'] as String, 'complete'),
                          icon: _statusBusy
                            ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.check_circle_outline),
                          label: const Text('Complete walk'),
                        )
                      else
                        FilledButton.icon(
                          onPressed: _statusBusy
                            ? null
                            : () => _updateBookingStatus(booking['bookingId'] as String, 'start'),
                          icon: _statusBusy
                            ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.play_arrow),
                          label: const Text('Start walk'),
                        ),
                    ]),
                  ),
                )),
            ],
          ),
        ),
      );
    },
  );
}
