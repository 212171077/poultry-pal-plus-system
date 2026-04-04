enum BoxSize {
    NONE("Select box size"),
    SIX_EGGS_BOX("6 Eggs Box"),
    TWELVE_EGGS_BOX("12 Eggs Box"),
    EIGHTEEN_EGGS_BOX("18 Eggs Box"),
    THIRTY_EGGS_BOX("30 Eggs Box");

    final String value;

    const BoxSize(this.value);

    static BoxSize fromValue(String value) {
        for (var phase in BoxSize.values) {
            if (phase.value == value || phase.name.toString() == value) {
                return phase;
            }
        }
        throw ArgumentError("Invalid egg box size value {$value}");
    }
}