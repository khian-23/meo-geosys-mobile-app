import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/application_summary.dart';
import '../models/polygon_point.dart';

class ApplicationController extends ChangeNotifier {
  static const _localApplicationsKey = 'mobile_local_applications';

  List<ApplicationSummary> applications = [];
  bool isLoading = false;
  String? error;

  // Load all saved applications from device storage.
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
    for (final app in applications) {
      if (app.applicationId == applicationId) return app;
    }
    return null;
  }

  // Create and persist a new application entirely on-device.
  Future<ApplicationSummary> submit({
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
    final refNum = 'GEO-${id.toString().padLeft(4, '0')}';

    // Centroid
    double lat = 0, lng = 0;
    for (final p in polygonPoints) {
      lat += p.latitude;
      lng += p.longitude;
    }
    if (polygonPoints.isNotEmpty) {
      lat /= polygonPoints.length;
      lng /= polygonPoints.length;
    }

    // Shoelace formula for polygon area in square metres.
    // Uses the spherical excess approximation: 1° ≈ 111 320 m along a meridian,
    // and longitude degrees are scaled by cos(lat) to account for convergence.
    double area = 0;
    final n = polygonPoints.length;
    if (n >= 3) {
      for (var i = 0; i < n; i++) {
        final j = (i + 1) % n;
        final latI = polygonPoints[i].latitude * (pi / 180);
        final latJ = polygonPoints[j].latitude * (pi / 180);
        final lngI = polygonPoints[i].longitude * (pi / 180);
        final lngJ = polygonPoints[j].longitude * (pi / 180);
        // Approximate: project to local metres then apply shoelace
        area += lngI * latJ;
        area -= lngJ * latI;
      }
      // Convert from steradians (radians²) → metres²
      // R² where R = 6 371 000 m
      const R = 6371000.0;
      area = (area.abs() / 2) * R * R;
    }

    final created = ApplicationSummary(
      applicationId: id,
      referenceNumber: refNum,
      projectName: projectName,
      buildingType: buildingType,
      projectLocationText: locationText,
      latitude: lat,
      longitude: lng,
      status: 'recorded',
      submittedAt: DateTime.now().toIso8601String(),
      polygonPoints: polygonPoints,
      barangayName: barangayName,
      mappedAddress: mappedAddress,
      lotAreaSqm: area > 0 ? double.parse(area.toStringAsFixed(2)) : null,
    );

    applications = [created, ...applications];
    await _writeLocalApplications(applications);
    notifyListeners();
    return created;
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

  Future<void> _writeLocalApplications(List<ApplicationSummary> apps) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _localApplicationsKey,
      jsonEncode(apps.map((a) => a.toJson()).toList()),
    );
  }
}
