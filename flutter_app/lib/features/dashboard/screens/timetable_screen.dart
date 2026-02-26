import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/api_service.dart';
import '../../../core/theme/app_theme.dart';

class TimetableScreen extends ConsumerStatefulWidget {
  const TimetableScreen({super.key});

  @override
  ConsumerState<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends ConsumerState<TimetableScreen> {
  late Future<List<TimetableEntry>> _timetableFuture;
  late Future<List<StaffResponse>> _staffFuture;
  late Future<List<SubjectResponse>> _subjectsFuture;
  late Future<List<ClassroomResponse>> _classroomsFuture;

  static const _days = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday'
  ];
  static const _slots = [
    '8:00 AM - 9:00 AM',
    '9:00 AM - 10:00 AM',
    '10:00 AM - 11:00 AM',
    '11:00 AM - 12:00 PM',
    '12:00 PM - 1:00 PM',
    '2:00 PM - 3:00 PM',
    '3:00 PM - 4:00 PM',
    '4:00 PM - 5:00 PM',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final api = ref.read(apiServiceProvider);
    _timetableFuture = api.getTimetable();
    _staffFuture = api.getStaff();
    _subjectsFuture = api.getSubjects();
    _classroomsFuture = api.getClassrooms();
  }

  void _showAddDialog({
    required List<StaffResponse> staffList,
    required List<SubjectResponse> subjects,
    required List<ClassroomResponse> classrooms,
  }) {
    String? day;
    String? slot;
    int? staffId;
    int? subjectId;
    int? classroomId;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Add Timetable Entry'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: day,
                  decoration:
                      const InputDecoration(labelText: 'Day *', isDense: true),
                  items: _days
                      .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                      .toList(),
                  onChanged: (v) => setDialogState(() => day = v),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: slot,
                  decoration: const InputDecoration(
                      labelText: 'Time Slot *', isDense: true),
                  items: _slots
                      .map((s) => DropdownMenuItem(
                          value: s,
                          child: Text(s, style: const TextStyle(fontSize: 13))))
                      .toList(),
                  onChanged: (v) => setDialogState(() => slot = v),
                  isExpanded: true,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  value: staffId,
                  decoration: const InputDecoration(
                      labelText: 'Teacher', isDense: true),
                  items: staffList
                      .map((s) =>
                          DropdownMenuItem(value: s.id, child: Text(s.name)))
                      .toList(),
                  onChanged: (v) => setDialogState(() => staffId = v),
                  isExpanded: true,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  value: subjectId,
                  decoration: const InputDecoration(
                      labelText: 'Subject', isDense: true),
                  items: subjects
                      .map((s) =>
                          DropdownMenuItem(value: s.id, child: Text(s.name)))
                      .toList(),
                  onChanged: (v) => setDialogState(() => subjectId = v),
                  isExpanded: true,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  value: classroomId,
                  decoration: const InputDecoration(
                      labelText: 'Classroom', isDense: true),
                  items: classrooms
                      .map((r) =>
                          DropdownMenuItem(value: r.id, child: Text(r.name)))
                      .toList(),
                  onChanged: (v) => setDialogState(() => classroomId = v),
                  isExpanded: true,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: day == null || slot == null
                  ? null
                  : () async {
                      Navigator.pop(ctx);
                      try {
                        await ref.read(apiServiceProvider).createTimetableEntry(
                              TimetableCreateRequest(
                                dayOfWeek: day!,
                                timeSlot: slot!,
                                staffId: staffId,
                                subjectId: subjectId,
                                classroomId: classroomId,
                              ),
                            );
                        setState(_load);
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: $e')),
                          );
                        }
                      }
                    },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Timetable'),
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => setState(_load)),
        ],
      ),
      body: FutureBuilder<List<dynamic>>(
        future: Future.wait([
          _timetableFuture,
          _staffFuture,
          _subjectsFuture,
          _classroomsFuture
        ]),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final data = snapshot.data!;
          final entries = data[0] as List<TimetableEntry>;
          final staffList = data[1] as List<StaffResponse>;
          final subjects = data[2] as List<SubjectResponse>;
          final classrooms = data[3] as List<ClassroomResponse>;

          // Group entries by day
          final Map<String, List<TimetableEntry>> grouped = {};
          for (final e in entries) {
            (grouped[e.dayOfWeek] ??= []).add(e);
          }

          return Stack(
            children: [
              entries.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.calendar_today,
                              size: 72, color: Colors.grey.shade300),
                          const SizedBox(height: 16),
                          Text('No timetable entries yet.',
                              style: TextStyle(
                                  color: Colors.grey.shade600, fontSize: 16)),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () => _showAddDialog(
                                staffList: staffList,
                                subjects: subjects,
                                classrooms: classrooms),
                            icon: const Icon(Icons.add),
                            label: const Text('Add First Entry'),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
                      itemCount:
                          _days.where((d) => grouped.containsKey(d)).length,
                      itemBuilder: (context, index) {
                        final day = _days
                            .where((d) => grouped.containsKey(d))
                            .elementAt(index);
                        final dayEntries = grouped[day]!;
                        dayEntries
                            .sort((a, b) => a.timeSlot.compareTo(b.timeSlot));

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryColor,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(day,
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13)),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                      child:
                                          Divider(color: Colors.grey.shade300)),
                                ],
                              ),
                            ),
                            ...dayEntries.map((e) => _TimetableTile(
                                  entry: e,
                                  onDelete: () async {
                                    await ref
                                        .read(apiServiceProvider)
                                        .deleteTimetableEntry(e.id);
                                    setState(_load);
                                  },
                                )),
                          ],
                        );
                      },
                    ),
              Positioned(
                bottom: 16,
                right: 16,
                child: FloatingActionButton.extended(
                  onPressed: () => _showAddDialog(
                      staffList: staffList,
                      subjects: subjects,
                      classrooms: classrooms),
                  icon: const Icon(Icons.add),
                  label: const Text('Add Entry'),
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TimetableTile extends StatelessWidget {
  final TimetableEntry entry;
  final VoidCallback onDelete;
  const _TimetableTile({required this.entry, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            entry.timeSlot.split(' - ').first,
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryColor),
            textAlign: TextAlign.center,
          ),
        ),
        title: Text(
          entry.subjectName ?? 'No Subject',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        subtitle: Text(
          [
            if (entry.staffName != null) '👤 ${entry.staffName}',
            if (entry.classroomName != null) '🏫 ${entry.classroomName}',
            entry.timeSlot,
          ].join('  •  '),
          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
          onPressed: () {
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Remove Entry'),
                content: Text(
                    'Remove ${entry.subjectName ?? "this entry"} on ${entry.dayOfWeek}?'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel')),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      onDelete();
                    },
                    style:
                        ElevatedButton.styleFrom(backgroundColor: Colors.red),
                    child: const Text('Remove'),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
