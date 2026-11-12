// Home search (Figma 329:3722, decision 0144): local and offline over the
// cached learning streams, the simulations list, quiz sets and the user's scans.
import 'package:flutter/material.dart';

import '../../models/home_stats.dart';
import '../../theme/elio_tokens.dart';
import '../../widgets/auth/auth_widgets.dart' show authPalette;
import 'home_parts.dart';
import 'package:elio/l10n/l10n.dart';

enum SearchScope {
  all,
  lessons,
  simulasi,
  quiz,
  scans;

  String get label => switch (this) {
    all => l10n.searchAll,
    lessons => l10n.searchLessons,
    simulasi => l10n.searchSims,
    quiz => l10n.searchQuiz,
    scans => l10n.searchScans,
  };

  String? get header => switch (this) {
    all => null,
    lessons => l10n.searchLessonsHeader,
    simulasi => l10n.searchSimsHeader,
    quiz => l10n.searchQuizHeader,
    scans => l10n.searchScansHeader,
  };
}

class SearchItem {
  const SearchItem({
    required this.scope,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.icon,
    this.bin,
  });

  final SearchScope scope;
  final String title, subtitle;
  final VoidCallback onTap;

  /// Null for scans, which use the scan line art.
  final IconData? icon;
  final HomeBin? bin;
}

bool searchMatches(String text, String query) =>
    text.toLowerCase().contains(query.trim().toLowerCase());

class HomeSearchField extends StatelessWidget {
  const HomeSearchField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.scope,
    required this.onScope,
    required this.resultCount,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final SearchScope scope;
  final ValueChanged<SearchScope> onScope;

  /// Null while the query is empty.
  final int? resultCount;

  @override
  Widget build(BuildContext context) {
    final p = authPalette(context);
    final active = controller.text.isNotEmpty;
    OutlineInputBorder border(Color c, double w) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(999),
      borderSide: BorderSide(color: c, width: w),
    );
    return TextField(
      controller: controller,
      focusNode: focusNode,
      textInputAction: TextInputAction.search,
      style: ElioTokens.body.copyWith(color: p.textPrimary),
      decoration: InputDecoration(
        filled: true,
        fillColor: p.surface,
        hintText: l10n.searchHint,
        hintStyle: ElioTokens.bodySmall.copyWith(color: p.textTertiary),
        hintMaxLines: 1,
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
        prefixIcon: Icon(
          Icons.search_rounded,
          color: active ? p.primaryText : p.textSecondary,
        ),
        enabledBorder: border(
          active ? p.primaryText : p.borderSubtle,
          active ? 2 : 1,
        ),
        focusedBorder: border(p.primaryText, 2),
        suffixIcon: active
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l10n.resultCount(resultCount ?? 0), style: homeSmall(p)),
                  IconButton(
                    tooltip: l10n.clearSearch,
                    onPressed: controller.clear,
                    icon: Icon(Icons.close_rounded, color: p.textSecondary),
                  ),
                ],
              )
            : Padding(
                padding: const EdgeInsets.only(right: 6),
                child: PopupMenuButton<SearchScope>(
                  tooltip: l10n.searchIn,
                  initialValue: scope,
                  onSelected: onScope,
                  itemBuilder: (_) => [
                    for (final s in SearchScope.values)
                      PopupMenuItem(value: s, child: Text(s.label)),
                  ],
                  child: Container(
                    constraints: const BoxConstraints(
                      minHeight: 48,
                      minWidth: 48,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: DecoratedBox(
                      decoration: ShapeDecoration(
                        color: p.surfaceRaised,
                        shape: homeShape(999),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              scope.label,
                              style: ElioTokens.button.copyWith(
                                color: p.textPrimary,
                              ),
                            ),
                            Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: p.textPrimary,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

class HomeSearchResults extends StatelessWidget {
  const HomeSearchResults({
    super.key,
    required this.query,
    required this.items,
    required this.scope,
    required this.onScope,
    required this.expanded,
    required this.onExpand,
  });

  final String query;

  /// Every match, all scopes.
  final List<SearchItem> items;
  final SearchScope scope;
  final ValueChanged<SearchScope> onScope;
  final bool expanded;
  final VoidCallback onExpand;

  static const _collapsedPerGroup = 2;

  @override
  Widget build(BuildContext context) {
    final p = authPalette(context);
    int count(SearchScope s) => s == SearchScope.all
        ? items.length
        : items.where((i) => i.scope == s).length;
    final groups = [
      for (final s in SearchScope.values.skip(1))
        if (scope == SearchScope.all || scope == s)
          (s, items.where((i) => i.scope == s).toList()),
    ].where((g) => g.$2.isNotEmpty).toList();
    final limit = expanded || scope != SearchScope.all
        ? 1 << 30
        : _collapsedPerGroup;
    final hidden = groups.fold(
      0,
      (n, g) => n + (g.$2.length > limit ? g.$2.length - limit : 0),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final s in SearchScope.values)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _ScopeChip(
                    label: '${s.label} ${count(s)}',
                    selected: s == scope,
                    onTap: () => onScope(s),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        if (groups.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              l10n.noResultsFor(query.trim()),
              textAlign: TextAlign.center,
              style: ElioTokens.body.copyWith(color: p.textSecondary),
            ),
          ),
        for (final (s, list) in groups) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 12, 0, 8),
            child: Semantics(
              header: true,
              child: Text(s.header!, style: homeOverline(p.textSecondary)),
            ),
          ),
          HomeCard(
            padding: 0,
            child: Column(
              children: [
                for (var i = 0; i < list.length && i < limit; i++) ...[
                  if (i > 0) Divider(height: 1, color: p.borderSubtle),
                  _ResultRow(item: list[i], query: query),
                ],
              ],
            ),
          ),
        ],
        if (hidden > 0)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: TextButton(
              onPressed: onExpand,
              style: TextButton.styleFrom(
                minimumSize: const Size(48, 48),
                foregroundColor: p.primaryText,
              ),
              child: Text(context.l10n.searchSeeAll(items.length)),
            ),
          ),
      ],
    );
  }
}

class _ScopeChip extends StatelessWidget {
  const _ScopeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = authPalette(context);
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        customBorder: homeShape(999),
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: ShapeDecoration(
            color: selected ? p.primary : p.surfaceRaised,
            shape: homeShape(999),
          ),
          child: Text(
            label,
            style: ElioTokens.button.copyWith(
              fontSize: 15,
              color: selected ? p.onPrimary : p.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({required this.item, required this.query});
  final SearchItem item;
  final String query;

  @override
  Widget build(BuildContext context) {
    final p = authPalette(context);
    final base = ElioTokens.body.copyWith(color: p.textPrimary, height: 1.4);
    final q = query.trim().toLowerCase();
    final at = item.title.toLowerCase().indexOf(q);
    final title = at < 0 || q.isEmpty
        ? TextSpan(text: item.title, style: base)
        : TextSpan(
            style: base,
            children: [
              TextSpan(text: item.title.substring(0, at)),
              TextSpan(
                text: item.title.substring(at, at + q.length),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              TextSpan(text: item.title.substring(at + q.length)),
            ],
          );
    final iconColor = switch (item.scope) {
      SearchScope.quiz => p.secondaryText,
      _ => p.tertiaryText,
    };
    return Semantics(
      button: true,
      label:
          '${l10n.a11ySearchItem(item.title, item.subtitle)}${item.bin == null ? '' : ', ${item.bin!.label}'}',
      container: true,
      excludeSemantics: true,
      child: InkWell(
        onTap: item.onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                item.icon == null
                    ? homeArt('scan_line_art', width: 24, height: 24)
                    : Icon(item.icon, color: iconColor),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text.rich(title),
                      Text(item.subtitle, style: homeSmall(p)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (item.bin != null)
                  BinChip(item.bin!)
                else
                  Icon(Icons.chevron_right_rounded, color: p.textSecondary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
