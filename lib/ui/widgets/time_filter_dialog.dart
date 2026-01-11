import 'package:flutter/material.dart';
import '../../models/time_filter.dart';
import '../../models/search_filter.dart';

class TimeFilterDialog extends StatefulWidget {
  const TimeFilterDialog({super.key});

  @override
  State<TimeFilterDialog> createState() => _TimeFilterDialogState();
}

class _TimeFilterDialogState extends State<TimeFilterDialog> {
  TimeFilterType _selectedType = TimeFilterType.newerThan;
  final TextEditingController _valueController = TextEditingController();
  TimeFilterUnit _selectedUnit = TimeFilterUnit.days;
  DateTime? _selectedDateTime;

  String _displayStringForTimeFilterType(TimeFilterType type) {
    switch (type) {
      case TimeFilterType.newerThan:
        return 'Newer than';
      case TimeFilterType.olderThan:
        return 'Older than';
    }
  }

  String _displayStringForTimeFilterUnit(TimeFilterUnit unit) {
    return unit.toString().split('.').last;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Filter by Time'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButton<TimeFilterType>(
            value: _selectedType,
            onChanged: (TimeFilterType? newValue) {
              setState(() {
                _selectedType = newValue!;
              });
            },
            items: TimeFilterType.values.map((TimeFilterType type) {
              return DropdownMenuItem<TimeFilterType>(
                value: type,
                child: Text(_displayStringForTimeFilterType(type)),
              );
            }).toList(),
          ),
          TextField(
            controller: _valueController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Value'),
          ),
          DropdownButton<TimeFilterUnit>(
            value: _selectedUnit,
            onChanged: (TimeFilterUnit? newValue) {
              setState(() {
                _selectedUnit = newValue!;
              });
            },
            items: TimeFilterUnit.values.map((TimeFilterUnit unit) {
              return DropdownMenuItem<TimeFilterUnit>(
                value: unit,
                child: Text(_displayStringForTimeFilterUnit(unit)),
              );
            }).toList(),
          ),
          ElevatedButton(
            onPressed: () async {
              final selectedDate = await showDatePicker(
                context: context,
                initialDate: DateTime.now(),
                firstDate: DateTime(2000),
                lastDate: DateTime(2101),
              );
              if (selectedDate != null && context.mounted) {
                final selectedTime = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay.fromDateTime(DateTime.now()),
                );
                if (selectedTime != null) {
                  setState(() {
                    _selectedDateTime = DateTime(
                      selectedDate.year,
                      selectedDate.month,
                      selectedDate.day,
                      selectedTime.hour,
                      selectedTime.minute,
                    );
                  });
                }
              }
            },
            child: const Text('Select Specific Time'),
          ),
          if (_selectedDateTime != null)
            Text('Selected: ${_selectedDateTime.toString()}'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            final value = int.tryParse(_valueController.text) ?? 0;
            final timeFilter = TimeFilter(
              type: _selectedType,
              value: value,
              unit: _selectedUnit,
              specificTime: _selectedDateTime,
            );

            final label = timeFilter.specificTime != null
                ? 'Time: ${_displayStringForTimeFilterType(timeFilter.type)} ${timeFilter.specificTime!.toIso8601String()}'
                : 'Time: ${_displayStringForTimeFilterType(timeFilter.type)} ${timeFilter.value} ${_displayStringForTimeFilterUnit(timeFilter.unit)}';

            Navigator.of(context).pop(
              FilterToken(
                id: 'time_${DateTime.now().millisecondsSinceEpoch}',
                type: FilterType.time,
                label: label,
                value: timeFilter,
              ),
            );
          },
          child: const Text('Apply'),
        ),
      ],
    );
  }
}
