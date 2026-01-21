// ============================================================
// 1. CREATE: lib/models/network_project.dart
// ============================================================

class NetworkProject {
  final String id;
  final String name;
  final DateTime createdAt;
  final DateTime updatedAt;
  final double transmitterPower;
  final Map<String, dynamic>? diagramData;

  NetworkProject({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    required this.transmitterPower,
    this.diagramData,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'transmitterPower': transmitterPower,
      'diagramData': diagramData,
    };
  }

  factory NetworkProject.fromJson(Map<String, dynamic> json) {
    return NetworkProject(
      id: json['id'],
      name: json['name'],
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
      transmitterPower: json['transmitterPower'] ?? 19.0,
      diagramData: json['diagramData'],
    );
  }
}
