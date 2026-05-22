import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../models/polygon_point.dart';

class PolygonMapPicker extends StatefulWidget {
  const PolygonMapPicker({
    super.key,
    required this.points,
    required this.onChanged,
  });

  final List<PolygonPoint> points;
  final ValueChanged<List<PolygonPoint>> onChanged;

  @override
  State<PolygonMapPicker> createState() => _PolygonMapPickerState();
}

class _PolygonMapPickerState extends State<PolygonMapPicker> {
  static const LatLng _defaultCenter = LatLng(10.3740, 122.8660);
  final MapController _mapController = MapController();
  bool _capturing = false;

  Future<void> _captureCurrentCorner() async {
    setState(() => _capturing = true);
    final permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permission is required to capture a corner.')),
        );
      }
      setState(() => _capturing = false);
      return;
    }

    final position = await Geolocator.getCurrentPosition();
    final updated = [
      ...widget.points,
      PolygonPoint(
        latitude: position.latitude,
        longitude: position.longitude,
        label: 'Corner ${widget.points.length + 1}',
      ),
    ];
    widget.onChanged(updated);
    _mapController.move(
      LatLng(position.latitude, position.longitude),
      _mapController.camera.zoom,
    );
    setState(() => _capturing = false);
  }

  void _addMapPoint(LatLng latLng) {
    widget.onChanged([
      ...widget.points,
      PolygonPoint(
        latitude: latLng.latitude,
        longitude: latLng.longitude,
        label: 'Corner ${widget.points.length + 1}',
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final markers = <Marker>[
      for (var i = 0; i < widget.points.length; i++)
        Marker(
          point: LatLng(widget.points[i].latitude, widget.points[i].longitude),
          width: 28,
          height: 28,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFD4A017),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF1A1208), width: 1.5),
            ),
            alignment: Alignment.center,
            child: Text(
              '${i + 1}',
              style: const TextStyle(
                color: Colors.black,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
    ];

    final polygons = widget.points.length >= 3
        ? [
            Polygon(
              points: widget.points
                  .map((point) => LatLng(point.latitude, point.longitude))
                  .toList(),
              color: const Color(0x331A5C2E),
              borderColor: const Color(0xFF1A5C2E),
              borderStrokeWidth: 3,
            ),
          ]
        : <Polygon>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Capture lot corners', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        const Text('Walk to each corner and capture your current location, or tap the map to add a corner manually.'),
        const SizedBox(height: 12),
        SizedBox(
          height: 320,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _defaultCenter,
                initialZoom: 15,
                minZoom: 13,
                maxZoom: 20,
                onTap: (_, latLng) => _addMapPoint(latLng),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'meo_geosys_mobile',
                ),
                PolygonLayer(polygons: polygons),
                MarkerLayer(markers: markers),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            FilledButton.icon(
              onPressed: _capturing ? null : _captureCurrentCorner,
              icon: const Icon(Icons.gps_fixed),
              label: Text(_capturing ? 'Capturing...' : 'Capture current corner'),
            ),
            OutlinedButton.icon(
              onPressed: widget.points.isEmpty ? null : () => widget.onChanged(widget.points.sublist(0, widget.points.length - 1)),
              icon: const Icon(Icons.undo),
              label: const Text('Remove last'),
            ),
            OutlinedButton.icon(
              onPressed: widget.points.isEmpty ? null : () => widget.onChanged(const []),
              icon: const Icon(Icons.delete_outline),
              label: const Text('Clear all'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...widget.points.asMap().entries.map(
              (entry) => ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(radius: 14, child: Text('${entry.key + 1}')),
                title: Text(entry.value.label ?? 'Corner ${entry.key + 1}'),
                subtitle: Text('${entry.value.latitude.toStringAsFixed(7)}, ${entry.value.longitude.toStringAsFixed(7)}'),
              ),
            ),
      ],
    );
  }
}
