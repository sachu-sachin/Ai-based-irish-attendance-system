import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'storage_service.dart';

// ─────────────────────────────────────────────
// API Service (Direct Dio — no code generation needed)
// ─────────────────────────────────────────────

class ApiService {
  final Dio _dio;
  Dio get dio => _dio;

  ApiService(this._dio);

  // ── Auth ──────────────────────────────────────

  Future<LoginResponse> login(LoginRequest request) async {
    print('ApiService: POST /auth/login with ${request.toJson()}');
    final resp = await _dio.post('/auth/login', data: request.toJson());
    print('ApiService: POST /auth/login received response');
    return LoginResponse.fromJson(Map<String, dynamic>.from(resp.data as Map));
  }

  Future<dynamic> getCurrentUser() async {
    final r = await _dio.get('/auth/me');
    return r.data;
  }

  Future<void> logout() async {
    try {
      await _dio.post('/auth/logout');
    } catch (_) {}
  }

  Future<dynamic> changePassword(PasswordChangeRequest request) async {
    final r = await _dio.post('/auth/change-password', data: request.toJson());
    return r.data;
  }

  // ── Dashboard ─────────────────────────────────

  Future<DashboardStats> getDashboardStats() async {
    final r = await _dio.get('/admin/dashboard/stats');
    return DashboardStats.fromJson(Map<String, dynamic>.from(r.data as Map));
  }

  // ── Departments ───────────────────────────────

  Future<List<DepartmentResponse>> getDepartments() async {
    final r = await _dio.get('/departments/');
    return (r.data as List)
        .map((e) =>
            DepartmentResponse.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<DepartmentResponse> createDepartment(
      DepartmentCreateRequest request) async {
    final r = await _dio.post('/departments/', data: request.toJson());
    return DepartmentResponse.fromJson(
        Map<String, dynamic>.from(r.data as Map));
  }

  // ── Subjects ──────────────────────────────────

  Future<List<SubjectResponse>> getSubjects() async {
    final r = await _dio.get('/subjects/');
    return (r.data as List)
        .map((e) =>
            SubjectResponse.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<SubjectResponse> createSubject(SubjectCreateRequest request) async {
    final r = await _dio.post('/subjects/', data: request.toJson());
    return SubjectResponse.fromJson(Map<String, dynamic>.from(r.data as Map));
  }

  // ── Classrooms ────────────────────────────────

  Future<List<ClassroomResponse>> getClassrooms() async {
    final r = await _dio.get('/classrooms/');
    return (r.data as List)
        .map((e) =>
            ClassroomResponse.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<ClassroomResponse> createClassroom(
      ClassroomCreateRequest request) async {
    final r = await _dio.post('/classrooms/', data: request.toJson());
    return ClassroomResponse.fromJson(Map<String, dynamic>.from(r.data as Map));
  }

  // ── Staff ─────────────────────────────────────

  Future<List<StaffResponse>> getStaff() async {
    final r = await _dio.get('/staff/');
    return (r.data as List)
        .map((e) => StaffResponse.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<StaffResponse> getStaffMember(int staffId) async {
    final r = await _dio.get('/staff/$staffId');
    return StaffResponse.fromJson(Map<String, dynamic>.from(r.data as Map));
  }

  Future<StaffResponse> registerStaff(StaffCreateRequest request) async {
    final r = await _dio.post('/staff/', data: request.toJson());
    return StaffResponse.fromJson(Map<String, dynamic>.from(r.data as Map));
  }

  Future<void> deleteStaff(int staffId) async {
    await _dio.delete('/staff/$staffId');
  }

  Future<List<dynamic>> getStaffAttendance(int staffId, {String? date}) async {
    final r = await _dio.get(
      '/staff/$staffId/attendance',
      queryParameters: date != null ? {'attendance_date': date} : null,
    );
    return r.data as List;
  }

  // ── Students ──────────────────────────────────

  Future<List<StudentResponse>> getStudents({
    int? skip,
    int? limit,
    int? departmentId,
    String? year,
  }) async {
    final r = await _dio.get('/students/', queryParameters: {
      if (skip != null) 'skip': skip,
      if (limit != null) 'limit': limit,
      if (departmentId != null) 'department_id': departmentId,
      if (year != null) 'year': year,
    });
    return (r.data as List)
        .map((e) =>
            StudentResponse.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<StudentResponse> getStudent(int studentId) async {
    final r = await _dio.get('/students/$studentId');
    return StudentResponse.fromJson(Map<String, dynamic>.from(r.data as Map));
  }

  Future<void> deleteStudent(int studentId) async {
    await _dio.delete('/students/$studentId');
  }

  Future<StudentResponse> registerStudent(FormData formData) async {
    final r = await _dio.post('/students/register', data: formData);
    return StudentResponse.fromJson(Map<String, dynamic>.from(r.data as Map));
  }

  // ── Attendance ────────────────────────────────

  Future<List<dynamic>> getTodayAttendance() async {
    final r = await _dio.get('/attendance/today');
    return r.data as List;
  }

  Future<List<dynamic>> getAttendance({
    String? date,
    int? studentId,
    int? subjectId,
    int? staffId,
    int? skip,
    int? limit,
  }) async {
    final r = await _dio.get('/attendance', queryParameters: {
      if (date != null) 'attendance_date': date,
      if (studentId != null) 'student_id': studentId,
      if (subjectId != null) 'subject_id': subjectId,
      if (staffId != null) 'staff_id': staffId,
      if (skip != null) 'skip': skip,
      if (limit != null) 'limit': limit,
    });
    return r.data as List;
  }

  Future<dynamic> markManualAttendance(ManualAttendanceRequest request) async {
    final r = await _dio.post('/attendance/manual', data: request.toJson());
    return r.data;
  }

  Future<dynamic> markIrisAttendance(IrisAttendanceRequest request) async {
    final r = await _dio.post('/attendance/iris', data: request.toJson());
    return r.data;
  }

  Future<AttendanceStats> getTodayAttendanceStats() async {
    final r = await _dio.get('/attendance/stats/today');
    return AttendanceStats.fromJson(Map<String, dynamic>.from(r.data as Map));
  }

  // ── Timetable ─────────────────────────────────

  Future<List<TimetableEntry>> getTimetable() async {
    final r = await _dio.get('/admin/timetable/');
    return (r.data as List)
        .map(
            (e) => TimetableEntry.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<TimetableEntry> createTimetableEntry(
      TimetableCreateRequest request) async {
    final r = await _dio.post('/admin/timetable/', data: request.toJson());
    return TimetableEntry.fromJson(Map<String, dynamic>.from(r.data as Map));
  }

  Future<void> deleteTimetableEntry(int entryId) async {
    await _dio.delete('/admin/timetable/$entryId');
  }

  // ── Legacy / Misc ─────────────────────────────

  Future<dynamic> getServiceStatus() async {
    final r = await _dio.get('/service/status');
    return r.data;
  }
}

// ─────────────────────────────────────────────
// DTOs
// ─────────────────────────────────────────────

class LoginRequest {
  final String username;
  final String password;
  LoginRequest({required this.username, required this.password});
  Map<String, dynamic> toJson() => {'username': username, 'password': password};
}

class LoginResponse {
  final String accessToken;
  final String tokenType;
  final Map<String, dynamic> user;

  LoginResponse(
      {required this.accessToken, required this.tokenType, required this.user});

  factory LoginResponse.fromJson(Map<String, dynamic> json) => LoginResponse(
        accessToken: json['access_token'] as String,
        tokenType: json['token_type'] as String,
        user: Map<String, dynamic>.from(json['user'] as Map),
      );
}

class PasswordChangeRequest {
  final String currentPassword;
  final String newPassword;
  PasswordChangeRequest(
      {required this.currentPassword, required this.newPassword});
  Map<String, dynamic> toJson() => {
        'current_password': currentPassword,
        'new_password': newPassword,
      };
}

class DashboardStats {
  final int totalStudents;
  final int totalStaff;
  final int todayAttendance;
  final int totalSubjects;
  final int totalDepartments;
  final int totalAdmins;
  final int totalCameras;

  DashboardStats({
    required this.totalStudents,
    required this.totalStaff,
    required this.todayAttendance,
    required this.totalSubjects,
    required this.totalDepartments,
    this.totalAdmins = 0,
    this.totalCameras = 0,
  });

  // Compat getter for old dashboard widgets
  int get totalAttendanceToday => todayAttendance;

  factory DashboardStats.fromJson(Map<String, dynamic> json) => DashboardStats(
        totalStudents: (json['total_students'] as int?) ?? 0,
        totalStaff: (json['total_staff'] as int?) ?? 0,
        todayAttendance: (json['today_attendance'] ??
            json['total_attendance_today'] ??
            0) as int,
        totalSubjects: (json['total_subjects'] as int?) ?? 0,
        totalDepartments: (json['total_departments'] as int?) ?? 0,
        totalAdmins: (json['total_admins'] as int?) ?? 0,
        totalCameras: (json['total_cameras'] as int?) ?? 0,
      );
}

class DepartmentResponse {
  final int id;
  final String name;
  DepartmentResponse({required this.id, required this.name});
  factory DepartmentResponse.fromJson(Map<String, dynamic> json) =>
      DepartmentResponse(id: json['id'] as int, name: json['name'] as String);
  Map<String, dynamic> toJson() => {'id': id, 'name': name};
}

class DepartmentCreateRequest {
  final String name;
  DepartmentCreateRequest({required this.name});
  Map<String, dynamic> toJson() => {'name': name};
}

class SubjectResponse {
  final int id;
  final String name;
  final String subjectType;
  SubjectResponse(
      {required this.id, required this.name, required this.subjectType});
  factory SubjectResponse.fromJson(Map<String, dynamic> json) =>
      SubjectResponse(
        id: json['id'] as int,
        name: json['name'] as String,
        subjectType: (json['subject_type'] as String?) ?? 'General',
      );
  Map<String, dynamic> toJson() =>
      {'id': id, 'name': name, 'subject_type': subjectType};
}

class SubjectCreateRequest {
  final String name;
  final String subjectType;
  SubjectCreateRequest({required this.name, this.subjectType = 'General'});
  Map<String, dynamic> toJson() => {'name': name, 'subject_type': subjectType};
}

class ClassroomResponse {
  final int id;
  final String name;
  final int? departmentId;
  ClassroomResponse({required this.id, required this.name, this.departmentId});
  factory ClassroomResponse.fromJson(Map<String, dynamic> json) =>
      ClassroomResponse(
        id: json['id'] as int,
        name: json['name'] as String,
        departmentId: json['department_id'] as int?,
      );
  Map<String, dynamic> toJson() => {'id': id, 'name': name};
}

class ClassroomCreateRequest {
  final String name;
  final int? departmentId;
  ClassroomCreateRequest({required this.name, this.departmentId});
  Map<String, dynamic> toJson() => {
        'name': name,
        if (departmentId != null) 'department_id': departmentId,
      };
}

class StaffResponse {
  final int id;
  final String name;
  final int? subjectId;
  final String? subjectName;
  final String username;
  final String role;
  final bool isActive;
  final String createdAt;

  StaffResponse({
    required this.id,
    required this.name,
    this.subjectId,
    this.subjectName,
    required this.username,
    required this.role,
    required this.isActive,
    required this.createdAt,
  });

  factory StaffResponse.fromJson(Map<String, dynamic> json) => StaffResponse(
        id: json['id'] as int,
        name: json['name'] as String,
        subjectId: json['subject_id'] as int?,
        subjectName: json['subject_name'] as String?,
        username: json['username'] as String,
        role: json['role'] as String,
        isActive: (json['is_active'] as bool?) ?? true,
        createdAt: json['created_at'] as String,
      );
}

class StaffCreateRequest {
  final String name;
  final int? subjectId;
  final String? password;
  StaffCreateRequest({required this.name, this.subjectId, this.password});
  Map<String, dynamic> toJson() => {
        'name': name,
        if (subjectId != null) 'subject_id': subjectId,
        if (password != null) 'password': password,
      };
}

class StudentResponse {
  final int id;
  final String rollNumber;
  final String name;
  final String year;
  final int? departmentId;
  final String? departmentName;
  final double? cgpa;
  final String? studentType;
  final int? classroomId;
  final String? classroomName;
  final String? subjects;
  final int? facultyId;
  final String? facultyName;
  final String? facultySlot;
  final bool isEnrolled;
  final String createdAt;

  StudentResponse({
    required this.id,
    required this.rollNumber,
    required this.name,
    required this.year,
    this.departmentId,
    this.departmentName,
    this.cgpa,
    this.studentType,
    this.classroomId,
    this.classroomName,
    this.subjects,
    this.facultyId,
    this.facultyName,
    this.facultySlot,
    required this.isEnrolled,
    required this.createdAt,
  });

  factory StudentResponse.fromJson(Map<String, dynamic> json) =>
      StudentResponse(
        id: json['id'] as int,
        rollNumber: json['roll_number'] as String,
        name: json['name'] as String,
        year: json['year'] as String,
        departmentId: json['department_id'] as int?,
        departmentName: json['department_name'] as String?,
        cgpa: (json['cgpa'] as num?)?.toDouble(),
        studentType: json['student_type'] as String?,
        classroomId: json['classroom_id'] as int?,
        classroomName: json['classroom_name'] as String?,
        subjects: json['subjects'] as String?,
        facultyId: json['faculty_id'] as int?,
        facultyName: json['faculty_name'] as String?,
        facultySlot: json['faculty_slot'] as String?,
        isEnrolled: (json['is_enrolled'] as bool?) ?? false,
        createdAt: json['created_at'] as String,
      );

  // Legacy compat
  String get studentId => rollNumber;
  String get department => departmentName ?? '';
}

class TimetableEntry {
  final int id;
  final String dayOfWeek;
  final String timeSlot;
  final int? staffId;
  final String? staffName;
  final int? subjectId;
  final String? subjectName;
  final int? classroomId;
  final String? classroomName;

  TimetableEntry({
    required this.id,
    required this.dayOfWeek,
    required this.timeSlot,
    this.staffId,
    this.staffName,
    this.subjectId,
    this.subjectName,
    this.classroomId,
    this.classroomName,
  });

  factory TimetableEntry.fromJson(Map<String, dynamic> json) => TimetableEntry(
        id: json['id'] as int,
        dayOfWeek: json['day_of_week'] as String,
        timeSlot: json['time_slot'] as String,
        staffId: json['staff_id'] as int?,
        staffName: json['staff_name'] as String?,
        subjectId: json['subject_id'] as int?,
        subjectName: json['subject_name'] as String?,
        classroomId: json['classroom_id'] as int?,
        classroomName: json['classroom_name'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'day_of_week': dayOfWeek,
        'time_slot': timeSlot,
      };
}

class TimetableCreateRequest {
  final String dayOfWeek;
  final String timeSlot;
  final int? staffId;
  final int? subjectId;
  final int? classroomId;
  TimetableCreateRequest({
    required this.dayOfWeek,
    required this.timeSlot,
    this.staffId,
    this.subjectId,
    this.classroomId,
  });
  Map<String, dynamic> toJson() => {
        'day_of_week': dayOfWeek,
        'time_slot': timeSlot,
        if (staffId != null) 'staff_id': staffId,
        if (subjectId != null) 'subject_id': subjectId,
        if (classroomId != null) 'classroom_id': classroomId,
      };
}

class ManualAttendanceRequest {
  final int studentId;
  final int? subjectId;
  final int? staffId;
  final String status;
  final double confidence;
  ManualAttendanceRequest({
    required this.studentId,
    this.subjectId,
    this.staffId,
    this.status = 'present',
    this.confidence = 1.0,
  });
  Map<String, dynamic> toJson() => {
        'student_id': studentId,
        if (subjectId != null) 'subject_id': subjectId,
        if (staffId != null) 'staff_id': staffId,
        'status': status,
        'confidence': confidence,
      };
}

class IrisAttendanceRequest {
  final int studentId;
  final int? subjectId;
  final int? staffId;
  final bool isFakeEye;
  final double confidence;
  IrisAttendanceRequest({
    required this.studentId,
    this.subjectId,
    this.staffId,
    this.isFakeEye = false,
    this.confidence = 1.0,
  });
  Map<String, dynamic> toJson() => {
        'student_id': studentId,
        if (subjectId != null) 'subject_id': subjectId,
        if (staffId != null) 'staff_id': staffId,
        'is_fake_eye': isFakeEye,
        'confidence': confidence,
      };
}

class AttendanceStats {
  final int totalPresent;
  final int totalStudents;
  final String date;
  AttendanceStats(
      {required this.totalPresent,
      required this.totalStudents,
      required this.date});
  factory AttendanceStats.fromJson(Map<String, dynamic> json) =>
      AttendanceStats(
        totalPresent: (json['present'] ?? json['total_present'] ?? 0) as int,
        totalStudents: (json['total_students'] as int?) ?? 0,
        date: (json['date'] as String?) ?? '',
      );
}

class AttendanceRecord {
  final int id;
  final int studentId;
  final String studentName;
  final String rollNumber;
  final String? subjectName;
  final String date;
  final String status;
  final bool isFakeEye;
  final double confidence;
  final String timestamp;

  AttendanceRecord({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.rollNumber,
    this.subjectName,
    required this.date,
    required this.status,
    required this.isFakeEye,
    required this.confidence,
    required this.timestamp,
  });

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) =>
      AttendanceRecord(
        id: json['id'] as int,
        studentId: json['student_id'] as int,
        studentName: (json['student_name'] as String?) ?? '',
        rollNumber: (json['roll_number'] as String?) ?? '',
        subjectName: json['subject_name'] as String?,
        date: (json['date'] as String?) ?? '',
        status: (json['status'] as String?) ?? 'present',
        isFakeEye: (json['is_fake_eye'] as bool?) ?? false,
        confidence: ((json['confidence'] as num?)?.toDouble()) ?? 1.0,
        timestamp: (json['timestamp'] as String?) ?? '',
      );
}

// Legacy compat
class UserResponse {
  final String username;
  final String role;
  UserResponse({required this.username, required this.role});
  factory UserResponse.fromJson(Map<String, dynamic> json) => UserResponse(
      username: json['username'] as String, role: json['role'] as String);
}

// ─────────────────────────────────────────────
// Provider
// ─────────────────────────────────────────────

final apiServiceProvider = Provider<ApiService>((ref) {
  final dio = Dio();
  dio.options.baseUrl = 'http://192.168.157.61:8001';
  dio.options.connectTimeout = const Duration(seconds: 30);
  dio.options.receiveTimeout = const Duration(seconds: 30);

  print('ApiService initialized with baseUrl: ${dio.options.baseUrl}');

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        final storage = ref.read(storageServiceProvider);
        final token = await storage.getAuthToken();
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
    ),
  );

  return ApiService(dio);
});
