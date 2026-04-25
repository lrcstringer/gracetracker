import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../data/datasources/remote/auth_service.dart';
import '../../domain/entities/journal_entry.dart';
import '../../domain/repositories/journal_repository.dart';

enum JournalSortOrder { newestFirst, oldestFirst, byHabit }

class JournalProvider extends ChangeNotifier {
  final JournalRepository _repository;

  JournalProvider(this._repository) {
    AuthService.shared.addListener(_onAuthChanged);
    if (AuthService.shared.isAuthenticated) _subscribeToEntries();
  }

  List<JournalEntry> _entries = [];
  bool _isLoading = false;
  String _searchQuery = '';
  JournalSortOrder _sortOrder = JournalSortOrder.newestFirst;

  StreamSubscription<List<JournalEntry>>? _entriesSub;

  bool get isLoading => _isLoading;
  String get searchQuery => _searchQuery;
  JournalSortOrder get sortOrder => _sortOrder;

  @override
  void dispose() {
    _entriesSub?.cancel();
    AuthService.shared.removeListener(_onAuthChanged);
    super.dispose();
  }

  void _onAuthChanged() {
    if (AuthService.shared.isAuthenticated) {
      _subscribeToEntries();
    } else {
      _entriesSub?.cancel();
      _entriesSub = null;
      _entries = [];
      _isLoading = false;
      notifyListeners();
    }
  }

  void _subscribeToEntries() {
    _entriesSub?.cancel();
    _isLoading = true;
    notifyListeners();
    _entriesSub = _repository.watchEntries().listen(
      (entries) {
        _entries = entries;
        _isLoading = false;
        notifyListeners();
      },
      onError: (_) {
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  List<JournalEntry> get allEntries => List.unmodifiable(_entries);

  JournalEntry? getEntry(String id) =>
      _entries.where((e) => e.id == id).firstOrNull;

  List<JournalEntry> get filteredEntries {
    var result = List<JournalEntry>.from(_entries);

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      result = result.where((e) {
        final textMatch = JournalEntry.extractPlainText(e.text).toLowerCase().contains(q);
        final habitMatch = e.habitName?.toLowerCase().contains(q) ?? false;
        return textMatch || habitMatch;
      }).toList();
    }

    switch (_sortOrder) {
      case JournalSortOrder.newestFirst:
        result.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      case JournalSortOrder.oldestFirst:
        result.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      case JournalSortOrder.byHabit:
        result.sort((a, b) {
          final primary = (a.habitName ?? '').compareTo(b.habitName ?? '');
          return primary != 0 ? primary : b.createdAt.compareTo(a.createdAt);
        });
    }

    final pinned = result.where((e) => e.pinned).toList();
    final unpinned = result.where((e) => !e.pinned).toList();
    return [...pinned, ...unpinned];
  }

  Future<void> saveEntry({
    String? text,
    List<String> imageLocalPaths = const [],
    String? voiceLocalPath,
    String? habitId,
    String? habitName,
    required String sourceType,
  }) async {
    final entry = JournalEntry.create(
      text: text,
      habitId: habitId,
      habitName: habitName,
      sourceType: sourceType,
    );
    _repository.saveEntry(entry).ignore();
  }

  Future<void> updateEntry(
    JournalEntry entry, {
    String? text,
    bool clearText = false,
    List<String> newImageLocalPaths = const [],
    String? newVoiceLocalPath,
    List<String>? removedImageUrls,
    bool? removeVoice,
  }) async {
    final resolvedText = clearText ? null : (text ?? entry.text);
    final updated = JournalEntry(
      id: entry.id,
      createdAt: entry.createdAt,
      updatedAt: DateTime.now(),
      text: resolvedText,
      habitId: entry.habitId,
      habitName: entry.habitName,
      sourceType: entry.sourceType,
      pinned: entry.pinned,
    );
    _repository.updateEntry(updated).ignore();
  }

  Future<void> deleteAllEntries() async {
    final all = List<JournalEntry>.from(_entries);
    await Future.wait(all.map(deleteEntry));
  }

  Future<void> deleteEntry(JournalEntry entry) async {
    _repository.deleteEntry(entry.id).ignore();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  Future<void> togglePin(JournalEntry entry) async {
    final updated = entry.copyWith(pinned: !entry.pinned);
    _repository.updateEntry(updated).ignore();
  }

  void setSortOrder(JournalSortOrder order) {
    _sortOrder = order;
    notifyListeners();
  }
}
