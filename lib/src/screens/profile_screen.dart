import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/session_controller.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final profile = session.profile ?? const <String, dynamic>{};

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(title: const Text('Name'), subtitle: Text('${profile['first_name'] ?? ''} ${profile['last_name'] ?? ''}'.trim())),
          ListTile(title: const Text('Email'), subtitle: Text(profile['email']?.toString() ?? '')),
          ListTile(title: const Text('Phone'), subtitle: Text(profile['phone']?.toString() ?? '')),
          ListTile(title: const Text('Address'), subtitle: Text(profile['address']?.toString() ?? '')),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () async {
              await session.logout();
              if (context.mounted) {
                Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
              }
            },
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}
