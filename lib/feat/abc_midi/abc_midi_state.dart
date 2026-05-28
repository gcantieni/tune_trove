enum AbcMidiStatus { idle, loading, playing, error }

class AbcMidiState {
  final AbcMidiStatus status;
  final String? message;

  const AbcMidiState({this.status = AbcMidiStatus.idle, this.message});

  bool get isActive =>
      status == AbcMidiStatus.playing || status == AbcMidiStatus.loading;
}
