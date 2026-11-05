import '../l10n/l10n.dart';

// Learn documents (elearning_modules and their videos, guides, quizzes) may
// carry `i18n: {"en": {...}, "id": {...}}` with translated fields
// (tools/l10n/translate_firestore.py, decision 0185). The app language wins;
// otherwise the document's original field is shown.

Map<String, dynamic> contentI18n(Map<String, dynamic> map) =>
    map['i18n'] is Map ? Map<String, dynamic>.from(map['i18n'] as Map) : const {};

String contentText(Map<String, dynamic> i18n, String field, String base) {
  final side = i18n[l10n.localeName];
  final value = side is Map ? side[field] : null;
  return value is String && value.trim().isNotEmpty ? value : base;
}

/// A translated list is used only when it keeps the length (quiz options:
/// the correct index must stay right).
List<String> contentList(Map<String, dynamic> i18n, String field, List<String> base) {
  final side = i18n[l10n.localeName];
  final value = side is Map ? side[field] : null;
  if (value is! List || value.length != base.length) return base;
  final list = [for (final v in value) '$v'];
  return list.any((v) => v.trim().isEmpty) ? base : list;
}
