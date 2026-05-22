import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;

import '../models/application_summary.dart';
import '../models/polygon_point.dart';

class ApiClient {
  ApiClient({required this.baseUrl, this.token});

  final String baseUrl;
  String? token;

  Map<String, String> _headers({bool json = true, String? idempotencyKey}) {
    final headers = <String, String>{};
    if (json) headers['Content-Type'] = 'application/json';
    if (token != null && token!.isNotEmpty) headers['Authorization'] = 'Bearer $token';
    if (idempotencyKey != null && idempotencyKey.isNotEmpty) headers['X-Idempotency-Key'] = idempotencyKey;
    return headers;
  }

  Future<Map<String, dynamic>> register(Map<String, dynamic> payload) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/v1/auth/register'),
      headers: _headers(),
      body: jsonEncode(payload),
    );
    return _decode(response);
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/v1/auth/login'),
      headers: _headers(),
      body: jsonEncode({'email': email, 'password': password}),
    );
    return _decode(response);
  }

  Future<Map<String, dynamic>> me() async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/v1/me'),
      headers: _headers(json: false),
    );
    return _decode(response);
  }

  Future<List<ApplicationSummary>> fetchApplications() async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/v1/applications'),
      headers: _headers(json: false),
    );
    final data = _decode(response);
    return (data['applications'] as List<dynamic>? ?? [])
        .map((item) => ApplicationSummary.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  Future<ApplicationSummary> fetchApplication(int id) async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/v1/applications/$id'),
      headers: _headers(json: false),
    );
    final data = _decode(response);
    return ApplicationSummary.fromJson(Map<String, dynamic>.from(data['application'] as Map));
  }

  Future<ApplicationSummary> createApplication({
    required String projectName,
    required String buildingType,
    required String projectLocationText,
    required List<PolygonPoint> polygonPoints,
    required String idempotencyKey,
    String? mappedAddress,
    String? barangayName,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/v1/applications'),
      headers: _headers(idempotencyKey: idempotencyKey),
      body: jsonEncode({
        'project_name': projectName,
        'building_type': buildingType,
        'project_location_text': projectLocationText,
        'mapped_address': mappedAddress,
        'barangay_name': barangayName,
        'polygon_points': polygonPoints.map((point) => point.toJson()).toList(),
        'idempotency_key': idempotencyKey,
      }),
    );
    final data = _decode(response);
    return ApplicationSummary.fromJson(Map<String, dynamic>.from(data['application'] as Map));
  }

  Future<void> uploadAttachment(int applicationId, PlatformFile file) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/api/v1/applications/$applicationId/attachments'),
    );
    request.headers.addAll(_headers(json: false));
    request.files.add(await http.MultipartFile.fromPath('attachment', file.path!));
    final response = await http.Response.fromStream(await request.send());
    _decode(response);
  }

  Map<String, dynamic> _decode(http.Response response) {
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 400 || payload['success'] != true) {
      throw ApiException(payload['message']?.toString() ?? 'Request failed.');
    }
    return payload;
  }
}

class ApiException implements Exception {
  ApiException(this.message);
  final String message;

  @override
  String toString() => message;
}
