import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';

import '../../../core/services/api_service.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/theme/app_theme.dart';

// ─────────────────────────────────────────────────
// Model
// ─────────────────────────────────────────────────

class IrisScanResult {
  final bool eyeDetected;
  final bool isFakeEye;
  final double livenessScore;
  final bool matched;
  final int? studentId;
  final String? studentName;
  final String? rollNumber;
  final double confidence;
  final double hammingDistance;
  final bool attendanceMarked;
  final String message;

  const IrisScanResult({
    required this.eyeDetected,
    required this.isFakeEye,
    required this.livenessScore,
    required this.matched,
    this.studentId,
    this.studentName,
    this.rollNumber,
    required this.confidence,
    required this.hammingDistance,
    required this.attendanceMarked,
    required this.message,
  });

  factory IrisScanResult.fromJson(Map<String, dynamic> j) => IrisScanResult(
        eyeDetected: j['eye_detected'] as bool? ?? false,
        isFakeEye: j['is_fake_eye'] as bool? ?? false,
        livenessScore: (j['liveness_score'] as num?)?.toDouble() ?? 0.0,
        matched: j['matched'] as bool? ?? false,
        studentId: j['student_id'] as int?,
        studentName: j['student_name'] as String?,
        rollNumber: j['roll_number'] as String?,
        confidence: (j['confidence'] as num?)?.toDouble() ?? 0.0,
        hammingDistance: (j['hamming_distance'] as num?)?.toDouble() ?? 1.0,
        attendanceMarked: j['attendance_marked'] as bool? ?? false,
        message: j['message'] as String? ?? '',
      );
}

// ─────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────

class IrisScanScreen extends ConsumerStatefulWidget {
  const IrisScanScreen({super.key});

  @override
  ConsumerState<IrisScanScreen> createState() => _IrisScanScreenState();
}

class _IrisScanScreenState extends ConsumerState<IrisScanScreen>
    with TickerProviderStateMixin {
  final _picker = ImagePicker();

  // State
  bool _scanning = false;
  XFile? _capturedImage;
  IrisScanResult? _lastResult;
  String? _error;

  int? _selectedSubjectId;
  final List<Map<String, dynamic>> _subjects = [];
  bool _loadingSubjects = true;

  // Animation controller for the scan ring
  late final AnimationController _ringCtrl;
  late final Animation<double> _ringAnim;

  @override
  void initState() {
    super.initState();
    _ringCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _ringAnim = CurvedAnimation(parent: _ringCtrl, curve: Curves.linear);
    _loadSubjects();
  }

  @override
  void dispose() {
    _ringCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSubjects() async {
    try {
      final api = ref.read(apiServiceProvider);
      final res = await api.dio.get('/subjects/');
      final list = res.data as List? ?? [];
      setState(() {
        _subjects.addAll(list.cast<Map<String, dynamic>>());
        _loadingSubjects = false;
      });
    } catch (_) {
      setState(() => _loadingSubjects = false);
    }
  }

  // ─── Camera / Gallery ─────────────────────────

  Future<void> _takePhoto() async {
    final file = await _picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.front,
      imageQuality: 90,
    );
    if (file == null) return;
    setState(() {
      _capturedImage = file;
      _lastResult = null;
      _error = null;
    });
  }

  Future<void> _pickFromGallery() async {
    final file = await _picker.pickImage(source: ImageSource.gallery);
    if (file == null) return;
    setState(() {
      _capturedImage = file;
      _lastResult = null;
      _error = null;
    });
  }

  // ─── Scan ──────────────────────────────────────

  Future<void> _scan() async {
    if (_capturedImage == null || _scanning) return;
    setState(() {
      _scanning = true;
      _error = null;
      _lastResult = null;
    });

    try {
      final api = ref.read(apiServiceProvider);
      final store = ref.read(storageServiceProvider);
      final token = await store.getAuthToken();

      Uint8List bytes;
      if (kIsWeb) {
        bytes = await _capturedImage!.readAsBytes();
      } else {
        bytes = await File(_capturedImage!.path).readAsBytes();
      }

      final formData = FormData.fromMap({
        'image': MultipartFile.fromBytes(
          bytes,
          filename: 'iris_scan.jpg',
        ),
        if (_selectedSubjectId != null)
          'subject_id': _selectedSubjectId.toString(),
        'mark_attendance': 'true',
      });

      final resp = await api.dio.post(
        '/iris/scan',
        data: formData,
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
          contentType: 'multipart/form-data',
        ),
      );

      final result = IrisScanResult.fromJson(
        Map<String, dynamic>.from(resp.data as Map),
      );
      setState(() => _lastResult = result);
    } on DioException catch (e) {
      final detail = (e.response?.data as Map?)?['detail']?.toString();
      setState(() => _error = detail ?? e.message ?? 'Network error');
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _scanning = false);
    }
  }

  // ─── Build ─────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Iris Scanner'),
        centerTitle: false,
        actions: [
          if (!_loadingSubjects && _subjects.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: DropdownButton<int?>(
                value: _selectedSubjectId,
                hint: const Text('Subject', style: TextStyle(fontSize: 13)),
                underline: const SizedBox(),
                items: [
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: Text('All subjects'),
                  ),
                  ..._subjects.map(
                    (s) => DropdownMenuItem<int?>(
                      value: s['id'] as int,
                      child: Text(s['name'] as String? ?? ''),
                    ),
                  ),
                ],
                onChanged: (v) => setState(() => _selectedSubjectId = v),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // ── Camera preview card ──────────────
            _buildCameraCard(),
            const SizedBox(height: 20),

            // ── Action buttons ───────────────────
            _buildButtons(),
            const SizedBox(height: 24),

            // ── Result card ──────────────────────
            if (_scanning)
              _buildScanningIndicator()
            else if (_error != null)
              _buildErrorCard(_error!)
            else if (_lastResult != null)
              _buildResultCard(_lastResult!),
          ],
        ),
      ),
    );
  }

  // ─── Camera Card ──────────────────────────────

  Widget _buildCameraCard() {
    return Container(
      height: 300,
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.outlineColor),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Preview or placeholder
            if (_capturedImage != null)
              kIsWeb
                  ? Image.network(_capturedImage!.path,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity)
                  : Image.file(File(_capturedImage!.path),
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity)
            else
              _buildEyeGuide(),

            // Scan animation overlay
            if (_scanning)
              Container(
                color: Colors.black45,
                child: Center(
                  child: RotationTransition(
                    turns: _ringAnim,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppTheme.primaryColor,
                          width: 3,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEyeGuide() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Eye oval guide
        Container(
          width: 160,
          height: 100,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(80),
            border: Border.all(
              color: AppTheme.primaryColor.withAlpha(120),
              width: 2,
            ),
          ),
          child: const Icon(Icons.remove_red_eye_outlined,
              size: 40, color: AppTheme.primaryColor),
        ),
        const SizedBox(height: 16),
        Text(
          'Position your eye inside the oval\nTap camera to capture',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 13,
            color: AppTheme.subtleColor,
          ),
        ),
      ],
    );
  }

  // ─── Buttons ──────────────────────────────────

  Widget _buildButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _scanning ? null : _pickFromGallery,
            icon: const Icon(Icons.photo_library_outlined, size: 18),
            label: const Text('Gallery'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: ElevatedButton.icon(
            onPressed: _scanning ? null : _takePhoto,
            icon: const Icon(Icons.camera_alt, size: 20),
            label: const Text('Take Photo'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 56,
          height: 56,
          child: ElevatedButton(
            onPressed: _capturedImage != null && !_scanning ? _scan : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.successColor,
              foregroundColor: Colors.white,
              padding: EdgeInsets.zero,
              shape: const CircleBorder(),
            ),
            child: const Icon(Icons.search, size: 24),
          ),
        ),
      ],
    );
  }

  // ─── Result Cards ─────────────────────────────

  Widget _buildScanningIndicator() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.outlineColor),
      ),
      child: const Column(
        children: [
          CircularProgressIndicator(color: AppTheme.primaryColor),
          SizedBox(height: 16),
          Text('Analysing iris…',
              style: TextStyle(fontFamily: 'Inter', fontSize: 15)),
          SizedBox(height: 4),
          Text('Detecting · Liveness check · Matching',
              style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  color: AppTheme.subtleColor)),
        ],
      ),
    );
  }

  Widget _buildErrorCard(String error) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.errorColor.withAlpha(20),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.errorColor.withAlpha(80)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppTheme.errorColor, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Text(error,
                style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    color: AppTheme.errorColor)),
          ),
        ],
      ),
    );
  }

  Widget _buildResultCard(IrisScanResult r) {
    final Color cardColor;
    final Color borderColor;
    final IconData icon;
    final String statusText;

    if (r.isFakeEye) {
      cardColor = const Color(0xFFFFF3CD);
      borderColor = AppTheme.warningColor;
      icon = Icons.warning_amber_rounded;
      statusText = '⚠ Fake Eye Detected';
    } else if (!r.eyeDetected) {
      cardColor = AppTheme.backgroundColor;
      borderColor = AppTheme.outlineColor;
      icon = Icons.visibility_off_outlined;
      statusText = 'No eye detected';
    } else if (r.matched) {
      cardColor = const Color(0xFFECFDF5);
      borderColor = AppTheme.successColor;
      icon = Icons.check_circle_rounded;
      statusText =
          r.attendanceMarked ? '✅ Present — Attendance Marked' : '✅ Matched';
    } else {
      cardColor = const Color(0xFFFEF2F2);
      borderColor = AppTheme.errorColor;
      icon = Icons.person_off_outlined;
      statusText = '❌ No match found';
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOut,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status row
          Row(
            children: [
              Icon(icon, color: borderColor, size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  statusText,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: borderColor,
                  ),
                ),
              ),
            ],
          ),

          if (r.matched && r.studentName != null) ...[
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),

            // Student avatar + info
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppTheme.primaryColor.withAlpha(30),
                  child: Text(
                    (r.studentName ?? '?')[0].toUpperCase(),
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r.studentName!,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.onSurfaceColor,
                          )),
                      const SizedBox(height: 2),
                      Text('Roll: ${r.rollNumber ?? '-'}',
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13,
                            color: AppTheme.subtleColor,
                          )),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Confidence bar
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Confidence',
                        style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13,
                            color: AppTheme.subtleColor)),
                    Text('${(r.confidence * 100).toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: borderColor,
                        )),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: r.confidence.clamp(0.0, 1.0),
                    minHeight: 8,
                    backgroundColor: borderColor.withAlpha(30),
                    valueColor: AlwaysStoppedAnimation<Color>(borderColor),
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 14),

          // Debug details
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _chip('Eye: ${r.eyeDetected ? "✓" : "✗"}',
                  r.eyeDetected ? AppTheme.successColor : AppTheme.errorColor),
              _chip(
                  'Liveness: ${(r.livenessScore * 100).toInt()}%',
                  r.livenessScore > 0.6
                      ? AppTheme.successColor
                      : AppTheme.warningColor),
              _chip('HD: ${r.hammingDistance.toStringAsFixed(3)}',
                  AppTheme.subtleColor),
            ],
          ),

          if (r.message.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(r.message,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  color: AppTheme.subtleColor,
                )),
          ],
        ],
      ),
    );
  }

  Widget _chip(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withAlpha(20),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withAlpha(80)),
        ),
        child: Text(label,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: color,
            )),
      );
}
