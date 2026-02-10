import 'dart:convert';

// ============================================================================
// DATA MODELS
// This file acts as the "Blueprint" for our data. It defines exactly what 
// a "Match" record and a "Pit" record look like.
// ============================================================================

// ----------------------------------------------------------------------------
// 1. MATCH RECORD
// Holds all data for a single match (Auto, Teleop, Notes, etc.)
// ----------------------------------------------------------------------------
class MatchRecord {
  // Metadata
  String matchNum;
  String team;
  String alliance; // "Red" or "Blue"
  String timestamp;
  String notes;
  
  // Scoring Data (Key = "Hub", "Outpost", etc.)
  Map<String, int> autoScores;
  Map<String, int> teleScores;
  int autoL; // Auto Leave Level
  int teleL; // Teleop Climb Level
  
  // Timing Data (How long spent in each zone)
  Map<String, double> autoTimes;
  Map<String, double> teleTimes;
  
  // Qualitative Ratings (Sliders)
  double def;
  double shoot;
  double feed;

  MatchRecord({
    required this.matchNum,
    required this.team,
    required this.alliance,
    required this.timestamp,
    required this.notes,
    required this.autoScores,
    required this.teleScores,
    required this.autoL,
    required this.teleL,
    required this.autoTimes,
    required this.teleTimes,
    required this.def,
    required this.shoot,
    required this.feed,
  });

  // toJson: Converts the Object into a JSON Map (for saving to phone storage)
  Map<String, dynamic> toJson() {
    return {
      'matchNum': matchNum,
      'team': team,
      'alliance': alliance,
      'timestamp': timestamp,
      'notes': notes,
      'autoScores': autoScores,
      'teleScores': teleScores,
      'autoL': autoL,
      'teleL': teleL,
      'autoTimes': autoTimes,
      'teleTimes': teleTimes,
      'def': def,
      'shoot': shoot,
      'feed': feed,
    };
  }

  // fromJson: Converts JSON Map back into an Object (for loading from storage)
  factory MatchRecord.fromJson(Map<String, dynamic> json) {
    return MatchRecord(
      matchNum: json['matchNum'] ?? "",
      team: json['team'] ?? "",
      alliance: json['alliance'] ?? "",
      timestamp: json['timestamp'] ?? "",
      notes: json['notes'] ?? "",
      // Use Map.from to ensure type safety when loading maps
      autoScores: Map<String, int>.from(json['autoScores'] ?? {}),
      teleScores: Map<String, int>.from(json['teleScores'] ?? {}),
      autoL: json['autoL'] ?? 0,
      teleL: json['teleL'] ?? 0,
      autoTimes: Map<String, double>.from(json['autoTimes'] ?? {}),
      teleTimes: Map<String, double>.from(json['teleTimes'] ?? {}),
      def: (json['def'] ?? 0).toDouble(),
      shoot: (json['shoot'] ?? 0).toDouble(),
      feed: (json['feed'] ?? 0).toDouble(),
    );
  }

  // toQRString: Formats data into a tab-separated string for the QR code.
  // This allows Excel/Google Sheets to easily split the data into columns.
  String toQRString() {
    String safeNotes = notes.replaceAll('\n', ' ').replaceAll('\t', ' ');
    return "$team\t$alliance\t$safeNotes\t$autoL\t$teleL\t"
      "${autoScores['outpost']}\t${autoScores['hub']}\t${autoScores['Nz']}\t${autoScores['Oz']}\t"
      "${teleScores['outpost']}\t${teleScores['hub']}\t${teleScores['Nz']}\t${teleScores['Oz']}\t"
      "${autoTimes['Az']?.toStringAsFixed(1)}\t${autoTimes['Nz']?.toStringAsFixed(1)}\t${autoTimes['Oz']?.toStringAsFixed(1)}\t"
      "${teleTimes['Az']?.toStringAsFixed(1)}\t${teleTimes['Nz']?.toStringAsFixed(1)}\t${teleTimes['Oz']?.toStringAsFixed(1)}\t"
      "${def.toInt()}\t${shoot.toInt()}\t${feed.toInt()}"; 
  }
}

// ----------------------------------------------------------------------------
// 2. PIT RECORD
// Holds robot physical data (Weight, Dimensions, Drive Type)
// ----------------------------------------------------------------------------
class PitRecord {
  String team;
  String width, length, weight, bumperThick;
  bool swerve, tank;
  String fuel;
  double stability;
  String comments;
  bool trench, bump;
  String climbLvl;
  String role;

  PitRecord({
    required this.team,
    required this.width, required this.length, required this.weight, required this.bumperThick,
    required this.swerve, required this.tank, 
    required this.fuel, required this.stability, required this.comments,
    required this.trench, required this.bump, required this.climbLvl,
    required this.role
  });

  Map<String, dynamic> toJson() {
    return {
      'team': team, 'width': width, 'length': length, 'weight': weight, 'bumper': bumperThick,
      'swerve': swerve, 'tank': tank, 'fuel': fuel, 'stability': stability, 'comments': comments,
      'trench': trench, 'bump': bump, 'climb': climbLvl, 'role': role
    };
  }

  factory PitRecord.fromJson(Map<String, dynamic> json) {
    return PitRecord(
      team: json['team'] ?? "", 
      width: json['width'] ?? "", length: json['length'] ?? "", 
      weight: json['weight'] ?? "", bumperThick: json['bumper'] ?? "",
      swerve: json['swerve'] ?? false, tank: json['tank'] ?? false, 
      fuel: json['fuel'] ?? "", stability: (json['stability'] ?? 1.0).toDouble(), 
      comments: json['comments'] ?? "",
      trench: json['trench'] ?? false, bump: json['bump'] ?? false, 
      climbLvl: json['climb'] ?? "", role: json['role'] ?? ""
    );
  }

  String toQRString() {
    String cleanNotes = comments.replaceAll('\n', ' ').replaceAll('\t', ' ');
    return "$team\t$width\t$length\t$weight\t$bumperThick\t"
           "${swerve?1:0}\t${tank?1:0}\t$fuel\t$stability\t$cleanNotes\t"
           "${trench?1:0}\t${bump?1:0}\t$climbLvl\t$role";
  }
}