import 'polygon_point.dart';

class ApplicationSummary {
  const ApplicationSummary({
    required this.applicationId,
    required this.referenceNumber,
    required this.projectName,
    required this.buildingType,
    required this.projectLocationText,
    required this.latitude,
    required this.longitude,
    required this.status,
    required this.submittedAt,
    required this.polygonPoints,
    this.barangayName,
    this.mappedAddress,
    this.lotAreaSqm,
  });

  final int applicationId;
  final String referenceNumber;
  final String projectName;
  final String buildingType;
  final String projectLocationText;
  final double latitude;
  final double longitude;
  final String status;
  final String submittedAt;
  final List<PolygonPoint> polygonPoints;
  final String? barangayName;
  final String? mappedAddress;
  final double? lotAreaSqm;

  Map<String, dynamic> toJson() => {
        'application_id': applicationId,
        'reference_number': referenceNumber,
        'project_name': projectName,
        'building_type': buildingType,
        'project_location_text': projectLocationText,
        'latitude': latitude,
        'longitude': longitude,
        'status': status,
        'submitted_at': submittedAt,
        'polygon_coordinates':
            polygonPoints.map((point) => point.toJson()).toList(),
        'barangay_name': barangayName,
        'mapped_address': mappedAddress,
        'lot_area_sqm': lotAreaSqm,
      };

  factory ApplicationSummary.fromJson(Map<String, dynamic> json) {
    final polygon = (json['polygon_coordinates'] as List<dynamic>? ?? [])
        .map((point) =>
            PolygonPoint.fromJson(Map<String, dynamic>.from(point as Map)))
        .toList();

    return ApplicationSummary(
      applicationId: json['application_id'] as int,
      referenceNumber: json['reference_number'] as String,
      projectName: json['project_name'] as String,
      buildingType: json['building_type'] as String,
      projectLocationText: json['project_location_text'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      status: json['status'] as String,
      submittedAt: json['submitted_at'] as String,
      polygonPoints: polygon,
      barangayName: json['barangay_name'] as String?,
      mappedAddress: json['mapped_address'] as String?,
      lotAreaSqm: (json['lot_area_sqm'] as num?)?.toDouble(),
    );
  }
}
