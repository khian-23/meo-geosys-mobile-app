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
  // FIX: Use a unique key so the map widget rebuilds when needed
  final _mapKey = GlobalKey();
  final MapController _mapController = MapController();
  bool _capturing = false;
  bool _mapReady = false;

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  Future<bool> _ensureLocationPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location services are disabled. Please enable GPS.'),
            duration: Duration(seconds: 3),
          ),
        );
      }
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('Location permission is required to capture a corner.'),
            duration: Duration(seconds: 3),
          ),
        );
      }
      return false;
    }
    return true;
  }

  Future<void> _captureCurrentCorner() async {
    setState(() => _capturing = true);

    final hasPermission = await _ensureLocationPermission();
    if (!hasPermission) {
      setState(() => _capturing = false);
      return;
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );

      final newPoint = PolygonPoint(
        latitude: position.latitude,
        longitude: position.longitude,
        label: 'Corner ${widget.points.length + 1}',
      );

      final updated = [...widget.points, newPoint];
      widget.onChanged(updated);

      // FIX: Only move map after it is confirmed ready, with a small delay
      // to let the widget settle after onChanged rebuilds the parent.
      if (mounted && _mapReady) {
        await Future.delayed(const Duration(milliseconds: 100));
        if (mounted) {
          _mapController.move(
            LatLng(position.latitude, position.longitude),
            18.0, // zoom in close for precise corner capture
          );
        }
      }
    } on LocationServiceDisabledException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('GPS is turned off. Please enable it.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not get location: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  Future<void> _goToCurrentLocation() async {
    final hasPermission = await _ensureLocationPermission();
    if (!hasPermission) return;

    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
      if (mounted && _mapReady) {
        _mapController.move(
          LatLng(position.latitude, position.longitude),
          18.0,
        );
      }
    } catch (_) {}
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
          width: 32,
          height: 32,
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
                  .map((p) => LatLng(p.latitude, p.longitude))
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
        Text('Capture lot corners',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        const Text('Walk to each corner and press "Capture current corner", '
            'or tap the map to add a corner manually. '
            'Use the crosshair button to centre the map on your position.'),
        const SizedBox(height: 12),
        SizedBox(
          height: 340,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Stack(
              children: [
                // FIX: onMapReady callback ensures we only call move() after
                // the MapController is fully attached to the FlutterMap.
                FlutterMap(
                  key: _mapKey,
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _defaultCenter,
                    initialZoom: 16,
                    minZoom: 10,
                    maxZoom: 20,
                    onTap: (_, latLng) => _addMapPoint(latLng),
                    onMapReady: () {
                      setState(() => _mapReady = true);
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'meo_geosys_mobile',
                      // FIX: Add tile error builder so a missing tile doesn't
                      // crash the map.
                      errorTileCallback: (tile, error, stackTrace) {},
                    ),
                    if (polygons.isNotEmpty) PolygonLayer(polygons: polygons),
                    if (markers.isNotEmpty) MarkerLayer(markers: markers),
                  ],
                ),
                // FIX: floating "go to my location" button overlaid on the map
                Positioned(
                  bottom: 12,
                  right: 12,
                  child: FloatingActionButton.small(
                    heroTag: 'map_location_btn',
                    tooltip: 'Centre map on my location',
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF1A5C2E),
                    onPressed: _goToCurrentLocation,
                    child: const Icon(Icons.my_location),
                  ),
                ),
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
              icon: _capturing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.gps_fixed),
              label: Text(_capturing ? 'Capturing…' : 'Capture current corner'),
            ),
            OutlinedButton.icon(
              onPressed: widget.points.isEmpty
                  ? null
                  : () => widget.onChanged(
                      widget.points.sublist(0, widget.points.length - 1)),
              icon: const Icon(Icons.undo),
              label: const Text('Remove last'),
            ),
            OutlinedButton.icon(
              onPressed: widget.points.isEmpty
                  ? null
                  : () => widget.onChanged(const []),
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
                leading:
                    CircleAvatar(radius: 14, child: Text('${entry.key + 1}')),
                title: Text(entry.value.label ?? 'Corner ${entry.key + 1}'),
                subtitle: Text('${entry.value.latitude.toStringAsFixed(7)}, '
                    '${entry.value.longitude.toStringAsFixed(7)}'),
              ),
            ),
      ],
    );
  }
}
