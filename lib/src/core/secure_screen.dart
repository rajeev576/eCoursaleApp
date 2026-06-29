import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Toggles Android FLAG_SECURE (blocks screenshots, screen recording, and hides
/// the screen from the recents thumbnail). Used by the test player + solution to
/// protect exam content. No-ops on platforms without the channel (e.g. iOS for
/// now), so callers don't need platform checks.
class SecureScreen {
  static const _channel = MethodChannel('ecoursale/secure');

  static Future<void> enable() async {
    try {
      await _channel.invokeMethod('enable');
    } catch (_) {/* channel not available — ignore */}
  }

  static Future<void> disable() async {
    try {
      await _channel.invokeMethod('disable');
    } catch (_) {/* ignore */}
  }
}

/// Wrap any subtree to keep FLAG_SECURE ON while it's mounted (and OFF when it
/// leaves). Drop-in for stateless screens that need screenshot protection.
class SecureScope extends StatefulWidget {
  const SecureScope({super.key, required this.child});
  final Widget child;
  @override
  State<SecureScope> createState() => _SecureScopeState();
}

class _SecureScopeState extends State<SecureScope> {
  @override
  void initState() {
    super.initState();
    SecureScreen.enable();
  }

  @override
  void dispose() {
    SecureScreen.disable();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
