import 'package:poultry_pal_plus_app/models/transition_coop.dart';

import 'growing_phase.dart';

class PhaseTransition {
  final GrowingPhase currentPhase;
  final GrowingPhase newPhase;
  final List<TransitionCoop> transitionCoops;

  PhaseTransition(
      {required this.currentPhase,
      required this.newPhase,
      required this.transitionCoops});

  factory PhaseTransition.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return PhaseTransition(
          currentPhase: GrowingPhase.NONE,
          newPhase: GrowingPhase.NONE,
          transitionCoops: []);
    }

    List<TransitionCoop> transCoops = [];
    if (json['transitionCoops'] != null) {
      transCoops = (json['transitionCoops'] as List?)
              ?.map((expJson) => TransitionCoop.fromJson(expJson))
              .toList() ??
          [];
    }

    return PhaseTransition(
      currentPhase: GrowingPhase.fromValue(json['currentPhase'] ?? 'NONE'),
      newPhase: GrowingPhase.fromValue(json['newPhase']),
      transitionCoops: transCoops,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'currentPhase': currentPhase,
      'newPhase': newPhase,
      'transitionCoops': transitionCoops,
    };
  }
}
