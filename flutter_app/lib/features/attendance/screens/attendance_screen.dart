import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/services/api_service.dart';
import '../../../core/theme/app_theme.dart';

class AttendanceScreen extends ConsumerStatefulWidget {
  const AttendanceScreen({super.key});

  @override
  ConsumerState<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends ConsumerState<AttendanceScreen> {
  late Future<List<dynamic>> _attendanceFuture;
  late Future<List<SubjectResponse>> _subjectsFuture;
  DateTime _selectedDate = DateTime.now();
  int? _filterSubjectId;

  @override
  void initState() {
    super.initState();
    _subjectsFuture = ref.read(apiServiceProvider).getSubjects();
    _load();
  }

  void _load() {
    final api = ref.read(apiServiceProvider);
    _attendanceFuture = api.getAttendance(
      date: DateFormat('yyyy-MM-dd').format(_selectedDate),
      subjectId: _filterSubjectId,
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _load();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance'),
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => setState(_load)),
        ],
      ),
      body: Column(
        children: [
          _FilterBar(
            selectedDate: _selectedDate,
            selectedSubjectId: _filterSubjectId,
            subjectsFuture: _subjectsFuture,
            onDateTap: _pickDate,
            onSubjectChanged: (id) {
              setState(() {
                _filterSubjectId = id;
                _load();
              });
            },
          ),
          Expanded(
            child: FutureBuilder<List<dynamic>>(
              future: _attendanceFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline,
                            size: 48, color: Colors.red),
                        const SizedBox(height: 12),
                        Text('${snapshot.error}', textAlign: TextAlign.center),
                        ElevatedButton(
                            onPressed: () => setState(_load),
                            child: const Text('Retry')),
                      ],
                    ),
                  );
                }

                final records = (snapshot.data ?? [])
                    .map((e) => AttendanceRecord.fromJson(
                        Map<String, dynamic>.from(e as Map)))
                    .toList();

                if (records.isEmpty) {
                  return _EmptyAttendance(
                      date: DateFormat('dd MMM yyyy').format(_selectedDate));
                }

                // Summary header
                final present =
                    records.where((r) => r.status == 'present').length;
                final absent =
                    records.where((r) => r.status != 'present').length;
                final fakeEye = records.where((r) => r.isFakeEye).length;

                return Column(
                  children: [
                    _SummaryHeader(
                        present: present, absent: absent, fakeEye: fakeEye),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        itemCount: records.length,
                        itemBuilder: (context, i) {
                          final r = records[i];
                          return _AttendanceTile(
                            record: r,
                            onTap: () =>
                                context.push('/attendance/detail/${r.date}'),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  final DateTime selectedDate;
  final int? selectedSubjectId;
  final Future<List<SubjectResponse>> subjectsFuture;
  final VoidCallback onDateTap;
  final void Function(int?) onSubjectChanged;

  const _FilterBar({
    required this.selectedDate,
    required this.selectedSubjectId,
    required this.subjectsFuture,
    required this.onDateTap,
    required this.onSubjectChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      color: Colors.grey.shade50,
      child: Row(
        children: [
          OutlinedButton.icon(
            onPressed: onDateTap,
            icon: const Icon(Icons.calendar_today, size: 16),
            label: Text(DateFormat('dd MMM yyyy').format(selectedDate)),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: FutureBuilder<List<SubjectResponse>>(
              future: subjectsFuture,
              builder: (context, snap) {
                if (!snap.hasData) return const SizedBox.shrink();
                final subjects = snap.data!;
                return DropdownButtonFormField<int?>(
                  value: selectedSubjectId,
                  isDense: true,
                  decoration: InputDecoration(
                    hintText: 'All Subjects',
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                    fillColor: Colors.white,
                    filled: true,
                  ),
                  items: [
                    const DropdownMenuItem<int?>(
                        value: null, child: Text('All Subjects')),
                    ...subjects.map(
                      (s) => DropdownMenuItem<int?>(
                          value: s.id, child: Text(s.name)),
                    ),
                  ],
                  onChanged: onSubjectChanged,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryHeader extends StatelessWidget {
  final int present, absent, fakeEye;
  const _SummaryHeader(
      {required this.present, required this.absent, required this.fakeEye});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryColor.withOpacity(0.85),
            AppTheme.accentColor.withOpacity(0.7)
          ],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _Stat('Present', present, Colors.greenAccent),
          _Stat('Absent', absent, Colors.redAccent),
          _Stat('Fake Eye', fakeEye, Colors.orangeAccent),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  const _Stat(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('$value',
            style: TextStyle(
                color: color, fontSize: 22, fontWeight: FontWeight.bold)),
        Text(label,
            style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }
}

class _AttendanceTile extends StatelessWidget {
  final AttendanceRecord record;
  final VoidCallback onTap;
  const _AttendanceTile({required this.record, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isPresent = record.status == 'present';
    Color statusColor = isPresent ? Colors.green : Colors.red;
    if (record.isFakeEye) statusColor = Colors.orange;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: statusColor.withOpacity(0.3)),
      ),
      child: ListTile(
        onTap: onTap,
        dense: true,
        leading: CircleAvatar(
          radius: 20,
          backgroundColor: statusColor.withOpacity(0.12),
          child: Icon(
            record.isFakeEye
                ? Icons.warning_amber
                : (isPresent ? Icons.check : Icons.close),
            color: statusColor,
            size: 20,
          ),
        ),
        title: Text(record.studentName,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Text(
          'Roll: ${record.rollNumber}${record.subjectName != null ? " • ${record.subjectName}" : ""}'
          '${record.isFakeEye ? " • ⚠ Fake Eye" : ""}',
          style: TextStyle(
              fontSize: 12,
              color: record.isFakeEye ? Colors.orange : Colors.grey.shade600),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: statusColor.withOpacity(0.4)),
              ),
              child: Text(
                record.isFakeEye
                    ? 'FAKE EYE'
                    : (isPresent ? 'PRESENT' : 'ABSENT'),
                style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 10),
              ),
            ),
            const SizedBox(height: 2),
            Text('${(record.confidence * 100).round()}%',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

class _EmptyAttendance extends StatelessWidget {
  final String date;
  const _EmptyAttendance({required this.date});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_busy, size: 72, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text('No attendance records for $date',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 15)),
          const SizedBox(height: 8),
          Text('Iris attendance will appear here when scanned.',
              style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
        ],
      ),
    );
  }
}
