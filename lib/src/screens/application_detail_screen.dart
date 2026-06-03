import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../models/application_summary.dart';
import '../models/polygon_point.dart';
import '../state/application_controller.dart';

class ApplicationDetailScreen extends StatefulWidget {
  const ApplicationDetailScreen({super.key, required this.applicationId});

  final int applicationId;

  @override
  State<ApplicationDetailScreen> createState() =>
      _ApplicationDetailScreenState();
}

class _ApplicationDetailScreenState extends State<ApplicationDetailScreen> {
  ApplicationSummary? _application;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    try {
      _application = await context
          .read<ApplicationController>()
          .findLocalById(widget.applicationId);
    } catch (e) {
      _error = e.toString();
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null) {
      return Scaffold(
          appBar: AppBar(title: const Text('Details')),
          body: Center(child: Text(_error!)));
    }
    final app = _application;
    if (app == null) {
      return Scaffold(
          appBar: AppBar(title: const Text('Details')),
          body: const Center(child: Text('Record not found.')));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
            app.projectName.isEmpty ? app.referenceNumber : app.projectName),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy_outlined),
            tooltip: 'Copy all coordinates',
            onPressed: () => _copyAll(app.polygonPoints),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Summary card ──────────────────────────────────────────────
          _SummaryCard(app: app),
          const SizedBox(height: 16),

          // ── Area result ───────────────────────────────────────────────
          _AreaCard(app: app),
          const SizedBox(height: 16),

          // ── Map preview ───────────────────────────────────────────────
          if (app.polygonPoints.length >= 2) ...[
            _MapPreview(points: app.polygonPoints),
            const SizedBox(height: 16),
          ],

          // ── Coordinates table ─────────────────────────────────────────
          _CoordinatesTable(points: app.polygonPoints),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  void _copyAll(List<PolygonPoint> pts) {
    final buf = StringBuffer();
    for (var i = 0; i < pts.length; i++) {
      buf.writeln('Corner ${i + 1}: ${pts[i].latitude.toStringAsFixed(8)}, '
          '${pts[i].longitude.toStringAsFixed(8)}');
    }
    Clipboard.setData(ClipboardData(text: buf.toString()));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Coordinates copied to clipboard')),
      );
    }
  }
}

// ── Summary card ──────────────────────────────────────────────────────────────
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.app});
  final ApplicationSummary app;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _row('Reference', app.referenceNumber),
            if (app.projectName.isNotEmpty)
              _row('Project name', app.projectName),
            if (app.buildingType.isNotEmpty)
              _row('Building type', app.buildingType),
            if (app.projectLocationText.isNotEmpty)
              _row('Location', app.projectLocationText),
            if (app.barangayName != null && app.barangayName!.isNotEmpty)
              _row('Barangay', app.barangayName!),
            if (app.mappedAddress != null && app.mappedAddress!.isNotEmpty)
              _row('Address', app.mappedAddress!),
            _row('Recorded', _formatDate(app.submittedAt)),
            _row('Total corners', '${app.polygonPoints.length}'),
            _row('Centroid',
                '${app.latitude.toStringAsFixed(7)}, ${app.longitude.toStringAsFixed(7)}'),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label,
                style: const TextStyle(
                    fontWeight: FontWeight.w500, color: Colors.black54)),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.year}-${_z(dt.month)}-${_z(dt.day)}  '
          '${_z(dt.hour)}:${_z(dt.minute)}';
    } catch (_) {
      return iso;
    }
  }

  String _z(int n) => n.toString().padLeft(2, '0');
}

// ── Area card ─────────────────────────────────────────────────────────────────
class _AreaCard extends StatelessWidget {
  const _AreaCard({required this.app});
  final ApplicationSummary app;

  @override
  Widget build(BuildContext context) {
    final sqm = app.lotAreaSqm;
    final color = Theme.of(context).colorScheme.primary;

    return Card(
      color: color.withOpacity(0.08),
      shape: RoundedRectangleBorder(
        side: BorderSide(color: color.withOpacity(0.4)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                Icon(Icons.straighten_outlined, color: color),
                const SizedBox(width: 8),
                Text('Estimated Lot Area',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: color)),
              ],
            ),
            const SizedBox(height: 12),
            if (sqm != null) ...[
              Text(
                '${_formatSqm(sqm)} m²',
                style: TextStyle(
                    fontSize: 32, fontWeight: FontWeight.bold, color: color),
              ),
              const SizedBox(height: 4),
              Text(
                '≈ ${_formatHa(sqm)} hectares',
                style: const TextStyle(fontSize: 15, color: Colors.black54),
              ),
              const SizedBox(height: 4),
              Text(
                '≈ ${_formatSqm(_toSquareMeters(sqm))} sq. meters (rounded)',
                style: const TextStyle(fontSize: 13, color: Colors.black45),
              ),
            ] else ...[
              Text(
                app.polygonPoints.length < 3
                    ? 'Need at least 3 corners to compute area.'
                    : 'Area could not be computed.',
                style: const TextStyle(color: Colors.black54),
              ),
            ],
            const SizedBox(height: 8),
            const Text(
              'Calculated using the spherical polygon formula.\n'
              'For official land area use a licensed surveyor.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: Colors.black38),
            ),
          ],
        ),
      ),
    );
  }

  String _formatSqm(double v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(4)}×10⁶';
    if (v >= 10000) return v.toStringAsFixed(2);
    return v.toStringAsFixed(2);
  }

  String _formatHa(double sqm) => (sqm / 10000).toStringAsFixed(6);
  double _toSquareMeters(double sqm) => sqm; // alias kept for clarity
}

// ── Map preview ───────────────────────────────────────────────────────────────
class _MapPreview extends StatelessWidget {
  const _MapPreview({required this.points});
  final List<PolygonPoint> points;

  @override
  Widget build(BuildContext context) {
    final latLngs = points.map((p) => LatLng(p.latitude, p.longitude)).toList();

    // Compute bounding box to fit the map
    double minLat = latLngs.map((l) => l.latitude).reduce(min);
    double maxLat = latLngs.map((l) => l.latitude).reduce(max);
    double minLng = latLngs.map((l) => l.longitude).reduce(min);
    double maxLng = latLngs.map((l) => l.longitude).reduce(max);

    final center = LatLng((minLat + maxLat) / 2, (minLng + maxLng) / 2);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Map Preview',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            height: 260,
            child: FlutterMap(
              options: MapOptions(
                initialCenter: center,
                initialZoom: 17,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'meo_geosys_mobile',
                  errorTileCallback: (tile, error, stackTrace) {},
                ),
                if (points.length >= 3)
                  PolygonLayer(polygons: [
                    Polygon(
                      points: latLngs,
                      color: const Color(0x331A5C2E),
                      borderColor: const Color(0xFF1A5C2E),
                      borderStrokeWidth: 3,
                    ),
                  ]),
                MarkerLayer(
                  markers: [
                    for (var i = 0; i < latLngs.length; i++)
                      Marker(
                        point: latLngs[i],
                        width: 30,
                        height: 30,
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFD4A017),
                            shape: BoxShape.circle,
                            border:
                                Border.all(color: Colors.black54, width: 1.5),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '${i + 1}',
                            style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.black),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Coordinates table ─────────────────────────────────────────────────────────
class _CoordinatesTable extends StatelessWidget {
  const _CoordinatesTable({required this.points});
  final List<PolygonPoint> points;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Corner Coordinates  (${points.length} points)',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (points.isEmpty)
          const Text('No coordinates recorded.',
              style: TextStyle(color: Colors.grey))
        else
          Card(
            clipBehavior: Clip.antiAlias,
            child: Table(
              columnWidths: const {
                0: FixedColumnWidth(44),
                1: FlexColumnWidth(1),
                2: FlexColumnWidth(1),
              },
              border: TableBorder(
                horizontalInside:
                    BorderSide(color: Colors.grey.shade200, width: 1),
              ),
              children: [
                // Header row
                TableRow(
                  decoration: BoxDecoration(color: color.withOpacity(0.12)),
                  children: const [
                    _TCell('#', isHeader: true),
                    _TCell('Latitude', isHeader: true),
                    _TCell('Longitude', isHeader: true),
                  ],
                ),
                // Data rows
                for (var i = 0; i < points.length; i++)
                  TableRow(
                    decoration: BoxDecoration(
                      color: i.isEven ? Colors.white : Colors.grey.shade50,
                    ),
                    children: [
                      _TCell('${i + 1}'),
                      _TCell(points[i].latitude.toStringAsFixed(8), mono: true),
                      _TCell(points[i].longitude.toStringAsFixed(8),
                          mono: true),
                    ],
                  ),
              ],
            ),
          ),
        const SizedBox(height: 8),
        // Individual copy buttons
        ...points.asMap().entries.map((e) => _CoordRow(
              index: e.key,
              point: e.value,
            )),
      ],
    );
  }
}

class _TCell extends StatelessWidget {
  const _TCell(this.text, {this.isHeader = false, this.mono = false});
  final String text;
  final bool isHeader;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Text(
        text,
        style: TextStyle(
          fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
          fontFamily: mono ? 'monospace' : null,
          fontSize: isHeader ? 13 : 12,
        ),
      ),
    );
  }
}

class _CoordRow extends StatelessWidget {
  const _CoordRow({required this.index, required this.point});
  final int index;
  final PolygonPoint point;

  @override
  Widget build(BuildContext context) {
    final coordStr =
        '${point.latitude.toStringAsFixed(8)}, ${point.longitude.toStringAsFixed(8)}';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor:
                Theme.of(context).colorScheme.primary.withOpacity(0.15),
            child: Text(
              '${index + 1}',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              coordStr,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.copy, size: 18),
            tooltip: 'Copy corner ${index + 1}',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: coordStr));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text('Corner ${index + 1} copied'),
                    duration: const Duration(seconds: 1)),
              );
            },
          ),
        ],
      ),
    );
  }
}
