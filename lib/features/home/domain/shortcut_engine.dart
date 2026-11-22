import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';

enum ShortcutId {
  scanReceipt,
  pasteSms,
  budgets,
  recurring,
  iouNotes,
  splitCalculator,
  exportCsv,
  backup,
}

class ShortcutDefinition {
  final ShortcutId id;
  final String label;
  final IconData icon;

  const ShortcutDefinition({
    required this.id,
    required this.label,
    required this.icon,
  });
}

class ShortcutUsage {
  final double score;
  final DateTime? lastUsed;
  final DateTime lastDecayed;

  const ShortcutUsage({
    required this.score,
    this.lastUsed,
    required this.lastDecayed,
  });

  Map<String, dynamic> toJson() => {
    'score': score,
    'lastUsed': lastUsed?.toIso8601String(),
    'lastDecayed': lastDecayed.toIso8601String(),
  };

  factory ShortcutUsage.fromJson(Map<String, dynamic> json) {
    return ShortcutUsage(
      score: (json['score'] as num?)?.toDouble() ?? 0.0,
      lastUsed: json['lastUsed'] != null ? DateTime.tryParse(json['lastUsed'] as String) : null,
      lastDecayed: json['lastDecayed'] != null
          ? (DateTime.tryParse(json['lastDecayed'] as String) ?? DateTime.now())
          : DateTime.now(),
    );
  }
}

class ShortcutEngine {
  const ShortcutEngine._();

  static const List<ShortcutDefinition> allShortcuts = [
    ShortcutDefinition(
      id: ShortcutId.scanReceipt,
      label: 'Scan receipt',
      icon: Icons.document_scanner_rounded,
    ),
    ShortcutDefinition(
      id: ShortcutId.pasteSms,
      label: 'Paste SMS',
      icon: Icons.sms_rounded,
    ),
    ShortcutDefinition(
      id: ShortcutId.budgets,
      label: 'Budgets',
      icon: Icons.pie_chart_rounded,
    ),
    ShortcutDefinition(
      id: ShortcutId.iouNotes,
      label: 'IOU notes',
      icon: Icons.note_alt_rounded,
    ),
    ShortcutDefinition(
      id: ShortcutId.splitCalculator,
      label: 'Split calc',
      icon: Icons.calculate_rounded,
    ),
    ShortcutDefinition(
      id: ShortcutId.recurring,
      label: 'Recurring',
      icon: Icons.repeat_rounded,
    ),
    ShortcutDefinition(
      id: ShortcutId.exportCsv,
      label: 'Export CSV',
      icon: Icons.file_download_rounded,
    ),
    ShortcutDefinition(
      id: ShortcutId.backup,
      label: 'Backup',
      icon: Icons.backup_rounded,
    ),
  ];

  static const List<ShortcutId> defaultOrder = [
    ShortcutId.scanReceipt,
    ShortcutId.pasteSms,
    ShortcutId.budgets,
    ShortcutId.iouNotes,
    ShortcutId.splitCalculator,
    ShortcutId.recurring,
    ShortcutId.exportCsv,
    ShortcutId.backup,
  ];

  /// Halves the score every 14 days
  static double decayScore(double score, DateTime lastDecayed, DateTime now) {
    final diffMs = now.difference(lastDecayed).inMilliseconds;
    if (diffMs <= 0 || score <= 0) return score;
    final periods = diffMs / (14.0 * 24 * 3600 * 1000);
    return score * math.pow(0.5, periods);
  }

  /// Decay all usages to `now`
  static Map<ShortcutId, ShortcutUsage> decayAll(
    Map<ShortcutId, ShortcutUsage> usages,
    DateTime now,
  ) {
    final result = <ShortcutId, ShortcutUsage>{};
    for (final id in ShortcutId.values) {
      final existing = usages[id];
      if (existing == null) {
        result[id] = ShortcutUsage(score: 0.0, lastUsed: null, lastDecayed: now);
      } else {
        final decayed = decayScore(existing.score, existing.lastDecayed, now);
        result[id] = ShortcutUsage(
          score: decayed,
          lastUsed: existing.lastUsed,
          lastDecayed: now,
        );
      }
    }
    return result;
  }

  /// Register a tap on shortcut `id`
  static Map<ShortcutId, ShortcutUsage> recordTap(
    Map<ShortcutId, ShortcutUsage> usages,
    ShortcutId id,
    DateTime now,
  ) {
    final decayed = decayAll(usages, now);
    final current = decayed[id] ?? ShortcutUsage(score: 0.0, lastUsed: null, lastDecayed: now);
    decayed[id] = ShortcutUsage(
      score: current.score + 1.0,
      lastUsed: now,
      lastDecayed: now,
    );
    return decayed;
  }

  /// Pure function to rank shortcuts and return top 5
  static List<ShortcutDefinition> rankShortcuts(
    Map<ShortcutId, ShortcutUsage> usages,
  ) {
    final list = List<ShortcutDefinition>.from(allShortcuts);

    list.sort((a, b) {
      final usageA = usages[a.id];
      final usageB = usages[b.id];
      final scoreA = usageA?.score ?? 0.0;
      final scoreB = usageB?.score ?? 0.0;

      // Higher score first (with tolerance for precision)
      if ((scoreA - scoreB).abs() > 0.0001) {
        return scoreB.compareTo(scoreA);
      }

      // Then last used desc
      final timeA = usageA?.lastUsed;
      final timeB = usageB?.lastUsed;
      if (timeA != null && timeB != null) {
        final timeComp = timeB.compareTo(timeA);
        if (timeComp != 0) return timeComp;
      } else if (timeA != null) {
        return -1;
      } else if (timeB != null) {
        return 1;
      }

      // Fallback to defaultOrder
      final indexA = defaultOrder.indexOf(a.id);
      final indexB = defaultOrder.indexOf(b.id);
      return indexA.compareTo(indexB);
    });

    return list.take(5).toList();
  }

  static String serializeUsages(Map<ShortcutId, ShortcutUsage> usages) {
    final map = <String, dynamic>{};
    for (final entry in usages.entries) {
      map[entry.key.name] = entry.value.toJson();
    }
    return jsonEncode(map);
  }

  static Map<ShortcutId, ShortcutUsage> deserializeUsages(String jsonString) {
    try {
      final decoded = jsonDecode(jsonString) as Map<String, dynamic>;
      final map = <ShortcutId, ShortcutUsage>{};
      for (final entry in decoded.entries) {
        final id = ShortcutId.values.firstWhere(
          (e) => e.name == entry.key,
          orElse: () => ShortcutId.scanReceipt,
        );
        map[id] = ShortcutUsage.fromJson(entry.value as Map<String, dynamic>);
      }
      return map;
    } catch (_) {
      return {};
    }
  }
}
