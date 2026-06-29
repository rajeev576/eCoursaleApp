import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';

/// Full "Daily Practice" list (web parity) — ALL daily practice sets, newest
/// first, with infinite scroll. Since a set is posted every day, the list grows
/// without bound, so it's grouped under MONTH headers and can be filtered by
/// status (attempted / pending), difficulty and subject. Filtering is applied to
/// the sets already loaded — scroll down to pull in older months, then filter.
/// Each set opens the native quiz player in DPP mode.
class DppListScreen extends ConsumerStatefulWidget {
  const DppListScreen({super.key});
  @override
  ConsumerState<DppListScreen> createState() => _DppListScreenState();
}

enum _StatusFilter { all, pending, attempted }

class _DppListScreenState extends ConsumerState<DppListScreen> {
  final _scroll = ScrollController();
  final _items = <Map<String, dynamic>>[];
  int _page = 1;
  int _streak = 0;
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  bool _error = false;

  // Filters (applied to loaded items).
  _StatusFilter _status = _StatusFilter.all;
  String _difficulty = ''; // '' = any
  String _subject = ''; // '' = any

  // Which month sections are expanded. Every month starts COLLAPSED — the user
  // taps a month header to reveal that month's sets. Toggles are remembered here.
  final _expanded = <String>{};

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _loadFirst();
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 400) _loadMore();
  }

  Future<void> _loadFirst() async {
    setState(() { _loading = true; _error = false; });
    try {
      final r = await ref.read(contentRepoProvider).dppPage(1);
      setState(() {
        _items..clear()..addAll(r.items);
        _streak = r.streak;
        _hasMore = r.hasMore;
        _page = 2;
        _loading = false;
      });
    } catch (_) {
      setState(() { _loading = false; _error = true; });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore || _loading) return;
    setState(() => _loadingMore = true);
    try {
      final r = await ref.read(contentRepoProvider).dppPage(_page);
      setState(() {
        _items.addAll(r.items);
        _hasMore = r.hasMore;
        _page++;
        _loadingMore = false;
      });
    } catch (_) {
      setState(() { _loadingMore = false; _hasMore = false; });
    }
  }

  // ── Filtering / grouping over the loaded items ─────────────────────────────
  bool _matches(Map<String, dynamic> d) {
    final attempted = d['attempted'] == true;
    if (_status == _StatusFilter.pending && attempted) return false;
    if (_status == _StatusFilter.attempted && !attempted) return false;
    if (_difficulty.isNotEmpty &&
        '${d['difficulty'] ?? ''}'.toLowerCase() != _difficulty.toLowerCase()) {
      return false;
    }
    if (_subject.isNotEmpty &&
        '${d['subject'] ?? ''}'.toLowerCase() != _subject.toLowerCase()) {
      return false;
    }
    return true;
  }

  /// Distinct non-empty subjects across loaded items (for the subject dropdown).
  List<String> get _subjects {
    final seen = <String>{};
    final out = <String>[];
    for (final d in _items) {
      final s = '${d['subject'] ?? ''}'.trim();
      if (s.isNotEmpty && seen.add(s.toLowerCase())) out.add(s);
    }
    out.sort();
    return out;
  }

  /// Distinct non-empty difficulties across loaded items.
  List<String> get _difficulties {
    final seen = <String>{};
    final out = <String>[];
    for (final d in _items) {
      final s = '${d['difficulty'] ?? ''}'.trim();
      if (s.isNotEmpty && seen.add(s.toLowerCase())) out.add(s);
    }
    return out;
  }

  /// Filtered items collapsed into a flat render list of (collapsible) month
  /// headers and item rows, newest-first. A month's item rows are emitted only
  /// when that month is expanded; the header always carries its set count.
  List<_Row> _buildRows() {
    // First pass: bucket matching items by month, preserving order.
    final order = <String>[];
    final byMonth = <String, List<Map<String, dynamic>>>{};
    for (final d in _items) {
      if (!_matches(d)) continue;
      final date = DateTime.tryParse((d['practice_date'] ?? '').toString());
      final month = date == null ? 'Undated' : _fmtMonth(date);
      if (!byMonth.containsKey(month)) {
        byMonth[month] = [];
        order.add(month);
      }
      byMonth[month]!.add(d);
    }
    // Second pass: header (+ items only if expanded).
    final rows = <_Row>[];
    for (final month in order) {
      final items = byMonth[month]!;
      final open = _expanded.contains(month);
      rows.add(_Row.header(month, count: items.length, expanded: open));
      if (open) {
        for (final d in items) {
          rows.add(_Row.item(d));
        }
      }
    }
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Practice'),
        actions: [
          if (_streak > 0)
            Center(child: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Row(children: [
                const Icon(Icons.local_fire_department, size: 18),
                const SizedBox(width: 3),
                Text('$_streak', style: const TextStyle(fontWeight: FontWeight.w700)),
              ]),
            )),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error && _items.isEmpty
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.wifi_off, size: 44, color: cs.onSurfaceVariant),
                  const SizedBox(height: 12),
                  Text('Couldn’t load.', style: TextStyle(color: cs.onSurfaceVariant)),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(onPressed: _loadFirst,
                      icon: const Icon(Icons.refresh), label: const Text('Retry')),
                ]))
              : _items.isEmpty
                  ? Center(child: Text('No daily practice yet.',
                      style: TextStyle(color: cs.onSurfaceVariant)))
                  : Column(children: [
                      _filterBar(cs),
                      Expanded(child: _list(cs)),
                    ]),
    );
  }

  Widget _filterBar(ColorScheme cs) {
    final difficulties = _difficulties;
    final subjects = _subjects;
    return Material(
      color: cs.surface,
      elevation: 0.5,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            // Status
            _chip('All', _status == _StatusFilter.all,
                () => setState(() => _status = _StatusFilter.all), cs),
            const SizedBox(width: 8),
            _chip('Pending', _status == _StatusFilter.pending,
                () => setState(() => _status = _StatusFilter.pending), cs),
            const SizedBox(width: 8),
            _chip('Done', _status == _StatusFilter.attempted,
                () => setState(() => _status = _StatusFilter.attempted), cs),
            if (difficulties.isNotEmpty) ...[
              _divider(cs),
              for (final d in difficulties) ...[
                _chip(d.toUpperCase(), _difficulty.toLowerCase() == d.toLowerCase(),
                    () => setState(() => _difficulty =
                        _difficulty.toLowerCase() == d.toLowerCase() ? '' : d), cs),
                const SizedBox(width: 8),
              ],
            ],
            if (subjects.isNotEmpty) ...[
              _divider(cs),
              _subjectDropdown(subjects, cs),
            ],
          ]),
        ),
      ),
    );
  }

  Widget _divider(ColorScheme cs) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Container(width: 1, height: 22, color: cs.outlineVariant),
      );

  Widget _chip(String label, bool selected, VoidCallback onTap, ColorScheme cs) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      labelStyle: TextStyle(
        fontSize: 12,
        color: selected ? cs.onPrimary : cs.onSurfaceVariant,
        fontWeight: FontWeight.w600,
      ),
      selectedColor: cs.primary,
      backgroundColor: cs.surfaceContainerHighest,
      side: BorderSide(color: selected ? cs.primary : cs.outlineVariant),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  Widget _subjectDropdown(List<String> subjects, ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _subject.isEmpty ? cs.outlineVariant : cs.primary),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _subject.isEmpty ? null : _subject,
          hint: Text('Subject',
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant, fontWeight: FontWeight.w600)),
          isDense: true,
          icon: Icon(Icons.arrow_drop_down, size: 18, color: cs.onSurfaceVariant),
          style: TextStyle(fontSize: 12, color: cs.onSurface, fontWeight: FontWeight.w600),
          items: [
            const DropdownMenuItem(value: '', child: Text('All subjects')),
            ...subjects.map((s) => DropdownMenuItem(value: s, child: Text(s))),
          ],
          onChanged: (v) => setState(() => _subject = v ?? ''),
        ),
      ),
    );
  }

  Widget _list(ColorScheme cs) {
    final rows = _buildRows();
    final showMoreSpinner = _hasMore;
    // With months collapsed the content can be too short to scroll, so the
    // scroll-listener never fires to pull older months. If there's more to load
    // and nothing yet fills the viewport, fetch the next page proactively.
    if (_hasMore && !_loadingMore && !_loading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (!_scroll.hasClients ||
            _scroll.position.maxScrollExtent <= 0) {
          _loadMore();
        }
      });
    }
    if (rows.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadFirst,
        child: ListView(
          controller: _scroll,
          children: [
            const SizedBox(height: 120),
            Center(child: Text('No sets match these filters.',
                style: TextStyle(color: cs.onSurfaceVariant))),
            if (_hasMore)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Center(child: Text('Scroll to load older sets…',
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant))),
              ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadFirst,
      child: ListView.builder(
        controller: _scroll,
        padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + MediaQuery.of(context).padding.bottom),
        itemCount: rows.length + (showMoreSpinner ? 1 : 0),
        itemBuilder: (_, i) {
          if (i >= rows.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: SizedBox(
                  height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2))),
            );
          }
          final row = rows[i];
          if (row.isHeader) {
            return _monthHeader(row, topPad: i == 0 ? 0 : 8, cs: cs);
          }
          return _setTile(row.data!, cs);
        },
      ),
    );
  }

  Widget _monthHeader(_Row row, {required double topPad, required ColorScheme cs}) {
    final month = row.month!;
    final open = row.expanded;
    return Padding(
      padding: EdgeInsets.only(top: topPad, bottom: 8),
      child: Material(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => setState(() {
            if (!_expanded.remove(month)) _expanded.add(month);
          }),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(children: [
              AnimatedRotation(
                turns: open ? 0.25 : 0,
                duration: const Duration(milliseconds: 150),
                child: Icon(Icons.chevron_right, size: 20, color: cs.onSurfaceVariant),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(month,
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        letterSpacing: 0.3,
                        color: cs.onSurface)),
              ),
              Text('${row.count} set${row.count == 1 ? '' : 's'}',
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _setTile(Map<String, dynamic> d, ColorScheme cs) {
    final qc = (d['question_count'] ?? 0) as int;
    final attempted = d['attempted'] == true;
    final date = DateTime.tryParse((d['practice_date'] ?? '').toString());
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: cs.primary.withValues(alpha: 0.12),
          child: Icon(attempted ? Icons.check : Icons.bolt, color: cs.primary),
        ),
        title: Text((d['title'] ?? '') as String,
            maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Text([
          if (date != null) _fmtDate(date),
          '$qc Q',
          if ((d['subject'] ?? '').toString().isNotEmpty) '${d['subject']}',
          if ((d['difficulty'] ?? '').toString().isNotEmpty)
            '${d['difficulty']}'.toUpperCase(),
        ].join('  ·  '),
            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push('/dpp/${d['slug']}/play',
            extra: {'title': d['title']}),
      ),
    );
  }

  String _fmtDate(DateTime d) {
    const m = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${d.day} ${m[d.month - 1]}';
  }

  String _fmtMonth(DateTime d) {
    const m = ['January','February','March','April','May','June','July',
      'August','September','October','November','December'];
    final now = DateTime.now();
    final label = '${m[d.month - 1]} ${d.year}';
    return d.year == now.year ? m[d.month - 1] : label;
  }
}

/// One rendered row: either a (collapsible) month header or a DPP set.
class _Row {
  _Row.header(this.month, {this.count = 0, this.expanded = false}) : data = null;
  _Row.item(this.data)
      : month = null,
        count = 0,
        expanded = false;
  final String? month;
  final int count;
  final bool expanded;
  final Map<String, dynamic>? data;
  bool get isHeader => month != null;
}
