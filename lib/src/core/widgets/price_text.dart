import 'package:flutter/material.dart';

/// Consistent price display for products (course / test series / bundle), matching
/// the WEBSITE: when a discount is active the ORIGINAL price is shown struck
/// through next to the DISCOUNTED final price; otherwise just the price; free
/// products show "Free". The app must never show the raw price while the web
/// shows a discounted one — both read the same backend `final_price` /
/// `discount_active`.
class PriceText extends StatelessWidget {
  const PriceText({
    super.key,
    required this.price,
    required this.finalPrice,
    required this.discountActive,
    this.isFree = false,
    this.size = 14,
    this.color,
    this.alignEnd = false,
  });

  final String price;          // original
  final String finalPrice;     // discounted (what the student pays)
  final bool discountActive;
  final bool isFree;
  final double size;
  final Color? color;          // colour for the final/primary price
  final bool alignEnd;

  bool get _zero {
    final f = double.tryParse(finalPrice.replaceAll('₹', '').trim()) ?? 0;
    final p = double.tryParse(price.replaceAll('₹', '').trim()) ?? 0;
    return f == 0 && p == 0;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final primary = color ?? cs.primary;
    if (isFree || _zero) {
      return Text('Free',
          style: TextStyle(color: Colors.green.shade700, fontSize: size, fontWeight: FontWeight.w700));
    }
    final showStrike = discountActive && finalPrice != price;
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: alignEnd ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: [
        Text('₹$finalPrice',
            style: TextStyle(color: primary, fontSize: size, fontWeight: FontWeight.w800)),
        if (showStrike) ...[
          const SizedBox(width: 6),
          Text('₹$price',
              style: TextStyle(
                color: cs.onSurfaceVariant,
                fontSize: size - 2,
                fontWeight: FontWeight.w500,
                decoration: TextDecoration.lineThrough,
              )),
        ],
      ],
    );
  }
}
