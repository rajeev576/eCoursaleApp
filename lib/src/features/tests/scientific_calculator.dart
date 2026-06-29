import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'player_theme.dart';

/// Native scientific calculator (GATE-style) shown from the test player when the
/// test's template enables it (`showCalculator`). Pure Flutter — no webview, works
/// offline. Supports + − × ÷, parentheses, decimals, percentage, and the common
/// scientific functions (sin/cos/tan, ln/log, √, x², xʸ, π, e, !, 1/x, ±).
///
/// It evaluates a normal infix expression with a small shunting-yard parser, so
/// it behaves like a real calculator (operator precedence + parentheses), not a
/// running accumulator. Trig is in DEGREES by default with a RAD/DEG toggle.
void showScientificCalculator(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _CalculatorSheet(),
  );
}

class _CalculatorSheet extends StatefulWidget {
  const _CalculatorSheet();
  @override
  State<_CalculatorSheet> createState() => _CalculatorSheetState();
}

class _CalculatorSheetState extends State<_CalculatorSheet> {
  String _expr = '';
  String _result = '';
  bool _radians = false; // DEG by default (GATE/most exams)

  void _input(String t) => setState(() {
        _expr += t;
        _live();
      });

  void _clear() => setState(() {
        _expr = '';
        _result = '';
      });

  void _back() => setState(() {
        if (_expr.isNotEmpty) _expr = _expr.substring(0, _expr.length - 1);
        _live();
      });

  void _live() {
    try {
      final v = _Evaluator(radians: _radians).eval(_expr);
      _result = _fmt(v);
    } catch (_) {
      _result = '';
    }
  }

  void _equals() => setState(() {
        try {
          final v = _Evaluator(radians: _radians).eval(_expr);
          _result = _fmt(v);
          _expr = _result;
        } catch (_) {
          _result = 'Error';
        }
      });

  String _fmt(double v) {
    if (v.isNaN || v.isInfinite) return 'Error';
    if (v == v.roundToDouble() && v.abs() < 1e15) {
      return v.toStringAsFixed(0);
    }
    var s = v.toStringAsFixed(8);
    s = s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
    return s;
  }

  @override
  Widget build(BuildContext context) {
    final p = PlayerPalette.of(context);
    return Container(
      decoration: BoxDecoration(
        color: p.bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // grab handle + title + close
              Row(children: [
                const SizedBox(width: 8),
                Text('Calculator',
                    style: TextStyle(color: p.text, fontWeight: FontWeight.w800, fontSize: 16)),
                const Spacer(),
                _RadDegToggle(
                  radians: _radians,
                  p: p,
                  onChanged: (r) => setState(() { _radians = r; _live(); }),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close, color: p.textMuted),
                ),
              ]),
              // display
              Container(
                width: double.infinity,
                margin: const EdgeInsets.symmetric(vertical: 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: p.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: p.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(_expr.isEmpty ? '0' : _expr,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: p.text, fontSize: 22, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(_result,
                        style: TextStyle(color: p.textMuted, fontSize: 16)),
                  ],
                ),
              ),
              _grid(p),
            ],
          ),
        ),
      ),
    );
  }

  Widget _grid(PlayerPalette p) {
    // function row(s) + number pad
    final rows = <List<_Btn>>[
      [_f('sin', 'sin('), _f('cos', 'cos('), _f('tan', 'tan('), _f('π', 'π'), _f('e', 'e')],
      [_f('ln', 'ln('), _f('log', 'log('), _f('√', '√('), _f('x²', '^2'), _f('xʸ', '^')],
      [_f('(', '('), _f(')', ')'), _f('!', '!'), _f('1/x', '1/('), _f('%', '%')],
      [_n('7'), _n('8'), _n('9'), _op('÷', '/'), _act('C', _clear, danger: true)],
      [_n('4'), _n('5'), _n('6'), _op('×', '*'), _act('⌫', _back)],
      [_n('1'), _n('2'), _n('3'), _op('−', '-'), _f('±', 'neg')],
      [_n('0'), _n('.', '.'), _op('+', '+'), _eq()],
    ];
    return Column(
      children: [
        for (final row in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                for (final b in row)
                  Expanded(
                    flex: b.flex,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: _key(p, b),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _key(PlayerPalette p, _Btn b) {
    Color bg;
    Color fg;
    switch (b.kind) {
      case _Kind.number:
        bg = p.surface; fg = p.text; break;
      case _Kind.op:
        bg = p.surfaceAlt; fg = p.accent; break;
      case _Kind.func:
        bg = p.surfaceAlt; fg = p.textMuted; break;
      case _Kind.danger:
        bg = PlayerPalette.incorrect.withValues(alpha: p.isDark ? 0.22 : 0.12);
        fg = PlayerPalette.incorrect; break;
      case _Kind.equals:
        bg = p.accent; fg = p.onAccent; break;
    }
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: b.onTap,
        child: Container(
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: b.kind == _Kind.number ? Border.all(color: p.border) : null,
          ),
          child: Text(b.label,
              style: TextStyle(color: fg, fontSize: 18, fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }

  // button factories
  _Btn _n(String label, [String? t]) => _Btn(label, _Kind.number, () => _input(t ?? label));
  _Btn _op(String label, String t) => _Btn(label, _Kind.op, () => _input(t));
  _Btn _f(String label, String t) => _Btn(label, _Kind.func, () {
        if (t == 'neg') {
          setState(() { _expr = _expr.startsWith('-') ? _expr.substring(1) : '-$_expr'; _live(); });
        } else {
          _input(t);
        }
      });
  _Btn _act(String label, VoidCallback fn, {bool danger = false}) =>
      _Btn(label, danger ? _Kind.danger : _Kind.func, fn);
  _Btn _eq() => _Btn('=', _Kind.equals, _equals, flex: 2);
}

enum _Kind { number, op, func, danger, equals }

class _Btn {
  _Btn(this.label, this.kind, this.onTap, {this.flex = 1});
  final String label;
  final _Kind kind;
  final VoidCallback onTap;
  final int flex;
}

class _RadDegToggle extends StatelessWidget {
  const _RadDegToggle({required this.radians, required this.onChanged, required this.p});
  final bool radians;
  final ValueChanged<bool> onChanged;
  final PlayerPalette p;
  @override
  Widget build(BuildContext context) {
    Widget seg(String label, bool isRad) {
      final on = radians == isRad;
      return GestureDetector(
        onTap: () => onChanged(isRad),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: on ? p.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(label,
              style: TextStyle(
                color: on ? p.onAccent : p.textMuted,
                fontWeight: FontWeight.w700, fontSize: 12)),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: p.border),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [seg('DEG', false), seg('RAD', true)]),
    );
  }
}

/// Tiny shunting-yard expression evaluator with scientific functions. Tokenises,
/// converts to RPN honouring precedence + right-assoc power, then evaluates.
class _Evaluator {
  _Evaluator({required this.radians});
  final bool radians;

  double eval(String input) {
    final tokens = _tokenize(_normalize(input));
    final rpn = _toRpn(tokens);
    return _evalRpn(rpn);
  }

  String _normalize(String s) {
    // Map display symbols + implicit things to a clean parseable form.
    return s
        .replaceAll('×', '*')
        .replaceAll('÷', '/')
        .replaceAll('−', '-')
        .replaceAll('π', '${math.pi}')
        .replaceAll('e', '${math.e}');
  }

  static const _funcs = {'sin', 'cos', 'tan', 'ln', 'log', '√', 'sqrt'};

  List<String> _tokenize(String s) {
    final out = <String>[];
    int i = 0;
    while (i < s.length) {
      final c = s[i];
      if (c == ' ') { i++; continue; }
      if (RegExp(r'[0-9.]').hasMatch(c)) {
        final m = RegExp(r'[0-9.]+').matchAsPrefix(s, i)!;
        out.add(m.group(0)!);
        i = m.end;
        continue;
      }
      // function names / √
      final fm = RegExp(r'(sin|cos|tan|ln|log|sqrt|√)').matchAsPrefix(s, i);
      if (fm != null) { out.add(fm.group(0)!); i = fm.end; continue; }
      if ('+-*/()^!%'.contains(c)) { out.add(c); i++; continue; }
      i++; // skip anything unexpected
    }
    return out;
  }

  int _prec(String op) {
    switch (op) {
      case '+': case '-': return 2;
      case '*': case '/': case '%': return 3;
      case '^': return 4;
      case '!': return 5;
      default: return 0;
    }
  }

  bool _rightAssoc(String op) => op == '^';

  List<String> _toRpn(List<String> tokens) {
    final out = <String>[];
    final ops = <String>[];
    for (final t in tokens) {
      if (double.tryParse(t) != null) {
        out.add(t);
      } else if (_funcs.contains(t)) {
        ops.add(t);
      } else if (t == '(') {
        ops.add(t);
      } else if (t == ')') {
        while (ops.isNotEmpty && ops.last != '(') {
          out.add(ops.removeLast());
        }
        if (ops.isNotEmpty) ops.removeLast(); // pop '('
        if (ops.isNotEmpty && _funcs.contains(ops.last)) out.add(ops.removeLast());
      } else if (t == '!') {
        out.add(t); // postfix
      } else {
        while (ops.isNotEmpty && ops.last != '(' &&
            (_prec(ops.last) > _prec(t) ||
                (_prec(ops.last) == _prec(t) && !_rightAssoc(t)))) {
          out.add(ops.removeLast());
        }
        ops.add(t);
      }
    }
    while (ops.isNotEmpty) {
      out.add(ops.removeLast());
    }
    return out;
  }

  double _evalRpn(List<String> rpn) {
    final st = <double>[];
    for (final t in rpn) {
      final n = double.tryParse(t);
      if (n != null) { st.add(n); continue; }
      if (t == '!') {
        final a = st.removeLast();
        st.add(_factorial(a));
        continue;
      }
      if (_funcs.contains(t)) {
        final a = st.removeLast();
        st.add(_func(t, a));
        continue;
      }
      final b = st.removeLast();
      final a = st.isNotEmpty ? st.removeLast() : 0;
      switch (t) {
        case '+': st.add(a + b); break;
        case '-': st.add(a - b); break;
        case '*': st.add(a * b); break;
        case '/': st.add(a / b); break;
        case '%': st.add(a % b); break;
        case '^': st.add(math.pow(a, b).toDouble()); break;
      }
    }
    return st.isEmpty ? double.nan : st.last;
  }

  double _func(String f, double a) {
    final x = radians ? a : a * math.pi / 180;
    switch (f) {
      case 'sin': return math.sin(x);
      case 'cos': return math.cos(x);
      case 'tan': return math.tan(x);
      case 'ln': return math.log(a);
      case 'log': return math.log(a) / math.ln10;
      case '√': case 'sqrt': return math.sqrt(a);
    }
    return a;
  }

  double _factorial(double a) {
    if (a < 0 || a != a.roundToDouble()) return double.nan;
    double r = 1;
    for (int i = 2; i <= a.toInt(); i++) {
      r *= i;
    }
    return r;
  }
}
