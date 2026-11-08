import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n.dart';
import '../../../services/daily_guide_service.dart';
import '../../../widgets/learn/learn_ui.dart';
import 'guides_page.dart';
import 'learn_content.dart';

class DailyGuidesLink extends StatelessWidget {
  const DailyGuidesLink({super.key});

  @override
  Widget build(BuildContext context) => LearnListCard(
    children: [
      GuideLessonRow(
        title: l10n.dailyGuidesTitle,
        subtitle: l10n.dailyGuidesDescription,
        icon: Icons.newspaper_rounded,
        onTap: () => Navigator.of(
          context,
        ).push(learnRoute<void>(const DailyGuidesPage())),
      ),
    ],
  );
}

class DailyGuidesPage extends ConsumerStatefulWidget {
  const DailyGuidesPage({super.key});

  @override
  ConsumerState<DailyGuidesPage> createState() => _DailyGuidesPageState();
}

class _DailyGuidesPageState extends ConsumerState<DailyGuidesPage>
    with WidgetsBindingObserver {
  late Future<DailyGuideFeed> _feed;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _feed = ref.read(dailyGuideServiceProvider).load();
  }

  Future<void> _refresh() async {
    final next = ref.read(dailyGuideServiceProvider).load();
    setState(() {
      _feed = next;
    });
    try {
      await next;
    } catch (_) {
      // The FutureBuilder shows the failure and a retry action.
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LearnPageScaffold(
    title: l10n.dailyGuidesTitle,
    actions: [
      IconButton(
        tooltip: l10n.dailyGuidesRefresh,
        onPressed: _refresh,
        icon: const Icon(Icons.refresh_rounded),
      ),
    ],
    body: FutureBuilder<DailyGuideFeed>(
      future: _feed,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Center(child: LearnSpinner(label: l10n.lnLoadingGuide));
        }
        if (snapshot.hasError) {
          return LearnListView(
            children: [
              LearnStateView(
                asset: LearnArt.stateOffline,
                title: l10n.guidePdfUnavailable,
                message: l10n.lnCheckOpenAgain,
                primaryLabel: l10n.dailyGuidesRefresh,
                onPrimary: _refresh,
              ),
            ],
          );
        }
        final feed = snapshot.data!;
        return LearnListView(
          onRefresh: _refresh,
          children: [
            if (feed.offline) LearnHintCard(text: l10n.dailyGuidesOffline),
            if (feed.guides.isEmpty)
              LearnStateView(
                asset: LearnArt.stateEmpty,
                title: l10n.dailyGuidesEmpty,
              )
            else ...[
              LearnSectionHeader(title: l10n.dailyGuidesLatest),
              for (var i = 0; i < feed.guides.length; i++) ...[
                if (i == 1) LearnSectionHeader(title: l10n.dailyGuidesArchive),
                Builder(
                  builder: (context) {
                    final issue = feed.guides[i];
                    final lesson = issue.lesson(l10n.localeName);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: LearnListCard(
                        children: [
                          GuideLessonRow(
                            title: lesson.title,
                            subtitle: '${issue.date} · ${lesson.description}',
                            onTap: () => openGuideLesson(
                              context: context,
                              ref: ref,
                              lesson: lesson,
                              isDaily: true,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ],
          ],
        );
      },
    ),
  );
}
