import 'dart:math';

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
  // Default centre: Roxas City, Capiz
  static const LatLng _defaultCenter = LatLng(11.5854, 122.7519);
  final MapController _mapController = MapController();
  bool _capturing = false;
  bool _mapReady = false;

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  // ── Auto-fit the map to show all recorded points ────────────────────────
  void _fitPoints() {
    if (!_mapReady || widget.points.isEmpty) return;
    final lats = widget.points.map((p) => p.latitude);
    final lngs = widget.points.map((p) => p.longitude);
    final minLat = lats.reduce(min);
    final maxLat = lats.reduce(max);
    final minLng = lngs.reduce(min);
    final maxLng = lngs.reduce(max);

    // Add padding around the bounding box
    const pad = 0.0003;
    final bounds = LatLngBounds(
      LatLng(minLat - pad, minLng - pad),
      LatLng(maxLat + pad, maxLng + pad),
    );
    _mapController.fitCamera(
      CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(40)),
    );
  }

  Future<bool> _ensureLocationPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Location services disabled. Please enable GPS.'),
              duration: Duration(seconds: 3)),
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
                  Text('Location permission required to capture a corner.'),
              duration: Duration(seconds: 3)),
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
      if (mounted) setState(() => _capturing = false);
      return;
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.bestForNavigation,
        timeLimit: const Duration(seconds: 20),
      );

      final newPoint = PolygonPoint(
        latitude: position.latitude,
        longitude: position.longitude,
        label: 'Corner ${widget.points.length + 1}',
      );

      widget.onChanged([...widget.points, newPoint]);

      // After adding, fit map to show all points
      if (mounted && _mapReady) {
        await Future.delayed(const Duration(milliseconds: 150));
        if (mounted) _fitPoints();
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
            LatLng(position.latitude, position.longitude), 19.0);
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
    // Fit after a short delay to let setState propagate
    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) _fitPoints();
    });
  }

  @override
  Widget build(BuildContext context) {
    final markers = <Marker>[
      for (var i = 0; i < widget.points.length; i++)
        Marker(
          point: LatLng(widget.points[i].latitude, widget.points[i].longitude),
          width: 36,
          height: 36,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFD4A017),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.black54, width: 2),
              boxShadow: const [
                BoxShadow(
                    color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))
              ],
            ),
            alignment: Alignment.center,
            child: Text(
              '${i + 1}',
              style: const TextStyle(
                  color: Colors.black,
                  fontSize: 12,
                  fontWeight: FontWeight.w800),
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
              color: const Color(0x441A5C2E),
              borderColor: const Color(0xFF1A5C2E),
              borderStrokeWidth: 3,
            ),
          ]
        : <Polygon>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Instruction banner
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(Icons.info_outline, size: 16, color: Colors.blue),
                SizedBox(width: 6),
                Text('How to capture corners',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                        fontSize: 13)),
              ]),
              SizedBox(height: 4),
              Text(
                '• Walk to each physical corner of the lot\n'
                '• Press "Capture Corner" at each spot\n'
                '• Or tap the map to pin manually\n'
                '• Need at least 3 corners to form a polygon',
                style: TextStyle(fontSize: 12, color: Colors.black87),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // Corner count + fit button row
        Row(
          children: [
            Text(
              '${widget.points.length} corner${widget.points.length == 1 ? '' : 's'} recorded',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const Spacer(),
            if (widget.points.length >= 2)
              TextButton.icon(
                onPressed: _fitPoints,
                icon: const Icon(Icons.fit_screen, size: 18),
                label: const Text('Fit all'),
                style:
                    TextButton.styleFrom(visualDensity: VisualDensity.compact),
              ),
          ],
        ),
        const SizedBox(height: 6),

        // Map
        SizedBox(
          height: 320,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _defaultCenter,
                    initialZoom: 15,
                    minZoom: 10,
                    maxZoom: 20,
                    onTap: (_, latLng) => _addMapPoint(latLng),
                    onMapReady: () {
                      setState(() => _mapReady = true);
                      // If points already exist (e.g. editing), fit immediately
                      if (widget.points.isNotEmpty) {
                        Future.delayed(
                            const Duration(milliseconds: 200), _fitPoints);
                      }
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'meo_geosys_mobile',
                      errorTileCallback: (tile, error, stackTrace) {},
                    ),
                    if (polygons.isNotEmpty) PolygonLayer(polygons: polygons),
                    MarkerLayer(markers: markers),
                  ],
                ),
                // My location button
                Positioned(
                  bottom: 12,
                  right: 12,
                  child: FloatingActionButton.small(
                    heroTag: 'map_location_btn',
                    tooltip: 'Centre on my location',
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

        // Action buttons
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            FilledButton.icon(
              onPressed: _capturing ? null : _captureCurrentCorner,
              icon: _capturing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.gps_fixed),
              label: Text(_capturing ? 'Capturing…' : 'Capture Corner'),
            ),
            OutlinedButton.icon(
              onPressed: widget.points.isEmpty
                  ? null
                  : () {
                      widget.onChanged(
                          widget.points.sublist(0, widget.points.length - 1));
                      Future.delayed(const Duration(milliseconds: 150), () {
                        if (mounted) _fitPoints();
                      });
                    },
              icon: const Icon(Icons.undo),
              label: const Text('Undo last'),
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

        // Live coordinate list
        if (widget.points.isNotEmpty) ...[
          const SizedBox(height: 14),
          const Divider(),
          const Text('Recorded Coordinates',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 2),
          const Text(
            'Tip: coordinates look similar when captured in the same spot.',
            style: TextStyle(fontSize: 11, color: Colors.black45),
          ),
          const SizedBox(height: 6),
          ...widget.points.asMap().entries.map(
                (entry) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: const BoxDecoration(
                          color: Color(0xFFD4A017),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '${entry.key + 1}',
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.black),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '${entry.value.latitude.toStringAsFixed(8)},  '
                          '${entry.value.longitude.toStringAsFixed(8)}',
                          style: const TextStyle(
                              fontFamily: 'monospace', fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ],
    );
  }
}
