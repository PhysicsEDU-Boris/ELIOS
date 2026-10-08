class PorosityState {
  final double porosityPercent;

  const PorosityState({this.porosityPercent = 50.0});

  bool get isAnaerobic => porosityPercent < 25.0;

  PorosityState copyWith({double? porosityPercent}) {
    return PorosityState(porosityPercent: porosityPercent ?? this.porosityPercent);
  }
}
