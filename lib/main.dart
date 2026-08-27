import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(const AttendanceApp());

class AttendanceApp extends StatelessWidget {
  const AttendanceApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Attendance App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1565C0),
          brightness: Brightness.light,
        ),
      ),
      home: const LoginPage(),
    );
  }
}

// ══════════════════════════════════════════════════
// MODELS
// ══════════════════════════════════════════════════

class TeacherModel {
  final String id, name, username, password;
  TeacherModel({required this.id, required this.name, required this.username, required this.password});
  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'username': username, 'password': password};
  factory TeacherModel.fromJson(Map<String, dynamic> j) => TeacherModel(
    id: j['id'] as String, name: j['name'] as String,
    username: j['username'] as String, password: j['password'] as String);
}

class Course {
  final String id, name, teacherId;
  Course({required this.id, required this.name, required this.teacherId});
  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'teacherId': teacherId};
  factory Course.fromJson(Map<String, dynamic> j) => Course(
    id: j['id'] as String, name: j['name'] as String, teacherId: j['teacherId'] as String);
}

class Student {
  final String id, name, rollNumber, courseId;
  Student({required this.id, required this.name, required this.rollNumber, required this.courseId});
  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'rollNumber': rollNumber, 'courseId': courseId};
  factory Student.fromJson(Map<String, dynamic> j) => Student(
    id: j['id'] as String, name: j['name'] as String,
    rollNumber: j['rollNumber'] as String, courseId: j['courseId'] as String);
}

enum AttStatus { present, absent, late }

class AttRecord {
  final String studentId, date;
  final AttStatus status;
  AttRecord({required this.studentId, required this.date, required this.status});
  Map<String, dynamic> toJson() => {'studentId': studentId, 'date': date, 'status': status.name};
  factory AttRecord.fromJson(Map<String, dynamic> j) => AttRecord(
    studentId: j['studentId'] as String, date: j['date'] as String,
    status: AttStatus.values.byName(j['status'] as String));
}

// ══════════════════════════════════════════════════
// STORAGE
// ══════════════════════════════════════════════════

class AppStorage {
  // Cache the SharedPreferences instance — avoids re-fetching on every call
  SharedPreferences? _prefs;
  Future<SharedPreferences> get _p async => _prefs ??= await SharedPreferences.getInstance();

  // Teachers
  Future<List<TeacherModel>> getTeachers() async {
    final raw = (await _p).getString('teachers');
    if (raw == null) return [];
    return (jsonDecode(raw) as List).map((e) => TeacherModel.fromJson(e as Map<String, dynamic>)).toList();
  }
  Future<void> saveTeachers(List<TeacherModel> list) async =>
    (await _p).setString('teachers', jsonEncode(list.map((t) => t.toJson()).toList()));
  Future<void> addTeacher(TeacherModel t) async { final l = await getTeachers(); l.add(t); await saveTeachers(l); }
  Future<void> deleteTeacher(String id) async {
    final teachers = await getTeachers(); teachers.removeWhere((t) => t.id == id); await saveTeachers(teachers);
    final courses = await getCourses(); courses.removeWhere((c) => c.teacherId == id); await saveCourses(courses);
    // Remove students whose course was deleted
    final remaining = await getCourses();
    final remainingIds = remaining.map((c) => c.id).toSet();
    final students = await getStudents(); students.removeWhere((s) => !remainingIds.contains(s.courseId)); await saveStudents(students);
  }

  // Courses
  Future<List<Course>> getCourses() async {
    final raw = (await _p).getString('courses');
    if (raw == null) return [];
    return (jsonDecode(raw) as List).map((e) => Course.fromJson(e as Map<String, dynamic>)).toList();
  }
  Future<void> saveCourses(List<Course> list) async =>
    (await _p).setString('courses', jsonEncode(list.map((c) => c.toJson()).toList()));
  Future<void> addCourse(Course c) async { final l = await getCourses(); l.add(c); await saveCourses(l); }
  Future<void> deleteCourse(String id) async {
    final courses = await getCourses(); courses.removeWhere((c) => c.id == id); await saveCourses(courses);
    final students = await getStudents(); students.removeWhere((s) => s.courseId == id); await saveStudents(students);
  }

  // Students
  Future<List<Student>> getStudents({String? courseId}) async {
    final raw = (await _p).getString('students');
    if (raw == null) return [];
    final all = (jsonDecode(raw) as List).map((e) => Student.fromJson(e as Map<String, dynamic>)).toList();
    if (courseId != null) return all.where((s) => s.courseId == courseId).toList();
    return all;
  }
  Future<void> saveStudents(List<Student> list) async =>
    (await _p).setString('students', jsonEncode(list.map((s) => s.toJson()).toList()));
  Future<void> addStudent(Student s) async { final l = await getStudents(); l.add(s); await saveStudents(l); }
  Future<void> deleteStudent(String id) async {
    final students = await getStudents(); students.removeWhere((s) => s.id == id); await saveStudents(students);
    final records = await getRecords(); records.removeWhere((r) => r.studentId == id); await saveRecords(records);
  }

  // Records
  Future<List<AttRecord>> getRecords({String? courseId}) async {
    final raw = (await _p).getString('records');
    if (raw == null) return [];
    final all = (jsonDecode(raw) as List).map((e) => AttRecord.fromJson(e as Map<String, dynamic>)).toList();
    if (courseId != null) {
      final students = await getStudents(courseId: courseId);
      final ids = students.map((s) => s.id).toSet();
      return all.where((r) => ids.contains(r.studentId)).toList();
    }
    return all;
  }
  Future<void> saveRecords(List<AttRecord> list) async =>
    (await _p).setString('records', jsonEncode(list.map((r) => r.toJson()).toList()));
  Future<void> mark(AttRecord record) async {
    final list = await getRecords();
    list.removeWhere((r) => r.studentId == record.studentId && r.date == record.date);
    list.add(record); await saveRecords(list);
  }

  // Teacher login
  Future<TeacherModel?> loginTeacher(String username, String password) async {
    final teachers = await getTeachers();
    return teachers.cast<TeacherModel?>().firstWhere(
      (t) => t!.username == username && t.password == password, orElse: () => null);
  }
}

final _store = AppStorage();

// ══════════════════════════════════════════════════
// LOGIN PAGE  —  Two buttons: Admin / Teacher
// ══════════════════════════════════════════════════

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.school_rounded, size: 72, color: cs.primary),
              const SizedBox(height: 16),
              Text('Attendance App',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: cs.primary)),
              const SizedBox(height: 8),
              Text('Select your role to continue',
                style: TextStyle(fontSize: 14, color: cs.onSurface.withValues(alpha: 0.55))),
              const SizedBox(height: 48),

              // Admin credentials hint
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: cs.primaryContainer.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(10)),
                child: Row(children: [
                  Icon(Icons.info_outline, size: 16, color: cs.primary),
                  const SizedBox(width: 8),
                  Text('Admin: username = admin  |  password = 123',
                    style: TextStyle(fontSize: 12, color: cs.primary, fontWeight: FontWeight.w500)),
                ])),
              const SizedBox(height: 20),

              // ── Admin Login Button ──
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.admin_panel_settings_outlined, size: 22),
                  label: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: Text('Admin Login', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    side: BorderSide(color: cs.primary, width: 1.5),
                  ),
                  onPressed: () => _showAdminLogin(context),
                ),
              ),

              const SizedBox(height: 16),

              // ── Teacher Login Button ──
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  icon: const Icon(Icons.person_outline, size: 22),
                  label: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: Text('Teacher Login', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () => _showTeacherLogin(context),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  void _showAdminLogin(BuildContext context) {
    final passCtrl = TextEditingController();
    String? error;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSt) => AlertDialog(
        title: const Text('Admin Login'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [

          TextField(
            controller: passCtrl,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Password',
              hintText: 'Default: 123',
              prefixIcon: Icon(Icons.lock_outline),
            ),
          ),
          if (error != null) ...[
            const SizedBox(height: 8),
            Text(error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
          ],
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () async {
            if (passCtrl.text.trim() == '123') {
              Navigator.pop(ctx);
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AdminPage()));
            } else {
              setSt(() => error = 'Wrong password');
            }
          }, child: const Text('Login')),
        ],
      )),
    );
  }

  void _showTeacherLogin(BuildContext context) {
    final userCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    bool loading = false;
    String? error;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSt) => AlertDialog(
        title: const Text('Teacher Login'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: userCtrl,
            decoration: const InputDecoration(
              labelText: 'Username',
              prefixIcon: Icon(Icons.person_outline),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: passCtrl,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Password',
              prefixIcon: Icon(Icons.lock_outline),
            ),
          ),
          if (error != null) ...[
            const SizedBox(height: 8),
            Text(error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
          ],
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: loading ? null : () async {
            setSt(() { loading = true; error = null; });
            final teacher = await _store.loginTeacher(
              userCtrl.text.trim(), passCtrl.text.trim());
            if (!ctx.mounted) return;
            if (teacher != null) {
              Navigator.pop(ctx);
              Navigator.pushReplacement(context,
                MaterialPageRoute(builder: (_) => TeacherPage(teacher: teacher)));
            } else {
              setSt(() { loading = false; error = 'Invalid username or password'; });
            }
          }, child: loading
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
            : const Text('Login')),
        ],
      )),
    );
  }
}

// ══════════════════════════════════════════════════
// ADMIN PAGE
// ══════════════════════════════════════════════════

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});
  @override State<AdminPage> createState() => _AdminPageState();
}
class _AdminPageState extends State<AdminPage> {
  int _tab = 0;

  // GlobalKeys allow us to call _load() on each tab when switching
  final _teachersKey = GlobalKey<_AdminTeachersTabState>();
  final _coursesKey  = GlobalKey<_AdminCoursesTabState>();
  final _studentsKey = GlobalKey<_AdminStudentsTabState>();

  void _logout() {
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginPage()));
  }

  void _onTabChanged(int i) {
    setState(() => _tab = i);
    // Auto-reload the newly selected tab so data is always fresh
    switch (i) {
      case 0: _teachersKey.currentState?._load(); break;
      case 1: _coursesKey.currentState?._load();  break;
      case 2: _studentsKey.currentState?._load(); break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: cs.surface,
        elevation: 0,
        title: Text('Admin Panel',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: cs.primary)),
        actions: [
          IconButton(icon: const Icon(Icons.logout), tooltip: 'Logout', onPressed: _logout),
        ],
      ),
      body: IndexedStack(index: _tab, children: [
        AdminTeachersTab(key: _teachersKey),
        AdminCoursesTab(key: _coursesKey),
        AdminStudentsTab(key: _studentsKey),
      ]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: _onTabChanged,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Teachers'),
          NavigationDestination(icon: Icon(Icons.book_outlined), selectedIcon: Icon(Icons.book), label: 'Courses'),
          NavigationDestination(icon: Icon(Icons.school_outlined), selectedIcon: Icon(Icons.school), label: 'Students'),
        ],
      ),
    );
  }
}

// ── Admin: Teachers Tab ───────────────────────────

class AdminTeachersTab extends StatefulWidget {
  const AdminTeachersTab({super.key});
  @override State<AdminTeachersTab> createState() => _AdminTeachersTabState();
}
class _AdminTeachersTabState extends State<AdminTeachersTab> {
  List<TeacherModel> _teachers = [];
  bool _loading = true;

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final t = await _store.getTeachers();
    setState(() { _teachers = t; _loading = false; });
  }

  void _showAdd() {
    final nameCtrl = TextEditingController();
    final userCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Add Teacher'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: nameCtrl, textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Full Name', prefixIcon: Icon(Icons.person_outline))),
        const SizedBox(height: 10),
        TextField(controller: userCtrl,
          decoration: const InputDecoration(labelText: 'Username', prefixIcon: Icon(Icons.alternate_email))),
        const SizedBox(height: 10),
        TextField(controller: passCtrl, obscureText: true,
          decoration: const InputDecoration(labelText: 'Password', prefixIcon: Icon(Icons.lock_outline))),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        FilledButton(onPressed: () async {
          if (nameCtrl.text.trim().isEmpty || userCtrl.text.trim().isEmpty || passCtrl.text.trim().isEmpty) return;
          await _store.addTeacher(TeacherModel(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            name: nameCtrl.text.trim(),
            username: userCtrl.text.trim(),
            password: passCtrl.text.trim()));
          if (!ctx.mounted) return;
          Navigator.pop(ctx); _load();
        }, child: const Text('Add')),
      ],
    ));
  }

  Future<void> _delete(TeacherModel t) async {
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Delete Teacher'),
      content: Text('Delete "${t.name}"? Their courses and students will also be removed.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(style: FilledButton.styleFrom(backgroundColor: Colors.red),
          onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
      ],
    ));
    if (ok == true) { await _store.deleteTeacher(t.id); _load(); }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: _loading ? const Center(child: CircularProgressIndicator())
        : _teachers.isEmpty
          ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.people_outline, size: 64, color: cs.onSurface.withValues(alpha: 0.3)),
              const SizedBox(height: 12),
              Text('No teachers yet', style: TextStyle(color: cs.onSurface.withValues(alpha: 0.5), fontSize: 16)),
              const SizedBox(height: 6),
              Text('Tap + to add a teacher', style: TextStyle(color: cs.onSurface.withValues(alpha: 0.4), fontSize: 13)),
            ]))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _teachers.length,
              itemBuilder: (ctx, i) {
                final t = _teachers[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: cs.primaryContainer,
                      child: Text(t.name[0].toUpperCase(),
                        style: TextStyle(color: cs.primary, fontWeight: FontWeight.bold))),
                    title: Text(t.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text('Username: ${t.username}',
                      style: TextStyle(color: cs.onSurface.withValues(alpha: 0.55), fontSize: 12)),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                      onPressed: () => _delete(t)),
                  ),
                );
              }),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAdd, icon: const Icon(Icons.person_add), label: const Text('Add Teacher')),
    );
  }
}

// ── Admin: Courses Tab ────────────────────────────

class AdminCoursesTab extends StatefulWidget {
  const AdminCoursesTab({super.key});
  @override State<AdminCoursesTab> createState() => _AdminCoursesTabState();
}
class _AdminCoursesTabState extends State<AdminCoursesTab> {
  List<Course> _courses = [];
  List<TeacherModel> _teachers = [];
  bool _loading = true;

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final c = await _store.getCourses();
    final t = await _store.getTeachers();
    setState(() { _courses = c; _teachers = t; _loading = false; });
  }

  String _tName(String id) => _teachers.firstWhere((t) => t.id == id,
    orElse: () => TeacherModel(id: '', name: 'Unknown', username: '', password: '')).name;

  void _showAdd() {
    if (_teachers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a teacher first!'), behavior: SnackBarBehavior.floating));
      return;
    }
    final nameCtrl = TextEditingController();
    TeacherModel? selected = _teachers.first;
    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setSt) => AlertDialog(
      title: const Text('Add Course'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: nameCtrl, textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Course Name', prefixIcon: Icon(Icons.book_outlined))),
        const SizedBox(height: 12),
        DropdownButtonFormField<TeacherModel>(
          value: selected,
          decoration: const InputDecoration(labelText: 'Assign to Teacher', prefixIcon: Icon(Icons.person_outline)),
          items: _teachers.map((t) => DropdownMenuItem(value: t, child: Text(t.name))).toList(),
          onChanged: (v) => setSt(() => selected = v)),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        FilledButton(onPressed: () async {
          if (nameCtrl.text.trim().isEmpty || selected == null) return;
          await _store.addCourse(Course(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            name: nameCtrl.text.trim(),
            teacherId: selected!.id));
          if (!ctx.mounted) return;
          Navigator.pop(ctx); _load();
        }, child: const Text('Add')),
      ],
    )));
  }

  Future<void> _delete(Course c) async {
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Delete Course'),
      content: Text('Delete "${c.name}"? Enrolled students will also be removed.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(style: FilledButton.styleFrom(backgroundColor: Colors.red),
          onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
      ],
    ));
    if (ok == true) { await _store.deleteCourse(c.id); _load(); }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: _loading ? const Center(child: CircularProgressIndicator())
        : _courses.isEmpty
          ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.book_outlined, size: 64, color: cs.onSurface.withValues(alpha: 0.3)),
              const SizedBox(height: 12),
              Text('No courses yet', style: TextStyle(color: cs.onSurface.withValues(alpha: 0.5), fontSize: 16)),
              const SizedBox(height: 6),
              Text('Tap + to add a course', style: TextStyle(color: cs.onSurface.withValues(alpha: 0.4), fontSize: 13)),
            ]))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _courses.length,
              itemBuilder: (ctx, i) {
                final c = _courses[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: cs.secondaryContainer,
                      child: Icon(Icons.book, color: cs.secondary)),
                    title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text('Teacher: ${_tName(c.teacherId)}',
                      style: TextStyle(color: cs.onSurface.withValues(alpha: 0.55), fontSize: 12)),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                      onPressed: () => _delete(c)),
                  ),
                );
              }),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAdd, icon: const Icon(Icons.add), label: const Text('Add Course')),
    );
  }
}

// ── Admin: Students Tab ───────────────────────────

class AdminStudentsTab extends StatefulWidget {
  const AdminStudentsTab({super.key});
  @override State<AdminStudentsTab> createState() => _AdminStudentsTabState();
}
class _AdminStudentsTabState extends State<AdminStudentsTab> {
  List<Student> _students = [];
  List<Course> _courses = [];
  List<TeacherModel> _teachers = [];
  bool _loading = true;

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final s = await _store.getStudents();
    final c = await _store.getCourses();
    final t = await _store.getTeachers();
    setState(() { _students = s; _courses = c; _teachers = t; _loading = false; });
  }

  String _cName(String id) => _courses.firstWhere((c) => c.id == id,
    orElse: () => Course(id: '', name: 'Unknown', teacherId: '')).name;
  String _tName(String courseId) {
    final course = _courses.cast<Course?>().firstWhere((c) => c?.id == courseId, orElse: () => null);
    if (course == null) return '';
    return _teachers.firstWhere((t) => t.id == course.teacherId,
      orElse: () => TeacherModel(id: '', name: 'Unknown', username: '', password: '')).name;
  }

  void _showEnroll() {
    if (_courses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a course first!'), behavior: SnackBarBehavior.floating));
      return;
    }
    final nameCtrl = TextEditingController();
    final rollCtrl = TextEditingController();
    Course? selectedCourse = _courses.first;
    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setSt) => AlertDialog(
      title: const Text('Enroll Student'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: nameCtrl, textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Student Name', prefixIcon: Icon(Icons.person_outline))),
        const SizedBox(height: 10),
        TextField(controller: rollCtrl,
          decoration: const InputDecoration(labelText: 'Roll Number', prefixIcon: Icon(Icons.tag))),
        const SizedBox(height: 12),
        DropdownButtonFormField<Course>(
          value: selectedCourse,
          decoration: const InputDecoration(labelText: 'Course', prefixIcon: Icon(Icons.book_outlined)),
          items: _courses.map((c) => DropdownMenuItem(value: c, child: Text(c.name))).toList(),
          onChanged: (v) => setSt(() => selectedCourse = v)),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        FilledButton(onPressed: () async {
          if (nameCtrl.text.trim().isEmpty || rollCtrl.text.trim().isEmpty || selectedCourse == null) return;
          await _store.addStudent(Student(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            name: nameCtrl.text.trim(),
            rollNumber: rollCtrl.text.trim(),
            courseId: selectedCourse!.id));
          if (!ctx.mounted) return;
          Navigator.pop(ctx); _load();
        }, child: const Text('Enroll')),
      ],
    )));
  }

  Future<void> _delete(Student s) async {
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Remove Student'),
      content: Text('Remove "${s.name}"?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(style: FilledButton.styleFrom(backgroundColor: Colors.red),
          onPressed: () => Navigator.pop(ctx, true), child: const Text('Remove')),
      ],
    ));
    if (ok == true) { await _store.deleteStudent(s.id); _load(); }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: _loading ? const Center(child: CircularProgressIndicator())
        : _students.isEmpty
          ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.school_outlined, size: 64, color: cs.onSurface.withValues(alpha: 0.3)),
              const SizedBox(height: 12),
              Text('No students enrolled', style: TextStyle(color: cs.onSurface.withValues(alpha: 0.5), fontSize: 16)),
              const SizedBox(height: 6),
              Text('Tap + to enroll a student', style: TextStyle(color: cs.onSurface.withValues(alpha: 0.4), fontSize: 13)),
            ]))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _students.length,
              itemBuilder: (ctx, i) {
                final s = _students[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: cs.primaryContainer,
                      child: Text(s.name[0].toUpperCase(),
                        style: TextStyle(color: cs.primary, fontWeight: FontWeight.bold))),
                    title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Roll: ${s.rollNumber}',
                        style: TextStyle(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.55))),
                      Text('Course: ${_cName(s.courseId)}  •  Teacher: ${_tName(s.courseId)}',
                        style: TextStyle(fontSize: 11, color: cs.primary.withValues(alpha: 0.8))),
                    ]),
                    isThreeLine: true,
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                      onPressed: () => _delete(s)),
                  ),
                );
              }),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showEnroll, icon: const Icon(Icons.person_add), label: const Text('Enroll Student')),
    );
  }
}

// ══════════════════════════════════════════════════
// TEACHER PAGE
// ══════════════════════════════════════════════════

class TeacherPage extends StatefulWidget {
  final TeacherModel teacher;
  const TeacherPage({super.key, required this.teacher});
  @override State<TeacherPage> createState() => _TeacherPageState();
}
class _TeacherPageState extends State<TeacherPage> {
  int _tab = 0;

  final _coursesKey = GlobalKey<_TeacherCoursesTabState>();
  final _recordsKey = GlobalKey<_TeacherRecordsTabState>();

  void _logout() {
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginPage()));
  }

  void _onTabChanged(int i) {
    setState(() => _tab = i);
    switch (i) {
      case 0: _coursesKey.currentState?._load(); break;
      case 1: _recordsKey.currentState?._load(); break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: cs.surface,
        elevation: 0,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.teacher.name,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: cs.primary)),
          const Text('Teacher', style: TextStyle(fontSize: 11, color: Colors.grey)),
        ]),
        actions: [
          IconButton(icon: const Icon(Icons.logout), tooltip: 'Logout', onPressed: _logout),
        ],
      ),
      body: IndexedStack(index: _tab, children: [
        TeacherCoursesTab(key: _coursesKey, teacher: widget.teacher),
        TeacherRecordsTab(key: _recordsKey, teacher: widget.teacher),
      ]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: _onTabChanged,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.book_outlined), selectedIcon: Icon(Icons.book), label: 'My Courses'),
          NavigationDestination(icon: Icon(Icons.list_alt_outlined), selectedIcon: Icon(Icons.list_alt), label: 'Records'),
        ],
      ),
    );
  }
}

// ── Teacher: My Courses Tab ───────────────────────

class TeacherCoursesTab extends StatefulWidget {
  final TeacherModel teacher;
  const TeacherCoursesTab({super.key, required this.teacher});
  @override State<TeacherCoursesTab> createState() => _TeacherCoursesTabState();
}
class _TeacherCoursesTabState extends State<TeacherCoursesTab> {
  List<Course> _courses = [];
  Map<String, int> _counts = {};
  bool _loading = true;

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final all = await _store.getCourses();
    // Only show courses assigned to this teacher
    final mine = all.where((c) => c.teacherId == widget.teacher.id).toList();
    final Map<String, int> counts = {};
    for (final c in mine) {
      final students = await _store.getStudents(courseId: c.id);
      counts[c.id] = students.length;
    }
    setState(() { _courses = mine; _counts = counts; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_courses.isEmpty) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.book_outlined, size: 64, color: cs.onSurface.withValues(alpha: 0.3)),
        const SizedBox(height: 12),
        Text('No courses assigned to you',
          style: TextStyle(color: cs.onSurface.withValues(alpha: 0.5), fontSize: 16)),
        const SizedBox(height: 6),
        Text('Ask admin to assign a course',
          style: TextStyle(color: cs.onSurface.withValues(alpha: 0.4), fontSize: 13)),
      ]));
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _courses.length,
        itemBuilder: (ctx, i) {
          final c = _courses[i];
          final count = _counts[c.id] ?? 0;
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: CircleAvatar(
                backgroundColor: cs.primaryContainer,
                child: Icon(Icons.book, color: cs.primary)),
              title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              subtitle: Text('$count student${count == 1 ? '' : 's'} enrolled',
                style: TextStyle(color: cs.onSurface.withValues(alpha: 0.55), fontSize: 12)),
              trailing: FilledButton.tonal(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => AttendancePage(course: c)),
                ).then((_) => _load()),
                child: const Text('Take Attendance'),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Attendance Page ───────────────────────────────

class AttendancePage extends StatefulWidget {
  final Course course;
  const AttendancePage({super.key, required this.course});
  @override State<AttendancePage> createState() => _AttendancePageState();
}
class _AttendancePageState extends State<AttendancePage> {
  List<Student> _students = [];
  Map<String, AttStatus?> _status = {};
  DateTime _date = DateTime.now();
  bool _loading = true;

  String get _dateKey =>
    '${_date.year.toString().padLeft(4, '0')}-'
    '${_date.month.toString().padLeft(2, '0')}-'
    '${_date.day.toString().padLeft(2, '0')}';

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final students = await _store.getStudents(courseId: widget.course.id);
    final records = await _store.getRecords(courseId: widget.course.id);
    final Map<String, AttStatus?> st = {};
    for (final s in students) {
      final rec = records.cast<AttRecord?>().firstWhere(
        (r) => r?.studentId == s.id && r?.date == _dateKey, orElse: () => null);
      st[s.id] = rec?.status;
    }
    setState(() { _students = students; _status = st; _loading = false; });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context, initialDate: _date,
      firstDate: DateTime(2020), lastDate: DateTime(2100));
    if (picked != null) { _date = picked; await _load(); }
  }

  Future<void> _markAll(AttStatus s) async {
    for (final st in _students) {
      await _store.mark(AttRecord(studentId: st.id, date: _dateKey, status: s));
    }
    _load();
  }

  String _fmtDate(DateTime d) {
    const m = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${d.day} ${m[d.month - 1]} ${d.year}';
  }

  Color _color(AttStatus s) {
    switch (s) {
      case AttStatus.present: return const Color(0xFF2E7D32);
      case AttStatus.absent:  return const Color(0xFFC62828);
      case AttStatus.late:    return const Color(0xFFE65100);
    }
  }
  IconData _icon(AttStatus s) {
    switch (s) {
      case AttStatus.present: return Icons.check_circle;
      case AttStatus.absent:  return Icons.cancel;
      case AttStatus.late:    return Icons.schedule;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final marked = _status.values.where((v) => v != null).length;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.course.name),
        backgroundColor: cs.surface,
        elevation: 0,
      ),
      body: Column(children: [
        // Date bar
        GestureDetector(
          onTap: _pickDate,
          child: Container(
            margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              Icon(Icons.calendar_today, color: cs.primary, size: 18),
              const SizedBox(width: 10),
              Text(_fmtDate(_date),
                style: TextStyle(color: cs.onPrimaryContainer, fontWeight: FontWeight.w600)),
              const Spacer(),
              Text('$marked / ${_students.length} marked',
                style: TextStyle(color: cs.onPrimaryContainer.withValues(alpha: 0.7), fontSize: 12)),
              const SizedBox(width: 6),
              Icon(Icons.edit_calendar, color: cs.onPrimaryContainer.withValues(alpha: 0.6), size: 16),
            ]),
          ),
        ),

        // Student list
        Expanded(
          child: _loading ? const Center(child: CircularProgressIndicator())
            : _students.isEmpty
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.people_outline, size: 64, color: cs.onSurface.withValues(alpha: 0.3)),
                  const SizedBox(height: 12),
                  Text('No students in this course',
                    style: TextStyle(color: cs.onSurface.withValues(alpha: 0.5), fontSize: 16)),
                  const SizedBox(height: 6),
                  Text('Ask admin to enroll students',
                    style: TextStyle(color: cs.onSurface.withValues(alpha: 0.4), fontSize: 13)),
                ]))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: _students.length,
                  itemBuilder: (ctx, i) {
                    final s = _students[i];
                    final st = _status[s.id];
                    final isMarked = st != null;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: isMarked ? _color(st) : Colors.transparent, width: 1.5)),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
                        child: Row(children: [
                          CircleAvatar(radius: 20,
                            backgroundColor: isMarked
                              ? _color(st).withValues(alpha: 0.15)
                              : cs.primaryContainer,
                            child: isMarked
                              ? Icon(_icon(st), color: _color(st), size: 22)
                              : Text(s.name[0].toUpperCase(),
                                  style: TextStyle(color: cs.primary, fontWeight: FontWeight.bold))),
                          const SizedBox(width: 12),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(s.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                            Text('Roll: ${s.rollNumber}',
                              style: TextStyle(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.55))),
                          ])),
                          // Present
                          _ABtn(label: 'P', color: const Color(0xFF2E7D32), selected: st == AttStatus.present,
                            onTap: () async { await _store.mark(AttRecord(studentId: s.id, date: _dateKey, status: AttStatus.present)); _load(); }),
                          const SizedBox(width: 4),
                          // Absent
                          _ABtn(label: 'A', color: const Color(0xFFC62828), selected: st == AttStatus.absent,
                            onTap: () async { await _store.mark(AttRecord(studentId: s.id, date: _dateKey, status: AttStatus.absent)); _load(); }),
                          const SizedBox(width: 4),
                          // Late
                          _ABtn(label: 'L', color: const Color(0xFFE65100), selected: st == AttStatus.late,
                            onTap: () async { await _store.mark(AttRecord(studentId: s.id, date: _dateKey, status: AttStatus.late)); _load(); }),
                        ]),
                      ),
                    );
                  }),
        ),

        // Mark All bar
        if (_students.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: cs.surfaceContainerHighest,
            child: Row(children: [
              const Text('Mark All:', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(width: 12),
              Expanded(child: _MarkAllBtn(label: 'Present', color: const Color(0xFF2E7D32),
                onTap: () => _markAll(AttStatus.present))),
              const SizedBox(width: 6),
              Expanded(child: _MarkAllBtn(label: 'Absent', color: const Color(0xFFC62828),
                onTap: () => _markAll(AttStatus.absent))),
              const SizedBox(width: 6),
              Expanded(child: _MarkAllBtn(label: 'Late', color: const Color(0xFFE65100),
                onTap: () => _markAll(AttStatus.late))),
            ]),
          ),
      ]),
    );
  }
}

// ── Teacher: Records Tab ──────────────────────────

class TeacherRecordsTab extends StatefulWidget {
  final TeacherModel teacher;
  const TeacherRecordsTab({super.key, required this.teacher});
  @override State<TeacherRecordsTab> createState() => _TeacherRecordsTabState();
}
class _TeacherRecordsTabState extends State<TeacherRecordsTab> {
  List<AttRecord> _records = [];
  List<Student> _students = [];
  List<Course> _courses = [];
  String? _filterCourseId;
  bool _loading = true;

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final allCourses = await _store.getCourses();
    final myCourses = allCourses.where((c) => c.teacherId == widget.teacher.id).toList();
    final myIds = myCourses.map((c) => c.id).toSet();
    final allStudents = await _store.getStudents();
    final myStudents = allStudents.where((s) => myIds.contains(s.courseId)).toList();
    final myStudentIds = myStudents.map((s) => s.id).toSet();
    final allRecords = await _store.getRecords();
    final myRecords = allRecords.where((r) => myStudentIds.contains(r.studentId)).toList();
    myRecords.sort((a, b) => b.date.compareTo(a.date));
    setState(() { _records = myRecords; _students = myStudents; _courses = myCourses; _loading = false; });
  }

  List<AttRecord> get _filtered {
    if (_filterCourseId == null) return _records;
    final courseStudentIds = _students
      .where((s) => s.courseId == _filterCourseId)
      .map((s) => s.id).toSet();
    return _records.where((r) => courseStudentIds.contains(r.studentId)).toList();
  }

  String _name(String id) => _students.firstWhere((s) => s.id == id,
    orElse: () => Student(id: id, name: 'Unknown', rollNumber: '?', courseId: '')).name;
  String _roll(String id) => _students.firstWhere((s) => s.id == id,
    orElse: () => Student(id: id, name: '?', rollNumber: '?', courseId: '')).rollNumber;

  Color _color(AttStatus s) {
    switch (s) {
      case AttStatus.present: return const Color(0xFF2E7D32);
      case AttStatus.absent:  return const Color(0xFFC62828);
      case AttStatus.late:    return const Color(0xFFE65100);
    }
  }
  IconData _icon(AttStatus s) {
    switch (s) {
      case AttStatus.present: return Icons.check_circle;
      case AttStatus.absent:  return Icons.cancel;
      case AttStatus.late:    return Icons.schedule;
    }
  }
  String _fmtDate(String d) {
    final p = d.split('-');
    const m = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${int.parse(p[2])} ${m[int.parse(p[1]) - 1]} ${p[0]}';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final f = _filtered;
    return Column(children: [
      // Filter chips
      if (_courses.isNotEmpty)
        SizedBox(height: 48, child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          children: [
            _FilterChip(label: 'All', selected: _filterCourseId == null,
              onTap: () => setState(() => _filterCourseId = null)),
            ..._courses.map((c) => _FilterChip(label: c.name, selected: _filterCourseId == c.id,
              onTap: () => setState(() => _filterCourseId = c.id))),
          ],
        )),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
        child: Row(children: [
          Text('${f.length} record(s)',
            style: TextStyle(fontSize: 13, color: cs.onSurface.withValues(alpha: 0.55))),
          const Spacer(),
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh), iconSize: 20),
        ]),
      ),
      Expanded(child: _loading ? const Center(child: CircularProgressIndicator())
        : f.isEmpty
          ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.inbox_outlined, size: 64, color: cs.onSurface.withValues(alpha: 0.3)),
              const SizedBox(height: 10),
              Text('No records yet', style: TextStyle(color: cs.onSurface.withValues(alpha: 0.5), fontSize: 16)),
            ]))
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: f.length,
              itemBuilder: (ctx, i) {
                final r = f[i];
                final color = _color(r.status);
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: color.withValues(alpha: 0.15),
                      child: Icon(_icon(r.status), color: color, size: 22)),
                    title: Text(_name(r.studentId),
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    subtitle: Text('Roll: ${_roll(r.studentId)}  •  ${_fmtDate(r.date)}',
                      style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.55))),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: color.withValues(alpha: 0.4))),
                      child: Text(r.status.name.toUpperCase(),
                        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold))),
                  ),
                );
              }),
      ),
    ]);
  }
}

// ══════════════════════════════════════════════════
// SHARED WIDGETS
// ══════════════════════════════════════════════════

class _ABtn extends StatelessWidget {
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  const _ABtn({required this.label, required this.color, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 34, height: 34,
      decoration: BoxDecoration(
        color: selected ? color : color.withValues(alpha: 0.08),
        shape: BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: selected ? 1 : 0.3), width: 1.5)),
      child: Center(child: Text(label,
        style: TextStyle(
          color: selected ? Colors.white : color,
          fontWeight: FontWeight.bold, fontSize: 13))),
    ),
  );
}

class _MarkAllBtn extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _MarkAllBtn({required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4))),
      child: Center(child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13))),
    ),
  );
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? cs.primary : cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20)),
        child: Text(label,
          style: TextStyle(
            color: selected ? cs.onPrimary : cs.onSurface.withValues(alpha: 0.7),
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            fontSize: 13)),
      ),
    );
  }
}
