import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

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
      colorSchemeSeed: const Color(0xFFFF7900),
      useMaterial3: true,
      inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder()),
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
  final _displayName = TextEditingController();
  final _legacyEmail = TextEditingController();
  final _legacyPassword = TextEditingController();
  bool _busy = false;
  bool _codeSent = false;
  bool _linkingLegacy = false;
  bool _showLegacy = false;
  String? _verificationId;
  int? _resendToken;

  @override
  void dispose() {
    _phone.dispose();
    _otp.dispose();
    _displayName.dispose();
    _legacyEmail.dispose();
    _legacyPassword.dispose();
    super.dispose();
  }

  String? _e164Phone() {
    final digits = _phone.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 10 && RegExp(r'^[6-9]\d{9}$').hasMatch(digits)) return '+91$digits';
    if (digits.length == 12 && digits.startsWith('91') && RegExp(r'^91[6-9]\d{9}$').hasMatch(digits)) return '+$digits';
    return null;
  }

  void _message(String value) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }

  Future<void> _requestOtp({bool linkLegacy = false, bool resend = false}) async {
    final phone = _e164Phone();
    if (phone == null) {
      _message('Enter a valid 10-digit Indian mobile number.');
      return;
    }
    setState(() => _busy = true);
    try {
      final auth = FirebaseAuth.instance;
      if (linkLegacy && !_linkingLegacy) {
        if (_legacyEmail.text.trim().isEmpty || _legacyPassword.text.isEmpty) {
          _message('Enter your existing account email and password first.');
          return;
        }
        final result = await auth.signInWithEmailAndPassword(
          email: _legacyEmail.text.trim(),
          password: _legacyPassword.text,
        );
        if (result.user == null) throw FirebaseAuthException(code: 'user-not-found');
        if (result.user!.phoneNumber != null) {
          _message('This account already has a verified phone. Sign in using mobile OTP.');
          return;
        }
        _linkingLegacy = true;
      }

      await auth.verifyPhoneNumber(
        phoneNumber: phone,
        timeout: const Duration(seconds: 60),
        forceResendingToken: resend ? _resendToken : null,
        verificationCompleted: (credential) async {
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
          _message('OTP sent. Enter the 6-digit code.');
        },
        codeAutoRetrievalTimeout: (verificationId) {
          _verificationId = verificationId;
        },
      );
    } on FirebaseAuthException catch (error) {
      _message(error.code == 'credential-already-in-use' || error.code == 'phone-number-already-exists'
        ? 'This mobile number is linked to another account. Account recovery is required; accounts will not be merged automatically.'
        : error.message ?? 'Authentication failed. Please try again.');
    } catch (_) {
      _message('Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _finishCredential(PhoneAuthCredential credential) async {
    try {
      final auth = FirebaseAuth.instance;
      if (_linkingLegacy && auth.currentUser != null) {
        await auth.currentUser!.linkWithCredential(credential);
        await auth.currentUser!.reload();
      } else {
        await auth.signInWithCredential(credential);
      }
      final name = _displayName.text.trim();
      if (name.isNotEmpty && auth.currentUser != null) {
        await auth.currentUser!.updateDisplayName(name);
      }
      if (!mounted) return;
      setState(() {
        _codeSent = false;
        _linkingLegacy = false;
        _verificationId = null;
        _otp.clear();
      });
      _message('Mobile number verified successfully.');
    } on FirebaseAuthException catch (error) {
      _message(error.code == 'credential-already-in-use' || error.code == 'phone-number-already-exists'
        ? 'This mobile number belongs to another account. Please contact support for secure account recovery.'
        : error.message ?? 'Could not verify this mobile number.');
    } catch (_) {
      _message('Could not complete mobile verification. Please try again.');
    }
  }

  Future<void> _verifyOtp() async {
    final verificationId = _verificationId;
    final code = _otp.text.trim();
    if (verificationId == null || !RegExp(r'^\d{6}$').hasMatch(code)) {
      _message('Enter the 6-digit OTP.');
      return;
    }
    setState(() => _busy = true);
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: code,
      );
      await _finishCredential(credential);
    } on FirebaseAuthException catch (error) {
      _message(error.message ?? 'Invalid or expired OTP.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
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
              Text(
                _linkingLegacy ? 'Secure your existing account' : 'Welcome to DOJO WALK',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(_linkingLegacy
                ? 'Verify your mobile by OTP. It will be linked to your existing account so your history stays safe.'
                : 'Continue securely with your mobile number. No password required.'),
              const SizedBox(height: 24),
              if (!_codeSent && !_showLegacy) ...[
                TextField(
                  controller: _displayName,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Your name (optional)'),
                ),
                const SizedBox(height: 14),
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
                    : const Text('Continue with OTP'),
                ),
                TextButton(
                  onPressed: _busy ? null : () => setState(() => _showLegacy = true),
                  child: const Text('Already have an account? Link it safely'),
                ),
              ],
              if (!_codeSent && _showLegacy) ...[
                const Text('Existing account recovery'),
                const SizedBox(height: 12),
                TextField(
                  controller: _legacyEmail,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Existing account email'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _legacyPassword,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Existing account password'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  maxLength: 10,
                  decoration: const InputDecoration(labelText: 'Mobile number to verify', prefixText: '+91 ', counterText: ''),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _busy ? null : () => _requestOtp(linkLegacy: true),
                  child: _busy
                    ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Verify & link mobile'),
                ),
                TextButton(
                  onPressed: _busy ? null : () => setState(() => _showLegacy = false),
                  child: const Text('Back to mobile OTP sign in'),
                ),
              ],
              if (_codeSent) ...[
                Text('Enter the OTP sent to +91 ' + _phone.text.trim()),
                const SizedBox(height: 12),
                TextField(
                  controller: _otp,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  decoration: const InputDecoration(labelText: '6-digit OTP', counterText: ''),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _busy ? null : _verifyOtp,
                  child: _busy
                    ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Verify OTP'),
                ),
                TextButton(
                  onPressed: _busy ? null : () => _requestOtp(resend: true),
                  child: const Text('Resend OTP'),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
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
        initialPhone: data['phone'] as String? ?? '',
        onSubmitted: _refresh,
        rejected: status == 'rejected',
      );
    },
  );
}

class WalkerApplicationScreen extends StatefulWidget {
  const WalkerApplicationScreen({
    required this.initialName,
    required this.initialPhone,
    required this.onSubmitted,
    required this.rejected,
    super.key,
  });

  final String initialName;
  final String initialPhone;
  final Future<void> Function() onSubmitted;
  final bool rejected;

  @override
  State<WalkerApplicationScreen> createState() => _WalkerApplicationScreenState();
}

class _WalkerApplicationScreenState extends State<WalkerApplicationScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name = TextEditingController(text: widget.initialName);
  late final TextEditingController _phone = TextEditingController(text: widget.initialPhone);
  final _pincode = TextEditingController();
  String _city = 'Noida';
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
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
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: '10-digit mobile number'),
              validator: (v) => v == null || !RegExp(r'^[6-9][0-9]{9}$').hasMatch(v.trim())
                ? 'Enter a valid 10-digit Indian mobile number' : null,
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

class WalkerDashboard extends StatefulWidget {
  const WalkerDashboard({required this.name, super.key});
  final String name;

  @override
  State<WalkerDashboard> createState() => _WalkerDashboardState();
}

class _WalkerDashboardState extends State<WalkerDashboard> {
  late Future<Map<String, dynamic>> _dashboard;
  bool _saving = false;

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
              Text('Welcome, ${widget.name}', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 6),
              const Text('Your walker account is approved and active.'),
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
                ...bookings.map((booking) => Card(
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
                          onPressed: () => _updateBookingStatus(booking['bookingId'] as String, 'complete'),
                          icon: const Icon(Icons.check_circle_outline),
                          label: const Text('Complete walk'),
                        )
                      else
                        FilledButton.icon(
                          onPressed: () => _updateBookingStatus(booking['bookingId'] as String, 'start'),
                          icon: const Icon(Icons.play_arrow),
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
