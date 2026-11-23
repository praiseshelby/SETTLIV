class SavingsGoal {
  final String id;
  final String name;
  final int targetPaise;
  final int savedPaise;
  final DateTime? targetDate;
  final DateTime createdAt;

  const SavingsGoal({
    required this.id,
    required this.name,
    required this.targetPaise,
    this.savedPaise = 0,
    this.targetDate,
    required this.createdAt,
  });

  bool get isAchieved => savedPaise >= targetPaise;
  
  double get progress {
    if (targetPaise <= 0) return 1.0;
    return (savedPaise / targetPaise).clamp(0.0, 1.0);
  }

  SavingsGoal copyWith({
    String? id,
    String? name,
    int? targetPaise,
    int? savedPaise,
    DateTime? targetDate,
    DateTime? createdAt,
  }) {
    return SavingsGoal(
      id: id ?? this.id,
      name: name ?? this.name,
      targetPaise: targetPaise ?? this.targetPaise,
      savedPaise: savedPaise ?? this.savedPaise,
      targetDate: targetDate ?? this.targetDate,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'targetPaise': targetPaise,
      'savedPaise': savedPaise,
      'targetDate': targetDate?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory SavingsGoal.fromJson(Map<String, dynamic> json) {
    return SavingsGoal(
      id: json['id'] as String,
      name: json['name'] as String,
      targetPaise: (json['targetPaise'] as num).toInt(),
      savedPaise: (json['savedPaise'] as num?)?.toInt() ?? 0,
      targetDate: json['targetDate'] != null
          ? DateTime.tryParse(json['targetDate'] as String)
          : null,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
    );
  }
}
