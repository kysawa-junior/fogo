import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/geocoding_service.dart';

/// Busca geográfica REAL (Nominatim/OSM) — assíncrona com debounce.
final searchQueryProvider = NotifierProvider<SearchQueryNotifier, SearchState>(
  SearchQueryNotifier.new,
);

enum SearchStatus { idle, loading, ready, error }

class SearchState {
  const SearchState({
    this.query = '',
    this.status = SearchStatus.idle,
    this.results = const [],
    this.error,
  });

  final String query;
  final SearchStatus status;
  final List<GeoSearchResult> results;
  final String? error;
}

class SearchQueryNotifier extends Notifier<SearchState> {
  Timer? _debounce;

  @override
  SearchState build() {
    ref.onDispose(() {
      _debounce?.cancel();
    });
    return const SearchState();
  }

  void set(String query) {
    _debounce?.cancel();
    if (query.trim().length < 2) {
      state = SearchState(query: query);
      return;
    }
    state = SearchState(query: query, status: SearchStatus.loading);
    _debounce = Timer(const Duration(milliseconds: 450), _run);
  }

  Future<void> _run() async {
    try {
      final List<GeoSearchResult> results = await ref
          .read(geocodingServiceProvider)
          .search(state.query.trim());
      state = SearchState(
        query: state.query,
        status: SearchStatus.ready,
        results: results,
      );
    } on GeocodingException catch (e) {
      state = SearchState(
        query: state.query,
        status: SearchStatus.error,
        error: e.message,
      );
    }
  }

  void clear() {
    _debounce?.cancel();
    state = const SearchState();
  }
}
