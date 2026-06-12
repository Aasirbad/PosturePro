import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:percent_indicator/percent_indicator.dart';
import '../models/exercise.dart';
import '../painters/pose_painter.dart';
import '../utils/camera_service.dart';

class CameraScreen extends StatefulWidget {
  final Exercise exercise;
  const CameraScreen({super.key, required this.exercise});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with SingleTickerProviderStateMixin {
  final CameraService _cameraService = CameraService();
  final PostureAnalyzer _analyzer = PostureAnalyzer();

  PostureResult? _result;
  Pose? _pose;
  Size? _imageSize;
  bool _cameraReady = false;
  bool _showKeyPoints = true;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      _cameraService.onPoseDetected = (pose, imageSize) {
        if (!mounted) return;
        final result = _analyzer.analyze(pose, widget.exercise.id);
        setState(() {
          _pose = pose;
          _imageSize = imageSize;
          _result = result;
        });
      };
      await _cameraService.initialize(cameras);
      if (mounted) setState(() => _cameraReady = true);
    } catch (e) {
      debugPrint('Camera init error: $e');
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _cameraService.dispose();
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }

  Color get _statusColor {
    return switch (_result?.overallStatus ?? PostureStatus.notDetected) {
      PostureStatus.good => const Color(0xFF00E676),
      PostureStatus.warning => const Color(0xFFFFD600),
      PostureStatus.bad => const Color(0xFFFF1744),
      PostureStatus.notDetected => const Color(0xFF78909C),
    };
  }

  String get _statusLabel {
    return switch (_result?.overallStatus ?? PostureStatus.notDetected) {
      PostureStatus.good => 'GOOD FORM',
      PostureStatus.warning => 'ADJUST',
      PostureStatus.bad => 'FIX POSTURE',
      PostureStatus.notDetected => 'DETECTING...',
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Camera Preview ──
          if (_cameraReady && _cameraService.controller != null)
            CameraPreview(_cameraService.controller!),

          // ── Skeleton Overlay ──
          if (_pose != null && _imageSize != null && _showKeyPoints)
            CustomPaint(
              painter: PosePainter(
                pose: _pose!,
                imageSize: _imageSize!,
                isFrontCamera: _cameraService.isFrontCamera,
                status: _result?.overallStatus ?? PostureStatus.notDetected,
              ),
            ),

          // ── Loading state ──
          if (!_cameraReady)
            Container(
              color: const Color(0xFF0A0E1A),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(
                      color: Color(0xFF00E676),
                    ),
                    const SizedBox(height: 16),
                    Text('Starting camera…',
                        style: GoogleFonts.inter(color: Colors.white54)),
                  ],
                ),
              ),
            ),

          // ── Gradient overlays ──
          Positioned(
            top: 0, left: 0, right: 0,
            child: Container(
              height: 180,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black, Colors.transparent],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              height: 300,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black, Colors.transparent],
                ),
              ),
            ),
          ),

          // ── Top bar ──
          SafeArea(child: _buildTopBar()),

          // ── Bottom panel ──
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: SafeArea(child: _buildBottomPanel()),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          // Back button
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white, size: 18),
            ),
          ),
          const SizedBox(width: 12),
          // Exercise name
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.exercise.name,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                Text(
                  widget.exercise.muscleGroup,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: Colors.white38,
                  ),
                ),
              ],
            ),
          ),
          // Status badge
          AnimatedBuilder(
            animation: _pulseController,
            builder: (_, __) {
              final isDetected = _result?.overallStatus != PostureStatus.notDetected;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _statusColor.withOpacity(
                      isDetected ? 0.15 + _pulseController.value * 0.05 : 0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _statusColor.withOpacity(isDetected ? 0.5 : 0.2),
                  ),
                ),
                child: Text(
                  _statusLabel,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _statusColor,
                    letterSpacing: 0.5,
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
          // Toggle skeleton
          GestureDetector(
            onTap: () => setState(() => _showKeyPoints = !_showKeyPoints),
            child: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: _showKeyPoints
                    ? const Color(0xFF00E676).withOpacity(0.15)
                    : Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _showKeyPoints
                      ? const Color(0xFF00E676).withOpacity(0.4)
                      : Colors.white.withOpacity(0.08),
                ),
              ),
              child: Icon(
                Icons.accessibility_new_rounded,
                color: _showKeyPoints ? const Color(0xFF00E676) : Colors.white38,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomPanel() {
    final result = _result;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Score + Rep counter row ──
          Row(
            children: [
              Expanded(child: _buildScoreCard(result)),
              const SizedBox(width: 12),
              _buildRepCounter(result),
            ],
          ),
          const SizedBox(height: 12),
          // ── Feedback card ──
          _buildFeedbackCard(result),
          const SizedBox(height: 12),
          // ── Joint angles ──
          if (result != null && result.jointAngles.isNotEmpty)
            _buildJointAngles(result),
          const SizedBox(height: 12),
          // ── Reset button ──
          _buildResetButton(),
        ],
      ),
    );
  }

  Widget _buildScoreCard(PostureResult? result) {
    final score = result?.score ?? 0;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.75),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('FORM SCORE',
              style: GoogleFonts.inter(
                  fontSize: 10, color: Colors.white38, letterSpacing: 1)),
          const SizedBox(height: 8),
          Row(
            children: [
              CircularPercentIndicator(
                radius: 28,
                lineWidth: 4,
                percent: score / 100,
                center: Text(
                  '${score.toInt()}',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _statusColor,
                  ),
                ),
                progressColor: _statusColor,
                backgroundColor: _statusColor.withOpacity(0.15),
                circularStrokeCap: CircularStrokeCap.round,
              ),
              const SizedBox(width: 10),
              Text(
                '%',
                style: GoogleFonts.inter(
                    fontSize: 13, color: Colors.white54),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRepCounter(PostureResult? result) {
    return Container(
      width: 100,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.75),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text('REPS',
              style: GoogleFonts.inter(
                  fontSize: 10, color: Colors.white38, letterSpacing: 1)),
          const SizedBox(height: 4),
          Text(
            '${result?.repCount ?? 0}',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 36,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: -1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedbackCard(PostureResult? result) {
    final feedback = result?.primaryFeedback ?? 'Stand in front of the camera';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _statusColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(
            _getFeedbackIcon(),
            color: _statusColor,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              feedback,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getFeedbackIcon() {
    return switch (_result?.overallStatus ?? PostureStatus.notDetected) {
      PostureStatus.good => Icons.check_circle_outline_rounded,
      PostureStatus.warning => Icons.warning_amber_rounded,
      PostureStatus.bad => Icons.error_outline_rounded,
      PostureStatus.notDetected => Icons.person_search_rounded,
    };
  }

  Widget _buildJointAngles(PostureResult result) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.75),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'JOINT ANGLES',
            style: GoogleFonts.inter(
                fontSize: 10, color: Colors.white38, letterSpacing: 1),
          ),
          const SizedBox(height: 8),
          ...result.jointAngles.take(3).map((a) => _buildAngleRow(a)),
        ],
      ),
    );
  }

  Widget _buildAngleRow(JointAngle angle) {
    final color = switch (angle.status) {
      PostureStatus.good => const Color(0xFF00E676),
      PostureStatus.warning => const Color(0xFFFFD600),
      PostureStatus.bad => const Color(0xFFFF1744),
      PostureStatus.notDetected => const Color(0xFF78909C),
    };

    final displayAngle = angle.angle < 0 ? '—' : '${angle.angle.toInt()}°';

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Container(
            width: 8, height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              angle.name,
              style: GoogleFonts.inter(fontSize: 12, color: Colors.white70),
            ),
          ),
          Text(
            displayAngle,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '(${angle.minAngle.toInt()}-${angle.maxAngle.toInt()}°)',
            style: GoogleFonts.inter(fontSize: 10, color: Colors.white30),
          ),
        ],
      ),
    );
  }

  Widget _buildResetButton() {
    return GestureDetector(
      onTap: () {
        _analyzer.resetReps(widget.exercise.id);
        setState(() {});
      },
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.07),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.refresh_rounded, color: Colors.white54, size: 18),
            const SizedBox(width: 6),
            Text(
              'Reset Reps',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: Colors.white54,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
