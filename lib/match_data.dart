import 'dart:convert';

// ============================================================================
// DATA MODELS
// ============================================================================

// ----------------------------------------------------------------------------
// 1. MATCH RECORD
// ----------------------------------------------------------------------------
class MatchRecord {
  // Metadata
  String matchNum;
  String team;
  String alliance; 
  String timestamp;
  String notes;
  
  // Auto Data
  String startPos; // "Left", "Center", "Right" (No default)
  int preload;
  int autoScoreCount;
  double autoScoreTime;
  int autoPassCount;
  double autoPassTime;
  bool autoPenalty;
  bool autoContrib;
  int autoL; // Auto Leave Level
  
  // Teleop Data
  Map<String, int> teleScores;
  Map<String, double> teleTimes;
  int teleL; // Teleop Climb Level
  
  // Qualitative Ratings
  double def;
  double shoot;
  double feed;

  MatchRecord({
    required this.matchNum, required this.team, required this.alliance, required this.timestamp, required this.notes,
    required this.startPos, required this.preload,
    required this.autoScoreCount, required this.autoScoreTime,
    required this.autoPassCount, required this.autoPassTime,
    required this.autoPenalty, required this.autoContrib, required this.autoL,
    required this.teleScores, required this.teleTimes, required this.teleL,
    required this.def, required this.shoot, required this.feed,
  });

  Map<String, dynamic> toJson() {
    return {
      'matchNum': matchNum, 'team': team, 'alliance': alliance, 'timestamp': timestamp, 'notes': notes,
      'startPos': startPos, 'preload': preload,
      'autoScoreCount': autoScoreCount, 'autoScoreTime': autoScoreTime,
      'autoPassCount': autoPassCount, 'autoPassTime': autoPassTime,
      'autoPenalty': autoPenalty, 'autoContrib': autoContrib, 'autoL': autoL,
      'teleScores': teleScores, 'teleTimes': teleTimes, 'teleL': teleL,
      'def': def, 'shoot': shoot, 'feed': feed,
    };
  }

  factory MatchRecord.fromJson(Map<String, dynamic> json) {
    return MatchRecord(
      matchNum: json['matchNum'] ?? "", team: json['team'] ?? "", alliance: json['alliance'] ?? "", timestamp: json['timestamp'] ?? "", notes: json['notes'] ?? "",
      startPos: json['startPos'] ?? "", preload: json['preload'] ?? 0,
      autoScoreCount: json['autoScoreCount'] ?? 0, autoScoreTime: (json['autoScoreTime'] ?? 0).toDouble(),
      autoPassCount: json['autoPassCount'] ?? 0, autoPassTime: (json['autoPassTime'] ?? 0).toDouble(),
      autoPenalty: json['autoPenalty'] ?? false, autoContrib: json['autoContrib'] ?? false, autoL: json['autoL'] ?? 0,
      teleScores: Map<String, int>.from(json['teleScores'] ?? {}), teleTimes: Map<String, double>.from(json['teleTimes'] ?? {}), teleL: json['teleL'] ?? 0,
      def: (json['def'] ?? 0).toDouble(), shoot: (json['shoot'] ?? 0).toDouble(), feed: (json['feed'] ?? 0).toDouble(),
    );
  }

  String toQRString() {
    String safeNotes = notes.replaceAll('\n', ' ').replaceAll('\t', ' ');
    return "$team\t$alliance\t$matchNum\t$startPos\t$preload\t"
      "$autoScoreCount\t${autoScoreTime.toStringAsFixed(1)}\t$autoPassCount\t${autoPassTime.toStringAsFixed(1)}\t"
      "${autoPenalty?'Yes':'No'}\t${autoContrib?'Yes':'No'}\t$autoL\t$teleL\t"
      "${teleScores['outpost']}\t${teleScores['hub']}\t${teleScores['Nz']}\t${teleScores['Oz']}\t"
      "${teleTimes['Az']?.toStringAsFixed(1)}\t${teleTimes['Nz']?.toStringAsFixed(1)}\t${teleTimes['Oz']?.toStringAsFixed(1)}\t"
      "${def.toInt()}\t${shoot.toInt()}\t${feed.toInt()}\t$safeNotes"; 
  }
}

// ----------------------------------------------------------------------------
// 2. PIT RECORD
// ----------------------------------------------------------------------------
class PitRecord {
  String team, width, length, height, weight; 
  bool swerve, tank;
  String fuel, fuelPerSec; 
  double stability, accuracy; 
  String comments;
  bool trench, bump;
  String climbLvl, role;

  PitRecord({required this.team, required this.width, required this.length, required this.height, required this.weight, required this.swerve, required this.tank, required this.fuel, required this.fuelPerSec, required this.stability, required this.accuracy, required this.comments, required this.trench, required this.bump, required this.climbLvl, required this.role});

  Map<String, dynamic> toJson() => {'team': team, 'width': width, 'length': length, 'height': height, 'weight': weight, 'swerve': swerve, 'tank': tank, 'fuel': fuel, 'fuelPerSec': fuelPerSec, 'stability': stability, 'accuracy': accuracy, 'comments': comments, 'trench': trench, 'bump': bump, 'climb': climbLvl, 'role': role};
  factory PitRecord.fromJson(Map<String, dynamic> json) => PitRecord(team: json['team'] ?? "", width: json['width'] ?? "", length: json['length'] ?? "", height: json['height'] ?? "", weight: json['weight'] ?? "", swerve: json['swerve'] ?? false, tank: json['tank'] ?? false, fuel: json['fuel'] ?? "", fuelPerSec: json['fuelPerSec'] ?? "", stability: (json['stability'] ?? 1.0).toDouble(), accuracy: (json['accuracy'] ?? 0.0).toDouble(), comments: json['comments'] ?? "", trench: json['trench'] ?? false, bump: json['bump'] ?? false, climbLvl: json['climb'] ?? "", role: json['role'] ?? "");
  String toQRString() => "$team\t$width\t$length\t$height\t$weight\t${swerve?1:0}\t${tank?1:0}\t$fuel\t$fuelPerSec\t$stability\t$accuracy\t${comments.replaceAll('\n', ' ').replaceAll('\t', ' ')}\t${trench?1:0}\t${bump?1:0}\t$climbLvl\t$role";
}