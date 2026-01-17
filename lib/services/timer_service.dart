import 'dart:async';
import 'package:flutter/foundation.dart';

class TimerService extends ChangeNotifier {
  Timer? _timer;
  final Duration interval;

  TimerService({this.interval = const Duration(minutes: 1)}) {
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(interval, (_) {
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
