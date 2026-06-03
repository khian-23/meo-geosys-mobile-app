import 'dart:convert';
import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/application_summary.dart';
import '../models/polygon_point.dart';
import '../services/api_client.dart';

class ApplicationController extends ChangeNotifier {
  static const _localApplicationsKey = 'mobile_local_applications';

  List<ApplicationSummary> applications = [];
  bool isLoading = false;
  String? error;

  // -----------------------------------------------------------------------
  // Load from remote API.  Not called in local / offline mode.
  // -----------------------------------------------------------------------
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

  Future<void> loadLocal() async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      applications = await _readLocalApplications();
    } catch (e) {
      error = e.toString();
    }
    isLoading = false;
    notifyListeners();
  }

  Future<ApplicationSummary?> findLocalById(int applicationId) async {
    if (applications.isEmpty) {
      applications = await _readLocalApplications();
      notifyListeners();
    }
    for (final application in applications) {
      if (application.applicationId == applicationId) return application;
    }
    return null;
  }

  // -----------------------------------------------------------------------
  // Submit — tries remote API; on network failure falls back to a local
  // in-memory record so the user can still test the full flow.
  // -----------------------------------------------------------------------
  Future<ApplicationSummary> submit({
    required ApiClient api,
    required String projectName,
    required String buildingType,
    required String locationText,
    required List<PolygonPoint> polygonPoints,
    String? mappedAddress,
    String? barangayName,
    // FIX: pass localMode flag from SessionController
    bool localMode = false,
  }) async {
    if (localMode) {
      return _localSubmit(
        projectName: projectName,
        buildingType: buildingType,
        locationText: locationText,
        polygonPoints: polygonPoints,
        mappedAddress: mappedAddress,
        barangayName: barangayName,
      );
    }

    final key =
        '${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(999999)}';
    try {
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
    } catch (e) {
      // Network error — save locally so the user doesn't lose their work.
      if (e is ApiException) rethrow;
      return _localSubmit(
        projectName: projectName,
        buildingType: buildingType,
        locationText: locationText,
        polygonPoints: polygonPoints,
        mappedAddress: mappedAddress,
        barangayName: barangayName,
      );
    }
  }

  Future<ApplicationSummary> _localSubmit({
    required String projectName,
    required String buildingType,
    required String locationText,
    required List<PolygonPoint> polygonPoints,
    String? mappedAddress,
    String? barangayName,
  }) async {
    final id = applications.fold<int>(
          0,
          (highest, app) =>
              app.applicationId > highest ? app.applicationId : highest,
        ) +
        1;
    final refNum = 'LOCAL-${id.toString().padLeft(4, '0')}';

    // Compute centroid
    double lat = 0, lng = 0;
    for (final p in polygonPoints) {
      lat += p.latitude;
      lng += p.longitude;
    }
    if (polygonPoints.isNotEmpty) {
      lat /= polygonPoints.length;
      lng /= polygonPoints.length;
    }

    // Rough lot area via shoelace formula (in square metres)
    double area = 0;
    final n = polygonPoints.length;
    for (var i = 0; i < n; i++) {
      final j = (i + 1) % n;
      area += polygonPoints[i].latitude * polygonPoints[j].longitude;
      area -= polygonPoints[j].latitude * polygonPoints[i].longitude;
    }
    // 1 degree lat ≈ 111 km; rough conversion only
    final areaSqm = (area.abs() / 2) * 111000 * 111000;

    final created = ApplicationSummary(
      applicationId: id,
      referenceNumber: refNum,
      projectName: projectName,
      buildingType: buildingType,
      projectLocationText: locationText,
      latitude: lat,
      longitude: lng,
      status: 'pending',
      submittedAt: DateTime.now().toIso8601String(),
      polygonPoints: polygonPoints,
      barangayName: barangayName,
      mappedAddress: mappedAddress,
      lotAreaSqm: areaSqm > 0 ? areaSqm : null,
    );

    applications = [created, ...applications];
    await _writeLocalApplications(applications);
    notifyListeners();
    return created;
  }

  Future<void> uploadAttachments({
    required ApiClient api,
    required int applicationId,
    required List<PlatformFile> files,
    bool localMode = false,
  }) async {
    if (localMode) return; // silently skip uploads in offline mode
    for (final file in files) {
      await api.uploadAttachment(applicationId, file);
    }
  }

  Future<List<ApplicationSummary>> _readLocalApplications() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_localApplicationsKey);
    if (raw == null || raw.isEmpty) return [];

    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((item) =>
            ApplicationSummary.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  Future<void> _writeLocalApplications(
      List<ApplicationSummary> applications) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _localApplicationsKey,
      jsonEncode(
          applications.map((application) => application.toJson()).toList()),
    );
  }
}
