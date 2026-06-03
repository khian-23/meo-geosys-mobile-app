import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/application_controller.dart';
import '../state/session_controller.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final session = context.read<SessionController>();
      // Only try to load remote applications when connected to the real API.
      if (session.isLocalMode) {
        context.read<ApplicationController>().loadLocal();
      } else {
        context.read<ApplicationController>().load(session.api);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final apps = context.watch<ApplicationController>();
    final name = session.profile?['first_name']?.toString() ?? 'Client';

    return Scaffold(
      appBar: AppBar(
        title: Text('Welcome, $name'),
        actions: [
          IconButton(
            onPressed: () => Navigator.pushNamed(context, '/profile'),
            icon: const Icon(Icons.person_outline),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.pushNamed(context, '/new-application'),
        icon: const Icon(Icons.add_location_alt_outlined),
        label: const Text('New application'),
      ),
      body: RefreshIndicator(
        onRefresh: () =>
            session.isLocalMode ? apps.loadLocal() : apps.load(session.api),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // FIX: Show an offline-mode banner so the user knows
            // the backend is not connected.
            if (session.isLocalMode)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  border: Border.all(color: Colors.orange.shade300),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(Icons.wifi_off,
                        size: 18, color: Colors.orange.shade700),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Running in offline mode — '
                        'data is stored on this device only. '
                        'Connect to the server to sync.',
                        style: TextStyle(
                            fontSize: 13, color: Colors.orange.shade800),
                      ),
                    ),
                  ],
                ),
              ),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Corner capture flow',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    SizedBox(height: 8),
                    Text('Walk to every lot corner, record the coordinate, '
                        'review the polygon, then submit.'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (!session.isLocalMode && apps.isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
              ),
            if (!session.isLocalMode && apps.error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(apps.error!,
                    style: const TextStyle(color: Colors.red)),
              ),
            if (session.isLocalMode && apps.applications.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'No applications yet.\nTap "+ New application" to get started.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              ),
            ...apps.applications.map(
              (app) => Card(
                child: ListTile(
                  title: Text(app.projectName),
                  subtitle: Text(
                      '${app.referenceNumber} • ${app.status.toUpperCase()}'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.pushNamed(
                      context, '/application-detail',
                      arguments: app.applicationId),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
