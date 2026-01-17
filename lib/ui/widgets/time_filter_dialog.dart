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
  final TextEditingController _rangeController =
      TextEditingController(); // Replaces valueController
  DateTime? _selectedDateTime;
  DateTime? _selectedDateTimeEnd; // Added end date

  String _displayStringForTimeFilterType(TimeFilterType type) {
    switch (type) {
      case TimeFilterType.newerThan:
        return 'Newer than';
      case TimeFilterType.olderThan:
        return 'Older than';
      case TimeFilterType.between:
        return 'Between';
      case TimeFilterType.inRange:
        return 'In Range';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Filter by Time'),
      content: SingleChildScrollView(
        // Added scroll for flexibility
        child: Column(
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
            const SizedBox(height: 16),
            if (_selectedType == TimeFilterType.inRange ||
                _selectedType == TimeFilterType.newerThan ||
                _selectedType == TimeFilterType.olderThan)
              Column(
                children: [
                  TextField(
                    controller: _rangeController,
                    decoration: const InputDecoration(
                        labelText: 'Range (e.g., "5 days", "last week")'),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8.0,
                    children:
                        ['15 minutes', '1 hour', '1 day', '7 days', '30 days']
                            .map((range) => FilterChip(
                                  label: Text(range),
                                  onSelected: (selected) {
                                    _rangeController.text = range;
                                  },
                                ))
                            .toList(),
                  ),
                ],
              ),
            const SizedBox(height: 16),
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
              child: Text(_selectedDateTime == null
                  ? 'Select Specific Time'
                  : 'Time: ${_selectedDateTime.toString()}'),
            ),
            if (_selectedType == TimeFilterType.between) ...[
              const SizedBox(height: 8),
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
                        _selectedDateTimeEnd = DateTime(
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
                child: Text(_selectedDateTimeEnd == null
                    ? 'Select End Time'
                    : 'End Time: ${_selectedDateTimeEnd.toString()}'),
              ),
            ]
          ],
        ),
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
            final range =
                _rangeController.text.isNotEmpty ? _rangeController.text : null;
            final timeFilter = TimeFilter(
              type: _selectedType,
              range: range,
              specificTime: _selectedDateTime,
              specificTimeEnd: _selectedDateTimeEnd,
            );

            String label;
            if (timeFilter.specificTime != null) {
              if (timeFilter.type == TimeFilterType.between &&
                  timeFilter.specificTimeEnd != null) {
                label =
                    'Time: Between ${timeFilter.specificTime} and ${timeFilter.specificTimeEnd}';
              } else {
                label =
                    'Time: ${_displayStringForTimeFilterType(timeFilter.type)} ${timeFilter.specificTime}';
              }
            } else {
              label =
                  'Time: ${_displayStringForTimeFilterType(timeFilter.type)} ${timeFilter.range ?? ""}';
            }

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
