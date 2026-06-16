import 'package:json_annotation/json_annotation.dart';

part 'sleep_data.g.dart';

enum SleepWakeState {
  UNKNOWN,
  WAKE,
  REM,
  NONREM12,
  NONREM3,
}

enum SleepRating {
  SLEPT_UNDEFINED,
  SLEPT_POORLY,
  SLEPT_SOMEWHAT_POORLY,
  SLEPT_NEITHER_POORLY_NOR_WELL,
  SLEPT_SOMEWHAT_WELL,
  SLEPT_WELL,
}

@JsonSerializable()
class PolarSleepAnalysisResult {
  final DateTime sleepStartTime;
  final DateTime sleepEndTime;
  final DateTime lastModified;
  final int sleepGoalMinutes;
  final List<SleepWakePhase> sleepWakePhases;
  final List<DateTime>? snoozeTime;
  final DateTime? alarmTime;
  final int sleepStartOffsetSeconds;
  final int sleepEndOffsetSeconds;
  final SleepRating? userSleepRating;
  final String? deviceId;
  final bool? batteryRanOut;
  final List<SleepCycle> sleepCycles;
  final OriginalSleepRange? originalSleepRange;
  final SleepSkinTemperatureResult? sleepSkinTemperatureResult;

  PolarSleepAnalysisResult({
    required this.sleepStartTime,
    required this.sleepEndTime,
    required this.lastModified,
    required this.sleepGoalMinutes,
    required this.sleepWakePhases,
    this.snoozeTime,
    this.alarmTime,
    required this.sleepStartOffsetSeconds,
    required this.sleepEndOffsetSeconds,
    this.userSleepRating,
    this.deviceId,
    this.batteryRanOut,
    required this.sleepCycles,
    this.originalSleepRange,
    this.sleepSkinTemperatureResult,
  });

  factory PolarSleepAnalysisResult.fromJson(Map<String, dynamic> json) =>
      _$PolarSleepAnalysisResultFromJson(json);

  Map<String, dynamic> toJson() => _$PolarSleepAnalysisResultToJson(this);
}

@JsonSerializable()
class SleepWakePhase {
  final int secondsFromSleepStart;
  final SleepWakeState state;

  SleepWakePhase({
    required this.secondsFromSleepStart,
    required this.state,
  });

  factory SleepWakePhase.fromJson(Map<String, dynamic> json) =>
      _$SleepWakePhaseFromJson(json);

  Map<String, dynamic> toJson() => _$SleepWakePhaseToJson(this);
}

@JsonSerializable()
class SleepCycle {
  final int secondsFromSleepStart;
  final double sleepDepthStart;

  SleepCycle({
    required this.secondsFromSleepStart,
    required this.sleepDepthStart,
  });

  factory SleepCycle.fromJson(Map<String, dynamic> json) =>
      _$SleepCycleFromJson(json);

  Map<String, dynamic> toJson() => _$SleepCycleToJson(this);
}

@JsonSerializable()
class OriginalSleepRange {
  final DateTime? startTime;
  final DateTime? endTime;

  OriginalSleepRange({
    this.startTime,
    this.endTime,
  });

  factory OriginalSleepRange.fromJson(Map<String, dynamic> json) =>
      _$OriginalSleepRangeFromJson(json);

  Map<String, dynamic> toJson() => _$OriginalSleepRangeToJson(this);
}

@JsonSerializable()
class SleepSkinTemperatureResult {
  final DateTime? sleepResultDate;
  final double sleepSkinTemperatureCelsius;
  final double deviationFromBaseLine;

  SleepSkinTemperatureResult({
    this.sleepResultDate,
    required this.sleepSkinTemperatureCelsius,
    required this.deviationFromBaseLine,
  });

  factory SleepSkinTemperatureResult.fromJson(Map<String, dynamic> json) =>
      _$SleepSkinTemperatureResultFromJson(json);

  Map<String, dynamic> toJson() => _$SleepSkinTemperatureResultToJson(this);
}
