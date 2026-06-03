import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/application_controller.dart';

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
      context.read<ApplicationController>().loadLocal();
    });
  }

  @override
  Widget build(BuildContext context) {
    final apps = context.watch<ApplicationController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('MEO GeoSys'),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.pushNamed(context, '/new-application')
            .then((_) => context.read<ApplicationController>().loadLocal()),
        icon: const Icon(Icons.add_location_alt_outlined),
        label: const Text('New Record'),
      ),
      body: RefreshIndicator(
        onRefresh: () => context.read<ApplicationController>().loadLocal(),
        child: apps.isLoading
            ? const Center(child: CircularProgressIndicator())
            : apps.applications.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.map_outlined,
                              size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text(
                            'No records yet.\nTap "+ New Record" to capture lot corners.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey, fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                    itemCount: apps.applications.length,
                    itemBuilder: (context, index) {
                      final app = apps.applications[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor:
                                Theme.of(context).colorScheme.primary,
                            foregroundColor: Colors.white,
                            child: Text('${index + 1}'),
                          ),
                          title: Text(
                            app.projectName.isEmpty
                                ? app.referenceNumber
                                : app.projectName,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            '${app.referenceNumber}  •  '
                            '${app.polygonPoints.length} corners'
                            '${app.lotAreaSqm != null ? '  •  ${_formatArea(app.lotAreaSqm!)}' : ''}',
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.pushNamed(
                            context,
                            '/application-detail',
                            arguments: app.applicationId,
                          ).then((_) => context
                              .read<ApplicationController>()
                              .loadLocal()),
                        ),
                      );
                    },
                  ),
      ),
    );
  }

  String _formatArea(double sqm) {
    if (sqm >= 10000) {
      return '${(sqm / 10000).toStringAsFixed(4)} ha';
    }
    return '${sqm.toStringAsFixed(2)} m²';
  }
}
