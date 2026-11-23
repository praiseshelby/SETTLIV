enum FeedbackType {
  problem('Problem report'),
  feature('Feature request');

  final String label;
  const FeedbackType(this.label);
}

class FeedbackReport {
  final String id;
  final FeedbackType type;
  final String category;
  final String description;
  final String? contactEmail;
  final Map<String, String>? deviceInfo;
  final DateTime createdAt;
  final String status;

  const FeedbackReport({
    required this.id,
    required this.type,
    required this.category,
    required this.description,
    this.contactEmail,
    this.deviceInfo,
    required this.createdAt,
    this.status = 'Saved on this device',
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'category': category,
      'description': description,
      'contactEmail': contactEmail,
      'deviceInfo': deviceInfo,
      'createdAt': createdAt.toIso8601String(),
      'status': status,
    };
  }

  factory FeedbackReport.fromJson(Map<String, dynamic> json) {
    return FeedbackReport(
      id: json['id'] as String,
      type: FeedbackType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => FeedbackType.problem,
      ),
      category: json['category'] as String,
      description: json['description'] as String,
      contactEmail: json['contactEmail'] as String?,
      deviceInfo: (json['deviceInfo'] as Map<String, dynamic>?)?.map(
        (k, v) => MapEntry(k, v.toString()),
      ),
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      status: json['status'] as String? ?? 'Saved on this device',
    );
  }

  String formatAsText() {
    final buffer = StringBuffer();
    buffer.writeln('Settliv Feedback Report');
    buffer.writeln('----------------------');
    buffer.writeln('Type: ${type.label}');
    buffer.writeln('Category: $category');
    buffer.writeln('Date: ${createdAt.toIso8601String()}');
    buffer.writeln('Status: $status');
    if (contactEmail != null && contactEmail!.trim().isNotEmpty) {
      buffer.writeln('Contact Email: $contactEmail');
    }
    buffer.writeln('\nDescription:');
    buffer.writeln(description);
    if (deviceInfo != null && deviceInfo!.isNotEmpty) {
      buffer.writeln('\nDevice Diagnostics:');
      deviceInfo!.forEach((k, v) {
        buffer.writeln('- $k: $v');
      });
    }
    return buffer.toString();
  }
}
