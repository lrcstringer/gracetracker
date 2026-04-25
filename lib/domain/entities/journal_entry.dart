import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

class JournalEntry {
  final String id;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? text;
  final String? habitId;
  final String? habitName;

  /// 'habit' | 'free' | 'linked'
  final String sourceType;

  final bool pinned;

  const JournalEntry({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    this.text,
    this.habitId,
    this.habitName,
    required this.sourceType,
    this.pinned = false,
  });

  factory JournalEntry.create({
    String? text,
    String? habitId,
    String? habitName,
    required String sourceType,
  }) {
    final now = DateTime.now();
    return JournalEntry(
      id: const Uuid().v4(),
      createdAt: now,
      updatedAt: now,
      text: text,
      habitId: habitId,
      habitName: habitName,
      sourceType: sourceType,
    );
  }

  JournalEntry copyWith({
    String? text,
    String? habitId,
    String? habitName,
    String? sourceType,
    DateTime? updatedAt,
    bool? pinned,
  }) {
    return JournalEntry(
      id: id,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      text: text ?? this.text,
      habitId: habitId ?? this.habitId,
      habitName: habitName ?? this.habitName,
      sourceType: sourceType ?? this.sourceType,
      pinned: pinned ?? this.pinned,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'id': id,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'text': text,
        'habitId': habitId,
        'habitName': habitName,
        'sourceType': sourceType,
        'pinned': pinned,
      };

  factory JournalEntry.fromFirestore(Map<String, dynamic> data) {
    return JournalEntry(
      id: data['id'] as String? ?? '',
      createdAt: _parseDate(data['createdAt']),
      updatedAt: _parseDate(data['updatedAt']),
      text: data['text'] as String?,
      habitId: data['habitId'] as String?,
      habitName: data['habitName'] as String?,
      sourceType: data['sourceType'] as String? ?? 'free',
      pinned: (data['pinned'] as bool?) ?? false,
    );
  }

  /// Extracts plain text from a Delta JSON string produced by flutter_quill.
  static String extractPlainText(String? deltaJson) {
    if (deltaJson == null || deltaJson.isEmpty) return '';
    try {
      final ops = jsonDecode(deltaJson) as List;
      final buffer = StringBuffer();
      for (final op in ops) {
        if (op is Map) {
          final insert = op['insert'];
          if (insert is String) buffer.write(insert);
        }
      }
      return buffer.toString().trim();
    } catch (_) {
      return '';
    }
  }

  static DateTime _parseDate(dynamic raw) {
    if (raw is Timestamp) return raw.toDate();
    if (raw is String) return DateTime.tryParse(raw) ?? DateTime.now();
    return DateTime.now();
  }
}
