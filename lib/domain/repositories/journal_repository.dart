import '../entities/journal_entry.dart';

abstract class JournalRepository {
  Stream<List<JournalEntry>> watchEntries();
  Future<List<JournalEntry>> loadEntries();
  Future<void> saveEntry(JournalEntry entry);
  Future<void> updateEntry(JournalEntry entry);
  Future<void> deleteEntry(String id);
}
