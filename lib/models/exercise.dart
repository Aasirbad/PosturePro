import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

enum PostureStatus { good, warning, bad, notDetected }

class JointAngle {
  final String name;
  final double angle;
  final double minAngle;
  final double maxAngle;
  final String feedback;

  JointAngle({
    required this.name,
    required this.angle,
    required this.minAngle,
    required this.maxAngle,
    required this.feedback,
  });

  PostureStatus get status {
    if (angle >= minAngle && angle <= maxAngle) return PostureStatus.good;
    final tolerance = (maxAngle - minAngle) * 0.15;
    if (angle >= minAngle - tolerance && angle <= maxAngle + tolerance) {
      return PostureStatus.warning;
    }
    return PostureStatus.bad;
  }
}

class PostureResult {
  final PostureStatus overallStatus;
  final List<JointAngle> jointAngles;
  final String primaryFeedback;
  final double score; // 0-100
  final int repCount;

  PostureResult({
    required this.overallStatus,
    required this.jointAngles,
    required this.primaryFeedback,
    required this.score,
    required this.repCount,
  });
}

class Exercise {
  final String id;
  final String name;
  final String emoji;
  final String description;
  final List<String> keyPoints;
  final String muscleGroup;

  const Exercise({
    required this.id,
    required this.name,
    required this.emoji,
    required this.description,
    required this.keyPoints,
    required this.muscleGroup,
  });
}

const List<Exercise> kExercises = [
  Exercise(
    id: 'squat',
    name: 'Squat',
    emoji: '🏋️',
    description: 'Stand with feet shoulder-width apart, lower until thighs are parallel to floor.',
    keyPoints: ['Knees track over toes', 'Back stays straight', 'Thighs parallel to floor', 'Chest up'],
    muscleGroup: 'Legs & Glutes',
  ),
  Exercise(
    id: 'pushup',
    name: 'Push-up',
    emoji: '💪',
    description: 'Start in plank, lower chest to floor keeping body straight.',
    keyPoints: ['Body straight line', 'Elbows at 45°', 'Chest close to floor', 'Core tight'],
    muscleGroup: 'Chest & Triceps',
  ),
  Exercise(
    id: 'lunge',
    name: 'Lunge',
    emoji: '🦵',
    description: 'Step forward and lower back knee toward ground.',
    keyPoints: ['Front knee over ankle', 'Back knee near floor', 'Torso upright', '90° both knees'],
    muscleGroup: 'Legs & Glutes',
  ),
  Exercise(
    id: 'plank',
    name: 'Plank',
    emoji: '🪵',
    description: 'Hold a straight body position supported on forearms and toes.',
    keyPoints: ['Straight line head to heels', 'Hips level', 'Core engaged', 'Look down'],
    muscleGroup: 'Core',
  ),
  Exercise(
    id: 'deadlift',
    name: 'Deadlift',
    emoji: '🏋️‍♂️',
    description: 'Hinge at hips to lift weight from floor with straight back.',
    keyPoints: ['Neutral spine', 'Hip hinge', 'Shoulders back', 'Bar close to legs'],
    muscleGroup: 'Back & Hamstrings',
  ),
  Exercise(
    id: 'bicep_curl',
    name: 'Bicep Curl',
    emoji: '💪',
    description: 'Curl weight from hip to shoulder keeping elbows still.',
    keyPoints: ['Elbows pinned to sides', 'Full range of motion', 'Slow lowering', 'Wrists neutral'],
    muscleGroup: 'Biceps',
  ),
  Exercise(
    id: 'shoulder_press',
    name: 'Shoulder Press',
    emoji: '🙌',
    description: 'Press weight overhead from shoulder height.',
    keyPoints: ['Full arm extension', 'Core braced', 'Elbows at 90° start', 'No arch in back'],
    muscleGroup: 'Shoulders',
  ),
  Exercise(
    id: 'situp',
    name: 'Sit-up',
    emoji: '🤸',
    description: 'Curl torso up from lying to seated position.',
    keyPoints: ['Controlled movement', 'Chin neutral', 'Full range of motion', 'Feet flat'],
    muscleGroup: 'Core & Hip Flexors',
  ),
  Exercise(
    id: 'burpee',
    name: 'Burpee',
    emoji: '🔥',
    description: 'Squat, jump back to plank, push-up, jump forward, jump up.',
    keyPoints: ['Plank position solid', 'Push-up chest to floor', 'Explosive jump', 'Arms overhead'],
    muscleGroup: 'Full Body',
  ),
  Exercise(
    id: 'jumping_jack',
    name: 'Jumping Jack',
    emoji: '⭐',
    description: 'Jump feet apart while raising arms overhead, then return.',
    keyPoints: ['Arms fully overhead', 'Feet wide apart', 'Consistent rhythm', 'Land softly'],
    muscleGroup: 'Full Body Cardio',
  ),
];

// ─── Angle helpers ───────────────────────────────────────────────────────────

double _angleBetween(
  PoseLandmark a,
  PoseLandmark b, // vertex
  PoseLandmark c,
) {
  final ab = Offset(a.x - b.x, a.y - b.y);
  final cb = Offset(c.x - b.x, c.y - b.y);
  final dot = ab.dx * cb.dx + ab.dy * cb.dy;
  final magAB = sqrt(ab.dx * ab.dx + ab.dy * ab.dy);
  final magCB = sqrt(cb.dx * cb.dx + cb.dy * cb.dy);
  if (magAB == 0 || magCB == 0) return 0;
  final cosTheta = (dot / (magAB * magCB)).clamp(-1.0, 1.0);
  return (acos(cosTheta) * 180 / pi);
}

PoseLandmark? _lm(Pose pose, PoseLandmarkType type) =>
    pose.landmarks[type];

double _safeAngle(Pose pose, PoseLandmarkType a, PoseLandmarkType b, PoseLandmarkType c) {
  final la = _lm(pose, a);
  final lb = _lm(pose, b);
  final lc = _lm(pose, c);
  if (la == null || lb == null || lc == null) return -1;
  if (la.likelihood < 0.5 || lb.likelihood < 0.5 || lc.likelihood < 0.5) return -1;
  return _angleBetween(la, lb, lc);
}

// ─── Per-exercise analyzers ──────────────────────────────────────────────────

class PostureAnalyzer {
  final Map<String, int> _repCounters = {};
  final Map<String, bool> _repInProgress = {};

  PostureResult analyze(Pose pose, String exerciseId) {
    switch (exerciseId) {
      case 'squat':       return _analyzeSquat(pose);
      case 'pushup':      return _analyzePushup(pose);
      case 'lunge':       return _analyzeLunge(pose);
      case 'plank':       return _analyzePlank(pose);
      case 'deadlift':    return _analyzeDeadlift(pose);
      case 'bicep_curl':  return _analyzeBicepCurl(pose);
      case 'shoulder_press': return _analyzeShoulderPress(pose);
      case 'situp':       return _analyzeSitup(pose);
      case 'burpee':      return _analyzeBurpee(pose);
      case 'jumping_jack': return _analyzeJumpingJack(pose);
      default:
        return PostureResult(
          overallStatus: PostureStatus.notDetected,
          jointAngles: [],
          primaryFeedback: 'Select an exercise',
          score: 0,
          repCount: 0,
        );
    }
  }

  void resetReps(String exerciseId) {
    _repCounters[exerciseId] = 0;
    _repInProgress[exerciseId] = false;
  }

  void _countRep(String id, bool isDown) {
    final inProgress = _repInProgress[id] ?? false;
    if (isDown && !inProgress) {
      _repInProgress[id] = true;
    } else if (!isDown && inProgress) {
      _repInProgress[id] = false;
      _repCounters[id] = (_repCounters[id] ?? 0) + 1;
    }
  }

  int _getReps(String id) => _repCounters[id] ?? 0;

  PostureResult _buildResult(
    List<JointAngle> angles,
    String exerciseId, {
    String? overrideFeedback,
    bool repIsDown = false,
    bool countReps = true,
  }) {
    if (angles.isEmpty || angles.any((a) => a.angle < 0)) {
      return PostureResult(
        overallStatus: PostureStatus.notDetected,
        jointAngles: [],
        primaryFeedback: 'Position yourself in front of the camera',
        score: 0,
        repCount: _getReps(exerciseId),
      );
    }

    if (countReps) _countRep(exerciseId, repIsDown);

    final badAngles = angles.where((a) => a.status == PostureStatus.bad);
    final warnAngles = angles.where((a) => a.status == PostureStatus.warning);

    PostureStatus overall;
    String feedback;

    if (badAngles.isNotEmpty) {
      overall = PostureStatus.bad;
      feedback = overrideFeedback ?? badAngles.first.feedback;
    } else if (warnAngles.isNotEmpty) {
      overall = PostureStatus.warning;
      feedback = overrideFeedback ?? warnAngles.first.feedback;
    } else {
      overall = PostureStatus.good;
      feedback = overrideFeedback ?? '✅ Great form! Keep it up!';
    }

    final goodCount = angles.where((a) => a.status == PostureStatus.good).length;
    final score = (goodCount / angles.length * 100).roundToDouble();

    return PostureResult(
      overallStatus: overall,
      jointAngles: angles,
      primaryFeedback: feedback,
      score: score,
      repCount: _getReps(exerciseId),
    );
  }

  // ── SQUAT ──
  PostureResult _analyzeSquat(Pose pose) {
    final leftKnee = _safeAngle(pose,
      PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee, PoseLandmarkType.leftAnkle);
    final rightKnee = _safeAngle(pose,
      PoseLandmarkType.rightHip, PoseLandmarkType.rightKnee, PoseLandmarkType.rightAnkle);
    final hipAngle = _safeAngle(pose,
      PoseLandmarkType.leftShoulder, PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee);

    final angles = [
      JointAngle(name: 'Left Knee', angle: leftKnee, minAngle: 70, maxAngle: 110,
          feedback: 'Bend knees more for a proper squat depth'),
      JointAngle(name: 'Right Knee', angle: rightKnee, minAngle: 70, maxAngle: 110,
          feedback: 'Bend knees more for a proper squat depth'),
      JointAngle(name: 'Hip Angle', angle: hipAngle, minAngle: 70, maxAngle: 130,
          feedback: 'Keep chest up and back straight'),
    ];

    final isDown = (leftKnee > 0 && leftKnee < 110) || (rightKnee > 0 && rightKnee < 110);
    return _buildResult(angles, 'squat', repIsDown: isDown);
  }

  // ── PUSH-UP ──
  PostureResult _analyzePushup(Pose pose) {
    final leftElbow = _safeAngle(pose,
      PoseLandmarkType.leftShoulder, PoseLandmarkType.leftElbow, PoseLandmarkType.leftWrist);
    final rightElbow = _safeAngle(pose,
      PoseLandmarkType.rightShoulder, PoseLandmarkType.rightElbow, PoseLandmarkType.rightWrist);
    final bodyLine = _safeAngle(pose,
      PoseLandmarkType.leftShoulder, PoseLandmarkType.leftHip, PoseLandmarkType.leftAnkle);

    final angles = [
      JointAngle(name: 'Left Elbow', angle: leftElbow, minAngle: 80, maxAngle: 175,
          feedback: 'Lower chest closer to floor'),
      JointAngle(name: 'Right Elbow', angle: rightElbow, minAngle: 80, maxAngle: 175,
          feedback: 'Lower chest closer to floor'),
      JointAngle(name: 'Body Line', angle: bodyLine, minAngle: 160, maxAngle: 185,
          feedback: 'Keep hips level — no sagging or piking'),
    ];

    final isDown = (leftElbow > 0 && leftElbow < 120) || (rightElbow > 0 && rightElbow < 120);
    return _buildResult(angles, 'pushup', repIsDown: isDown);
  }

  // ── LUNGE ──
  PostureResult _analyzeLunge(Pose pose) {
    final frontKnee = _safeAngle(pose,
      PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee, PoseLandmarkType.leftAnkle);
    final backKnee = _safeAngle(pose,
      PoseLandmarkType.rightHip, PoseLandmarkType.rightKnee, PoseLandmarkType.rightAnkle);
    final torso = _safeAngle(pose,
      PoseLandmarkType.leftShoulder, PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee);

    final angles = [
      JointAngle(name: 'Front Knee', angle: frontKnee, minAngle: 80, maxAngle: 100,
          feedback: 'Front knee should be at 90°'),
      JointAngle(name: 'Back Knee', angle: backKnee, minAngle: 80, maxAngle: 100,
          feedback: 'Lower back knee closer to ground'),
      JointAngle(name: 'Torso', angle: torso, minAngle: 160, maxAngle: 185,
          feedback: 'Keep torso upright'),
    ];

    final isDown = frontKnee > 0 && frontKnee < 100;
    return _buildResult(angles, 'lunge', repIsDown: isDown);
  }

  // ── PLANK ──
  PostureResult _analyzePlank(Pose pose) {
    final bodyLine = _safeAngle(pose,
      PoseLandmarkType.leftShoulder, PoseLandmarkType.leftHip, PoseLandmarkType.leftAnkle);
    final hipLevel = _safeAngle(pose,
      PoseLandmarkType.rightShoulder, PoseLandmarkType.rightHip, PoseLandmarkType.rightAnkle);
    final shoulderAngle = _safeAngle(pose,
      PoseLandmarkType.leftElbow, PoseLandmarkType.leftShoulder, PoseLandmarkType.leftHip);

    final angles = [
      JointAngle(name: 'Body Alignment', angle: bodyLine, minAngle: 165, maxAngle: 185,
          feedback: 'Raise or lower hips for a straight line'),
      JointAngle(name: 'Hip Level', angle: hipLevel, minAngle: 165, maxAngle: 185,
          feedback: 'Keep hips level — no rotation'),
      JointAngle(name: 'Shoulder Stack', angle: shoulderAngle, minAngle: 80, maxAngle: 100,
          feedback: 'Shoulders should be directly above elbows'),
    ];

    return _buildResult(angles, 'plank', countReps: false);
  }

  // ── DEADLIFT ──
  PostureResult _analyzeDeadlift(Pose pose) {
    final hipHinge = _safeAngle(pose,
      PoseLandmarkType.leftShoulder, PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee);
    final kneeAngle = _safeAngle(pose,
      PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee, PoseLandmarkType.leftAnkle);
    final spineAngle = _safeAngle(pose,
      PoseLandmarkType.nose, PoseLandmarkType.leftShoulder, PoseLandmarkType.leftHip);

    final angles = [
      JointAngle(name: 'Hip Hinge', angle: hipHinge, minAngle: 60, maxAngle: 150,
          feedback: 'Hinge at hips, push them back'),
      JointAngle(name: 'Knee Bend', angle: kneeAngle, minAngle: 140, maxAngle: 175,
          feedback: 'Slight bend in knees, not a squat'),
      JointAngle(name: 'Spine Neutral', angle: spineAngle, minAngle: 160, maxAngle: 185,
          feedback: 'Keep back neutral — no rounding'),
    ];

    final isDown = hipHinge > 0 && hipHinge < 100;
    return _buildResult(angles, 'deadlift', repIsDown: isDown);
  }

  // ── BICEP CURL ──
  PostureResult _analyzeBicepCurl(Pose pose) {
    final leftElbow = _safeAngle(pose,
      PoseLandmarkType.leftShoulder, PoseLandmarkType.leftElbow, PoseLandmarkType.leftWrist);
    final rightElbow = _safeAngle(pose,
      PoseLandmarkType.rightShoulder, PoseLandmarkType.rightElbow, PoseLandmarkType.rightWrist);
    final shoulderStability = _safeAngle(pose,
      PoseLandmarkType.leftElbow, PoseLandmarkType.leftShoulder, PoseLandmarkType.leftHip);

    final angles = [
      JointAngle(name: 'Left Elbow Curl', angle: leftElbow, minAngle: 30, maxAngle: 170,
          feedback: 'Full range: extend fully, curl fully'),
      JointAngle(name: 'Right Elbow Curl', angle: rightElbow, minAngle: 30, maxAngle: 170,
          feedback: 'Full range: extend fully, curl fully'),
      JointAngle(name: 'Elbow Position', angle: shoulderStability, minAngle: 0, maxAngle: 30,
          feedback: 'Keep elbows pinned to your sides'),
    ];

    final isDown = (leftElbow > 0 && leftElbow > 140) || (rightElbow > 0 && rightElbow > 140);
    return _buildResult(angles, 'bicep_curl', repIsDown: isDown);
  }

  // ── SHOULDER PRESS ──
  PostureResult _analyzeShoulderPress(Pose pose) {
    final leftArm = _safeAngle(pose,
      PoseLandmarkType.leftElbow, PoseLandmarkType.leftShoulder, PoseLandmarkType.leftHip);
    final rightArm = _safeAngle(pose,
      PoseLandmarkType.rightElbow, PoseLandmarkType.rightShoulder, PoseLandmarkType.rightHip);
    final elbowAngle = _safeAngle(pose,
      PoseLandmarkType.leftShoulder, PoseLandmarkType.leftElbow, PoseLandmarkType.leftWrist);

    final angles = [
      JointAngle(name: 'Left Arm Press', angle: leftArm, minAngle: 160, maxAngle: 185,
          feedback: 'Fully extend arms overhead'),
      JointAngle(name: 'Right Arm Press', angle: rightArm, minAngle: 160, maxAngle: 185,
          feedback: 'Fully extend arms overhead'),
      JointAngle(name: 'Starting Elbow', angle: elbowAngle, minAngle: 80, maxAngle: 100,
          feedback: 'Start with elbows at 90°'),
    ];

    final isDown = leftArm > 0 && leftArm < 100;
    return _buildResult(angles, 'shoulder_press', repIsDown: isDown);
  }

  // ── SIT-UP ──
  PostureResult _analyzeSitup(Pose pose) {
    final torsoAngle = _safeAngle(pose,
      PoseLandmarkType.leftShoulder, PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee);
    final kneeAngle = _safeAngle(pose,
      PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee, PoseLandmarkType.leftAnkle);
    final neckAngle = _safeAngle(pose,
      PoseLandmarkType.nose, PoseLandmarkType.leftShoulder, PoseLandmarkType.leftHip);

    final angles = [
      JointAngle(name: 'Torso Rise', angle: torsoAngle, minAngle: 60, maxAngle: 130,
          feedback: 'Curl torso all the way up'),
      JointAngle(name: 'Knee Bend', angle: kneeAngle, minAngle: 80, maxAngle: 100,
          feedback: 'Keep knees at 90° throughout'),
      JointAngle(name: 'Neck Neutral', angle: neckAngle, minAngle: 150, maxAngle: 185,
          feedback: 'Keep chin neutral — don\'t strain neck'),
    ];

    final isDown = torsoAngle > 0 && torsoAngle > 110;
    return _buildResult(angles, 'situp', repIsDown: isDown);
  }

  // ── BURPEE ──
  PostureResult _analyzeBurpee(Pose pose) {
    final bodyLine = _safeAngle(pose,
      PoseLandmarkType.leftShoulder, PoseLandmarkType.leftHip, PoseLandmarkType.leftAnkle);
    final armAngle = _safeAngle(pose,
      PoseLandmarkType.leftShoulder, PoseLandmarkType.leftElbow, PoseLandmarkType.leftWrist);
    final hipAngle = _safeAngle(pose,
      PoseLandmarkType.leftShoulder, PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee);

    final angles = [
      JointAngle(name: 'Body Plank', angle: bodyLine, minAngle: 160, maxAngle: 185,
          feedback: 'Maintain straight plank position'),
      JointAngle(name: 'Arms', angle: armAngle, minAngle: 80, maxAngle: 175,
          feedback: 'Full push-up range of motion'),
      JointAngle(name: 'Hip Position', angle: hipAngle, minAngle: 80, maxAngle: 185,
          feedback: 'Control hip movement throughout'),
    ];

    final isDown = bodyLine > 0 && bodyLine > 160 && bodyLine < 185 && armAngle > 0 && armAngle < 120;
    return _buildResult(angles, 'burpee', repIsDown: isDown);
  }

  // ── JUMPING JACK ──
  PostureResult _analyzeJumpingJack(Pose pose) {
    final leftArm = _safeAngle(pose,
      PoseLandmarkType.leftElbow, PoseLandmarkType.leftShoulder, PoseLandmarkType.leftHip);
    final rightArm = _safeAngle(pose,
      PoseLandmarkType.rightElbow, PoseLandmarkType.rightShoulder, PoseLandmarkType.rightHip);
    final legSpread = _safeAngle(pose,
      PoseLandmarkType.leftKnee, PoseLandmarkType.leftHip, PoseLandmarkType.rightHip);

    final angles = [
      JointAngle(name: 'Left Arm Raise', angle: leftArm, minAngle: 150, maxAngle: 185,
          feedback: 'Raise arms fully overhead'),
      JointAngle(name: 'Right Arm Raise', angle: rightArm, minAngle: 150, maxAngle: 185,
          feedback: 'Raise arms fully overhead'),
      JointAngle(name: 'Leg Spread', angle: legSpread, minAngle: 40, maxAngle: 70,
          feedback: 'Jump feet wider apart'),
    ];

    final isUp = leftArm > 0 && leftArm > 150;
    return _buildResult(angles, 'jumping_jack', repIsDown: !isUp);
  }
}
