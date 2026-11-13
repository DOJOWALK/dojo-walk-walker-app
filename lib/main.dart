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
      if (user == null) return const WalkerSignInScreen();
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
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _createAccount = false;
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final auth = FirebaseAuth.instance;
      if (_createAccount) {
        await auth.createUserWithEmailAndPassword(
          email: _email.text.trim(),
          password: _password.text,
        );
      } else {
        await auth.signInWithEmailAndPassword(
          email: _email.text.trim(),
          password: _password.text,
        );
      }
    } on FirebaseAuthException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message ?? 'Could not authenticate.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Something went wrong. Please try again.')),
        );
      }
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
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.pets, size: 56),
                const SizedBox(height: 12),
                Text(_createAccount ? 'Become a DOJO WALK partner' : 'Walker sign in',
                  style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 8),
                Text(_createAccount
                  ? 'Create an account and submit your details for admin approval.'
                  : 'Sign in to view your walker application and assigned walks.'),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email address'),
                  validator: (v) => v == null || !v.trim().contains('@')
                    ? 'Enter a valid email address' : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _password,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Password (minimum 8 characters)'),
                  validator: (v) => v == null || v.length < 8
                    ? 'Password must be at least 8 characters' : null,
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _busy ? null : _submit,
                  child: _busy
                    ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(_createAccount ? 'Create walker account' : 'Sign in'),
                ),
                TextButton(
                  onPressed: _busy ? null : () => setState(() => _createAccount = !_createAccount),
                  child: Text(_createAccount ? 'Already registered? Sign in' : 'New walker? Create account'),
                ),
              ],
            ),
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
                      const Text('Payment confirmed', style: TextStyle(color: Colors.green)),
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
