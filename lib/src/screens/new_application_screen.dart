import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/polygon_point.dart';
import '../services/api_client.dart';
import '../state/application_controller.dart';
import '../state/session_controller.dart';
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
  final List<PlatformFile> _attachments = [];
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

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(allowMultiple: true);
    if (result != null) {
      setState(() {
        _attachments
          ..clear()
          ..addAll(result.files.where((f) => f.path != null));
      });
    }
  }

  Future<void> _submit() async {
    if (_points.length < 3) {
      setState(() => _error = 'At least three corner points are required.');
      return;
    }

    setState(() {
      _error = null;
      _isSubmitting = true;
    });

    final session = context.read<SessionController>();
    final apps = context.read<ApplicationController>();

    try {
      final created = await apps.submit(
        api: session.api,
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
        // FIX: pass localMode so the controller skips the network call
        localMode: session.isLocalMode,
      );

      if (_attachments.isNotEmpty) {
        await apps.uploadAttachments(
          api: session.api,
          applicationId: created.applicationId,
          files: _attachments,
          localMode: session.isLocalMode,
        );
      }

      if (!mounted) return;
      Navigator.pop(context);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();

    return Scaffold(
      appBar: AppBar(title: const Text('New application')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (session.isLocalMode)
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                border: Border.all(color: Colors.orange.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Offline mode — this application will be saved on-device only.',
                style: TextStyle(fontSize: 13, color: Colors.orange.shade800),
              ),
            ),
          TextField(
              controller: _projectName,
              decoration: const InputDecoration(labelText: 'Project name')),
          const SizedBox(height: 12),
          TextField(
              controller: _buildingType,
              decoration: const InputDecoration(labelText: 'Building type')),
          const SizedBox(height: 12),
          TextField(
              controller: _locationText,
              decoration:
                  const InputDecoration(labelText: 'Project location text')),
          const SizedBox(height: 12),
          TextField(
              controller: _mappedAddress,
              decoration: const InputDecoration(
                  labelText: 'Mapped address (optional)')),
          const SizedBox(height: 12),
          TextField(
              controller: _barangayName,
              decoration:
                  const InputDecoration(labelText: 'Barangay (optional)')),
          const SizedBox(height: 16),
          PolygonMapPicker(
            points: _points,
            onChanged: (pts) => setState(() => _points = pts),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _pickFiles,
            icon: const Icon(Icons.attach_file),
            label: Text(_attachments.isEmpty
                ? 'Attach supporting files'
                : '${_attachments.length} file(s) selected'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _isSubmitting ? null : _submit,
            icon: const Icon(Icons.send_outlined),
            label: Text(_isSubmitting ? 'Submitting…' : 'Submit application'),
          ),
        ],
      ),
    );
  }
}
