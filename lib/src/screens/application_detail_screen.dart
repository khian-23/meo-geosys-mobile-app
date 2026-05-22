import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/application_summary.dart';
import '../state/session_controller.dart';

class ApplicationDetailScreen extends StatefulWidget {
  const ApplicationDetailScreen({super.key, required this.applicationId});

  final int applicationId;

  @override
  State<ApplicationDetailScreen> createState() => _ApplicationDetailScreenState();
}

class _ApplicationDetailScreenState extends State<ApplicationDetailScreen> {
  ApplicationSummary? _application;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final session = context.read<SessionController>();
    try {
      _application = await session.api.fetchApplication(widget.applicationId);
    } catch (e) {
      _error = e.toString();
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final app = _application;
    return Scaffold(
      appBar: AppBar(title: const Text('Application details')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : app == null
                  ? const Center(child: Text('Application not found.'))
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        ListTile(title: const Text('Reference number'), subtitle: Text(app.referenceNumber)),
                        ListTile(title: const Text('Status'), subtitle: Text(app.status)),
                        ListTile(title: const Text('Project name'), subtitle: Text(app.projectName)),
                        ListTile(title: const Text('Building type'), subtitle: Text(app.buildingType)),
                        ListTile(title: const Text('Project location'), subtitle: Text(app.projectLocationText)),
                        ListTile(title: const Text('Centroid'), subtitle: Text('${app.latitude}, ${app.longitude}')),
                        ListTile(title: const Text('Corners recorded'), subtitle: Text('${app.polygonPoints.length}')),
                        if (app.lotAreaSqm != null)
                          ListTile(title: const Text('Estimated lot area'), subtitle: Text('${app.lotAreaSqm} sqm')),
                      ],
                    ),
    );
  }
}
