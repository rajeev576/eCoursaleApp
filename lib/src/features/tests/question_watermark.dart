import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';

/// A faint, centered school-logo watermark drawn BEHIND the question content in
/// the test player and solution view (mirrors the web test window, which shows a
/// translucent brand watermark). Purely decorative + a mild anti-copy cue; it
/// never blocks interaction (wrapped in IgnorePointer by the caller's Stack
/// order — it sits at the bottom of the Stack).
///
/// Degrades to nothing when the school has no logo, so non-branded tenants just
/// get a clean background.
class QuestionWatermark extends ConsumerWidget {
  const QuestionWatermark({super.key, this.opacity = 0.05});
  final double opacity;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logo = ref.watch(schoolConfigProvider).maybeWhen(
          data: (c) => c.logo,
          orElse: () => '',
        );
    if (logo.isEmpty) return const SizedBox.shrink();
    return Positioned.fill(
      child: IgnorePointer(
        child: Center(
          child: Opacity(
            opacity: opacity,
            child: FractionallySizedBox(
              widthFactor: 0.6,
              child: CachedNetworkImage(
                imageUrl: logo,
                fit: BoxFit.contain,
                errorWidget: (_, __, ___) => const SizedBox.shrink(),
                placeholder: (_, __) => const SizedBox.shrink(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
