import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

import '../../../models/video_lesson.dart';
import '../../../providers/learning_progress_provider.dart';
import '../../../widgets/learn/learn_ui.dart';
import 'package:elio/l10n/l10n.dart';


/// Opens the YouTube player for [lesson] (youtubeId, else parsed from
/// videoUrl) and resumes from the saved position.
Future<void> openVideoLesson(
  BuildContext context,
  WidgetRef ref,
  VideoLesson lesson,
) async {
  final youtubeId = lesson.resolvedYoutubeId;
  if (youtubeId.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.videoUnavailable)),
    );
    return;
  }

  final progress = ref.read(learningProgressProvider).valueOrNull;
  final savedSeconds = progress?.videoWatchProgress[lesson.id] ?? 0;
  final completed = progress?.completedVideoIds.contains(lesson.id) ?? false;
  final durationSeconds = lesson.durationSeconds;
  final nearEnd = durationSeconds > 0 && savedSeconds >= (durationSeconds - 2);
  final initialPositionSeconds = completed || nearEnd ? 0 : savedSeconds;

  await Navigator.of(context).push(
    learnRoute<void>(
      _YoutubeVideoPage(
        title: lesson.title,
        youtubeId: youtubeId,
        videoId: lesson.id,
        moduleId: lesson.moduleId,
        durationSeconds: durationSeconds,
        initialPositionSeconds: initialPositionSeconds,
        forceStartFromBeginning: completed || nearEnd,
      ),
    ),
  );
}

class _YoutubeVideoPage extends ConsumerStatefulWidget {
  final String title;
  final String youtubeId;
  final String videoId;
  final String moduleId;
  final int durationSeconds;
  final int initialPositionSeconds;
  final bool forceStartFromBeginning;

  const _YoutubeVideoPage({
    required this.title,
    required this.youtubeId,
    required this.videoId,
    required this.moduleId,
    required this.durationSeconds,
    required this.initialPositionSeconds,
    required this.forceStartFromBeginning,
  });

  @override
  ConsumerState<_YoutubeVideoPage> createState() => _YoutubeVideoPageState();
}

class _YoutubeVideoPageState extends ConsumerState<_YoutubeVideoPage> {
  late final YoutubePlayerController _controller;
  late final LearningProgressNotifier _progressNotifier;
  StreamSubscription<YoutubeVideoState>? _videoStateSub;
  bool _didSeekToInitialPosition = false;
  int _lastSavedPositionSeconds = -1;
  int _latestPositionSeconds = 0;
  DateTime _lastSaveAt = DateTime.fromMillisecondsSinceEpoch(0);

  bool get _isCompletedReplayFromStart =>
      widget.forceStartFromBeginning && widget.initialPositionSeconds == 0;

  @override
  void initState() {
    super.initState();
    // The app pins portrait elsewhere; the player may turn for fullscreen.
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    _progressNotifier = ref.read(learningProgressProvider.notifier);
    _controller = YoutubePlayerController.fromVideoId(
      videoId: widget.youtubeId,
      autoPlay: true,
      params: const YoutubePlayerParams(mute: false, strictRelatedVideos: true),
    );
    _videoStateSub = _controller.videoStateStream.listen(_handlePlayerUpdate);
  }

  @override
  void dispose() {
    final shouldSkipTinyCompletedReplaySave =
        _isCompletedReplayFromStart && _latestPositionSeconds < 2;
    if (_latestPositionSeconds >= 0 && !shouldSkipTinyCompletedReplaySave) {
      _saveProgressAfterDispose(_latestPositionSeconds);
    }
    unawaited(_videoStateSub?.cancel());
    _controller.close();
    SystemChrome.setPreferredOrientations(const [DeviceOrientation.portraitUp]);
    super.dispose();
  }

  void _handlePlayerUpdate(YoutubeVideoState value) {
    final positionSeconds = value.position.inSeconds;
    _latestPositionSeconds = positionSeconds;

    if (!_didSeekToInitialPosition) {
      _didSeekToInitialPosition = true;

      final targetSeconds = widget.forceStartFromBeginning
          ? 0
          : widget.initialPositionSeconds;
      final shouldSeek =
          targetSeconds > 2 ||
          (widget.forceStartFromBeginning && positionSeconds > 1);

      if (shouldSeek) {
        _latestPositionSeconds = targetSeconds;
        unawaited(
          _controller.seekTo(
            seconds: targetSeconds.toDouble(),
            allowSeekAhead: true,
          ),
        );
        return;
      }
    }

    if (_isCompletedReplayFromStart && positionSeconds < 2) return;

    final now = DateTime.now();
    if (now.difference(_lastSaveAt).inSeconds < 10) return;
    if ((positionSeconds - _lastSavedPositionSeconds).abs() < 2) return;

    _saveProgress(positionSeconds);
  }

  void _saveProgressAfterDispose(int positionSeconds) {
    final notifier = _progressNotifier;
    final videoId = widget.videoId;
    final moduleId = widget.moduleId;
    final durationSeconds = widget.durationSeconds;

    Future<void>(() {
      unawaited(
        notifier.updateVideoWatchProgress(
          videoId,
          moduleId: moduleId,
          positionSeconds: positionSeconds,
          durationSeconds: durationSeconds,
        ),
      );
    });
  }

  void _saveProgress(int positionSeconds) {
    _lastSaveAt = DateTime.now();
    _lastSavedPositionSeconds = positionSeconds;

    unawaited(
      _progressNotifier.updateVideoWatchProgress(
        widget.videoId,
        moduleId: widget.moduleId,
        positionSeconds: positionSeconds,
        durationSeconds: widget.durationSeconds,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          widget.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.text.titleLarge?.copyWith(color: Colors.white),
        ),
      ),
      body: Center(child: YoutubePlayer(controller: _controller)),
    );
  }
}
