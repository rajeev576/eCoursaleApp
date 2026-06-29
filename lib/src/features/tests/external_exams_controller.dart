import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../data/models/models.dart';
import '../../data/repositories/content_repository.dart';

/// Infinite-scroll state for the external-exams list. Loads page 1 instantly,
/// then pages in the rest as the user scrolls — so a platform school with MANY
/// exams stays smooth and no exam past page 1 is ever hidden (the earlier bug).
class ExternalExamsState {
  const ExternalExamsState({
    this.items = const [],
    this.loading = false,
    this.loadingMore = false,
    this.hasMore = true,
    this.error = false,
    this.nextPage = 1,
  });

  final List<ExternalExam> items;
  final bool loading;       // first load (no items yet)
  final bool loadingMore;   // appending a further page
  final bool hasMore;
  final bool error;
  final int nextPage;

  ExternalExamsState copyWith({
    List<ExternalExam>? items,
    bool? loading,
    bool? loadingMore,
    bool? hasMore,
    bool? error,
    int? nextPage,
  }) =>
      ExternalExamsState(
        items: items ?? this.items,
        loading: loading ?? this.loading,
        loadingMore: loadingMore ?? this.loadingMore,
        hasMore: hasMore ?? this.hasMore,
        error: error ?? this.error,
        nextPage: nextPage ?? this.nextPage,
      );
}

class ExternalExamsController extends StateNotifier<ExternalExamsState> {
  ExternalExamsController(this._repo) : super(const ExternalExamsState()) {
    refresh();
  }
  final ContentRepository _repo;

  Future<void> refresh() async {
    state = const ExternalExamsState(loading: true);
    try {
      final PagedResult<ExternalExam> p = await _repo.externalExamsPage(page: 1);
      state = ExternalExamsState(
        items: p.items, loading: false, hasMore: p.hasMore, nextPage: 2);
    } catch (_) {
      state = const ExternalExamsState(loading: false, error: true, hasMore: false);
    }
  }

  Future<void> loadMore() async {
    if (state.loading || state.loadingMore || !state.hasMore) return;
    state = state.copyWith(loadingMore: true);
    try {
      final p = await _repo.externalExamsPage(page: state.nextPage);
      state = state.copyWith(
        items: [...state.items, ...p.items],
        loadingMore: false,
        hasMore: p.hasMore,
        nextPage: state.nextPage + 1,
      );
    } catch (_) {
      // Keep what we have; stop trying so we don't spin on a flaky page.
      state = state.copyWith(loadingMore: false, hasMore: false);
    }
  }
}

final externalExamsControllerProvider =
    StateNotifierProvider.autoDispose<ExternalExamsController, ExternalExamsState>(
        (ref) => ExternalExamsController(ref.watch(contentRepoProvider)));
