import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tune_trove/feat/music_kit/music_kit_models.dart';
import 'package:tune_trove/feat/music_kit/music_kit_service.dart';

class MusicKitState {
  final String authStatus;
  final List<MusicKitSearchResult> searchResults;
  final bool isSearching;

  const MusicKitState({
    required this.authStatus,
    this.searchResults = const [],
    this.isSearching = false,
  });

  MusicKitState copyWith({
    String? authStatus,
    List<MusicKitSearchResult>? searchResults,
    bool? isSearching,
  }) => MusicKitState(
    authStatus: authStatus ?? this.authStatus,
    searchResults: searchResults ?? this.searchResults,
    isSearching: isSearching ?? this.isSearching,
  );
}

class MusicKitNotifier extends AsyncNotifier<MusicKitState> {
  @override
  Future<MusicKitState> build() async {
    final service = ref.watch(musicKitServiceProvider);
    final authStatus = await service.authorizationStatus();
    return MusicKitState(authStatus: authStatus);
  }

  Future<void> authorize() async {
    final status = await ref.read(musicKitServiceProvider).authorize();
    final current = state.value;
    if (current != null) {
      state = AsyncData(current.copyWith(authStatus: status));
    }
  }

  Future<void> search(String query) async {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(current.copyWith(isSearching: true, searchResults: []));
    try {
      final service = ref.read(musicKitServiceProvider);
      if (state.value!.authStatus != 'authorized') {
        final status = await service.authorize();
        state = AsyncData(state.value!.copyWith(authStatus: status));
        if (status != 'authorized') {
          state = AsyncData(state.value!.copyWith(isSearching: false));
          return;
        }
      }
      final results = await service.search(query);
      state = AsyncData(
        state.value!.copyWith(isSearching: false, searchResults: results),
      );
    } catch (_) {
      state = AsyncData(state.value!.copyWith(isSearching: false));
      rethrow;
    }
  }
}

final musicKitProvider = AsyncNotifierProvider<MusicKitNotifier, MusicKitState>(
  MusicKitNotifier.new,
);
