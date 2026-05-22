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
      context.read<ApplicationController>().load(session.api);
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
        onRefresh: () => apps.load(session.api),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text('Corner capture flow',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    SizedBox(height: 8),
                    Text(
                        'Walk to every lot corner, record the coordinate, review the polygon, then submit.'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (apps.isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
              ),
            if (apps.error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(apps.error!,
                    style: const TextStyle(color: Colors.red)),
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
