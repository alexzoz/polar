// GENERATED CODE - DO NOT MODIFY BY HAND

// ignore_for_file: document_ignores, unnecessary_cast, require_trailing_commas, rexios_lints/not_null_assertion

part of 'sleep_data.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PolarSleepAnalysisResult _$PolarSleepAnalysisResultFromJson(
        Map<String, dynamic> json) =>
    PolarSleepAnalysisResult(
      sleepStartTime: DateTime.parse(json['sleepStartTime'] as String),
      sleepEndTime: DateTime.parse(json['sleepEndTime'] as String),
      lastModified: DateTime.parse(json['lastModified'] as String),
      sleepGoalMinutes: (json['sleepGoalMinutes'] as num).toInt(),
      sleepWakePhases: (json['sleepWakePhases'] as List<dynamic>)
          .map((e) => SleepWakePhase.fromJson(e as Map<String, dynamic>))
          .toList(),
      snoozeTime: (json['snoozeTime'] as List<dynamic>?)
          ?.map((e) => DateTime.parse(e as String))
          .toList(),
      alarmTime: json['alarmTime'] == null
          ? null
          : DateTime.parse(json['alarmTime'] as String),
      sleepStartOffsetSeconds: (json['sleepStartOffsetSeconds'] as num).toInt(),
      sleepEndOffsetSeconds: (json['sleepEndOffsetSeconds'] as num).toInt(),
      userSleepRating:
          $enumDecodeNullable(_$SleepRatingEnumMap, json['userSleepRating']),
      deviceId: json['deviceId'] as String?,
      batteryRanOut: json['batteryRanOut'] as bool?,
      sleepCycles: (json['sleepCycles'] as List<dynamic>)
          .map((e) => SleepCycle.fromJson(e as Map<String, dynamic>))
          .toList(),
      originalSleepRange: json['originalSleepRange'] == null
          ? null
          : OriginalSleepRange.fromJson(
              json['originalSleepRange'] as Map<String, dynamic>),
      sleepSkinTemperatureResult: json['sleepSkinTemperatureResult'] == null
          ? null
          : SleepSkinTemperatureResult.fromJson(
              json['sleepSkinTemperatureResult'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$PolarSleepAnalysisResultToJson(
        PolarSleepAnalysisResult instance) =>
    <String, dynamic>{
      'sleepStartTime': instance.sleepStartTime.toIso8601String(),
      'sleepEndTime': instance.sleepEndTime.toIso8601String(),
      'lastModified': instance.lastModified.toIso8601String(),
      'sleepGoalMinutes': instance.sleepGoalMinutes,
      'sleepWakePhases': instance.sleepWakePhases,
      'snoozeTime':
          instance.snoozeTime?.map((e) => e.toIso8601String()).toList(),
      'alarmTime': instance.alarmTime?.toIso8601String(),
      'sleepStartOffsetSeconds': instance.sleepStartOffsetSeconds,
      'sleepEndOffsetSeconds': instance.sleepEndOffsetSeconds,
      'userSleepRating': _$SleepRatingEnumMap[instance.userSleepRating],
      'deviceId': instance.deviceId,
      'batteryRanOut': instance.batteryRanOut,
      'sleepCycles': instance.sleepCycles,
      'originalSleepRange': instance.originalSleepRange,
      'sleepSkinTemperatureResult': instance.sleepSkinTemperatureResult,
    };

const _$SleepRatingEnumMap = {
  SleepRating.SLEPT_UNDEFINED: 'SLEPT_UNDEFINED',
  SleepRating.SLEPT_POORLY: 'SLEPT_POORLY',
  SleepRating.SLEPT_SOMEWHAT_POORLY: 'SLEPT_SOMEWHAT_POORLY',
  SleepRating.SLEPT_NEITHER_POORLY_NOR_WELL: 'SLEPT_NEITHER_POORLY_NOR_WELL',
  SleepRating.SLEPT_SOMEWHAT_WELL: 'SLEPT_SOMEWHAT_WELL',
  SleepRating.SLEPT_WELL: 'SLEPT_WELL',
};

SleepWakePhase _$SleepWakePhaseFromJson(Map<String, dynamic> json) =>
    SleepWakePhase(
      secondsFromSleepStart: (json['secondsFromSleepStart'] as num).toInt(),
      state: $enumDecode(_$SleepWakeStateEnumMap, json['state']),
    );

Map<String, dynamic> _$SleepWakePhaseToJson(SleepWakePhase instance) =>
    <String, dynamic>{
      'secondsFromSleepStart': instance.secondsFromSleepStart,
      'state': _$SleepWakeStateEnumMap[instance.state]!,
    };

const _$SleepWakeStateEnumMap = {
  SleepWakeState.UNKNOWN: 'UNKNOWN',
  SleepWakeState.WAKE: 'WAKE',
  SleepWakeState.REM: 'REM',
  SleepWakeState.NONREM12: 'NONREM12',
  SleepWakeState.NONREM3: 'NONREM3',
};

SleepCycle _$SleepCycleFromJson(Map<String, dynamic> json) => SleepCycle(
      secondsFromSleepStart: (json['secondsFromSleepStart'] as num).toInt(),
      sleepDepthStart: (json['sleepDepthStart'] as num).toDouble(),
    );

Map<String, dynamic> _$SleepCycleToJson(SleepCycle instance) =>
    <String, dynamic>{
      'secondsFromSleepStart': instance.secondsFromSleepStart,
      'sleepDepthStart': instance.sleepDepthStart,
    };

OriginalSleepRange _$OriginalSleepRangeFromJson(Map<String, dynamic> json) =>
    OriginalSleepRange(
      startTime: json['startTime'] == null
          ? null
          : DateTime.parse(json['startTime'] as String),
      endTime: json['endTime'] == null
          ? null
          : DateTime.parse(json['endTime'] as String),
    );

Map<String, dynamic> _$OriginalSleepRangeToJson(OriginalSleepRange instance) =>
    <String, dynamic>{
      'startTime': instance.startTime?.toIso8601String(),
      'endTime': instance.endTime?.toIso8601String(),
    };

SleepSkinTemperatureResult _$SleepSkinTemperatureResultFromJson(
        Map<String, dynamic> json) =>
    SleepSkinTemperatureResult(
      sleepResultDate: json['sleepResultDate'] == null
          ? null
          : DateTime.parse(json['sleepResultDate'] as String),
      sleepSkinTemperatureCelsius:
          (json['sleepSkinTemperatureCelsius'] as num).toDouble(),
      deviationFromBaseLine: (json['deviationFromBaseLine'] as num).toDouble(),
    );

Map<String, dynamic> _$SleepSkinTemperatureResultToJson(
        SleepSkinTemperatureResult instance) =>
    <String, dynamic>{
      'sleepResultDate': instance.sleepResultDate?.toIso8601String(),
      'sleepSkinTemperatureCelsius': instance.sleepSkinTemperatureCelsius,
      'deviationFromBaseLine': instance.deviationFromBaseLine,
    };
