import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/services/api_service.dart';
import '../../../core/theme/app_theme.dart';

class AttendanceDetailScreen extends ConsumerStatefulWidget {
  final String date;
  const AttendanceDetailScreen({super.key, required this.date});

  @override
  ConsumerState<AttendanceDetailScreen> createState() =>
      _AttendanceDetailScreenState();
}

class _AttendanceDetailScreenState
    extends ConsumerState<AttendanceDetailScreen> {
  late Future<List<dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = ref.read(apiServiceProvider).getAttendance(date: widget.date);
  }

  @override
  Widget build(BuildContext context) {
    String displayDate = widget.date;
    try {
      displayDate =
          DateFormat('dd MMM yyyy').format(DateTime.parse(widget.date));
    } catch (_) {}

    return Scaffold(
      appBar: AppBar(
        title: Text('Attendance — $displayDate'),
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => setState(_load)),
        ],
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final records = (snapshot.data ?? [])
              .map((e) => AttendanceRecord.fromJson(
                  Map<String, dynamic>.from(e as Map)))
              .toList();

          if (records.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.event_busy, size: 64, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text('No records for $displayDate',
                      style: TextStyle(color: Colors.grey.shade600)),
                ],
              ),
            );
          }

          // Group by subject
          final Map<String, List<AttendanceRecord>> grouped = {};
          for (final r in records) {
            final key = r.subjectName ?? 'General';
            (grouped[key] ??= []).add(r);
          }

          final present = records.where((r) => r.status == 'present').length;
          final fakeEye = records.where((r) => r.isFakeEye).length;

          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              // Summary card
              Card(
                color: AppTheme.primaryColor,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(displayDate,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 13)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _StatBlock(
                                label: 'Total',
                                value: records.length.toString(),
                                color: Colors.white),
                          ),
                          Expanded(
                            child: _StatBlock(
                                label: 'Present',
                                value: present.toString(),
                                color: Colors.greenAccent),
                          ),
                          Expanded(
                            child: _StatBlock(
                                label: 'Absent',
                                value: (records.length - present).toString(),
                                color: Colors.redAccent),
                          ),
                          Expanded(
                            child: _StatBlock(
                                label: 'Fake Eye',
                                value: fakeEye.toString(),
                                color: Colors.orangeAccent),
                          ),
                        ],
                      ),
                      if (records.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: present / records.length,
                            backgroundColor: Colors.white24,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                                Colors.greenAccent),
                            minHeight: 8,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${(present / records.length * 100).round()}% attendance rate',
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Grouped by subject
              ...grouped.entries.map((entry) {
                final subjectRecords = entry.value;
                final subPresent =
                    subjectRecords.where((r) => r.status == 'present').length;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          const Icon(Icons.book_outlined,
                              size: 18, color: AppTheme.primaryColor),
                          const SizedBox(width: 6),
                          Text(entry.key,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                  color: AppTheme.primaryColor)),
                          const SizedBox(width: 8),
                          Text(
                            '$subPresent/${subjectRecords.length} present',
                            style: TextStyle(
                                color: Colors.grey.shade500, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    ...subjectRecords.map(_RecordTile.new),
                    const SizedBox(height: 8),
                  ],
                );
              }),
            ],
          );
        },
      ),
    );
  }
}

class _StatBlock extends StatelessWidget {
  final String label, value;
  final Color color;
  const _StatBlock(
      {required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                color: color, fontSize: 20, fontWeight: FontWeight.bold)),
        Text(label,
            style: const TextStyle(color: Colors.white60, fontSize: 11)),
      ],
    );
  }
}

class _RecordTile extends StatelessWidget {
  final AttendanceRecord record;
  const _RecordTile(this.record);

  @override
  Widget build(BuildContext context) {
    final isPresent = record.status == 'present';
    final Color c = record.isFakeEye
        ? Colors.orange
        : (isPresent ? Colors.green : Colors.red);

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: c.withOpacity(0.3)),
      ),
      child: ListTile(
        dense: true,
        leading: CircleAvatar(
          radius: 18,
          backgroundColor: c.withOpacity(0.12),
          child: Icon(
            record.isFakeEye
                ? Icons.warning_amber
                : (isPresent ? Icons.check : Icons.close),
            color: c,
            size: 16,
          ),
        ),
        title: Text(record.studentName,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        subtitle: Text('Roll: ${record.rollNumber}',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              record.isFakeEye ? 'FAKE EYE' : record.status.toUpperCase(),
              style: TextStyle(
                  color: c, fontWeight: FontWeight.bold, fontSize: 10),
            ),
            Text('${(record.confidence * 100).round()}%',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 10)),
          ],
        ),
      ),
    );
  }
}
