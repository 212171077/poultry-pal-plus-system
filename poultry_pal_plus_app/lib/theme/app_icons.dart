import 'package:flutter/material.dart';

/// Shared domain symbols; the poultry glyphs are a bundled Fluent Emoji subset.
abstract final class AppIcons {
  static const chicken = IconData(0xe900, fontFamily: 'PoultryIcons');
  static const chick = IconData(0xe901, fontFamily: 'PoultryIcons');
  static const hatch = IconData(0xe902, fontFamily: 'PoultryIcons');
  static const eggs = Icons.egg_outlined;
  static const incubate = Icons.device_thermostat;
  static const transfer = Icons.swap_horiz;
  static const house = Icons.home_work_outlined;
}
