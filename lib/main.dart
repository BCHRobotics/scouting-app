import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:qr/qr.dart';
import 'match_data.dart'; 

// theme colors
class AppColors {
  static const bg = Color(0xFF0F172A);       
  static const card = Color(0xFF334155);     
  static const pitCard = Color(0xFF1E1B4B);  
}

// simple exit confirmation dialog
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

// main dashboard menu
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

// match scouting interface
class MatchScoutingScreen extends StatefulWidget {
  const MatchScoutingScreen({super.key});
  @override
  State<MatchScoutingScreen> createState() => _MatchScoutingScreenState();
}

class _MatchScoutingScreenState extends State<MatchScoutingScreen> {
  int pageIdx = 0; 
  final List<String> pages = ["Auto", "Teleop", "Finalize"];
  String? alliance; 
  final matchCtrl = TextEditingController();
  final teamCtrl = TextEditingController();
  final autoNoteCtrl = TextEditingController();
  final teleNoteCtrl = TextEditingController();

  // auto variables
  String? startPos; 
  int preload = 0;
  int autoScoreCount = 0;
  double autoScoreTime = 0.0;
  double _currHoldScore = 0.0;
  Timer? _scoreTimer;

  int autoPassCount = 0;
  double autoPassTime = 0.0;
  double _currHoldPass = 0.0;
  Timer? _passTimer;

  bool autoPenalty = false;
  bool autoContrib = false;
  int autoL = 0;

  // teleop variables
  int teleDefCount = 0; double teleDefTime = 0.0; double _currHoldDef = 0.0; Timer? _defTimer;
  int teleColCount = 0; double teleColTime = 0.0; double _currHoldCol = 0.0; Timer? _colTimer;
  int teleShootCount = 0; double teleShootTime = 0.0; double _currHoldShoot = 0.0; Timer? _shootTimer;
  int telePassCount = 0; double telePassTime = 0.0; double _currHoldPassT = 0.0; Timer? _passTimerT;
  
  String? climbPos;
  bool disabledTipped = false;
  bool telePenalty = false;

  // rating sliders (1-5)
  double rateShoot = 1.0;
  double rateFeed = 1.0;
  double rateDef = 1.0;
  double rateContrib = 1.0;
  double ratePen = 1.0;

  @override 
  void initState() { 
    super.initState();
    _loadDraft();
    matchCtrl.addListener(_saveDraft);
    teamCtrl.addListener(_saveDraft);
    autoNoteCtrl.addListener(_saveDraft);
    teleNoteCtrl.addListener(_saveDraft);
  }

  @override 
  void dispose() { 
    _scoreTimer?.cancel();
    _passTimer?.cancel();
    _colTimer?.cancel();
    _shootTimer?.cancel();
    _passTimerT?.cancel();
    _defTimer?.cancel();
    
    matchCtrl.removeListener(_saveDraft);
    teamCtrl.removeListener(_saveDraft);
    autoNoteCtrl.removeListener(_saveDraft);
    teleNoteCtrl.removeListener(_saveDraft);
    super.dispose(); 
  }

  // loads saved data if the app was accidentally closed
  Future<void> _loadDraft() async {
    final prefs = await SharedPreferences.getInstance();
    String? jsonStr = prefs.getString('match_draft');
    if (jsonStr != null) {
      try {
        MatchRecord r = MatchRecord.fromJson(jsonDecode(jsonStr));
        setState(() {
          matchCtrl.text = r.matchNum;
          teamCtrl.text = r.team;
          autoNoteCtrl.text = r.autoNotes;
          teleNoteCtrl.text = r.teleNotes;
          if (r.alliance.isNotEmpty) alliance = r.alliance;
          
          startPos = r.startPos.isEmpty ? null : r.startPos;
          preload = r.preload;
          autoScoreCount = r.autoScoreCount; autoScoreTime = r.autoScoreTime;
          autoPassCount = r.autoPassCount; autoPassTime = r.autoPassTime;
          autoPenalty = r.autoPenalty; autoContrib = r.autoContrib; autoL = r.autoL;

          teleDefCount = r.teleDefCount; teleDefTime = r.teleDefTime;
          teleColCount = r.teleColCount; teleColTime = r.teleColTime;
          teleShootCount = r.teleShootCount; teleShootTime = r.teleShootTime;
          telePassCount = r.telePassCount; telePassTime = r.telePassTime;
          
          climbPos = r.climbPos.isEmpty ? null : r.climbPos;
          disabledTipped = r.disabledTipped;
          telePenalty = r.telePenalty;
          
          rateShoot = r.rateShoot; rateFeed = r.rateFeed; rateDef = r.rateDef;
          rateContrib = r.rateContrib; ratePen = r.ratePen;
        });
        if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Draft Restored!"), duration: Duration(milliseconds: 1000)));
      } catch (e) { print("Error loading draft: $e"); }
    }
  }

  // writes state to memory so we don't lose anything
  void _saveDraft() async {
    MatchRecord r = MatchRecord(
      matchNum: matchCtrl.text, team: teamCtrl.text, alliance: alliance ?? "", timestamp: "",
      startPos: startPos ?? "", preload: preload, autoScoreCount: autoScoreCount, autoScoreTime: autoScoreTime,
      autoPassCount: autoPassCount, autoPassTime: autoPassTime, autoPenalty: autoPenalty, autoContrib: autoContrib, autoL: autoL,
      autoNotes: autoNoteCtrl.text,
      
      teleDefCount: teleDefCount, teleDefTime: teleDefTime,
      teleColCount: teleColCount, teleColTime: teleColTime,
      teleShootCount: teleShootCount, teleShootTime: teleShootTime,
      telePassCount: telePassCount, telePassTime: telePassTime,
      
      climbPos: climbPos ?? "", disabledTipped: disabledTipped, telePenalty: telePenalty, teleNotes: teleNoteCtrl.text,
      
      rateShoot: rateShoot, rateFeed: rateFeed, rateDef: rateDef, rateContrib: rateContrib, ratePen: ratePen,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('match_draft', jsonEncode(r.toJson()));
  }

  // helper functions to manage the hold timers cleanly
  void _startTimer(Function(double) onTick, Timer? timerRef, Function(Timer) setTimer) {
    setTimer(Timer.periodic(const Duration(milliseconds: 100), (t) => onTick(0.1)));
  }
  
  void _endTimer(Timer? timerRef, double currentHold, Function(int, double) onComplete) {
    timerRef?.cancel();
    if (currentHold > 0) {
      onComplete(1, currentHold);
    }
    _saveDraft();
  }

  void saveMatch() async {
    if (alliance == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("ERROR: Please Select Alliance!"), backgroundColor: Colors.red)); return; }
    if (matchCtrl.text.isEmpty || teamCtrl.text.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("ERROR: Enter Match & Team #!"), backgroundColor: Colors.red)); return; }
    if (startPos == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("ERROR: Select an Auto Start Position!"), backgroundColor: Colors.red)); return; }
    if (climbPos == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("ERROR: Select a Teleop Climb Position!"), backgroundColor: Colors.red)); return; }
    
    MatchRecord r = MatchRecord(
      matchNum: matchCtrl.text, team: teamCtrl.text, alliance: alliance!, timestamp: DateTime.now().toString(),
      startPos: startPos!, preload: preload, autoScoreCount: autoScoreCount, autoScoreTime: autoScoreTime, autoPassCount: autoPassCount, autoPassTime: autoPassTime, autoPenalty: autoPenalty, autoContrib: autoContrib, autoL: autoL, autoNotes: autoNoteCtrl.text,
      teleDefCount: teleDefCount, teleDefTime: teleDefTime, teleColCount: teleColCount, teleColTime: teleColTime, teleShootCount: teleShootCount, teleShootTime: teleShootTime, telePassCount: telePassCount, telePassTime: telePassTime,
      climbPos: climbPos!, disabledTipped: disabledTipped, telePenalty: telePenalty, teleNotes: teleNoteCtrl.text, 
      rateShoot: rateShoot, rateFeed: rateFeed, rateDef: rateDef, rateContrib: rateContrib, ratePen: ratePen,
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
    Color headColor = [const Color(0xFFD97706), const Color(0xFF2563EB), Colors.purple][pageIdx];
    
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
            IconButton(icon: const Icon(Icons.arrow_back_ios, color: Colors.white), onPressed: () => setState((){ pageIdx = (pageIdx - 1 + pages.length) % pages.length; })),
            // level toggle is only visible on the auto page now since tele has climb level buttons
            if(pageIdx == 0) GestureDetector(
              onTap: () { setState(() { autoL=(autoL+1)%4; _saveDraft(); }); },
              child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: Colors.grey[700], borderRadius: BorderRadius.circular(12)), child: Text("Lvl $autoL", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)))
            ),
            IconButton(icon: const Icon(Icons.arrow_forward_ios, color: Colors.white), onPressed: () => setState((){ pageIdx = (pageIdx + 1) % pages.length; })),
          ]),
        ),
        body: SafeArea(
          child: Column(children: [
            Container(width: double.infinity, padding: const EdgeInsets.all(10), color: headColor, child: Text(pages[pageIdx].toUpperCase(), textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white))),
            Expanded(child: _buildBody()),
            if(pageIdx != 2) _buildBottomBar()
          ]),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if(pageIdx == 0) return _buildAutoView();
    if(pageIdx == 1) return _buildTeleView();
    return _buildSavePage();
  }

  // auto view layout
  Widget _buildAutoView() {
    final screenHeight = MediaQuery.of(context).size.height;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        
        Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: startPos == null ? Colors.redAccent : Colors.transparent, width: 2)), child: Column(children: [
          Text(startPos == null ? "Select Start Position!" : "Start Position", style: TextStyle(color: startPos == null ? Colors.redAccent : Colors.white, fontSize: 18, fontWeight: FontWeight.bold)), const SizedBox(height: 10),
          Row(children: ["Left", "Center", "Right"].map((p) => Expanded(child: GestureDetector(
            onTap: ()=>setState((){ startPos = p; _saveDraft(); }),
            child: Container(margin: const EdgeInsets.symmetric(horizontal: 4), padding: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(color: startPos==p ? Colors.amber[700] : Colors.grey[800], borderRadius: BorderRadius.circular(8)), child: Center(child: Text(p, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16))))
          ))).toList()),
        ])),
        const SizedBox(height: 12),

        Container(
          height: screenHeight * 0.15, 
          padding: const EdgeInsets.all(12), 
          decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(12)), 
          child: Row(children: [
            const Expanded(flex: 2, child: Text("Preload\nScore", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold))),
            Expanded(flex: 1, child: Text("$preload", textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.bold))), 
            const SizedBox(width: 15),
            Expanded(flex: 2, child: _preloadBtn("-1", const Color(0xFF991B1B), () => setState(() { if(preload>0) preload--; _saveDraft(); }))), 
            const SizedBox(width: 10),
            Expanded(flex: 2, child: _preloadBtn("+1", const Color(0xFF15803D), () => setState(() { preload++; _saveDraft(); }))),
          ])
        ),
        const SizedBox(height: 12),

        SizedBox(
          height: screenHeight * 0.25, 
          child: _holdTimerBtn("SCORE", _currHoldScore, autoScoreCount, const Color(0xFF15803D), 
            (_) => _startTimer((v) => setState(() => _currHoldScore += v), _scoreTimer, (t) => _scoreTimer = t),
            (_) => _endTimer(_scoreTimer, _currHoldScore, (c, t) => setState(() { autoScoreCount += c; autoScoreTime += t; _currHoldScore = 0.0; }))
          )
        ),
        const SizedBox(height: 12),

        SizedBox(
          height: screenHeight * 0.25, 
          child: _holdTimerBtn("PASS", _currHoldPass, autoPassCount, const Color(0xFF2563EB), 
            (_) => _startTimer((v) => setState(() => _currHoldPass += v), _passTimer, (t) => _passTimer = t),
            (_) => _endTimer(_passTimer, _currHoldPass, (c, t) => setState(() { autoPassCount += c; autoPassTime += t; _currHoldPass = 0.0; }))
          )
        ),
        const SizedBox(height: 12),

        Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(12)), child: Column(children: [
          _largeCheckbox("Penalty", autoPenalty, Colors.redAccent, (v)=>setState((){autoPenalty=v; _saveDraft();})),
          const SizedBox(height: 15),
          _largeCheckbox("Contributed", autoContrib, Colors.greenAccent, (v)=>setState((){autoContrib=v; _saveDraft();})),
          const SizedBox(height: 20),
          _input(autoNoteCtrl, "Auto Notes...", lines: 3)
        ])),
      ]),
    );
  }

  // teleop view layout (updated with vertical buttons and specific ratings)
  Widget _buildTeleView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        
        // vertical stacked hold timers (big and wide)
        SizedBox(height: 130, child: _holdTimerBtn("DEFENSE", _currHoldDef, teleDefCount, const Color(0xFFD97706), 
          (_) => _startTimer((v) => setState(() => _currHoldDef += v), _defTimer, (t) => _defTimer = t),
          (_) => _endTimer(_defTimer, _currHoldDef, (c, t) => setState(() { teleDefCount += c; teleDefTime += t; _currHoldDef = 0.0; })))),
        const SizedBox(height: 12),
        
        SizedBox(height: 130, child: _holdTimerBtn("COLLECTING", _currHoldCol, teleColCount, const Color(0xFF16A34A), 
          (_) => _startTimer((v) => setState(() => _currHoldCol += v), _colTimer, (t) => _colTimer = t),
          (_) => _endTimer(_colTimer, _currHoldCol, (c, t) => setState(() { teleColCount += c; teleColTime += t; _currHoldCol = 0.0; })))),
        const SizedBox(height: 12),

        SizedBox(height: 130, child: _holdTimerBtn("SHOOTING", _currHoldShoot, teleShootCount, const Color(0xFFDC2626), 
          (_) => _startTimer((v) => setState(() => _currHoldShoot += v), _shootTimer, (t) => _shootTimer = t),
          (_) => _endTimer(_shootTimer, _currHoldShoot, (c, t) => setState(() { teleShootCount += c; teleShootTime += t; _currHoldShoot = 0.0; })))),
        const SizedBox(height: 12),
        
        SizedBox(height: 130, child: _holdTimerBtn("PASSING", _currHoldPassT, telePassCount, const Color(0xFF2563EB), 
          (_) => _startTimer((v) => setState(() => _currHoldPassT += v), _passTimerT, (t) => _passTimerT = t),
          (_) => _endTimer(_passTimerT, _currHoldPassT, (c, t) => setState(() { telePassCount += c; telePassTime += t; _currHoldPassT = 0.0; })))),
        const SizedBox(height: 16),

        // climb position selector
        Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: climbPos == null ? Colors.redAccent : Colors.transparent, width: 2)), child: Column(children: [
          Text(climbPos == null ? "Select Climb Position!" : "Climb Position", style: TextStyle(color: climbPos == null ? Colors.redAccent : Colors.white, fontSize: 18, fontWeight: FontWeight.bold)), const SizedBox(height: 10),
          Row(children: ["Left", "Center", "Right"].map((p) => Expanded(child: GestureDetector(
            onTap: ()=>setState((){ climbPos = p; _saveDraft(); }),
            child: Container(margin: const EdgeInsets.symmetric(horizontal: 4), padding: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(color: climbPos==p ? Colors.blueAccent : Colors.grey[800], borderRadius: BorderRadius.circular(8)), child: Center(child: Text(p, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16))))
          ))).toList()),
        ])),
        const SizedBox(height: 16),

        // penalty and tipped checkboxes
        Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(12)), child: Column(children: [
          _largeCheckbox("Disabled/Tipped", disabledTipped, Colors.orangeAccent, (v)=>setState((){disabledTipped=v; _saveDraft();})),
          const SizedBox(height: 15),
          _largeCheckbox("Penalty", telePenalty, Colors.redAccent, (v)=>setState((){telePenalty=v; _saveDraft();})),
        ])),
        const SizedBox(height: 16),

        // the 5 new rating sliders
        const Text("Qualitative Ratings", textAlign: TextAlign.center, style: TextStyle(color: Colors.white54, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        _ratingSlider("Shooter Accuracy", rateShoot, (v)=>setState((){rateShoot=v; _saveDraft();})),
        _ratingSlider("Feeding Ability", rateFeed, (v)=>setState((){rateFeed=v; _saveDraft();})),
        _ratingSlider("Defense", rateDef, (v)=>setState((){rateDef=v; _saveDraft();})),
        _ratingSlider("Contribution", rateContrib, (v)=>setState((){rateContrib=v; _saveDraft();})),
        _ratingSlider("Penalty Gain", ratePen, (v)=>setState((){ratePen=v; _saveDraft();})),
        
        const SizedBox(height: 16),
        _input(teleNoteCtrl, "Teleop Notes...", lines: 4),
        const SizedBox(height: 20),
          
      ]),
    );
  }

  // final confirmation view
  Widget _buildSavePage() {
    return Padding(padding: const EdgeInsets.all(20), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Text("FINALIZE MATCH", style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)), const SizedBox(height: 30),
      Row(children: [ _allianceBtn("Red", Colors.red), const SizedBox(width: 20), _allianceBtn("Blue", Colors.blue) ]), const SizedBox(height: 20),
      Row(children: [
        Expanded(child: Column(children: [ _input(matchCtrl, "M#", isBig: true), const SizedBox(height: 5), const Text("Match Number", style: TextStyle(color: Colors.grey)) ])),
        const SizedBox(width: 15), 
        Expanded(child: Column(children: [ _input(teamCtrl, "T#", isBig: true), const SizedBox(height: 5), const Text("Team Number", style: TextStyle(color: Colors.grey)) ]))
      ]),
      const SizedBox(height: 40),
      SizedBox(width: double.infinity, height: 70, child: _btn("SAVE & EXIT", Colors.green, saveMatch, isBig: true))
    ]));
  }

  // quick input bar for the bottom of the screen
  Widget _buildBottomBar() {
    return Container(padding: const EdgeInsets.all(8), color: const Color(0xFF1E293B), child: Row(children: [
      Expanded(flex: 2, child: Row(children: [_allianceBtn("Red", Colors.red), const SizedBox(width: 5), _allianceBtn("Blue", Colors.blue)])),
      const SizedBox(width: 8), Expanded(child: _input(matchCtrl, "M#")), const SizedBox(width: 5), Expanded(child: _input(teamCtrl, "T#"))
    ]));
  }

  // reusable ui components
  Widget _btn(String l, Color c, VoidCallback cb, {bool isBig=false}) => ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: c, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), onPressed: cb, child: Text(l, style: TextStyle(color: Colors.white, fontSize: isBig?28:16, fontWeight: FontWeight.bold)));
  Widget _preloadBtn(String l, Color c, VoidCallback cb) => ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: c, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.all(0)), onPressed: cb, child: FittedBox(fit: BoxFit.scaleDown, child: Text(l, style: const TextStyle(fontSize: 40, color: Colors.white, fontWeight: FontWeight.bold))));
  Widget _allianceBtn(String l, Color c) => Expanded(child: GestureDetector(onTap: () { setState(()=>alliance=l); _saveDraft(); }, child: Container(height: 50, decoration: BoxDecoration(color: alliance==l?c:AppColors.card, borderRadius: BorderRadius.circular(8), border: alliance==l?Border.all(color: Colors.white, width: 2):null), child: Center(child: Text(l.toUpperCase(), style: TextStyle(color: alliance==l?Colors.white:c, fontWeight: FontWeight.bold))))));
  Widget _input(TextEditingController c, String h, {int lines=1, Color? color, bool isBig=false}) => TextField(controller: c, maxLines: lines, keyboardType: lines==1?TextInputType.number:TextInputType.text, textAlign: isBig?TextAlign.center:TextAlign.start, style: TextStyle(color: Colors.white, fontSize: isBig?28:18, fontWeight: FontWeight.bold), decoration: InputDecoration(hintText: h, hintStyle: const TextStyle(color: Colors.grey), filled: true, fillColor: color ?? AppColors.card, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12)));
  
  Widget _largeCheckbox(String title, bool val, Color c, Function(bool) onChanged) {
    return GestureDetector(
      onTap: () => onChanged(!val),
      child: Row(children: [
        Transform.scale(scale: 1.8, child: Checkbox(activeColor: c, checkColor: Colors.white, value: val, onChanged: (v) => onChanged(v!))),
        const SizedBox(width: 15),
        Text(title, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
      ]),
    );
  }

  Widget _holdTimerBtn(String title, double currentHold, int count, Color c, Function(TapDownDetails) onDown, Function(dynamic) onUp) {
    bool isHolding = currentHold > 0;
    return GestureDetector(
      onTapDown: onDown, onTapUp: onUp, onTapCancel: () => onUp(null),
      child: Container(
        decoration: BoxDecoration(color: isHolding ? c.withOpacity(0.8) : AppColors.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: c, width: 4)),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text("HOLD FOR $title", textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 2.0)),
          const SizedBox(height: 5),
          FittedBox(fit: BoxFit.scaleDown, child: Text("${currentHold.toStringAsFixed(1)}s", style: TextStyle(color: isHolding ? Colors.white : Colors.white54, fontSize: 50, fontWeight: FontWeight.bold))),
          const SizedBox(height: 5),
          Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6), decoration: BoxDecoration(color: Colors.black38, borderRadius: BorderRadius.circular(8)), child: Text("Count: $count", style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)))
        ]),
      ),
    );
  }

  Widget _ratingSlider(String l, double v, Function(double) f) => Container(margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(12)), child: Column(children: [Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(l, style: const TextStyle(color: Colors.white, fontSize: 18)), Text(v.toInt().toString(), style: const TextStyle(color: Colors.blue, fontSize: 24))]), Slider(value: v, min: 1, max: 5, divisions: 4, onChanged: f)]));
}

// pit scouting screen
class PitScoutingScreen extends StatefulWidget { const PitScoutingScreen({super.key}); @override State<PitScoutingScreen> createState() => _PitScoutingScreenState(); }
class _PitScoutingScreenState extends State<PitScoutingScreen> {
  final teamCtrl = TextEditingController(), wCtrl = TextEditingController(), lCtrl = TextEditingController(), hCtrl = TextEditingController();
  final weightCtrl = TextEditingController(), fuelCtrl = TextEditingController(), fpsCtrl = TextEditingController(), commentCtrl = TextEditingController();
  bool isSwerve = false, isTank = false, isTrench = false, isBump = false;
  double stability = 1.0, accuracy = 0.0;
  String climbLvl = "", role = "";

  void savePit() async {
    if (teamCtrl.text.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Missing Team #"), backgroundColor: Colors.red)); return; }
    PitRecord rec = PitRecord(team: teamCtrl.text, width: wCtrl.text, length: lCtrl.text, height: hCtrl.text, weight: weightCtrl.text, swerve: isSwerve, tank: isTank, fuel: fuelCtrl.text, fuelPerSec: fpsCtrl.text, stability: stability, accuracy: accuracy, comments: commentCtrl.text, trench: isTrench, bump: isBump, climbLvl: climbLvl, role: role);
    final prefs = await SharedPreferences.getInstance();
    List<String> s = prefs.getStringList('frc_pit') ?? [];
    s.add(jsonEncode(rec.toJson()));
    await prefs.setStringList('frc_pit', s);
    if(mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, onPopInvoked: (didPop) async { if (!didPop && await _confirmExit(context, "Exit Pit Scouting?", "You will LOSE unsaved data.") && mounted) Navigator.pop(context); },
      child: Scaffold(backgroundColor: AppColors.bg, body: SafeArea(child: Column(children: [
          Container(padding: const EdgeInsets.all(16), color: Colors.red[900], child: Row(children: [ IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () async { if(await _confirmExit(context, "Exit Pit Scouting?", "You will LOSE unsaved data.") && mounted) Navigator.pop(context); }), Expanded(child: Center(child: SizedBox(width: 150, child: TextField(controller: teamCtrl, keyboardType: TextInputType.number, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold), decoration: const InputDecoration(hintText: "Team #", hintStyle: TextStyle(color: Colors.white60), border: InputBorder.none))))), const SizedBox(width: 40) ])),
          Expanded(child: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(children: [
            _card("Dimensions", [ Row(children: [Expanded(child: _labeledInput(wCtrl, "Width (in)")), const SizedBox(width: 12), Expanded(child: _labeledInput(lCtrl, "Length (in)")), const SizedBox(width: 12), Expanded(child: _labeledInput(hCtrl, "Height (in)"))]), const SizedBox(height: 12), Row(children: [Expanded(child: _labeledInput(weightCtrl, "Weight (lbs)")), const Spacer(flex: 2)]) ]), const SizedBox(height: 16),
            _card("Features", [ Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [_customToggle("Swerve", isSwerve, Colors.greenAccent, ()=>setState((){isSwerve=!isSwerve;if(isSwerve)isTank=false;})), _customToggle("Tank", isTank, Colors.redAccent, ()=>setState((){isTank=!isTank;if(isTank)isSwerve=false;}))]), const SizedBox(height: 16), Row(children: [Expanded(child: _labeledInput(fuelCtrl, "Fuel Capacity")), const SizedBox(width: 12), Expanded(child: _labeledInput(fpsCtrl, "Fuel / Sec"))]), const SizedBox(height: 16), Text("Stability: ${stability.toInt()}", style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)), Slider(value: stability, min: 1, max: 5, divisions: 4, activeColor: Colors.redAccent, label: "${stability.toInt()}", onChanged: (v)=>setState(()=>stability=v)), const SizedBox(height: 16), Text("Accuracy: ${accuracy.toInt()}%", style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)), Slider(value: accuracy, min: 0, max: 100, divisions: 10, activeColor: Colors.blueAccent, label: "${accuracy.toInt()}%", onChanged: (v)=>setState(()=>accuracy=v)), const SizedBox(height: 16), TextField(controller: commentCtrl, maxLines: 4, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white), decoration: InputDecoration(hintText: "Auto Comments", hintStyle: const TextStyle(color: Colors.grey), filled: true, fillColor: const Color(0xFF4B5563), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)))) ]), const SizedBox(height: 16),
            _card("Capabilities", [ Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [_customToggle("Trench", isTrench, Colors.greenAccent, ()=>setState(()=>isTrench=!isTrench)), _customToggle("Bump", isBump, Colors.redAccent, ()=>setState(()=>isBump=!isBump))]), const SizedBox(height: 16), const Text("Climb Level", style: TextStyle(color: Colors.white, fontSize: 16)), const SizedBox(height: 8), Row(children: ["1","2","3"].map((l)=>Expanded(child: GestureDetector(onTap: ()=>setState(()=>climbLvl=l), child: Container(margin: const EdgeInsets.symmetric(horizontal: 4), height: 40, decoration: BoxDecoration(color: climbLvl==l?Colors.orange:Colors.grey[700], borderRadius: BorderRadius.circular(4)), child: Center(child: Text(l, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))))))).toList()) ]), const SizedBox(height: 16),
            _card("Preferred Role", [Row(children: [_roleBtn("Score", Colors.blue), const SizedBox(width: 8), _roleBtn("Pass", Colors.purpleAccent), const SizedBox(width: 8), _roleBtn("Def", Colors.amber)])]), const SizedBox(height: 30),
            ElevatedButton(onPressed: savePit, style: ElevatedButton.styleFrom(backgroundColor: Colors.green, minimumSize: const Size(double.infinity, 50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))), child: const Text("SAVE DATA", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white))), const SizedBox(height: 50),
          ])))
      ]))),
    );
  }
  Widget _card(String title, List<Widget> children) => Container(width: double.infinity, padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: AppColors.pitCard, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white10)), child: Column(children: [Text(title, style: const TextStyle(color: Colors.white, fontSize: 22)), const SizedBox(height: 16), ...children]));
  Widget _labeledInput(TextEditingController c, String l) => Column(children: [SizedBox(height: 45, child: TextField(controller: c, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white), decoration: InputDecoration(filled: true, fillColor: const Color(0xFF4B5563), contentPadding: const EdgeInsets.symmetric(horizontal: 12), border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide.none)))), const SizedBox(height: 4), Text(l, style: const TextStyle(color: Colors.white70, fontSize: 12))]);
  Widget _customToggle(String l, bool a, Color c, VoidCallback t) => GestureDetector(onTap: t, child: Row(children: [Container(width: 40, height: 40, decoration: BoxDecoration(color: a?c:Colors.grey[800], borderRadius: BorderRadius.circular(4))), const SizedBox(width: 10), Text(l, style: const TextStyle(color: Colors.white, fontSize: 18))]));
  Widget _roleBtn(String l, Color c) => Expanded(child: GestureDetector(onTap: ()=>setState(()=>role=l), child: Container(height: 45, decoration: BoxDecoration(color: role==l?c:c.withOpacity(0.3), borderRadius: BorderRadius.circular(4), border: role==l?Border.all(color: Colors.white, width: 2):null), child: Center(child: Text(l, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))))));
}

// history menu
class HistoryScreen extends StatefulWidget { final bool isPit; const HistoryScreen({required this.isPit, super.key}); @override State<HistoryScreen> createState() => _HistoryScreenState(); }
class _HistoryScreenState extends State<HistoryScreen> {
  List<dynamic> history = [];
  @override void initState() { super.initState(); loadData(); }
  void loadData() async { final prefs = await SharedPreferences.getInstance(); List<String> raw = prefs.getStringList(widget.isPit ? 'frc_pit' : 'frc_matches') ?? []; setState(() { history = raw.map((e) => widget.isPit ? PitRecord.fromJson(jsonDecode(e)) : MatchRecord.fromJson(jsonDecode(e))).toList(); if (!widget.isPit) history = history.reversed.toList(); else history.sort((a, b) => int.parse(a.team).compareTo(int.parse(b.team))); }); }
  void deleteItem(int i) async { setState(() => history.removeAt(i)); final prefs = await SharedPreferences.getInstance(); List<dynamic> toSave = widget.isPit ? history : history.reversed.toList(); await prefs.setStringList(widget.isPit ? 'frc_pit' : 'frc_matches', toSave.map((e) => jsonEncode(e.toJson())).toList()); }
  
  void showQR(dynamic rec) { 
    String header = rec is MatchRecord ? "Match ${rec.matchNum} - Team ${rec.team}" : "Team ${rec.team}"; 
    showDialog(context: context, builder: (_) => AlertDialog(
      backgroundColor: AppColors.card,
      title: Text(header, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)), 
      content: Container(
        width: 320, height: 320, 
        padding: const EdgeInsets.all(16), 
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
        child: CustomPaint(painter: QrCodePainter(data: rec.toQRString()))
      ), 
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("CLOSE", style: TextStyle(color: Colors.white)))]
    )); 
  }

  @override Widget build(BuildContext context) { return Scaffold(backgroundColor: AppColors.bg, appBar: AppBar(title: Text(widget.isPit ? "Pit History" : "Match History"), backgroundColor: widget.isPit ? Colors.blue : Colors.amber[800]), body: history.isEmpty ? const Center(child: Text("No Records Found", style: TextStyle(color: Colors.white, fontSize: 20))) : ListView.builder(itemCount: history.length, itemBuilder: (ctx, i) { final rec = history[i]; String title = widget.isPit ? "Team ${rec.team}" : "Match ${rec.matchNum} | Team ${rec.team}"; String sub = widget.isPit ? "Role: ${rec.role}" : "${rec.alliance} | ${rec.timestamp.split(' ')[0]}"; return Card(color: AppColors.card, margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), child: ListTile(title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)), subtitle: Text(sub, style: const TextStyle(color: Colors.grey)), trailing: Row(mainAxisSize: MainAxisSize.min, children: [ IconButton(icon: const Icon(Icons.qr_code, color: Colors.white), onPressed: () => showQR(rec)), IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () async { bool confirm = await _confirmExit(context, "Delete Record?", "This cannot be undone.", yesLabel: "DELETE"); if (confirm) deleteItem(i); }) ]))); })); }
}

// paints the qr codes onto the screen
class QrCodePainter extends CustomPainter { 
  final String data; 
  QrCodePainter({required this.data}); 
  
  @override void paint(Canvas c, Size s) { 
    c.drawRect(Rect.fromLTWH(0, 0, s.width, s.height), Paint()..color = Colors.white);

    final qr = QrCode(15, QrErrorCorrectLevel.L)..addData(data); 
    final img = QrImage(qr); 
    final p = Paint()..style = PaintingStyle.fill..color = Colors.black; 
    final ps = s.width / img.moduleCount; 
    
    for (int x = 0; x < img.moduleCount; x++) { 
      for (int y = 0; y < img.moduleCount; y++) { 
        if (img.isDark(y, x)) c.drawRect(Rect.fromLTWH(x * ps, y * ps, ps, ps), p); 
      } 
    } 
  } 
  
  @override bool shouldRepaint(covariant CustomPainter old) => false; 
}