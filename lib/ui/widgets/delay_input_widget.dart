import 'package.flutter/material.dart';

enum DelayUnit { ms, s, min }

class DelayInputWidget extends StatefulWidget {
  final Duration initialDelay;
  final DelayUnit initialUnit;
  final Function(Duration, DelayUnit) onDelayChanged;
  final String? label;
  final bool isDense;

  const DelayInputWidget({
    super.key,
    required this.initialDelay,
    required this.initialUnit,
    required this.onDelayChanged,
    this.label,
    this.isDense = false,
  });

  @override
  State<DelayInputWidget> createState() => _DelayInputWidgetState();
}

class _DelayInputWidgetState extends State<DelayInputWidget> {
  final TextEditingController _controller = TextEditingController();
  late DelayUnit _unit;

  @override
  void initState() {
    super.initState();
    _unit = widget.initialUnit;
    _updateControllerFromDuration(widget.initialDelay, widget.initialUnit);
  }

  void _updateControllerFromDuration(Duration duration, DelayUnit unit) {
    switch (unit) {
      case DelayUnit.ms:
        _controller.text = duration.inMilliseconds.toString();
        break;
      case DelayUnit.s:
        _controller.text = duration.inSeconds.toString();
        break;
      case DelayUnit.min:
        _controller.text = duration.inMinutes.toString();
        break;
    }
  }

  void _notifyParent() {
    final value = int.tryParse(_controller.text) ?? 0;
    Duration newDuration;
    switch (_unit) {
      case DelayUnit.ms:
        newDuration = Duration(milliseconds: value);
        break;
      case DelayUnit.s:
        newDuration = Duration(seconds: value);
        break;
      case DelayUnit.min:
        newDuration = Duration(minutes: value);
        break;
    }
    widget.onDelayChanged(newDuration, _unit);
  }

  @override
  Widget build(BuildContext context) {
    final textStyle = TextStyle(fontSize: widget.isDense ? 12 : 14);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.label != null)
          Text(
            widget.label!,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 80,
              child: TextField(
                controller: _controller,
                decoration: InputDecoration(
                  isDense: widget.isDense,
                  border: const OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                style: textStyle,
                onChanged: (_) => _notifyParent(),
              ),
            ),
            const SizedBox(width: 8),
            DropdownButton<DelayUnit>(
              value: _unit,
              isDense: widget.isDense,
              underline: const SizedBox(),
              items: DelayUnit.values.map((unit) {
                return DropdownMenuItem(
                  value: unit,
                  child: Text(unit.name, style: textStyle),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() => _unit = val);
                  _notifyParent();
                }
              },
            ),
          ],
        ),
      ],
    );
  }
}
