enum HabitType { healthy, unhealthy }

enum HabitValueType { boolean, integer }

class Habit {
  Habit({
    required this.id,
    required this.name,
    required this.type,
    this.description,
    this.defaultOn = true,
    this.icon,
    this.value,
    this.valueType = HabitValueType.boolean,
    this.lastCheckIn,
  });

  factory Habit.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String? ?? 'healthy';
    final valueType = json['value_type'] as String? ?? 'boolean';
    return Habit(
      id: json['id'] as String,
      name: json['name'] as String,
      type: type == 'unhealthy' ? HabitType.unhealthy : HabitType.healthy,
      description: json['description'] as String?,
      defaultOn: json['default_on'] as bool? ?? true,
      icon: json['icon'] as String?,
      value: json['value'],
      valueType: valueType == 'integer'
          ? HabitValueType.integer
          : HabitValueType.boolean,
      lastCheckIn: json['last_check_in'] is String
          ? DateTime.tryParse(json['last_check_in'] as String)
          : null,
    );
  }

  final String id;
  final String name;
  final HabitType type;
  final String? description;
  final bool defaultOn;
  final String? icon;
  final Object? value;
  final HabitValueType valueType;
  final DateTime? lastCheckIn;

  bool get boolValue {
    if (value is bool) {
      return value as bool;
    }
    if (value is num) {
      return (value as num) > 0;
    }
    return false;
  }

  Habit copyWith({Object? value, DateTime? lastCheckIn}) {
    return Habit(
      id: id,
      name: name,
      type: type,
      description: description,
      defaultOn: defaultOn,
      icon: icon,
      value: value ?? this.value,
      valueType: valueType,
      lastCheckIn: lastCheckIn ?? this.lastCheckIn,
    );
  }
}
