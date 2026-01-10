class SessionRefreshSchedule {
  int intervalInMinutes;
  bool isEnabled;

  SessionRefreshSchedule({
    this.intervalInMinutes = 5,
    this.isEnabled = true,
  });

  factory SessionRefreshSchedule.fromJson(Map<String, dynamic> json) {
    return SessionRefreshSchedule(
      intervalInMinutes: json['intervalInMinutes'] as int? ?? 5,
      isEnabled: json['isEnabled'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'intervalInMinutes': intervalInMinutes,
      'isEnabled': isEnabled,
    };
  }
}
