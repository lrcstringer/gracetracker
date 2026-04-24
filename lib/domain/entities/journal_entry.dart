import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

class JournalEntry {
  final String id;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? text;

  /// Firebase Storage download URL — null until the upload completes.
  final String? voiceUrl;

  /// Firebase Storage download URLs — empty until uploads complete.
  final List<String> imageUrls;

  /// True while any local media file is still awaiting upload to Storage.
  final bool uploadPending;

  /// Habit this entry was written from (null for free entries).
  final String? habitId;

  /// Denormalised habit name for display without re-loading habits.
  final String? habitName;

  /// 'habit' | 'free' | 'linked'
  final String sourceType;

  /// Whether this entry is pinned to the top of the journal list.
  final bool pinned;

  const JournalEntry({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    this.text,
    this.voiceUrl,
    this.imageUrls = const [],
    this.uploadPending = false,
    this.habitId,
    this.habitName,
    required this.sourceType,
    this.pinned = false,
  });

  factory JournalEntry.create({
    String? text,
    String? voiceUrl,
    List<String> imageUrls = const [],
    bool uploadPending = false,
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
      voiceUrl: voiceUrl,
      imageUrls: imageUrls,
      uploadPending: uploadPending,
      habitId: habitId,
      habitName: habitName,
      sourceType: sourceType,
    );
  }

  JournalEntry copyWith({
    String? text,
    Object? voiceUrl = _keep,
    List<String>? imageUrls,
    bool? uploadPending,
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
      voiceUrl: voiceUrl == _keep ? this.voiceUrl : voiceUrl as String?,
      imageUrls: imageUrls ?? this.imageUrls,
      uploadPending: uploadPending ?? this.uploadPending,
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
        'voiceUrl': voiceUrl,
        'imageUrls': imageUrls,
        'uploadPending': uploadPending,
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
      voiceUrl: data['voiceUrl'] as String?,
      imageUrls: List<String>.from(data['imageUrls'] as List? ?? []),
      uploadPending: (data['uploadPending'] as bool?) ?? false,
      habitId: data['habitId'] as String?,
      habitName: data['habitName'] as String?,
      sourceType: data['sourceType'] as String? ?? 'free',
      pinned: (data['pinned'] as bool?) ?? false,
    );
  }

  /// Extracts plain text from a Delta JSON string produced by flutter_quill.
  /// Returns an empty string if [deltaJson] is null, empty, or unparseable.
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

// Sentinel for copyWith nullable fields.
const Object _keep = Object();
