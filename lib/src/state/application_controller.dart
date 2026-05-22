import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

import '../models/application_summary.dart';
import '../models/polygon_point.dart';
import '../services/api_client.dart';

class ApplicationController extends ChangeNotifier {
  List<ApplicationSummary> applications = [];
  bool isLoading = false;
  String? error;

  Future<void> load(ApiClient api) async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      applications = await api.fetchApplications();
    } catch (e) {
      error = e.toString();
    }
    isLoading = false;
    notifyListeners();
  }

  Future<ApplicationSummary> submit({
    required ApiClient api,
    required String projectName,
    required String buildingType,
    required String locationText,
    required List<PolygonPoint> polygonPoints,
    String? mappedAddress,
    String? barangayName,
  }) async {
    final key = '${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(999999)}';
    final created = await api.createApplication(
      projectName: projectName,
      buildingType: buildingType,
      projectLocationText: locationText,
      polygonPoints: polygonPoints,
      idempotencyKey: key,
      mappedAddress: mappedAddress,
      barangayName: barangayName,
    );
    applications = [created, ...applications];
    notifyListeners();
    return created;
  }

  Future<void> uploadAttachments({
    required ApiClient api,
    required int applicationId,
    required List<PlatformFile> files,
  }) async {
    for (final file in files) {
      await api.uploadAttachment(applicationId, file);
    }
  }
}
