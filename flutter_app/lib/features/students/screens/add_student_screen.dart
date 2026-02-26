import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';

import '../../../core/services/api_service.dart';
import '../../../core/theme/app_theme.dart';

class AddStudentScreen extends ConsumerStatefulWidget {
  final int? studentId;
  const AddStudentScreen({super.key, this.studentId});

  @override
  ConsumerState<AddStudentScreen> createState() => _AddStudentScreenState();
}

class _AddStudentScreenState extends ConsumerState<AddStudentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _rollCtrl = TextEditingController();
  final _cgpaCtrl = TextEditingController();

  String? _selectedYear;
  int? _selectedDeptId;
  int? _selectedClassroomId;
  int? _selectedFacultyId;
  String? _selectedFacultySlot;
  String? _selectedStudentType;
  final Set<int> _selectedSubjectIds = {};

  File? _leftEyeFile;
  File? _rightEyeFile;

  List<DepartmentResponse> _departments = [];
  List<SubjectResponse> _subjects = [];
  List<ClassroomResponse> _classrooms = [];
  List<StaffResponse> _staffList = [];

  bool _isLoading = false;
  bool _isFetchingData = true;
  String? _errorMessage;

  static const _years = ['1st', '2nd', '3rd', '4th'];
  static const _studentTypes = ['Product', 'Service'];
  static const _facultySlots = ['1st', 'End'];

  @override
  void initState() {
    super.initState();
    _fetchDropdownData();
  }

  Future<void> _fetchDropdownData() async {
    final api = ref.read(apiServiceProvider);
    try {
      final results = await Future.wait([
        api.getDepartments(),
        api.getSubjects(),
        api.getClassrooms(),
        api.getStaff(),
      ]);
      setState(() {
        _departments = results[0] as List<DepartmentResponse>;
        _subjects = results[1] as List<SubjectResponse>;
        _classrooms = results[2] as List<ClassroomResponse>;
        _staffList = results[3] as List<StaffResponse>;
        _isFetchingData = false;
      });
    } catch (e) {
      setState(() {
        _isFetchingData = false;
        _errorMessage = 'Failed to load form data: $e';
      });
    }
  }

  Future<void> _pickImage(bool isLeft) async {
    final picker = ImagePicker();
    final picked =
        await picker.pickImage(source: ImageSource.camera, imageQuality: 90);
    if (picked != null) {
      setState(() {
        if (isLeft) {
          _leftEyeFile = File(picked.path);
        } else {
          _rightEyeFile = File(picked.path);
        }
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedYear == null) {
      setState(() => _errorMessage = 'Please select a year');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final api = ref.read(apiServiceProvider);

      final formData = FormData.fromMap({
        'roll_number': _rollCtrl.text.trim(),
        'name': _nameCtrl.text.trim(),
        'year': _selectedYear!,
        if (_selectedDeptId != null)
          'department_id': _selectedDeptId.toString(),
        if (_cgpaCtrl.text.isNotEmpty) 'cgpa': _cgpaCtrl.text.trim(),
        if (_selectedStudentType != null) 'student_type': _selectedStudentType,
        if (_selectedClassroomId != null)
          'classroom_id': _selectedClassroomId.toString(),
        if (_selectedSubjectIds.isNotEmpty)
          'subjects': _selectedSubjectIds.join(','),
        if (_selectedFacultyId != null)
          'faculty_id': _selectedFacultyId.toString(),
        if (_selectedFacultySlot != null) 'faculty_slot': _selectedFacultySlot,
        if (_leftEyeFile != null)
          'iris_left': await MultipartFile.fromFile(_leftEyeFile!.path,
              filename: 'left_iris.jpg'),
        if (_rightEyeFile != null)
          'iris_right': await MultipartFile.fromFile(_rightEyeFile!.path,
              filename: 'right_iris.jpg'),
      });

      await api.registerStudent(formData);

      setState(() => _isLoading = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Student registered successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      String msg = e.toString();
      if (e is DioException && e.response?.data != null) {
        msg = e.response!.data['detail']?.toString() ?? msg;
      }
      setState(() {
        _isLoading = false;
        _errorMessage = msg;
      });
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _rollCtrl.dispose();
    _cgpaCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
            widget.studentId == null ? 'Register Student' : 'Edit Student'),
      ),
      body: _isFetchingData
          ? const Center(
              child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Loading form data…'),
              ],
            ))
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _SectionHeader(
                      title: 'Basic Information', icon: Icons.person),
                  const SizedBox(height: 12),
                  _buildTextField(_nameCtrl, 'Full Name', Icons.badge,
                      required: true),
                  const SizedBox(height: 12),
                  _buildTextField(_rollCtrl, 'Roll Number', Icons.tag,
                      required: true),
                  const SizedBox(height: 12),
                  _buildTextField(
                      _cgpaCtrl, 'CGPA (e.g. 8.5)', Icons.star_outline,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true)),
                  const SizedBox(height: 12),
                  _buildDropdown<String>(
                    label: 'Year',
                    value: _selectedYear,
                    items: _years
                        .map((y) => DropdownMenuItem(value: y, child: Text(y)))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedYear = v),
                    required: true,
                  ),
                  const SizedBox(height: 12),
                  _buildDropdown<String>(
                    label: 'Student Type',
                    value: _selectedStudentType,
                    items: _studentTypes
                        .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedStudentType = v),
                  ),
                  const SizedBox(height: 24),
                  _SectionHeader(title: 'Academic Details', icon: Icons.school),
                  const SizedBox(height: 12),
                  _buildDropdown<int>(
                    label: 'Department',
                    value: _selectedDeptId,
                    items: _departments
                        .map((d) =>
                            DropdownMenuItem(value: d.id, child: Text(d.name)))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedDeptId = v),
                  ),
                  const SizedBox(height: 12),
                  _buildDropdown<int>(
                    label: 'Classroom',
                    value: _selectedClassroomId,
                    items: _classrooms
                        .map((r) =>
                            DropdownMenuItem(value: r.id, child: Text(r.name)))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedClassroomId = v),
                  ),
                  const SizedBox(height: 16),
                  Text('Subjects',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  ..._subjects.map((sub) => CheckboxListTile(
                        title: Text(sub.name),
                        subtitle: Text(sub.subjectType,
                            style: const TextStyle(fontSize: 12)),
                        value: _selectedSubjectIds.contains(sub.id),
                        onChanged: (v) {
                          setState(() {
                            if (v == true) {
                              _selectedSubjectIds.add(sub.id);
                            } else {
                              _selectedSubjectIds.remove(sub.id);
                            }
                          });
                        },
                        activeColor: AppTheme.primaryColor,
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                      )),
                  const SizedBox(height: 24),
                  _SectionHeader(
                      title: 'Faculty Assignment', icon: Icons.person_pin),
                  const SizedBox(height: 12),
                  _buildDropdown<int>(
                    label: 'Faculty Handler',
                    value: _selectedFacultyId,
                    items: _staffList
                        .map((s) => DropdownMenuItem(
                            value: s.id,
                            child: Text('${s.name} (${s.subjectName ?? "—"})')))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedFacultyId = v),
                  ),
                  const SizedBox(height: 12),
                  _buildDropdown<String>(
                    label: 'Faculty Slot',
                    value: _selectedFacultySlot,
                    items: _facultySlots
                        .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedFacultySlot = v),
                  ),
                  const SizedBox(height: 24),
                  _SectionHeader(
                      title: 'Iris Enrollment', icon: Icons.remove_red_eye),
                  const SizedBox(height: 8),
                  Text(
                    'Capture both left and right iris images separately for liveness-based attendance.',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _IrisCaptureTile(
                          label: 'Left Eye',
                          icon: Icons.remove_red_eye_outlined,
                          file: _leftEyeFile,
                          onCapture: () => _pickImage(true),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _IrisCaptureTile(
                          label: 'Right Eye',
                          icon: Icons.remove_red_eye,
                          file: _rightEyeFile,
                          onCapture: () => _pickImage(false),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  if (_errorMessage != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline,
                              color: Colors.red, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(_errorMessage!,
                                style: const TextStyle(
                                    color: Colors.red, fontSize: 13)),
                          ),
                        ],
                      ),
                    ),
                  SizedBox(
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _submit,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.save),
                      label: Text(
                          _isLoading ? 'Registering…' : 'Register Student'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Widget _buildTextField(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    bool required = false,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label + (required ? ' *' : ''),
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
      validator: required
          ? (v) =>
              (v == null || v.trim().isEmpty) ? 'Please enter $label' : null
          : null,
    );
  }

  Widget _buildDropdown<T>({
    required String label,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required void Function(T?) onChanged,
    bool required = false,
  }) {
    return DropdownButtonFormField<T>(
      value: value,
      items: items,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label + (required ? ' *' : ''),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      ),
      validator:
          required ? (v) => v == null ? 'Please select $label' : null : null,
      isExpanded: true,
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  const _SectionHeader({required this.title, required this.icon});
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppTheme.primaryColor),
        const SizedBox(width: 8),
        Text(title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700, color: AppTheme.primaryColor)),
        const SizedBox(width: 8),
        const Expanded(child: Divider()),
      ],
    );
  }
}

class _IrisCaptureTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final File? file;
  final VoidCallback onCapture;
  const _IrisCaptureTile({
    required this.label,
    required this.icon,
    required this.file,
    required this.onCapture,
  });

  @override
  Widget build(BuildContext context) {
    final captured = file != null;
    return InkWell(
      onTap: onCapture,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 120,
        decoration: BoxDecoration(
          color: captured
              ? AppTheme.successColor.withOpacity(0.08)
              : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: captured ? AppTheme.successColor : Colors.grey.shade300,
            width: 2,
          ),
        ),
        child: captured
            ? ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.file(file!, fit: BoxFit.cover),
                    Positioned(
                      bottom: 4,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.check,
                            color: Colors.white, size: 14),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        color: Colors.black54,
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text(
                          label,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 36, color: Colors.grey.shade400),
                  const SizedBox(height: 8),
                  Text(label,
                      style: TextStyle(
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500)),
                  const SizedBox(height: 4),
                  Text('Tap to capture',
                      style:
                          TextStyle(color: Colors.grey.shade400, fontSize: 11)),
                ],
              ),
      ),
    );
  }
}
