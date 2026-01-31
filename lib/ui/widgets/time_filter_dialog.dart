import 'package:flutter/material.dart';
import '../../models/time_filter.dart';
import '../../models/search_filter.dart';

class TimeFilterDialog extends StatefulWidget {
  final TimeFilterType? initialType;
  final TimeFilterField? initialField;

  const TimeFilterDialog({super.key, this.initialType, this.initialField});

  @override
  State<TimeFilterDialog> createState() => _TimeFilterDialogState();
}

class _TimeFilterDialogState extends State<TimeFilterDialog> {
  late TimeFilterType _selectedType;
  late TimeFilterField _selectedField;
  final TextEditingController _rangeController =
      TextEditingController(); // Replaces valueController
  DateTime? _selectedDateTime;
  DateTime? _selectedDateTimeEnd; // Added end date

  @override
  void initState() {
    super.initState();
    _selectedType = widget.initialType ?? TimeFilterType.newerThan;
    _selectedField = widget.initialField ?? TimeFilterField.updated;
  }

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

  String _displayStringForTimeFilterField(TimeFilterField field) {
    switch (field) {
      case TimeFilterField.updated:
        return 'Updated';
      case TimeFilterField.created:
        return 'Created';
    }
  }

  Future<void> _pickSpecificTime() async {
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (selectedDate == null || !mounted) return;

    final selectedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(DateTime.now()),
    );
    if (selectedTime != null && mounted) {
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

  Future<void> _pickEndTime() async {
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (selectedDate == null || !mounted) return;

    final selectedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(DateTime.now()),
    );
    if (selectedTime != null && mounted) {
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

  Widget _buildRangeInput() {
    return Column(
      children: [
        TextField(
          controller: _rangeController,
          decoration: const InputDecoration(
            labelText: 'Range (e.g., "5 days", "last week")',
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8.0,
          children: ['15 minutes', '1 hour', '1 day', '7 days', '30 days']
              .map(
                (range) => FilterChip(
                  label: Text(range),
                  onSelected: (selected) {
                    _rangeController.text = range;
                  },
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  Widget _buildBetweenSection() {
    return Column(
      children: [
        const SizedBox(height: 8),
        ElevatedButton(
          onPressed: _pickEndTime,
          child: Text(
            _selectedDateTimeEnd == null
                ? 'Select End Time'
                : 'End Time: ${_selectedDateTimeEnd.toString()}',
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Filter by Time'),
      content: SingleChildScrollView(
        // Added scroll for flexibility
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                DropdownButton<TimeFilterField>(
                  value: _selectedField,
                  onChanged: (TimeFilterField? newValue) {
                    setState(() {
                      _selectedField = newValue!;
                    });
                  },
                  items: TimeFilterField.values.map((TimeFilterField field) {
                    return DropdownMenuItem<TimeFilterField>(
                      value: field,
                      child: Text(_displayStringForTimeFilterField(field)),
                    );
                  }).toList(),
                ),
                const SizedBox(width: 8),
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
              ],
            ),
            const SizedBox(height: 16),
            if (_selectedType == TimeFilterType.inRange ||
                _selectedType == TimeFilterType.newerThan ||
                _selectedType == TimeFilterType.olderThan)
              _buildRangeInput(),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _pickSpecificTime,
              child: Text(
                _selectedDateTime == null
                    ? 'Select Specific Time'
                    : 'Time: ${_selectedDateTime.toString()}',
              ),
            ),
            if (_selectedType == TimeFilterType.between) _buildBetweenSection(),
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
            final range = _rangeController.text.isNotEmpty
                ? _rangeController.text
                : null;
            final timeFilter = TimeFilter(
              type: _selectedType,
              range: range,
              specificTime: _selectedDateTime,
              specificTimeEnd: _selectedDateTimeEnd,
              field: _selectedField,
            );

            String fieldLabel = _displayStringForTimeFilterField(
              timeFilter.field,
            );
            String label;
            if (timeFilter.specificTime != null) {
              if (timeFilter.type == TimeFilterType.between &&
                  timeFilter.specificTimeEnd != null) {
                label =
                    '$fieldLabel: Between ${timeFilter.specificTime} and ${timeFilter.specificTimeEnd}';
              } else {
                label =
                    '$fieldLabel: ${_displayStringForTimeFilterType(timeFilter.type)} ${timeFilter.specificTime}';
              }
            } else {
              label =
                  '$fieldLabel: ${_displayStringForTimeFilterType(timeFilter.type)} ${timeFilter.range ?? ""}';
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
