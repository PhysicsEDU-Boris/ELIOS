import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:open_settings_plus/open_settings_plus.dart';

/// ── State Management ─────────────────────────────────────────────────
/// A Riverpod StreamProvider that listens to connectivity changes.
/// This completely decouples the network evaluation logic from the UI.
final connectivityStreamProvider = StreamProvider<List<ConnectivityResult>>((ref) {
  return Connectivity().onConnectivityChanged;
});

/// ── UI Wrapper ────────────────────────────────────────────────────────
/// A production-ready wrapper widget that enforces LAN network rules.
/// If cellular data is active without a corresponding Wi-Fi connection,
/// a non-dismissible blocking overlay is rendered.
class HotspotTrapWrapper extends ConsumerWidget {
  /// The underlying application interface to wrap.
  final Widget child;

  const HotspotTrapWrapper({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the connectivity state safely via Riverpod
    final connectivityState = ref.watch(connectivityStreamProvider);
    
    return Stack(
      children: [
        // 1. Render the underlying app interface natively
        child,
        
        // 2. Conditionally render the blocking overlay based on the data stream
        connectivityState.when(
          data: (List<ConnectivityResult> results) {
            // Evaluate network topology
            final hasCellular = results.contains(ConnectivityResult.mobile);
            final hasWifi = results.contains(ConnectivityResult.wifi);
            
            // Trigger block if cellular is active AND Wi-Fi/LAN is missing
            final shouldBlock = hasCellular && !hasWifi;
            
            if (shouldBlock) {
              return Positioned.fill(
                child: _buildBlockingOverlay(),
              );
            }
            
            // Auto-dismissal: return empty widget when condition resolves
            return const SizedBox.shrink();
          },
          // Maintain a transparent state during initial load or stream errors
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const SizedBox.shrink(),
        ),
      ],
    );
  }

  /// Builds the non-dismissible, 95% opacity black overlay UI.
  Widget _buildBlockingOverlay() {
    return Material(
      color: Colors.black.withValues(alpha: 0.95),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.wifi_tethering_error_rounded,
                color: Colors.white,
                size: 80,
              ),
              const SizedBox(height: 24),
              const Text(
                'Hotspot Required',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'A personal hotspot is mandatory for the robot\'s UDP discovery protocol to function properly. Please enable your hotspot to establish a local wireless network connection with ELIO.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 48),
              ElevatedButton(
                onPressed: () {
                  // Execute platform-specific deep-linking
                  if (Platform.isAndroid) {
                    const OpenSettingsPlusAndroid().tether();
                  } else if (Platform.isIOS) {
                    const OpenSettingsPlusIOS().personalHotspot();
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1D9E75),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Open Hotspot Settings',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
