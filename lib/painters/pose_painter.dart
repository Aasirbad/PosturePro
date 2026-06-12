import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import '../models/exercise.dart';

class PosePainter extends CustomPainter {
  final Pose pose;
  final Size imageSize;
  final bool isFrontCamera;
  final PostureStatus status;

  PosePainter({
    required this.pose,
    required this.imageSize,
    required this.isFrontCamera,
    required this.status,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Color skeletonColor = switch (status) {
      PostureStatus.good => const Color(0xFF00E676),
      PostureStatus.warning => const Color(0xFFFFD600),
      PostureStatus.bad => const Color(0xFFFF1744),
      PostureStatus.notDetected => const Color(0xFF78909C),
    };

    final jointPaint = Paint()
      ..color = skeletonColor
      ..strokeWidth = 8
      ..style = PaintingStyle.fill;

    final bonePaint = Paint()
      ..color = skeletonColor.withOpacity(0.85)
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final glowPaint = Paint()
      ..color = skeletonColor.withOpacity(0.25)
      ..strokeWidth = 10
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    final landmarks = pose.landmarks;

    Offset _translate(PoseLandmark lm) {
      final scaleX = size.width / imageSize.width;
      final scaleY = size.height / imageSize.height;
      final x = isFrontCamera ? size.width - lm.x * scaleX : lm.x * scaleX;
      final y = lm.y * scaleY;
      return Offset(x, y);
    }

    void drawBone(PoseLandmarkType a, PoseLandmarkType b) {
      final la = landmarks[a];
      final lb = landmarks[b];
      if (la == null || lb == null) return;
      if (la.likelihood < 0.4 || lb.likelihood < 0.4) return;
      final from = _translate(la);
      final to = _translate(lb);
      canvas.drawLine(from, to, glowPaint);
      canvas.drawLine(from, to, bonePaint);
    }

    void drawJoint(PoseLandmarkType type, {double radius = 5}) {
      final lm = landmarks[type];
      if (lm == null || lm.likelihood < 0.4) return;
      final pt = _translate(lm);
      canvas.drawCircle(pt, radius + 3, Paint()..color = skeletonColor.withOpacity(0.2));
      canvas.drawCircle(pt, radius, jointPaint);
      canvas.drawCircle(pt, radius, Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5);
    }

    // ── Draw skeleton connections ──
    // Face
    drawBone(PoseLandmarkType.leftEar, PoseLandmarkType.leftEye);
    drawBone(PoseLandmarkType.rightEar, PoseLandmarkType.rightEye);
    drawBone(PoseLandmarkType.leftEye, PoseLandmarkType.nose);
    drawBone(PoseLandmarkType.rightEye, PoseLandmarkType.nose);

    // Torso
    drawBone(PoseLandmarkType.leftShoulder, PoseLandmarkType.rightShoulder);
    drawBone(PoseLandmarkType.leftShoulder, PoseLandmarkType.leftHip);
    drawBone(PoseLandmarkType.rightShoulder, PoseLandmarkType.rightHip);
    drawBone(PoseLandmarkType.leftHip, PoseLandmarkType.rightHip);

    // Left arm
    drawBone(PoseLandmarkType.leftShoulder, PoseLandmarkType.leftElbow);
    drawBone(PoseLandmarkType.leftElbow, PoseLandmarkType.leftWrist);
    drawBone(PoseLandmarkType.leftWrist, PoseLandmarkType.leftIndex);

    // Right arm
    drawBone(PoseLandmarkType.rightShoulder, PoseLandmarkType.rightElbow);
    drawBone(PoseLandmarkType.rightElbow, PoseLandmarkType.rightWrist);
    drawBone(PoseLandmarkType.rightWrist, PoseLandmarkType.rightIndex);

    // Left leg
    drawBone(PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee);
    drawBone(PoseLandmarkType.leftKnee, PoseLandmarkType.leftAnkle);
    drawBone(PoseLandmarkType.leftAnkle, PoseLandmarkType.leftFootIndex);

    // Right leg
    drawBone(PoseLandmarkType.rightHip, PoseLandmarkType.rightKnee);
    drawBone(PoseLandmarkType.rightKnee, PoseLandmarkType.rightAnkle);
    drawBone(PoseLandmarkType.rightAnkle, PoseLandmarkType.rightFootIndex);

    // ── Draw joints ──
    const bigJoints = [
      PoseLandmarkType.leftShoulder, PoseLandmarkType.rightShoulder,
      PoseLandmarkType.leftElbow, PoseLandmarkType.rightElbow,
      PoseLandmarkType.leftHip, PoseLandmarkType.rightHip,
      PoseLandmarkType.leftKnee, PoseLandmarkType.rightKnee,
      PoseLandmarkType.leftAnkle, PoseLandmarkType.rightAnkle,
    ];

    for (final type in bigJoints) {
      drawJoint(type, radius: 6);
    }

    drawJoint(PoseLandmarkType.nose, radius: 8);
    drawJoint(PoseLandmarkType.leftWrist, radius: 4);
    drawJoint(PoseLandmarkType.rightWrist, radius: 4);
  }

  @override
  bool shouldRepaint(PosePainter oldDelegate) => true;
}
