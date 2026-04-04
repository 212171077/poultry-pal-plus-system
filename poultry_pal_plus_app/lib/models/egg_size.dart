enum EggSize {
    NONE("Select egg size"),
    PEEWEE("Peewee"),
    SMALL("Small"),
    MEDIUM("Medium"),
    LARGE("Large"),
    EXTRA_LARGE("Extra-Large"),
    JUMBO("Jumbo"),
    MIX_SIZE("Mix Size");

    final String value;

    const EggSize(this.value);

    static EggSize fromValue(String value) {
        for (var phase in EggSize.values) {
            if (phase.value == value || phase.name.toString() == value) {
                return phase;
            }
        }
        throw ArgumentError("Invalid egg size value {$value}");
    }
}