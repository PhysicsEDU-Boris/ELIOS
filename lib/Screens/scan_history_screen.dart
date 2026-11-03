import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/scan_record.dart';
import '../services/ai_quiz_service.dart';
import '../services/quiz_pdf_service.dart';
import '../services/scan_record_store.dart';
import '../widgets/quiz_explanation_overlay.dart';

const _ink = Color(0xFF1C2833);
const _subLabel = Color(0xFF6B6B6B);
const _cardBorder = Color(0xFFE5E7E9);
const _goldAccent = Color(0xFFF39C12);
const _goldBg = Color(0xFFFEF9E7);
const _goldBorder = Color(0xFFFAD7A0);
const _greenAccent = Color(0xFF16A085);
const _greenDark = Color(0xFF0D5C46);
const _redAccent = Color(0xFFE74C3C);

/// Scan History screen (Figma node 100:170).
/// Displays recent scans, trophies earned, student level progress,
/// category filters, and detailed quiz breakdowns for each scan.
class ScanHistoryScreen extends StatefulWidget {
  const ScanHistoryScreen({
    super.key,
    this.store,
    this.onClose,
  });

  final ScanRecordStore? store;
  final VoidCallback? onClose;

  @override
  State<ScanHistoryScreen> createState() => _ScanHistoryScreenState();
}

class _ScanHistoryScreenState extends State<ScanHistoryScreen> {
  late final ScanRecordStore _store;
  ScanCategory? _selectedFilter;
  String? _selectedRecordId;
  final Set<String> _expandedQuestions = {};

  @override
  void initState() {
    super.initState();
    _store = widget.store ?? ScanRecordStore.instance;
    _store.addListener(_onStoreChanged);
    if (!_store.isLoaded) {
      _store.load();
    }
  }

  @override
  void dispose() {
    _store.removeListener(_onStoreChanged);
    super.dispose();
  }

  void _onStoreChanged() {
    if (mounted) setState(() {});
  }

  List<ScanRecord> get _filteredRecords {
    if (_selectedFilter == null) return _store.records;
    return _store.records.where((r) => r.category == _selectedFilter).toList();
  }

  ScanRecord? get _activeRecord {
    final list = _filteredRecords;
    if (list.isEmpty) return null;
    if (_selectedRecordId == null) return list.first;
    return list.firstWhere((r) => r.id == _selectedRecordId, orElse: () => list.first);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F6),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 750;
            return Container(
              margin: EdgeInsets.all(isWide ? 16 : 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 16,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _buildHeader(isWide),
                  const Divider(height: 1, color: _cardBorder),
                  Expanded(
                    child: isWide
                        ? _buildWideContent()
                        : _buildNarrowContent(),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(bool isWide) {
    final totalTrophies = _store.totalTrophies;
    final level = _store.userLevel;
    final progress = _store.levelProgress;

    final trophyCard = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _goldBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _goldBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: const BoxDecoration(
              color: _goldAccent,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.emoji_events_rounded, size: 18, color: Colors.white),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$totalTrophies trophies',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _ink),
              ),
              const SizedBox(height: 2),
              SizedBox(
                width: 80,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 4,
                    backgroundColor: const Color(0xFFE5E8E8),
                    valueColor: const AlwaysStoppedAnimation<Color>(_goldAccent),
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                level.levelAndTitle,
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF7D6608)),
              ),
            ],
          ),
        ],
      ),
    );

    final lokalChip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F8F5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFA3E4D7)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_outline_rounded, size: 14, color: _greenAccent),
          SizedBox(width: 4),
          Text(
            'Tersimpan lokal',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _greenDark),
          ),
        ],
      ),
    );

    final closeBtn = Material(
      color: Colors.transparent,
      child: InkWell(
        key: const ValueKey('scan_history_close_button'),
        onTap: widget.onClose ?? () => Navigator.of(context).maybePop(),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _cardBorder),
          ),
          child: const Icon(Icons.close_rounded, size: 20, color: _ink),
        ),
      ),
    );

    if (!isWide) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Scan History',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _ink),
                  ),
                ),
                lokalChip,
                const SizedBox(width: 8),
                closeBtn,
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Quiz results & trophies',
                    style: TextStyle(fontSize: 12, color: _subLabel),
                  ),
                ),
                trophyCard,
              ],
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Scan History',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: _ink,
                    letterSpacing: -0.3,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Every item you scanned, with its quiz results and trophies',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, color: _subLabel),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          lokalChip,
          const SizedBox(width: 12),
          trophyCard,
          const SizedBox(width: 12),
          closeBtn,
        ],
      ),
    );
  }

  Widget _buildWideContent() {
    if (_store.records.isEmpty) {
      return _buildEmptyState();
    }
    final active = _activeRecord;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left column: filters and recent scans list
        Expanded(
          flex: 5,
          child: _buildRecentScansList(active),
        ),
        const VerticalDivider(width: 1, color: _cardBorder),
        // Right column: detailed question inspection
        Expanded(
          flex: 7,
          child: active == null
              ? _buildEmptyDetailPlaceholder()
              : _buildDetailPanel(active),
        ),
      ],
    );
  }

  Widget _buildEmptyDetailPlaceholder() {
    return const Center(
      child: Text(
        'Pilih scan di sebelah kiri untuk melihat detail kuis.',
        style: TextStyle(fontSize: 14, color: _subLabel),
      ),
    );
  }

  Widget _buildNarrowContent() {
    if (_store.records.isEmpty) {
      return _buildEmptyState();
    }
    // Narrow layout: list first; if an item is selected on mobile, allow opening detail with a back button.
    final active = _activeRecord;
    if (_selectedRecordId != null && active != null) {
      return Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: const Color(0xFFF9FAFA),
            child: Row(
              children: [
                TextButton.icon(
                  onPressed: () => setState(() => _selectedRecordId = null),
                  icon: const Icon(Icons.arrow_back_rounded, size: 18, color: _greenDark),
                  label: const Text('Back to list', style: TextStyle(color: _greenDark, fontWeight: FontWeight.w600)),
                ),
                Expanded(child: Text(active.itemName, textAlign: TextAlign.end,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold, color: _ink))),
              ],
            ),
          ),
          const Divider(height: 1, color: _cardBorder),
          Expanded(child: _buildDetailPanel(active)),
        ],
      );
    }
    return _buildRecentScansList(active);
  }

  Widget _buildRecentScansList(ScanRecord? active) {
    final records = _filteredRecords;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Filter bar and record count
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Recent scans',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _ink,
                  ),
                ),
              ),
              Text(
                '${records.length}',
                style: const TextStyle(fontSize: 13, color: _subLabel),
              ),
              if (!kReleaseMode) ...[
                const SizedBox(width: 4),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  icon: const Icon(Icons.playlist_add_rounded, size: 20, color: _greenDark),
                  tooltip: 'Seed Sample Data (Debug)',
                  onPressed: () async {
                    await _store.seedFigmaSampleRecords();
                    if (mounted) setState(() {});
                  },
                ),
              ],
            ],
          ),
        ),
        // Filter pills row
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              _buildFilterChip('All', isSelected: _selectedFilter == null, onTap: () {
                setState(() => _selectedFilter = null);
              }),
              const SizedBox(width: 8),
              _buildFilterChip('B3', isSelected: _selectedFilter == ScanCategory.b3, onTap: () {
                setState(() => _selectedFilter = ScanCategory.b3);
              }),
              const SizedBox(width: 8),
              _buildFilterChip('Recyclable', isSelected: _selectedFilter == ScanCategory.recyclable, onTap: () {
                setState(() => _selectedFilter = ScanCategory.recyclable);
              }),
              const SizedBox(width: 8),
              _buildFilterChip('Organic', isSelected: _selectedFilter == ScanCategory.organic, onTap: () {
                setState(() => _selectedFilter = ScanCategory.organic);
              }),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: records.isEmpty
              ? _buildEmptyState()
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: records.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final item = records[index];
                    final isSelected = active?.id == item.id;
                    return _buildRecordTile(item, isSelected: isSelected);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, {required bool isSelected, required VoidCallback onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: ValueKey('filter_chip_$label'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? _greenDark : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isSelected ? _greenDark : _cardBorder),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isSelected ? Colors.white : _ink,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRecordTile(ScanRecord item, {required bool isSelected}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: ValueKey('record_tile_${item.id}'),
        onTap: () {
          setState(() => _selectedRecordId = item.id);
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFF9FBFA) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? _greenDark : _cardBorder,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              _buildPhotoThumbnail(item.cropPhotoPath, size: 56),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.itemName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: _ink,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    _buildCategoryBadge(item.category),
                    const SizedBox(height: 4),
                    Text(
                      '${item.difficulty.name.capitalize()} · ${item.totalQuestions} questions',
                      style: const TextStyle(fontSize: 12, color: _subLabel),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.emoji_events_rounded, size: 18, color: Color(0xFFD4AC0D)),
                  const SizedBox(width: 4),
                  Text(
                    '+${item.trophies}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFB7950B),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailPanel(ScanRecord record) {
    return ListView(
      key: const ValueKey('detail_list_view'),
      padding: const EdgeInsets.all(16),
      children: [
        Center(child: _buildPhotoThumbnail(record.cropPhotoPath, size: 180)),
        const SizedBox(height: 12),
        // Detail summary card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _cardBorder),
          ),
          child: LayoutBuilder(
            builder: (context, cardBox) {
              final isCardWide = cardBox.maxWidth >= 440;
              final headerInfo = Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            Text(
                              record.itemName,
                              style: TextStyle(
                                fontSize: isCardWide ? 22 : 18,
                                fontWeight: FontWeight.bold,
                                color: _ink,
                              ),
                            ),
                            _buildCategoryBadge(record.category),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Scanned ${record.time.hour.toString().padLeft(2, '0')}:${record.time.minute.toString().padLeft(2, '0')} · Foto dan ${record.totalQuestions} soal tersimpan lokal',
                          style: const TextStyle(fontSize: 12, color: _subLabel),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            _buildDifficultyPill(
                              'Easy · ${record.difficulty == QuizDifficulty.easy ? record.totalQuestions : 1}Q',
                              isSelected: record.difficulty == QuizDifficulty.easy,
                            ),
                            _buildDifficultyPill(
                              'Medium · ${record.difficulty == QuizDifficulty.medium ? record.totalQuestions : 2}Q',
                              isSelected: record.difficulty == QuizDifficulty.medium,
                            ),
                            _buildDifficultyPill(
                              'Hard · ${record.difficulty == QuizDifficulty.hard ? record.totalQuestions : 3}Q',
                              isSelected: record.difficulty == QuizDifficulty.hard,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              );

              final trophiesCard = Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: _goldBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _goldBorder),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.emoji_events_rounded, size: 22, color: _goldAccent),
                        const SizedBox(width: 6),
                        Text(
                          '${record.trophies}',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF7D6608),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${record.correctCount} of ${record.totalQuestions} correct',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _ink),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      '10 trophies per right answer',
                      style: TextStyle(fontSize: 10, color: Color(0xFF7D6608)),
                    ),
                  ],
                ),
              );

              if (isCardWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: headerInfo),
                    const SizedBox(width: 12),
                    trophiesCard,
                  ],
                );
              } else {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    headerInfo,
                    const SizedBox(height: 12),
                    trophiesCard,
                  ],
                );
              }
            },
          ),
        ),
        const SizedBox(height: 16),
        // Questions header
        Row(
          children: [
            const Expanded(
              child: Text(
                'Questions',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _ink),
              ),
            ),
            OutlinedButton.icon(
              key: const ValueKey('export_pdf_button'),
              onPressed: () async {
                try {
                  await QuizPdfService.shareOrSave(record);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Laporan PDF berhasil diekspor')),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Gagal mengekspor PDF: $e')),
                    );
                  }
                }
              },
              icon: const Icon(Icons.picture_as_pdf_rounded, size: 14),
              label: const Text('Export PDF', style: TextStyle(fontSize: 11)),
              style: OutlinedButton.styleFrom(
                foregroundColor: _greenDark,
                side: const BorderSide(color: Color(0xFFA3E4D7)),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F8F5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${record.difficulty.name.capitalize()} · ${record.totalQuestions}Q',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _greenDark),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Question list
        ...record.questions.asMap().entries.map((entry) {
          final idx = entry.key + 1;
          final q = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildQuestionCard(record, idx, q),
          );
        }),
      ],
    );
  }

  Widget _buildQuestionCard(ScanRecord record, int index, RecordQuestion q) {
    final isCorrect = q.isCorrect;
    final stripeColor = q.gradingPending ? const Color(0xFF7D6608) : isCorrect ? _greenAccent : _redAccent;
    final expandKey = '${record.id}_$index';
    final isExpanded = _expandedQuestions.contains(expandKey);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _cardBorder),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 5, color: stripeColor),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: q.gradingPending ? stripeColor : isCorrect ? _greenDark : const Color(0xFFC0392B),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Q$index',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              q.question,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: _ink,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: q.gradingPending ? _goldBg : isCorrect ? const Color(0xFFE8F8F5) : const Color(0xFFFDEDEC),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      q.gradingPending ? Icons.hourglass_empty_rounded : isCorrect ? Icons.check_rounded : Icons.close_rounded,
                                      size: 13,
                                      color: stripeColor,
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      q.gradingPending ? 'Pending' : isCorrect ? 'Correct' : 'Wrong',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: stripeColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                decoration: BoxDecoration(
                                  color: _goldBg,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: _goldBorder),
                                ),
                                child: Text(
                                  '🏆 +${q.trophies}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF7D6608),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(
                            width: 100,
                            child: Text(
                              'YOUR ANSWER',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _subLabel),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              q.yourAnswer,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: stripeColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(
                            width: 100,
                            child: Text(
                              'RIGHT ANSWER',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _subLabel),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              q.rightAnswer,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: _greenAccent,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (q.isEssay) ...[
                        const SizedBox(height: 4),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(
                              width: 100,
                              child: Text(
                                'SCORE',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _subLabel),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                q.gradingPending ? 'Menunggu penilaian' : '${q.essayScore} / 10 · +${q.trophies} Piala',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF7D6608),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton.icon(
                            key: ValueKey('toggle_explanation_${record.id}_$index'),
                            onPressed: () {
                              setState(() {
                                if (isExpanded) {
                                  _expandedQuestions.remove(expandKey);
                                } else {
                                  _expandedQuestions.add(expandKey);
                                }
                              });
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: _greenDark,
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            icon: Icon(
                              isExpanded ? Icons.expand_less_rounded : Icons.menu_book_rounded,
                              size: 14,
                            ),
                            label: Text(
                              isExpanded ? 'Tutup Penjelasan' : 'Lihat Penjelasan',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      if (isExpanded) ...[
                        const Divider(color: _cardBorder, height: 16),
                        if (q.explanation != null && !q.explanation!.isUnavailable)
                          ExplanationBody(explanation: q.explanation!)
                        else
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              'Penjelasan tidak tersimpan untuk soal ini.',
                              style: TextStyle(fontSize: 12, color: _subLabel, fontStyle: FontStyle.italic),
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoThumbnail(String? path, {required double size}) {
    const placeholder = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.photo_outlined, size: 24, color: Color(0xFF7F8C8D)),
        SizedBox(height: 2),
        Text('PHOTO', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold,
            color: Color(0xFF7F8C8D))),
      ],
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: size,
        height: size,
        color: const Color(0xFFEAECEE),
        child: path == null
            ? placeholder
            : Image.file(File(path), fit: BoxFit.contain,
                errorBuilder: (_, error, stack) => placeholder),
      ),
    );
  }

  Widget _buildCategoryBadge(ScanCategory category) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: category.bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        category.badgeLabel,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: category.fg,
        ),
      ),
    );
  }

  Widget _buildDifficultyPill(String label, {required bool isSelected}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isSelected ? _greenDark : const Color(0xFFF2F4F4),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: isSelected ? Colors.white : _subLabel,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: Color(0xFFEAECEE),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.history_rounded, size: 36, color: _subLabel),
            ),
            const SizedBox(height: 16),
            const Text(
              'Belum Ada Riwayat Scan',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _ink),
            ),
            const SizedBox(height: 6),
            const Text(
              'Setiap sampah yang kamu scan dan kuis yang kamu selesaikan akan muncul di sini.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: _subLabel),
            ),
            if (!kReleaseMode) ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () async {
                  await _store.seedFigmaSampleRecords();
                  if (mounted) setState(() {});
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _greenDark,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                icon: const Icon(Icons.playlist_add_rounded, size: 18),
                label: const Text('Tambah Contoh Data (Debug)', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }
}
