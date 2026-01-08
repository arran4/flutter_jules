import 'package:uuid/uuid.dart';
import '../services/settings_provider.dart';

class RefreshSchedule {
  String id;
  String name;
  int intervalInMinutes;
  ListRefreshPolicy refreshPolicy;
  bool isEnabled;

  RefreshSchedule({
    String? id,
    required this.name,
    required this.intervalInMinutes,
    required this.refreshPolicy,
    this.isEnabled = true,
  }) : id = id ?? const Uuid().v4();

  factory RefreshSchedule.fromJson(Map<String, dynamic> json) {
    return RefreshSchedule(
      id: json['id'],
      name: json['name'],
      intervalInMinutes: json['intervalInMinutes'],
      refreshPolicy: ListRefreshPolicy.values[json['refreshPolicy']],
      isEnabled: json['isEnabled'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'intervalInMinutes': intervalInMinutes,
      'refreshPolicy': refreshPolicy.index,
      'isEnabled': isEnabled,
    };
  }
}
