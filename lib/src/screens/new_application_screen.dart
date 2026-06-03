import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/polygon_point.dart';
import '../state/application_controller.dart';
import '../widgets/polygon_map_picker.dart';

class NewApplicationScreen extends StatefulWidget {
  const NewApplicationScreen({super.key});

  @override
  State<NewApplicationScreen> createState() => _NewApplicationScreenState();
}

class _NewApplicationScreenState extends State<NewApplicationScreen> {
  final _projectName = TextEditingController();
  final _buildingType = TextEditingController();
  final _locationText = TextEditingController();
  final _mappedAddress = TextEditingController();
  final _barangayName = TextEditingController();
  List<PolygonPoint> _points = [];
  bool _isSubmitting = false;
  String? _error;

  @override
  void dispose() {
    _projectName.dispose();
    _buildingType.dispose();
    _locationText.dispose();
    _mappedAddress.dispose();
    _barangayName.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_points.length < 3) {
      setState(() =>
          _error = 'At least 3 corner points are required to define a lot.');
      return;
    }

    setState(() {
      _error = null;
      _isSubmitting = true;
    });

    try {
      final created = await context.read<ApplicationController>().submit(
            projectName: _projectName.text.trim(),
            buildingType: _buildingType.text.trim(),
            locationText: _locationText.text.trim(),
            polygonPoints: _points,
            mappedAddress: _mappedAddress.text.trim().isEmpty
                ? null
                : _mappedAddress.text.trim(),
            barangayName: _barangayName.text.trim().isEmpty
                ? null
                : _barangayName.text.trim(),
          );

      if (!mounted) return;
      // Replace the new-application screen with the detail screen so
      // the user sees their recorded coordinates immediately.
      Navigator.pushReplacementNamed(
        context,
        '/application-detail',
        arguments: created.applicationId,
      );
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Lot Record')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Project info ──────────────────────────────────────────────
          _sectionHeader('Project Information'),
          const SizedBox(height: 8),
          TextField(
            controller: _projectName,
            decoration: const InputDecoration(
              labelText: 'Project / Lot name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _buildingType,
            decoration: const InputDecoration(
              labelText: 'Building / Land type',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _locationText,
            decoration: const InputDecoration(
              labelText: 'Location description',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _mappedAddress,
            decoration: const InputDecoration(
              labelText: 'Mapped address (optional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _barangayName,
            decoration: const InputDecoration(
              labelText: 'Barangay (optional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),

          // ── Map / corner capture ──────────────────────────────────────
          _sectionHeader('Capture Lot Corners'),
          const SizedBox(height: 8),
          PolygonMapPicker(
            points: _points,
            onChanged: (pts) => setState(() => _points = pts),
          ),

          // ── Error & submit ────────────────────────────────────────────
          if (_error != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade300),
              ),
              child:
                  Text(_error!, style: TextStyle(color: Colors.red.shade800)),
            ),
          ],
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _isSubmitting ? null : _submit,
            icon: _isSubmitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(_isSubmitting ? 'Saving…' : 'Save & View Coordinates'),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Text(
      title,
      style: Theme.of(context)
          .textTheme
          .titleMedium
          ?.copyWith(fontWeight: FontWeight.bold),
    );
  }
}
