import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers.dart';

/// "Connect With Us" — the school's social handles, sourced from the SAME data the
/// web Community Hub uses (community_data.social_media: YouTube, Telegram,
/// WhatsApp, Instagram, Facebook, LinkedIn, …), each carrying its name + icon +
/// brand colour. Renders nothing when the school has none. Shown in Profile and
/// the Community page so students can follow the school.
class SocialLinksBar extends ConsumerWidget {
  const SocialLinksBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cfg = ref.watch(schoolConfigProvider).maybeWhen(
        data: (c) => c, orElse: () => null);
    if (cfg == null || !cfg.hasSocialLinks) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    final links = cfg.effectiveSocialLinks;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.primary.withValues(alpha: 0.15)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Connect With Us',
            style: TextStyle(fontWeight: FontWeight.w800, color: cs.onSurface, fontSize: 15)),
        const SizedBox(height: 12),
        ...links.map((l) {
          final brand = _hex(l.color) ?? cs.primary;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: cs.surface,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _open(l.url),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: cs.outlineVariant),
                  ),
                  child: Row(children: [
                    Container(
                      width: 38, height: 38,
                      decoration: BoxDecoration(
                        color: brand.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(_iconFor(l.icon, l.name), color: brand, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(l.name.isEmpty ? l.url : l.name,
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w600)),
                    ),
                    Icon(Icons.open_in_new, size: 16, color: cs.onSurfaceVariant),
                  ]),
                ),
              ),
            ),
          );
        }),
      ]),
    );
  }

  /// Map the web's FontAwesome class (or the name) to a Material icon.
  IconData _iconFor(String fa, String name) {
    final s = '$fa $name'.toLowerCase();
    if (s.contains('youtube')) return Icons.play_circle_fill;
    if (s.contains('telegram')) return Icons.send;
    if (s.contains('whatsapp')) return Icons.chat;
    if (s.contains('instagram')) return Icons.camera_alt_outlined;
    if (s.contains('facebook')) return Icons.facebook;
    if (s.contains('twitter') || s.contains('fa-x') || s == 'x') return Icons.alternate_email;
    if (s.contains('linkedin')) return Icons.work_outline;
    if (s.contains('globe') || s.contains('website') || s.contains('link')) return Icons.language;
    return Icons.public;
  }

  Color? _hex(String hex) {
    var h = hex.trim();
    if (h.isEmpty) return null;
    if (h.startsWith('#')) h = h.substring(1);
    if (h.length == 6) h = 'FF$h';
    final v = int.tryParse(h, radix: 16);
    return v == null ? null : Color(v);
  }

  Future<void> _open(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {/* ignore */}
  }
}
