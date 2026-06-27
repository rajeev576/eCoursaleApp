import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

import '../../core/providers.dart';

/// Native in-app Razorpay checkout (Testbook-style). Opens the Razorpay payment
/// sheet INSIDE the app — no webview, no browser. Money goes to the school's own
/// Razorpay account.
///
/// Usage:
///   final ok = await NativeCheckout(ref).buyItem(context, 'course', uuid);
///   // or buyCart(context)
class NativeCheckout {
  NativeCheckout(this.ref);
  final WidgetRef ref;

  Razorpay? _razorpay;
  BuildContext? _ctx;
  void Function(bool success)? _done;

  Future<void> buyItem(BuildContext context, String itemType, String uuid) =>
      _start(context, {'kind': 'item', 'item_type': itemType, 'uuid': uuid});

  Future<void> buyCart(BuildContext context) =>
      _start(context, {'kind': 'cart'});

  Future<void> buyPass(BuildContext context, int planMonths) =>
      _start(context, {'kind': 'pass', 'plan_months': planMonths});

  Future<void> _start(BuildContext context, Map<String, dynamic> body) async {
    _ctx = context;
    // 1) Create the order on the backend (amount computed server-side).
    showDialog(
      context: context, barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    Map<String, dynamic> order;
    try {
      final res = await ref.read(apiClientProvider).raw.post('/checkout/order/', data: body);
      order = Map<String, dynamic>.from(res.data as Map);
    } catch (e) {
      if (context.mounted) Navigator.of(context).maybePop();
      _snack(context, _errMsg(e));
      return;
    }
    if (context.mounted) Navigator.of(context).maybePop();

    // 2) Open the native Razorpay sheet.
    _razorpay = Razorpay()
      ..on(Razorpay.EVENT_PAYMENT_SUCCESS, _onSuccess)
      ..on(Razorpay.EVENT_PAYMENT_ERROR, _onError)
      ..on(Razorpay.EVENT_EXTERNAL_WALLET, _onWallet);

    final prefill = Map<String, dynamic>.from(order['prefill'] ?? {});
    final options = {
      'key': order['key_id'],
      'amount': order['amount'],
      'currency': order['currency'] ?? 'INR',
      'name': order['name'] ?? '',
      'order_id': order['order_id'],
      'prefill': {
        'name': prefill['name'] ?? '',
        'email': prefill['email'] ?? '',
        'contact': prefill['contact'] ?? '',
      },
    };
    try {
      _razorpay!.open(options);
    } catch (e) {
      _snack(context, 'Could not open payment.');
      _cleanup();
    }
  }

  Future<void> _onSuccess(PaymentSuccessResponse r) async {
    final ctx = _ctx;
    if (ctx != null && ctx.mounted) {
      showDialog(context: ctx, barrierDismissible: false,
          builder: (_) => const Center(child: CircularProgressIndicator()));
    }
    bool ok = false;
    try {
      final res = await ref.read(apiClientProvider).raw.post('/checkout/verify/', data: {
        'razorpay_order_id': r.orderId,
        'razorpay_payment_id': r.paymentId,
        'razorpay_signature': r.signature,
      });
      ok = (res.data is Map) && (res.data['success'] == true);
    } catch (_) {
      ok = false;
    }
    if (ctx != null && ctx.mounted) {
      Navigator.of(ctx).maybePop();
      _snack(ctx, ok ? 'Payment successful! You are enrolled.' : 'Payment received — confirming. Check My Orders.');
    }
    // Refresh content so enrolled state updates.
    ref.invalidate(cartProvider);
    ref.invalidate(ordersProvider);
    ref.invalidate(coursesProvider);
    _cleanup();
  }

  void _onError(PaymentFailureResponse r) {
    final ctx = _ctx;
    if (ctx != null && ctx.mounted) {
      _snack(ctx, r.code == Razorpay.PAYMENT_CANCELLED
          ? 'Payment cancelled.'
          : 'Payment failed. Please try again.');
    }
    _cleanup();
  }

  void _onWallet(ExternalWalletResponse r) {/* no-op */}

  void _cleanup() {
    try {
      _razorpay?.clear();
    } catch (_) {}
    _razorpay = null;
  }

  void _snack(BuildContext context, String msg) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  String _errMsg(Object e) {
    final s = e.toString();
    if (s.contains('not set up')) return 'Payments are not set up for this institute yet.';
    if (s.contains('empty')) return 'Your cart is empty.';
    if (s.contains('own')) return 'You already own this.';
    return 'Could not start checkout. Please try again.';
  }
}
