import 'package:equatable/equatable.dart';

/// One service clock on one equipment item. Null intervals inherit the
/// kind's defaults; a clock with all three intervals null never fires.
class ServiceSchedule extends Equatable {
  final String id;
  final String equipmentId;
  final String serviceKindId;
  final int? intervalDays;
  final int? intervalDives;
  final double? intervalHours;
  final DateTime? anchorDate;
  final bool enabled;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ServiceSchedule({
    required this.id,
    required this.equipmentId,
    required this.serviceKindId,
    this.intervalDays,
    this.intervalDives,
    this.intervalHours,
    this.anchorDate,
    this.enabled = true,
    required this.createdAt,
    required this.updatedAt,
  });

  ServiceSchedule copyWith({
    String? id,
    String? equipmentId,
    String? serviceKindId,
    int? intervalDays,
    int? intervalDives,
    double? intervalHours,
    DateTime? anchorDate,
    bool? enabled,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ServiceSchedule(
      id: id ?? this.id,
      equipmentId: equipmentId ?? this.equipmentId,
      serviceKindId: serviceKindId ?? this.serviceKindId,
      intervalDays: intervalDays ?? this.intervalDays,
      intervalDives: intervalDives ?? this.intervalDives,
      intervalHours: intervalHours ?? this.intervalHours,
      anchorDate: anchorDate ?? this.anchorDate,
      enabled: enabled ?? this.enabled,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    equipmentId,
    serviceKindId,
    intervalDays,
    intervalDives,
    intervalHours,
    anchorDate,
    enabled,
    createdAt,
    updatedAt,
  ];
}
