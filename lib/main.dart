import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:qr/qr.dart';
import 'match_data.dart'; 

// ============================================================================
// SECTION 0: CONSTANTS & HELPERS
// ============================================================================

class AppColors {
  static const bg = Color(0xFF0F172A);       
  static const card = Color(0xFF334155);     
  static const pitCard = Color(0xFF1E1B4B);  
}

Future<bool> _confirmExit(BuildContext context, String title, String msg, {String yesLabel = "EXIT"}) async {
  return (await showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title), content: Text(msg),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true), 
          child: Text(yesLabel, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold))
        ),
      ],
    ),
  )) ?? false;
}

void main() => runApp(MaterialApp(
  debugShowCheckedModeBanner: false, 
  theme: ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.bg, 
    canvasColor: AppColors.bg,             
    appBarTheme: const AppBarTheme(backgroundColor: AppColors.card, elevation: 0),
  ),
  home: const HomeScreen()
));

// ============================================================================
// SECTION 1: HOME SCREEN
// ============================================================================
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(children: [
          Expanded(child: Row(children: [
            _menuBtn(context, "MATCH SCOUTING", Colors.deepPurple, const MatchScoutingScreen()),
            _menuBtn(context, "MATCH HISTORY", Colors.amber[800]!, const HistoryScreen(isPit: false)),
          ])),
          Expanded(child: Row(children: [
            _menuBtn(context, "PIT SCOUTING", Colors.red[800]!, const PitScoutingScreen()),
            _menuBtn(context, "PIT HISTORY", Colors.blue[800]!, const HistoryScreen(isPit: true)),
          ])),
          Padding(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[800], padding: const EdgeInsets.all(20), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                onPressed: () async {
                  if (await _confirmExit(context, "Exit App?", "Are you sure you want to close the app?")) {
                    Platform.isAndroid ? SystemNavigator.pop() : exit(0);
                  }
                },
                child: const Text("EXIT APP", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.redAccent))
              ),
            ),
          )
        ]),
      ),
    );
  }

  Widget _menuBtn(BuildContext ctx, String txt, Color c, Widget page) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: c, 
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            minimumSize: const Size.fromHeight(double.infinity) 
          ),
          onPressed: () => Navigator.push(ctx, MaterialPageRoute(builder: (_) => page)),
          child: Text(txt, textAlign: TextAlign.center, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
        ),
      ),
    );
  }
}

// ============================================================================
// SECTION 2: MATCH SCOUTING SCREEN
// ============================================================================
class MatchScoutingScreen extends StatefulWidget {
  const MatchScoutingScreen({super.key});
  @override
  State<MatchScoutingScreen> createState() => _MatchScoutingScreenState();
}

class _MatchScoutingScreenState extends State<MatchScoutingScreen> {
  int pageIdx = 0; 
  final List<String> pages = ["Auto", "Tele", "Ratings", "Finalize"];
  String activeZone = "Az"; 
  String? alliance; 
  
  bool timerRunning = false;
  Timer? _timer;

  Map<String, int> autoScores = {"outpost": 0, "hub": 0, "Nz": 0, "Oz": 0};
  Map<String, int> teleScores = {"outpost": 0, "hub": 0, "Nz": 0, "Oz": 0};
  Map<String, double> autoTimes = {"Az": 0.0, "Nz": 0.0, "Oz": 0.0};
  Map<String, double> teleTimes = {"Az": 0.0, "Nz": 0.0, "Oz": 0.0};
  int autoL = 0, teleL = 0;
  double def = 0, shoot = 0, feed = 0;
  
  final matchCtrl = TextEditingController();
  final teamCtrl = TextEditingController();
  final noteCtrl = TextEditingController();

  Map<String, int> get currentScores => pageIdx == 0 ? autoScores : teleScores;
  Map<String, double> get currentTimes => pageIdx == 0 ? autoTimes : teleTimes;

  @override 
  void initState() { 
    super.initState();
    _loadDraft();
    matchCtrl.addListener(_saveDraft);
    teamCtrl.addListener(_saveDraft);
    noteCtrl.addListener(_saveDraft);
  }

  @override 
  void dispose() { 
    _timer?.cancel(); 
    matchCtrl.removeListener(_saveDraft);
    teamCtrl.removeListener(_saveDraft);
    noteCtrl.removeListener(_saveDraft);
    super.dispose(); 
  }

  Future<void> _loadDraft() async {
    final prefs = await SharedPreferences.getInstance();
    String? jsonStr = prefs.getString('match_draft');
    if (jsonStr != null) {
      try {
        MatchRecord r = MatchRecord.fromJson(jsonDecode(jsonStr));
        setState(() {
          matchCtrl.text = r.matchNum;
          teamCtrl.text = r.team;
          noteCtrl.text = r.notes;
          if (r.alliance.isNotEmpty) alliance = r.alliance;
          
          autoScores = Map.from(r.autoScores);
          teleScores = Map.from(r.teleScores);
          autoTimes = Map.from(r.autoTimes);
          teleTimes = Map.from(r.teleTimes);
          
          autoL = r.autoL;
          teleL = r.teleL;
          def = r.def;
          shoot = r.shoot;
          feed = r.feed;
        });
        if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Draft Restored!"), duration: Duration(milliseconds: 1000)));
      } catch (e) { print("Error loading draft: $e"); }
    }
  }

  void _saveDraft() async {
    MatchRecord r = MatchRecord(
      matchNum: matchCtrl.text, team: teamCtrl.text, alliance: alliance ?? "", timestamp: "",
      notes: noteCtrl.text, autoScores: autoScores, teleScores: teleScores,
      autoL: autoL, teleL: teleL, autoTimes: autoTimes, teleTimes: teleTimes,
      def: def, shoot: shoot, feed: feed,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('match_draft', jsonEncode(r.toJson()));
  }

  void toggleTimer() {
    setState(() => timerRunning = !timerRunning);
    if (timerRunning) {
      _timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
        setState(() => currentTimes[activeZone] = (currentTimes[activeZone] ?? 0) + 0.1);
        _saveDraft(); 
      });
    } else { 
      _timer?.cancel();
      _saveDraft();
    }
  }

  void updateScore(String key, int delta) {
    setState(() {
      if ((currentScores[key] ?? 0) + delta >= 0) {
        currentScores[key] = (currentScores[key] ?? 0) + delta;
      }
    });
    _saveDraft();
  }

  void saveMatch() async {
    if (alliance == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("ERROR: Please Select Alliance!"), backgroundColor: Colors.red));
      return;
    }
    if (matchCtrl.text.isEmpty || teamCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("ERROR: Enter Match & Team #!"), backgroundColor: Colors.red));
      return;
    }
    MatchRecord r = MatchRecord(
      matchNum: matchCtrl.text, team: teamCtrl.text, alliance: alliance!, timestamp: DateTime.now().toString(),
      notes: noteCtrl.text, autoScores: Map.from(autoScores), teleScores: Map.from(teleScores),
      autoL: autoL, teleL: teleL, autoTimes: Map.from(autoTimes), teleTimes: Map.from(teleTimes),
      def: def, shoot: shoot, feed: feed,
    );
    
    final prefs = await SharedPreferences.getInstance();
    List<String> s = prefs.getStringList('frc_matches') ?? [];
    s.add(jsonEncode(r.toJson()));
    await prefs.setStringList('frc_matches', s);
    await prefs.remove('match_draft');
    
    if(mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    Color headColor = [const Color(0xFFD97706), const Color(0xFF2563EB), const Color(0xFF16A34A), Colors.purple][pageIdx];
    
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async { 
        if (!didPop && await _confirmExit(context, "Exit Scouting?", "Draft will be saved.") && mounted) Navigator.pop(context); 
      },
      child: Scaffold(
        backgroundColor: AppColors.bg,
        appBar: AppBar(
          backgroundColor: AppColors.card,
          leading: IconButton(icon: const Icon(Icons.close, color: Colors.redAccent), onPressed: () async { 
            if(await _confirmExit(context, "Exit Scouting?", "Draft will be saved.") && mounted) Navigator.pop(context); 
          }),
          title: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            IconButton(icon: const Icon(Icons.arrow_back_ios, color: Colors.white), onPressed: () => setState((){ _timer?.cancel(); timerRunning=false; pageIdx = (pageIdx - 1 + pages.length) % pages.length; if(pageIdx<2) activeZone="Az"; })),
            if(pageIdx < 2) GestureDetector(
              onTap: () { if(timerRunning) setState(() { pageIdx==0 ? autoL=(autoL+1)%4 : teleL=(teleL+1)%4; _saveDraft(); }); },
              child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: timerRunning ? Colors.blue : Colors.grey[700], borderRadius: BorderRadius.circular(12)), child: Text("Lvl ${pageIdx==0?autoL:teleL}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)))
            ),
            IconButton(icon: const Icon(Icons.arrow_forward_ios, color: Colors.white), onPressed: () => setState((){ _timer?.cancel(); timerRunning=false; pageIdx = (pageIdx + 1) % pages.length; if(pageIdx<2) activeZone="Az"; })),
          ]),
        ),
        body: SafeArea(
          child: Column(children: [
            Container(width: double.infinity, padding: const EdgeInsets.all(10), color: headColor, child: Text(pages[pageIdx].toUpperCase(), textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white))),
            Expanded(child: _buildBody()),
            if(pageIdx != 3) _buildBottomBar()
          ]),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if(pageIdx < 2) return _buildScoring();
    if(pageIdx == 2) return _buildRatings();
    return _buildSavePage();
  }

  Widget _buildScoring() {
    return Column(children: [
      Padding(padding: const EdgeInsets.all(8), child: Row(children: ["Az", "Nz", "Oz"].map((z) => Expanded(child: GestureDetector(
        onTap: ()=>setState(()=>activeZone=z),
        child: Container(margin: const EdgeInsets.all(4), padding: const EdgeInsets.symmetric(vertical: 16), decoration: BoxDecoration(color: activeZone==z ? const Color(0xFF991B1B) : AppColors.card, borderRadius: BorderRadius.circular(12), border: activeZone==z ? Border.all(color: const Color(0xFFFCA5A5), width: 2) : null), child: Center(child: Text(z, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20))))
      ))).toList())),
      Expanded(child: activeZone == "Az" ? _buildAzView() : _buildPassView()),
    ]);
  }

  Widget _buildAzView() {
    return Column(children: [
      Container(margin: const EdgeInsets.all(12), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(12)), child: Column(children: [
        Text(timerRunning ? "RUNNING" : "PAUSED", style: TextStyle(color: timerRunning ? Colors.green : Colors.red, fontSize: 12)),
        Text("${(currentTimes['Az']??0).toStringAsFixed(1)}s", style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.bold)),
        Row(children: [ _timeBtn("Start", Colors.green), const SizedBox(width: 5), _timeBtn("Stop", Colors.red), const SizedBox(width: 5), Expanded(child: _btn("Reset", Colors.grey, (){_timer?.cancel(); setState((){timerRunning=false; currentTimes['Az']=0; _saveDraft();});})) ])
      ])),
      Expanded(child: _scoreRow("OUTPOST", "outpost", false)),
      Expanded(child: _scoreRow("HUB", "hub", true)),
    ]);
  }

  Widget _buildPassView() {
    return Container(margin: const EdgeInsets.all(12), padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(12)), child: Column(children: [
      Text("Passing ($activeZone)", style: const TextStyle(color: Colors.white, fontSize: 24)),
      Expanded(flex: 3, child: Center(child: Text("${currentScores[activeZone]}", style: const TextStyle(color: Colors.white, fontSize: 100, fontWeight: FontWeight.bold)))),
      Expanded(flex: 4, child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Expanded(flex: 1, child: _scoreBtn("-1", const Color(0xFF991B1B), () => updateScore(activeZone, -1))), 
        const SizedBox(width: 15),
        Expanded(flex: 2, child: _scoreBtn("+1", const Color(0xFF15803D), () => updateScore(activeZone, 1))),
      ]))
    ]));
  }

  Widget _scoreRow(String t, String k, bool ten) {
    return Container(margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5), padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(12)), child: Column(children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(t, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)), Text("${currentScores[k]}", style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold))]),
      Expanded(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Expanded(flex: 1, child: _scoreBtn("-1", const Color(0xFF991B1B), () => updateScore(k, -1))), 
        const SizedBox(width: 10),
        Expanded(flex: 2, child: _scoreBtn("+1", const Color(0xFF15803D), () => updateScore(k, 1))),
        if(ten) ...[const SizedBox(width: 10), Expanded(flex: 2, child: _scoreBtn("+10", const Color(0xFF15803D), () => updateScore(k, 10)))]
      ]))
    ]));
  }

  Widget _buildRatings() {
    return ListView(padding: const EdgeInsets.all(16), children: [
      for(var i in [["Defense", def], ["Shooter", shoot], ["Feeder", feed]]) 
        _ratingSlider(i[0] as String, i[1] as double, (v)=>setState((){
          if(i[0]=="Defense")def=v;else if(i[0]=="Shooter")shoot=v;else feed=v;
          _saveDraft();
        })),
      _input(noteCtrl, "Notes...", lines: 5, color: AppColors.card)
    ]);
  }

  Widget _buildSavePage() {
    return Padding(padding: const EdgeInsets.all(20), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Text("FINALIZE MATCH", style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)), const SizedBox(height: 30),
      Row(children: [ _allianceBtn("Red", Colors.red), const SizedBox(width: 20), _allianceBtn("Blue", Colors.blue) ]), const SizedBox(height: 20),
      Row(children: [
        Expanded(child: Column(children: [ _input(matchCtrl, "M#", isBig: true), const SizedBox(height: 5), const Text("Match Number", style: TextStyle(color: Colors.grey)) ])),
        const SizedBox(width: 15), 
        Expanded(child: Column(children: [ _input(teamCtrl, "T#", isBig: true), const SizedBox(height: 5), const Text("Team Number", style: TextStyle(color: Colors.grey)) ]))
      ]),
      const SizedBox(height: 50),
      SizedBox(width: double.infinity, height: 70, child: _btn("SAVE & EXIT", Colors.green, saveMatch, isBig: true))
    ]));
  }

  Widget _buildBottomBar() {
    return Container(padding: const EdgeInsets.all(8), color: const Color(0xFF1E293B), child: Row(children: [
      Expanded(flex: 2, child: Row(children: [_allianceBtn("Red", Colors.red), const SizedBox(width: 5), _allianceBtn("Blue", Colors.blue)])),
      const SizedBox(width: 8), Expanded(child: _input(matchCtrl, "M#")), const SizedBox(width: 5), Expanded(child: _input(teamCtrl, "T#"))
    ]));
  }

  Widget _btn(String l, Color c, VoidCallback cb, {bool isBig=false}) => ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: c, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), onPressed: cb, child: Text(l, style: TextStyle(color: Colors.white, fontSize: isBig?28:16, fontWeight: FontWeight.bold)));
  Widget _timeBtn(String l, Color c) => Expanded(child: _btn(l, c, toggleTimer));
  Widget _scoreBtn(String l, Color c, VoidCallback cb) => ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: timerRunning?c:Colors.grey[800], shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.all(0)), onPressed: timerRunning?cb:null, child: FittedBox(fit: BoxFit.scaleDown, child: Text(l, style: const TextStyle(fontSize: 28, color: Colors.white))));
  Widget _allianceBtn(String l, Color c) => Expanded(child: GestureDetector(onTap: () { setState(()=>alliance=l); _saveDraft(); }, child: Container(height: 50, decoration: BoxDecoration(color: alliance==l?c:AppColors.card, borderRadius: BorderRadius.circular(8), border: alliance==l?Border.all(color: Colors.white, width: 2):null), child: Center(child: Text(l.toUpperCase(), style: TextStyle(color: alliance==l?Colors.white:c, fontWeight: FontWeight.bold))))));
  Widget _input(TextEditingController c, String h, {int lines=1, Color? color, bool isBig=false}) => TextField(controller: c, maxLines: lines, keyboardType: lines==1?TextInputType.number:TextInputType.text, textAlign: isBig?TextAlign.center:TextAlign.start, style: TextStyle(color: Colors.white, fontSize: isBig?28:18, fontWeight: FontWeight.bold), decoration: InputDecoration(hintText: h, hintStyle: const TextStyle(color: Colors.grey), filled: true, fillColor: color ?? AppColors.card, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12)));
  Widget _ratingSlider(String l, double v, Function(double) f) => Container(margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(12)), child: Column(children: [Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(l, style: const TextStyle(color: Colors.white, fontSize: 18)), Text(v.toInt().toString(), style: const TextStyle(color: Colors.blue, fontSize: 24))]), Slider(value: v, min: 0, max: 5, divisions: 5, onChanged: f)]));
}

// ============================================================================
// SECTION 3: PIT SCOUTING SCREEN
// ============================================================================
class PitScoutingScreen extends StatefulWidget {
  const PitScoutingScreen({super.key});
  @override
  State<PitScoutingScreen> createState() => _PitScoutingScreenState();
}

class _PitScoutingScreenState extends State<PitScoutingScreen> {
  // TEXT CONTROLLERS (Removed Bumper Thickness, Added Height & Fuel/Sec)
  final teamCtrl = TextEditingController(), wCtrl = TextEditingController(), lCtrl = TextEditingController(), hCtrl = TextEditingController();
  final weightCtrl = TextEditingController(), fuelCtrl = TextEditingController(), fpsCtrl = TextEditingController(), commentCtrl = TextEditingController();
  
  // TOGGLES & SLIDERS
  bool isSwerve = false, isTank = false, isTrench = false, isBump = false;
  double stability = 1.0, accuracy = 0.0;
  String climbLvl = "", role = "";

  void savePit() async {
    if (teamCtrl.text.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Missing Team #"), backgroundColor: Colors.red)); return; }
    PitRecord rec = PitRecord(
      team: teamCtrl.text, 
      width: wCtrl.text, length: lCtrl.text, height: hCtrl.text, weight: weightCtrl.text, 
      swerve: isSwerve, tank: isTank, 
      fuel: fuelCtrl.text, fuelPerSec: fpsCtrl.text, stability: stability, accuracy: accuracy, comments: commentCtrl.text, 
      trench: isTrench, bump: isBump, climbLvl: climbLvl, role: role
    );
    final prefs = await SharedPreferences.getInstance();
    List<String> s = prefs.getStringList('frc_pit') ?? [];
    s.add(jsonEncode(rec.toJson()));
    await prefs.setStringList('frc_pit', s);
    if(mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async { if (!didPop && await _confirmExit(context, "Exit Pit Scouting?", "You will LOSE unsaved data.") && mounted) Navigator.pop(context); },
      child: Scaffold(
        backgroundColor: AppColors.bg,
        body: SafeArea(child: Column(children: [
          // Header
          Container(padding: const EdgeInsets.all(16), color: Colors.red[900], child: Row(children: [
            IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () async { if(await _confirmExit(context, "Exit Pit Scouting?", "You will LOSE unsaved data.") && mounted) Navigator.pop(context); }),
            Expanded(child: Center(child: SizedBox(width: 150, child: TextField(controller: teamCtrl, keyboardType: TextInputType.number, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold), decoration: const InputDecoration(hintText: "Team #", hintStyle: TextStyle(color: Colors.white60), border: InputBorder.none))))),
            const SizedBox(width: 40)
          ])),
          // Content
          Expanded(child: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(children: [
            
            // Dimensions Card
            _card("Dimensions", [
              Row(children: [Expanded(child: _labeledInput(wCtrl, "Width (in)")), const SizedBox(width: 12), Expanded(child: _labeledInput(lCtrl, "Length (in)")), const SizedBox(width: 12), Expanded(child: _labeledInput(hCtrl, "Height (in)"))]), 
              const SizedBox(height: 12),
              // We pad the weight box with empty Spacers so it doesn't stretch huge across the screen
              Row(children: [Expanded(child: _labeledInput(weightCtrl, "Weight (lbs)")), const Spacer(flex: 2)]),
            ]),
            const SizedBox(height: 16),
            
            // Features Card
            _card("Features", [
              Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [_customToggle("Swerve", isSwerve, Colors.greenAccent, ()=>setState((){isSwerve=!isSwerve;if(isSwerve)isTank=false;})), _customToggle("Tank", isTank, Colors.redAccent, ()=>setState((){isTank=!isTank;if(isTank)isSwerve=false;}))]),
              const SizedBox(height: 16), 
              
              Row(children: [Expanded(child: _labeledInput(fuelCtrl, "Fuel Capacity")), const SizedBox(width: 12), Expanded(child: _labeledInput(fpsCtrl, "Fuel / Sec"))]), const SizedBox(height: 16),
              
              Text("Stability: ${stability.toInt()}", style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              Slider(value: stability, min: 1, max: 5, divisions: 4, activeColor: Colors.redAccent, label: "${stability.toInt()}", onChanged: (v)=>setState(()=>stability=v)),
              const SizedBox(height: 16),
              
              Text("Accuracy: ${accuracy.toInt()}%", style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              Slider(value: accuracy, min: 0, max: 100, divisions: 10, activeColor: Colors.blueAccent, label: "${accuracy.toInt()}%", onChanged: (v)=>setState(()=>accuracy=v)),
              const SizedBox(height: 16),
              
              TextField(controller: commentCtrl, maxLines: 4, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white), decoration: InputDecoration(hintText: "Auto Comments", hintStyle: const TextStyle(color: Colors.grey), filled: true, fillColor: const Color(0xFF4B5563), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))))
            ]),
            const SizedBox(height: 16),
            
            // Capabilities Card
            _card("Capabilities", [
              Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [_customToggle("Trench", isTrench, Colors.greenAccent, ()=>setState(()=>isTrench=!isTrench)), _customToggle("Bump", isBump, Colors.redAccent, ()=>setState(()=>isBump=!isBump))]),
              const SizedBox(height: 16), const Text("Climb Level", style: TextStyle(color: Colors.white, fontSize: 16)), const SizedBox(height: 8),
              Row(children: ["1","2","3"].map((l)=>Expanded(child: GestureDetector(onTap: ()=>setState(()=>climbLvl=l), child: Container(margin: const EdgeInsets.symmetric(horizontal: 4), height: 40, decoration: BoxDecoration(color: climbLvl==l?Colors.orange:Colors.grey[700], borderRadius: BorderRadius.circular(4)), child: Center(child: Text(l, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))))))).toList())
            ]),
            const SizedBox(height: 16),
            
            // Preferred Role Card
            _card("Preferred Role", [Row(children: [_roleBtn("Score", Colors.blue), const SizedBox(width: 8), _roleBtn("Pass", Colors.purpleAccent), const SizedBox(width: 8), _roleBtn("Def", Colors.amber)])]),
            const SizedBox(height: 30),
            ElevatedButton(onPressed: savePit, style: ElevatedButton.styleFrom(backgroundColor: Colors.green, minimumSize: const Size(double.infinity, 50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))), child: const Text("SAVE DATA", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white))),
            const SizedBox(height: 50),
          ])))
        ])),
      ),
    );
  }

  Widget _card(String title, List<Widget> children) => Container(width: double.infinity, padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: AppColors.pitCard, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white10)), child: Column(children: [Text(title, style: const TextStyle(color: Colors.white, fontSize: 22)), const SizedBox(height: 16), ...children]));
  Widget _labeledInput(TextEditingController c, String l) => Column(children: [SizedBox(height: 45, child: TextField(controller: c, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white), decoration: InputDecoration(filled: true, fillColor: const Color(0xFF4B5563), contentPadding: const EdgeInsets.symmetric(horizontal: 12), border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide.none)))), const SizedBox(height: 4), Text(l, style: const TextStyle(color: Colors.white70, fontSize: 12))]);
  Widget _customToggle(String l, bool a, Color c, VoidCallback t) => GestureDetector(onTap: t, child: Row(children: [Container(width: 40, height: 40, decoration: BoxDecoration(color: a?c:Colors.grey[800], borderRadius: BorderRadius.circular(4))), const SizedBox(width: 10), Text(l, style: const TextStyle(color: Colors.white, fontSize: 18))]));
  Widget _roleBtn(String l, Color c) => Expanded(child: GestureDetector(onTap: ()=>setState(()=>role=l), child: Container(height: 45, decoration: BoxDecoration(color: role==l?c:c.withOpacity(0.3), borderRadius: BorderRadius.circular(4), border: role==l?Border.all(color: Colors.white, width: 2):null), child: Center(child: Text(l, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))))));
}

// ============================================================================
// SECTION 4: HISTORY SCREEN
// ============================================================================
class HistoryScreen extends StatefulWidget {
  final bool isPit;
  const HistoryScreen({required this.isPit, super.key});
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<dynamic> history = [];
  @override void initState() { super.initState(); loadData(); }
  
  void loadData() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> raw = prefs.getStringList(widget.isPit ? 'frc_pit' : 'frc_matches') ?? [];
    setState(() {
      history = raw.map((e) => widget.isPit ? PitRecord.fromJson(jsonDecode(e)) : MatchRecord.fromJson(jsonDecode(e))).toList();
      if (!widget.isPit) history = history.reversed.toList();
      else history.sort((a, b) => int.parse(a.team).compareTo(int.parse(b.team)));
    });
  }

  void deleteItem(int i) async {
    setState(() => history.removeAt(i));
    final prefs = await SharedPreferences.getInstance();
    List<dynamic> toSave = widget.isPit ? history : history.reversed.toList();
    await prefs.setStringList(widget.isPit ? 'frc_pit' : 'frc_matches', toSave.map((e) => jsonEncode(e.toJson())).toList());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: Text(widget.isPit ? "Pit History" : "Match History"), backgroundColor: widget.isPit ? Colors.blue : Colors.amber[800]),
      body: history.isEmpty 
        ? const Center(child: Text("No Records Found", style: TextStyle(color: Colors.white, fontSize: 20)))
        : ListView.builder(itemCount: history.length, itemBuilder: (ctx, i) {
            final rec = history[i];
            String title = widget.isPit ? "Team ${rec.team}" : "Match ${rec.matchNum} | Team ${rec.team}";
            String sub = widget.isPit ? "Role: ${rec.role}" : "${rec.alliance} | ${rec.timestamp.split(' ')[0]}";
            
            return Card(color: AppColors.card, margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), child: ListTile(
              title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              subtitle: Text(sub, style: const TextStyle(color: Colors.grey)),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton(icon: const Icon(Icons.qr_code, color: Colors.white), onPressed: () => showQR(rec)), 
                IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () async {
                  bool confirm = await _confirmExit(context, "Delete Record?", "This cannot be undone.", yesLabel: "DELETE");
                  if (confirm) deleteItem(i);
                })
              ]),
            ));
          }),
    );
  }

  void showQR(dynamic rec) {
    String header = rec is MatchRecord ? "Match ${rec.matchNum} - Team ${rec.team}" : "Team ${rec.team}";
    showDialog(context: context, builder: (_) => AlertDialog(
      title: Text(header, style: const TextStyle(fontWeight: FontWeight.bold)),
      content: SizedBox(width: 250, height: 250, child: CustomPaint(painter: QrCodePainter(data: rec.toQRString()))), 
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("CLOSE"))]
    ));
  }
}

// ============================================================================
// SECTION 5: QR PAINTER
// ============================================================================
class QrCodePainter extends CustomPainter {
  final String data;
  QrCodePainter({required this.data});
  @override
  void paint(Canvas c, Size s) {
    final qr = QrCode(40, QrErrorCorrectLevel.L)..addData(data);
    final img = QrImage(qr);
    final p = Paint()..style = PaintingStyle.fill..color = Colors.black;
    final ps = s.width / img.moduleCount;
    for (int x = 0; x < img.moduleCount; x++) {
      for (int y = 0; y < img.moduleCount; y++) {
        if (img.isDark(y, x)) c.drawRect(Rect.fromLTWH(x * ps, y * ps, ps, ps), p);
      }
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}