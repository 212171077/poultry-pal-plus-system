enum GrowingPhase {
  NONE("Select growth phase"),
  BROODING_PHASE("Brooding Phase"),
  GROWING_REARING_PHASE("Growing Phase"),
  PRODUCTION_FINISHING_PHASE("Production or Finishing Phase");

  final String value;

  const GrowingPhase(this.value);

  static GrowingPhase fromValue(String value) {
    for (var phase in GrowingPhase.values) {
      if (phase.value == value || phase.name.toString() == value) {
        return phase;
      }
    }
    throw ArgumentError("Invalid phase value {$value}");
  }
}