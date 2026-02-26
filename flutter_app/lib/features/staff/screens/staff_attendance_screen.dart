import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/services/api_service.dart';
import '../../../core/theme/app_theme.dart';

class StaffAttendanceScreen extends ConsumerStatefulWidget {
  final int staffId;
  const StaffAttendanceScreen({super.key, required this.staffId});

  @override
  ConsumerState<StaffAttendanceScreen> createState() =>
      _StaffAttendanceScreenState();
}

class _StaffAttendanceScreenState extends ConsumerState<StaffAttendanceScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late Future<List<dynamic>> _attendanceFuture;
  late Future<StaffResponse> _staffFuture;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  void _loadData() {
    final api = ref.read(apiServiceProvider);
    _staffFuture = api.getStaffMember(widget.staffId);
    _attendanceFuture = api.getStaffAttendance(
      widget.staffId,
      date: DateFormat('yyyy-MM-dd').format(_selectedDate),
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
        _loadData();
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: FutureBuilder<StaffResponse>(
          future: _staffFuture,
          builder: (context, snap) =>
              Text(snap.data?.name ?? 'Staff Attendance'),
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.check_circle_outline), text: 'Present'),
            Tab(icon: Icon(Icons.cancel_outlined), text: 'Absent'),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: _pickDate,
            icon:
                const Icon(Icons.calendar_today, size: 16, color: Colors.white),
            label: Text(
              DateFormat('dd MMM').format(_selectedDate),
              style: const TextStyle(color: Colors.white),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(_loadData),
          ),
        ],
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _attendanceFuture,
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

          final present = records.where((r) => r.status == 'present').toList();
          final absent = records.where((r) => r.status != 'present').toList();

          return Column(
            children: [
              _StatsBar(
                  total: records.length,
                  present: present.length,
                  absent: absent.length),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _AttendanceList(records: present, isPresent: true),
                    _AttendanceList(records: absent, isPresent: false),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StatsBar extends StatelessWidget {
  final int total, present, absent;
  const _StatsBar(
      {required this.total, required this.present, required this.absent});

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? (present / total * 100).round() : 0;
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryColor,
            AppTheme.primaryColor.withOpacity(0.7)
          ],
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          _StatTile(
              label: 'Total', value: total.toString(), color: Colors.white),
          const VerticalDivider(color: Colors.white30, thickness: 1),
          _StatTile(
              label: 'Present',
              value: present.toString(),
              color: Colors.greenAccent),
          const VerticalDivider(color: Colors.white30, thickness: 1),
          _StatTile(
              label: 'Absent',
              value: absent.toString(),
              color: Colors.redAccent),
          const VerticalDivider(color: Colors.white30, thickness: 1),
          _StatTile(
              label: 'Attendance', value: '$pct%', color: Colors.yellowAccent),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label, value;
  final Color color;
  const _StatTile(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: TextStyle(
                  color: color, fontWeight: FontWeight.bold, fontSize: 20)),
          Text(label,
              style: const TextStyle(color: Colors.white70, fontSize: 11)),
        ],
      ),
    );
  }
}

class _AttendanceList extends StatelessWidget {
  final List<AttendanceRecord> records;
  final bool isPresent;
  const _AttendanceList({required this.records, required this.isPresent});

  @override
  Widget build(BuildContext context) {
    if (records.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isPresent ? Icons.check_circle_outline : Icons.cancel_outlined,
              size: 60,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 12),
            Text(
              isPresent ? 'No students present.' : 'No absences recorded.',
              style: TextStyle(color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: records.length,
      itemBuilder: (context, i) {
        final r = records[i];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: isPresent
                  ? Colors.green.withOpacity(0.12)
                  : r.isFakeEye
                      ? Colors.orange.withOpacity(0.12)
                      : Colors.red.withOpacity(0.12),
              child: Icon(
                r.isFakeEye
                    ? Icons.warning_amber
                    : (isPresent ? Icons.check : Icons.close),
                color: r.isFakeEye
                    ? Colors.orange
                    : (isPresent ? Colors.green : Colors.red),
              ),
            ),
            title: Text(r.studentName,
                style:
                    const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            subtitle: Text(
              'Roll: ${r.rollNumber}${r.subjectName != null ? "  •  ${r.subjectName}" : ""}'
              '${r.isFakeEye ? "  ⚠ Fake Eye Detected" : ""}',
              style: TextStyle(
                  fontSize: 12,
                  color: r.isFakeEye ? Colors.orange : Colors.grey.shade600),
            ),
            trailing: Text(
              '${(r.confidence * 100).round()}%',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isPresent ? Colors.green : Colors.red,
              ),
            ),
          ),
        );
      },
    );
  }
}
