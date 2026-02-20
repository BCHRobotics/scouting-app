import 'dart:convert';

// blueprints for our app data

// 1. match record
class MatchRecord {
  String matchNum;
  String team;
  String alliance; 
  String timestamp;
  
  // auto data
  String startPos; 
  int preload;
  int autoScoreCount;
  double autoScoreTime;
  int autoPassCount;
  double autoPassTime;
  bool autoPenalty;
  bool autoContrib;
  int autoL; 
  String autoNotes;
  
  // teleop data (hold timers)
  int teleDefCount;
  double teleDefTime;
  int teleColCount;
  double teleColTime;
  int teleShootCount;
  double teleShootTime;
  int telePassCount;
  double telePassTime;
  
  // teleop specifics
  String climbPos; 
  bool disabledTipped;
  bool telePenalty;
  String teleNotes;
  int teleL; // <-- ADDED BACK IN: Teleop Climb Level
  
  // ratings (1-5)
  double rateShoot;
  double rateFeed;
  double rateDef;
  double rateContrib;
  double ratePen;

  MatchRecord({
    required this.matchNum, required this.team, required this.alliance, required this.timestamp,
    
    required this.startPos, required this.preload,
    required this.autoScoreCount, required this.autoScoreTime,
    required this.autoPassCount, required this.autoPassTime,
    required this.autoPenalty, required this.autoContrib, required this.autoL,
    required this.autoNotes,
    
    required this.teleDefCount, required this.teleDefTime,
    required this.teleColCount, required this.teleColTime,
    required this.teleShootCount, required this.teleShootTime,
    required this.telePassCount, required this.telePassTime,
    
    required this.climbPos, required this.disabledTipped, required this.telePenalty, required this.teleNotes, required this.teleL,
    
    required this.rateShoot, required this.rateFeed, required this.rateDef, required this.rateContrib, required this.ratePen,
  });

  Map<String, dynamic> toJson() {
    return {
      'matchNum': matchNum, 'team': team, 'alliance': alliance, 'timestamp': timestamp,
      'startPos': startPos, 'preload': preload,
      'autoScoreCount': autoScoreCount, 'autoScoreTime': autoScoreTime,
      'autoPassCount': autoPassCount, 'autoPassTime': autoPassTime,
      'autoPenalty': autoPenalty, 'autoContrib': autoContrib, 'autoL': autoL,
      'autoNotes': autoNotes,
      
      'teleDefCount': teleDefCount, 'teleDefTime': teleDefTime,
      'teleColCount': teleColCount, 'teleColTime': teleColTime,
      'teleShootCount': teleShootCount, 'teleShootTime': teleShootTime,
      'telePassCount': telePassCount, 'telePassTime': telePassTime,
      
      'climbPos': climbPos, 'disabledTipped': disabledTipped, 'telePenalty': telePenalty, 'teleNotes': teleNotes, 'teleL': teleL,
      
      'rateShoot': rateShoot, 'rateFeed': rateFeed, 'rateDef': rateDef, 'rateContrib': rateContrib, 'ratePen': ratePen,
    };
  }

  factory MatchRecord.fromJson(Map<String, dynamic> json) {
    return MatchRecord(
      matchNum: json['matchNum'] ?? "", team: json['team'] ?? "", alliance: json['alliance'] ?? "", timestamp: json['timestamp'] ?? "",
      startPos: json['startPos'] ?? "", preload: json['preload'] ?? 0,
      autoScoreCount: json['autoScoreCount'] ?? 0, autoScoreTime: (json['autoScoreTime'] ?? 0.0).toDouble(),
      autoPassCount: json['autoPassCount'] ?? 0, autoPassTime: (json['autoPassTime'] ?? 0.0).toDouble(),
      autoPenalty: json['autoPenalty'] ?? false, autoContrib: json['autoContrib'] ?? false, autoL: json['autoL'] ?? 0,
      autoNotes: json['autoNotes'] ?? "",
      
      teleDefCount: json['teleDefCount'] ?? 0, teleDefTime: (json['teleDefTime'] ?? 0.0).toDouble(),
      teleColCount: json['teleColCount'] ?? 0, teleColTime: (json['teleColTime'] ?? 0.0).toDouble(),
      teleShootCount: json['teleShootCount'] ?? 0, teleShootTime: (json['teleShootTime'] ?? 0.0).toDouble(),
      telePassCount: json['telePassCount'] ?? 0, telePassTime: (json['telePassTime'] ?? 0.0).toDouble(),
      
      climbPos: json['climbPos'] ?? "", disabledTipped: json['disabledTipped'] ?? false, telePenalty: json['telePenalty'] ?? false, teleNotes: json['teleNotes'] ?? "", teleL: json['teleL'] ?? 0,
      
      rateShoot: (json['rateShoot'] ?? 1.0).toDouble(), rateFeed: (json['rateFeed'] ?? 1.0).toDouble(), 
      rateDef: (json['rateDef'] ?? 1.0).toDouble(), rateContrib: (json['rateContrib'] ?? 1.0).toDouble(), ratePen: (json['ratePen'] ?? 1.0).toDouble(),
    );
  }

  String toQRString() {
    String aPen = autoPenalty ? 'Yes' : 'No';
    String aCon = autoContrib ? 'Yes' : 'No';
    String tDis = disabledTipped ? 'Yes' : 'No';
    String tPen = telePenalty ? 'Yes' : 'No';
    
    // clean up notes so they don't break the qr tab formatting
    String cleanAuto = autoNotes.replaceAll('\n', ' ').replaceAll('\t', ' ');
    String cleanTele = teleNotes.replaceAll('\n', ' ').replaceAll('\t', ' ');

    return "$matchNum\t$team\t$alliance\t$startPos\t$preload\t$autoScoreCount\t${autoScoreTime.toStringAsFixed(1)}\t"
           "$autoPassCount\t${autoPassTime.toStringAsFixed(1)}\t$aPen\t$aCon\t$autoL\t$cleanAuto\t"
           "$teleDefCount\t${teleDefTime.toStringAsFixed(1)}\t$teleColCount\t${teleColTime.toStringAsFixed(1)}\t"
           "$teleShootCount\t${teleShootTime.toStringAsFixed(1)}\t$telePassCount\t${telePassTime.toStringAsFixed(1)}\t"
           "$climbPos\t$tDis\t$tPen\t$teleL\t${rateShoot.toInt()}\t${rateFeed.toInt()}\t${rateDef.toInt()}\t${rateContrib.toInt()}\t${ratePen.toInt()}\t$cleanTele";
  }
}

// 2. pit record
class PitRecord {
  String team, width, length, height, weight, fuel, fuelPerSec, comments, climbLvl, role;
  bool swerve, tank, trench, bump;
  double stability, accuracy;

  PitRecord({required this.team, required this.width, required this.length, required this.height, required this.weight, required this.swerve, required this.tank, required this.fuel, required this.fuelPerSec, required this.stability, required this.accuracy, required this.comments, required this.trench, required this.bump, required this.climbLvl, required this.role});

  Map<String, dynamic> toJson() => {'team': team, 'width': width, 'length': length, 'height': height, 'weight': weight, 'swerve': swerve, 'tank': tank, 'fuel': fuel, 'fuelPerSec': fuelPerSec, 'stability': stability, 'accuracy': accuracy, 'comments': comments, 'trench': trench, 'bump': bump, 'climb': climbLvl, 'role': role};
  factory PitRecord.fromJson(Map<String, dynamic> json) => PitRecord(team: json['team'] ?? "", width: json['width'] ?? "", length: json['length'] ?? "", height: json['height'] ?? "", weight: json['weight'] ?? "", swerve: json['swerve'] ?? false, tank: json['tank'] ?? false, fuel: json['fuel'] ?? "", fuelPerSec: json['fuelPerSec'] ?? "", stability: (json['stability'] ?? 1.0).toDouble(), accuracy: (json['accuracy'] ?? 0.0).toDouble(), comments: json['comments'] ?? "", trench: json['trench'] ?? false, bump: json['bump'] ?? false, climbLvl: json['climb'] ?? "", role: json['role'] ?? "");
  String toQRString() => "$team\t$width\t$length\t$height\t$weight\t${swerve?1:0}\t${tank?1:0}\t$fuel\t$fuelPerSec\t${stability.toInt()}\t${accuracy.toInt()}\t${trench?1:0}\t${bump?1:0}\t$climbLvl\t$role\t${comments.replaceAll('\n', ' ').replaceAll('\t', ' ')}";
}