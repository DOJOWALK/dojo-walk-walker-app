import 'package:flutter/material.dart';

void main() => runApp(const WalkerApp());

class WalkerApp extends StatelessWidget {
  const WalkerApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'DOJO WALK Walker', debugShowCheckedModeBanner: false,
    theme: ThemeData(colorSchemeSeed: const Color(0xFFFF7900), useMaterial3: true),
    home: const WalkerHome(),
  );
}

class WalkerHome extends StatelessWidget {
  const WalkerHome({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('DOJO WALK • Walker')),
    body: const Padding(padding: EdgeInsets.all(24), child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [Text('Your walking dashboard', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
      SizedBox(height: 12), Text('New walk assignments and availability will appear here.'),
      SizedBox(height: 24), Card(child: ListTile(leading: Icon(Icons.pets), title: Text('No assigned walks yet'), subtitle: Text('Complete onboarding to get started.')))],
    )),
  );
}
