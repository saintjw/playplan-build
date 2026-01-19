import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart'; 
import 'package:cloud_firestore/cloud_firestore.dart'; 
import 'package:firebase_auth/firebase_auth.dart'; 
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
// import 'dart:html' as html; // ★ 삭제: 안드로이드 빌드 에러의 주범!

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: "AIzaSyBezDEy56DfOTOwGnyNT0_gVz0nVm1nHyw",
      authDomain: "pla-y-e6bfe.firebaseapp.com",
      projectId: "pla-y-e6bfe",
      storageBucket: "pla-y-e6bfe.firebasestorage.app",
      messagingSenderId: "199649538352",
      appId: "1:199649538352:web:4b39644e17754cce0cd8f5"
    ),
  );
  runApp(const PlaYApp());
}

class PlaYApp extends StatelessWidget {
  const PlaYApp({super.key});
  @override
  Widget build(BuildContext context) {
    // 모바일에서는 URL 파라미터를 직접 받을 수 없으므로 우선 기본 화면으로 시작합니다.
    // (딥링크 기능은 추후 고도화 단계에서 추가 가능)
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color(0xFFFF6B6B),
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFFF6B6B)),
        useMaterial3: true,
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Scaffold(body: Center(child: CircularProgressIndicator()));
          if (snapshot.hasData) return const PlanListScreen();
          return const LoginScreen();
        },
      ),
    );
  }
}

// --- 0. 로그인 화면 ---
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});
  Future<void> _signInWithGoogle() async {
    // 안드로이드에서는 구글 로그인 설정이 추가로 필요할 수 있지만, 
    // 우선 웹 기반 설정으로 시도합니다.
    GoogleAuthProvider googleProvider = GoogleAuthProvider();
    await FirebaseAuth.instance.signInWithPopup(googleProvider);
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text("Pla-Y 🎈", style: TextStyle(fontSize: 45, fontWeight: FontWeight.bold, color: Color(0xFFFF6B6B))),
            const SizedBox(height: 60),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15)),
              onPressed: _signInWithGoogle,
              icon: const Icon(Icons.login_rounded),
              label: const Text("Google 계정으로 시작하기"),
            ),
          ],
        ),
      ),
    );
  }
}

// --- 1. 플랜 목록 화면 ---
class PlanListScreen extends StatefulWidget {
  const PlanListScreen({super.key});
  @override
  State<PlanListScreen> createState() => _PlanListScreenState();
}

class _PlanListScreenState extends State<PlanListScreen> {
  final _planTitleController = TextEditingController();
  Color _selectedColor = const Color(0xFFFFAB91);
  final List<Color> _colorPalette = [const Color(0xFFFFAB91), const Color(0xFF90CAF9), const Color(0xFFC5E1A5), const Color(0xFFCE93D8), const Color(0xFFFFCC80)];

  String get uid => FirebaseAuth.instance.currentUser!.uid;
  CollectionReference get userPlans => FirebaseFirestore.instance.collection('users').doc(uid).collection('plans');

  void _showShareDialog(String shareUrl) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("공유 링크 생성 완료!"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("아래 링크를 복사해서 카톡으로 보내세요."),
            const SizedBox(height: 15),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(10)),
              child: Text(shareUrl, style: const TextStyle(fontSize: 12, color: Colors.blueGrey)),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("닫기")),
          ElevatedButton(onPressed: () {
            Clipboard.setData(ClipboardData(text: shareUrl));
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("링크가 복사되었습니다!")));
            Navigator.pop(ctx);
          }, child: const Text("복사하기")),
        ],
      ),
    );
  }

  void _showPlanDialog({String? docId, Map<String, dynamic>? currentData}) {
    if (currentData != null) {
      _planTitleController.text = currentData['title'] ?? "";
      _selectedColor = Color(currentData['colorValue'] ?? 0xFFFFAB91);
    } else {
      _planTitleController.clear(); _selectedColor = const Color(0xFFFFAB91);
    }
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text(docId == null ? "새 여행 플랜" : "플랜 수정"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: _planTitleController, decoration: const InputDecoration(labelText: "여행 제목")),
              const SizedBox(height: 20),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: _colorPalette.map((c) => GestureDetector(onTap: () => setS(() => _selectedColor = c), child: CircleAvatar(backgroundColor: c, radius: 15, child: _selectedColor == c ? const Icon(Icons.check, size: 16, color: Colors.white) : null))).toList()),
            ],
          ),
          actions: [ElevatedButton(onPressed: () async {
            if (_planTitleController.text.isNotEmpty) {
              final data = {"title": _planTitleController.text, "colorValue": _selectedColor.value, "order": DateTime.now().millisecondsSinceEpoch};
              if (docId == null) { await userPlans.add(data); } else { await userPlans.doc(docId).update(data); }
              Navigator.pop(ctx);
            }
          }, child: const Text("저장"))],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('나의 Pla-Y 목록 🚀', style: TextStyle(fontWeight: FontWeight.bold)), actions: [IconButton(icon: const Icon(Icons.logout), onPressed: () => FirebaseAuth.instance.signOut())]),
      body: StreamBuilder<QuerySnapshot>(
        stream: userPlans.orderBy('order', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snapshot.data!.docs;
          return ReorderableListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            onReorder: (oldIdx, newIdx) async {
              if (newIdx > oldIdx) newIdx -= 1;
              final list = List.from(docs);
              final item = list.removeAt(oldIdx);
              list.insert(newIdx, item);
              final batch = FirebaseFirestore.instance.batch();
              for (int i = 0; i < list.length; i++) { batch.update(userPlans.doc(list[i].id), {'order': list.length - i}); }
              await batch.commit();
            },
            itemBuilder: (ctx, i) {
              final plan = docs[i].data() as Map<String, dynamic>;
              final planColor = Color(plan['colorValue'] ?? 0xFFFFAB91);
              return Card(
                key: ValueKey(docs[i].id),
                margin: const EdgeInsets.only(bottom: 12),
                elevation: 0,
                color: planColor.withOpacity(0.12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(15),
                  leading: CircleAvatar(backgroundColor: planColor, radius: 8),
                  title: Text(plan['title'] ?? '무제', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: planColor.withOpacity(0.9))),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.share_outlined, size: 20, color: Colors.blueGrey),
                        onPressed: () {
                          // ★ 수정: 모바일에서는 html.window 대신 실제 호스팅 주소를 사용
                          const baseUrl = "https://pla-y-e6bfe.web.app"; 
                          final shareUrl = "$baseUrl/#/?share=${docs[i].id}&owner=$uid";
                          _showShareDialog(shareUrl);
                        },
                      ),
                      const Icon(Icons.drag_handle, color: Colors.grey),
                    ],
                  ),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => MainEditorScreen(planId: docs[i].id, planTitle: plan['title']))),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(onPressed: () => _showPlanDialog(), child: const Icon(Icons.add)),
    );
  }
}

// --- 2. 상세 편집 화면 ---
class MainEditorScreen extends StatefulWidget {
  final String planId; final String planTitle;
  final bool isReadOnly; final String? ownerId;
  const MainEditorScreen({super.key, required this.planId, required this.planTitle, this.isReadOnly = false, this.ownerId});
  @override
  State<MainEditorScreen> createState() => _MainEditorScreenState();
}

class _MainEditorScreenState extends State<MainEditorScreen> {
  List<Map<String, String>> _places = [];
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _stayTimeController = TextEditingController();
  String _selectedCategory = '식당';
  final GlobalKey _boundaryKey = GlobalKey(); 
  bool _isSyncing = false;

  CollectionReference get itemsRef {
    final String targetUid = widget.isReadOnly ? widget.ownerId! : FirebaseAuth.instance.currentUser!.uid;
    return FirebaseFirestore.instance.collection('users').doc(targetUid).collection('plans').doc(widget.planId).collection('items');
  }

  @override
  void initState() { super.initState(); _downloadFromServer(); }

  Future<void> _autoSave() async {
    if (widget.isReadOnly) return;
    setState(() => _isSyncing = true);
    try {
      final batch = FirebaseFirestore.instance.batch();
      var snaps = await itemsRef.get();
      for (var doc in snaps.docs) { batch.delete(doc.reference); }
      for (var place in _places) { batch.set(itemsRef.doc(), place); }
      await batch.commit();
    } catch (e) {
      debugPrint("Auto-Save Error: $e");
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  Future<void> _downloadFromServer() async {
    setState(() => _isSyncing = true);
    var snapshot = await itemsRef.get();
    setState(() {
      _places = snapshot.docs.map((doc) => Map<String, String>.from(doc.data() as Map)).toList();
      _isSyncing = false;
    });
  }

  // ★ 수정: 모바일 앱에서는 브라우저 다운로드가 안 되므로 안내 메시지로 대체
  Future<void> _downloadImage() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("앱 버전에서는 이미지 저장이 아직 지원되지 않습니다. (업데이트 예정)"))
    );
    // 참고: 나중에 path_provider와 gallery_saver 패키지를 써서 구현해야 합니다.
  }

  Color _getCatColor(String? cat) {
    switch (cat) {
      case '식당': return const Color(0xFFFFCCBC); case '카페': return const Color(0xFFD7CCC8);
      case '숙소': return const Color(0xFFC5CAE9); case '명소': return const Color(0xFFE1BEE7);
      default: return const Color(0xFFC8E6C9);
    }
  }

  void _showPlaceDialog({int? index}) {
    if (widget.isReadOnly) return;
    if (index != null) {
      _titleController.text = _places[index]['title']!; _descController.text = _places[index]['desc']!;
      _stayTimeController.text = _places[index]['duration']!; _selectedCategory = _places[index]['category']!;
    } else {
      _titleController.clear(); _descController.clear(); _stayTimeController.clear(); _selectedCategory = '식당';
    }
    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setS) => AlertDialog(
      title: Text(index == null ? "장소 추가" : "정보 수정"),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: _titleController, decoration: const InputDecoration(labelText: "이름")),
        TextField(controller: _descController, decoration: const InputDecoration(labelText: "메모")),
        TextField(controller: _stayTimeController, decoration: const InputDecoration(labelText: "체류 시간(분)")),
        const SizedBox(height: 15),
        SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: ['식당', '카페', '숙소', '명소', '기타'].map((c) => Padding(padding: const EdgeInsets.only(right: 5), child: ChoiceChip(label: Text(c, style: const TextStyle(fontSize: 12)), selected: _selectedCategory == c, onSelected: (s) => setS(() => _selectedCategory = c)))).toList())),
      ])),
      actions: [ElevatedButton(onPressed: () { 
        if (_titleController.text.isNotEmpty) { 
          setState(() { 
            final newData = {"id": index == null ? DateTime.now().toString() : _places[index]['id']!, "title": _titleController.text, "desc": _descController.text, "duration": _stayTimeController.text.isEmpty ? "0" : _stayTimeController.text, "category": _selectedCategory, "image": "https://picsum.photos/seed/${_titleController.text}/200"}; 
            if (index == null) { _places.add(newData); } else { _places[index] = newData; } 
          }); 
          Navigator.pop(ctx); 
          _autoSave(); 
        } 
      }, child: const Text("확인"))],
    )));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(widget.isReadOnly ? "${widget.planTitle} (공유)" : widget.planTitle, style: const TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          if (_isSyncing) const Padding(padding: EdgeInsets.all(15), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFF6B6B)))),
          IconButton(icon: const Icon(Icons.download_rounded, color: Color(0xFFFF6B6B)), onPressed: _downloadImage),
        ],
      ),
      body: RepaintBoundary(
        key: _boundaryKey,
        child: Container(color: Colors.white, child: widget.isReadOnly 
          ? ListView.builder(padding: const EdgeInsets.all(16), itemCount: _places.length, itemBuilder: (ctx, i) => Column(children: [_buildFinalCard(_places[i], i), if (i < _places.length - 1) _buildPath(i)]))
          : ReorderableListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _places.length,
            onReorder: (old, nw) { setState(() { if (nw > old) nw -= 1; _places.insert(nw, _places.removeAt(old)); }); _autoSave(); },
            itemBuilder: (ctx, i) => Column(key: ValueKey(_places[i]['id']), children: [
              Dismissible(
                key: Key(_places[i]['id']!), 
                direction: DismissDirection.horizontal, 
                onDismissed: (_) { setState(() { _places.removeAt(i); }); _autoSave(); }, 
                background: Container(alignment: Alignment.centerLeft, padding: const EdgeInsets.only(left: 20), decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(18)), child: const Icon(Icons.delete, color: Colors.red)), 
                child: _buildFinalCard(_places[i], i)
              ),
              if (i < _places.length - 1) _buildPath(i),
            ]),
          )
        ),
      ),
      floatingActionButton: widget.isReadOnly ? null : FloatingActionButton.extended(onPressed: () => _showPlaceDialog(), label: const Text("장소 추가"), icon: const Icon(Icons.add)),
    );
  }

  Widget _buildPath(int i) {
    final travelTime = 10 + Random(_places[i]['id'].hashCode).nextInt(15);
    return Container(margin: const EdgeInsets.only(left: 45), height: 35, decoration: BoxDecoration(border: Border(left: BorderSide(color: Colors.grey[200]!, width: 2))), child: Row(children: [const SizedBox(width: 15), Icon(Icons.directions_car, size: 14, color: Colors.grey[400]), const SizedBox(width: 8), Text("약 $travelTime분 이동", style: TextStyle(fontSize: 11, color: Colors.grey[400], fontWeight: FontWeight.bold))]));
  }

  Widget _buildFinalCard(Map<String, String> p, int i) {
    final catColor = _getCatColor(p['category']);
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(color: catColor.withOpacity(0.12), borderRadius: BorderRadius.circular(18)),
      child: IntrinsicHeight(child: Row(children: [
        Container(width: 6, decoration: BoxDecoration(color: catColor, borderRadius: const BorderRadius.only(topLeft: Radius.circular(18), bottomLeft: Radius.circular(18)))),
        Expanded(flex: 5, child: InkWell(onTap: () => _showPlaceDialog(index: i), child: Padding(padding: const EdgeInsets.all(12), child: Row(children: [ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.network(p['image']!, width: 45, height: 45, fit: BoxFit.cover)), const SizedBox(width: 12), Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [Text(p['title']!, style: const TextStyle(fontWeight: ui.FontWeight.w900, fontSize: 15)), Text("${p['duration']}분 체류", style: TextStyle(fontSize: 11, color: catColor.withOpacity(0.8), fontWeight: ui.FontWeight.w800))]))])))),
        VerticalDivider(width: 1, thickness: 1, color: catColor.withOpacity(0.1)),
        Expanded(flex: 4, child: Container(padding: const EdgeInsets.symmetric(horizontal: 10), alignment: Alignment.centerLeft, child: Text(p['desc']!.isEmpty ? "-" : p['desc']!, style: const TextStyle(fontSize: 12, color: Color(0xFF424242), fontWeight: ui.FontWeight.w500), maxLines: 2, overflow: TextOverflow.ellipsis))),
        VerticalDivider(width: 1, thickness: 1, color: catColor.withOpacity(0.1)),
        // ★ 구글 지도 연동 로직 수정 (모바일 호환 URL)
        InkWell(
          onTap: () async { 
            final query = Uri.encodeComponent(p['title']!);
            // 모바일 앱에서는 이 URL이 구글 지도 앱을 엽니다.
            final url = Uri.parse("https://www.google.com/maps/search/?api=1&query=$query");
            await launchUrl(url, mode: LaunchMode.externalApplication); 
          }, 
          child: Container(width: 45, alignment: Alignment.center, child: Icon(Icons.map_outlined, color: catColor.withOpacity(0.7)))
        ),
        if (!widget.isReadOnly) VerticalDivider(width: 1, thickness: 1, color: catColor.withOpacity(0.1)),
        if (!widget.isReadOnly) ReorderableDragStartListener(index: i, child: Container(width: 40, alignment: Alignment.center, child: Icon(Icons.drag_handle, color: catColor.withOpacity(0.4)))),
      ])),
    );
  }
}