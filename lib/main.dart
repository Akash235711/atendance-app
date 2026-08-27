import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(const AttendanceApp());

class AttendanceApp extends StatelessWidget {
  const AttendanceApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Attendance App',
    debugShowCheckedModeBanner: false,
    home: const LoginPage(),
  );
}

// ── MODELS ────────────────────────────────────────

class Teacher {
  final String id, name, username, password;
  Teacher({required this.id, required this.name, required this.username, required this.password});
  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'username': username, 'password': password};
  factory Teacher.fromJson(Map<String, dynamic> j) =>
    Teacher(id: j['id'], name: j['name'], username: j['username'], password: j['password']);
}

class Course {
  final String id, name, teacherId;
  Course({required this.id, required this.name, required this.teacherId});
  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'teacherId': teacherId};
  factory Course.fromJson(Map<String, dynamic> j) =>
    Course(id: j['id'], name: j['name'], teacherId: j['teacherId']);
}

class Student {
  final String id, name, roll, courseId;
  Student({required this.id, required this.name, required this.roll, required this.courseId});
  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'roll': roll, 'courseId': courseId};
  factory Student.fromJson(Map<String, dynamic> j) =>
    Student(id: j['id'], name: j['name'], roll: j['roll'], courseId: j['courseId']);
}

enum S { present, absent, late }

class Rec {
  final String studentId, date;
  final S status;
  Rec({required this.studentId, required this.date, required this.status});
  Map<String, dynamic> toJson() => {'studentId': studentId, 'date': date, 'status': status.name};
  factory Rec.fromJson(Map<String, dynamic> j) =>
    Rec(studentId: j['studentId'], date: j['date'], status: S.values.byName(j['status']));
}

// ── STORAGE ───────────────────────────────────────

class Store {
  SharedPreferences? _p;
  Future<SharedPreferences> get p async => _p ??= await SharedPreferences.getInstance();

  Future<List<Teacher>> teachers() async {
    final r = (await p).getString('teachers');
    return r == null ? [] : (jsonDecode(r) as List).map((e) => Teacher.fromJson(e)).toList();
  }
  Future<void> saveTeachers(List<Teacher> l) async =>
    (await p).setString('teachers', jsonEncode(l.map((e) => e.toJson()).toList()));
  Future<void> addTeacher(Teacher t) async { final l = await teachers(); l.add(t); await saveTeachers(l); }
  Future<void> delTeacher(String id) async {
    var l = await teachers(); l.removeWhere((t) => t.id == id); await saveTeachers(l);
    var c = await courses(); c.removeWhere((c) => c.teacherId == id); await saveCourses(c);
    final kept = (await courses()).map((c) => c.id).toSet();
    var s = await students(); s.removeWhere((s) => !kept.contains(s.courseId)); await saveStudents(s);
  }

  Future<List<Course>> courses() async {
    final r = (await p).getString('courses');
    return r == null ? [] : (jsonDecode(r) as List).map((e) => Course.fromJson(e)).toList();
  }
  Future<void> saveCourses(List<Course> l) async =>
    (await p).setString('courses', jsonEncode(l.map((e) => e.toJson()).toList()));
  Future<void> addCourse(Course c) async { final l = await courses(); l.add(c); await saveCourses(l); }
  Future<void> delCourse(String id) async {
    var l = await courses(); l.removeWhere((c) => c.id == id); await saveCourses(l);
    var s = await students(); s.removeWhere((s) => s.courseId == id); await saveStudents(s);
  }

  Future<List<Student>> students({String? courseId}) async {
    final r = (await p).getString('students');
    if (r == null) return [];
    final all = (jsonDecode(r) as List).map((e) => Student.fromJson(e)).toList();
    return courseId == null ? all : all.where((s) => s.courseId == courseId).toList();
  }
  Future<void> saveStudents(List<Student> l) async =>
    (await p).setString('students', jsonEncode(l.map((e) => e.toJson()).toList()));
  Future<void> addStudent(Student s) async { final l = await students(); l.add(s); await saveStudents(l); }
  Future<void> delStudent(String id) async {
    var l = await students(); l.removeWhere((s) => s.id == id); await saveStudents(l);
    var r = await recs(); r.removeWhere((r) => r.studentId == id); await saveRecs(r);
  }

  Future<List<Rec>> recs({String? courseId}) async {
    final r = (await p).getString('records');
    if (r == null) return [];
    final all = (jsonDecode(r) as List).map((e) => Rec.fromJson(e)).toList();
    if (courseId == null) return all;
    final ids = (await students(courseId: courseId)).map((s) => s.id).toSet();
    return all.where((r) => ids.contains(r.studentId)).toList();
  }
  Future<void> saveRecs(List<Rec> l) async =>
    (await p).setString('records', jsonEncode(l.map((e) => e.toJson()).toList()));
  Future<void> mark(Rec rec) async {
    final l = await recs();
    l.removeWhere((r) => r.studentId == rec.studentId && r.date == rec.date);
    l.add(rec); await saveRecs(l);
  }

  Future<Teacher?> loginTeacher(String u, String pw) async {
    final l = await teachers();
    return l.cast<Teacher?>().firstWhere((t) => t!.username == u && t.password == pw, orElse: () => null);
  }
}

final _store = Store();
String _uid() => DateTime.now().millisecondsSinceEpoch.toString();

// ── LOGIN PAGE ────────────────────────────────────

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Attendance App')),
    body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Text('Select Role', style: TextStyle(fontSize: 20)),
      const SizedBox(height: 24),
      ElevatedButton(
        onPressed: () => _adminDialog(context),
        child: const Text('Admin Login')),
      const SizedBox(height: 12),
      ElevatedButton(
        onPressed: () => _teacherDialog(context),
        child: const Text('Teacher Login')),
      const SizedBox(height: 20),
      const Text('Admin password: 123', style: TextStyle(color: Colors.grey)),
    ])),
  );

  void _adminDialog(BuildContext context) {
    final pw = TextEditingController();
    String? err;
    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, ss) => AlertDialog(
      title: const Text('Admin Login'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: pw, obscureText: true, decoration: const InputDecoration(labelText: 'Password')),
        if (err != null) Text(err!, style: const TextStyle(color: Colors.red)),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ElevatedButton(onPressed: () {
          if (pw.text.trim() == '123') {
            Navigator.pop(ctx);
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AdminPage()));
          } else { ss(() => err = 'Wrong password'); }
        }, child: const Text('Login')),
      ],
    )));
  }

  void _teacherDialog(BuildContext context) {
    final u = TextEditingController(); final pw = TextEditingController();
    bool loading = false; String? err;
    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, ss) => AlertDialog(
      title: const Text('Teacher Login'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: u, decoration: const InputDecoration(labelText: 'Username')),
        const SizedBox(height: 8),
        TextField(controller: pw, obscureText: true, decoration: const InputDecoration(labelText: 'Password')),
        if (err != null) Text(err!, style: const TextStyle(color: Colors.red)),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ElevatedButton(onPressed: loading ? null : () async {
          ss(() { loading = true; err = null; });
          final t = await _store.loginTeacher(u.text.trim(), pw.text.trim());
          if (!ctx.mounted) return;
          if (t != null) {
            Navigator.pop(ctx);
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => TeacherPage(teacher: t)));
          } else { ss(() { loading = false; err = 'Invalid credentials'; }); }
        }, child: const Text('Login')),
      ],
    )));
  }
}

// ── ADMIN PAGE ────────────────────────────────────

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});
  @override State<AdminPage> createState() => _AdminPageState();
}
class _AdminPageState extends State<AdminPage> {
  int _tab = 0;
  final _tk = GlobalKey<_TeachersTabState>();
  final _ck = GlobalKey<_CoursesTabState>();
  final _sk = GlobalKey<_StudentsTabState>();

  void _onTab(int i) {
    setState(() => _tab = i);
    switch(i) {
      case 0: _tk.currentState?.load(); break;
      case 1: _ck.currentState?.load(); break;
      case 2: _sk.currentState?.load(); break;
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Admin Panel'),
      actions: [IconButton(icon: const Icon(Icons.logout), onPressed: () =>
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginPage())))],
    ),
    body: IndexedStack(index: _tab, children: [
      TeachersTab(key: _tk), CoursesTab(key: _ck), StudentsTab(key: _sk),
    ]),
    bottomNavigationBar: BottomNavigationBar(
      currentIndex: _tab, onTap: _onTab,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Teachers'),
        BottomNavigationBarItem(icon: Icon(Icons.book), label: 'Courses'),
        BottomNavigationBarItem(icon: Icon(Icons.school), label: 'Students'),
      ]),
  );
}

// ── Admin: Teachers ───────────────────────────────

class TeachersTab extends StatefulWidget {
  const TeachersTab({super.key});
  @override State<TeachersTab> createState() => _TeachersTabState();
}
class _TeachersTabState extends State<TeachersTab> {
  List<Teacher> _list = []; bool _loading = true;
  @override void initState() { super.initState(); load(); }

  Future<void> load() async {
    setState(() => _loading = true);
    _list = await _store.teachers();
    setState(() => _loading = false);
  }

  void _add() {
    final n = TextEditingController(); final u = TextEditingController(); final pw = TextEditingController();
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Add Teacher'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: n, decoration: const InputDecoration(labelText: 'Full Name')),
        TextField(controller: u, decoration: const InputDecoration(labelText: 'Username')),
        TextField(controller: pw, obscureText: true, decoration: const InputDecoration(labelText: 'Password')),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ElevatedButton(onPressed: () async {
          if (n.text.isEmpty || u.text.isEmpty || pw.text.isEmpty) return;
          await _store.addTeacher(Teacher(id: _uid(), name: n.text.trim(), username: u.text.trim(), password: pw.text.trim()));
          if (!ctx.mounted) return;
          Navigator.pop(ctx); load();
        }, child: const Text('Add')),
      ],
    ));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: _loading ? const Center(child: CircularProgressIndicator())
      : _list.isEmpty ? const Center(child: Text('No teachers. Tap + to add.'))
      : ListView.builder(itemCount: _list.length, itemBuilder: (_, i) => ListTile(
          title: Text(_list[i].name),
          subtitle: Text('Username: ${_list[i].username}'),
          trailing: IconButton(icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: () async { await _store.delTeacher(_list[i].id); load(); }),
        )),
    floatingActionButton: FloatingActionButton(onPressed: _add, child: const Icon(Icons.add)),
  );
}

// ── Admin: Courses ────────────────────────────────

class CoursesTab extends StatefulWidget {
  const CoursesTab({super.key});
  @override State<CoursesTab> createState() => _CoursesTabState();
}
class _CoursesTabState extends State<CoursesTab> {
  List<Course> _list = []; List<Teacher> _teachers = []; bool _loading = true;
  @override void initState() { super.initState(); load(); }

  Future<void> load() async {
    setState(() => _loading = true);
    _list = await _store.courses(); _teachers = await _store.teachers();
    setState(() => _loading = false);
  }

  String _tname(String id) => _teachers.firstWhere((t) => t.id == id,
    orElse: () => Teacher(id: '', name: 'Unknown', username: '', password: '')).name;

  void _add() {
    if (_teachers.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Add a teacher first'))); return; }
    final n = TextEditingController(); Teacher? sel = _teachers.first;
    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, ss) => AlertDialog(
      title: const Text('Add Course'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: n, decoration: const InputDecoration(labelText: 'Course Name')),
        const SizedBox(height: 8),
        DropdownButtonFormField<Teacher>(
          value: sel,
          decoration: const InputDecoration(labelText: 'Assign Teacher'),
          items: _teachers.map((t) => DropdownMenuItem(value: t, child: Text(t.name))).toList(),
          onChanged: (v) => ss(() => sel = v)),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ElevatedButton(onPressed: () async {
          if (n.text.isEmpty || sel == null) return;
          await _store.addCourse(Course(id: _uid(), name: n.text.trim(), teacherId: sel!.id));
          if (!ctx.mounted) return;
          Navigator.pop(ctx); load();
        }, child: const Text('Add')),
      ],
    )));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: _loading ? const Center(child: CircularProgressIndicator())
      : _list.isEmpty ? const Center(child: Text('No courses. Tap + to add.'))
      : ListView.builder(itemCount: _list.length, itemBuilder: (_, i) => ListTile(
          title: Text(_list[i].name),
          subtitle: Text('Teacher: ${_tname(_list[i].teacherId)}'),
          trailing: IconButton(icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: () async { await _store.delCourse(_list[i].id); load(); }),
        )),
    floatingActionButton: FloatingActionButton(onPressed: _add, child: const Icon(Icons.add)),
  );
}

// ── Admin: Students ───────────────────────────────

class StudentsTab extends StatefulWidget {
  const StudentsTab({super.key});
  @override State<StudentsTab> createState() => _StudentsTabState();
}
class _StudentsTabState extends State<StudentsTab> {
  List<Student> _list = []; List<Course> _courses = []; bool _loading = true;
  @override void initState() { super.initState(); load(); }

  Future<void> load() async {
    setState(() => _loading = true);
    _list = await _store.students(); _courses = await _store.courses();
    setState(() => _loading = false);
  }

  String _cname(String id) => _courses.firstWhere((c) => c.id == id,
    orElse: () => Course(id: '', name: 'Unknown', teacherId: '')).name;

  void _enroll() {
    if (_courses.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Add a course first'))); return; }
    final n = TextEditingController(); final r = TextEditingController(); Course? sel = _courses.first;
    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, ss) => AlertDialog(
      title: const Text('Enroll Student'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: n, decoration: const InputDecoration(labelText: 'Student Name')),
        TextField(controller: r, decoration: const InputDecoration(labelText: 'Roll Number')),
        const SizedBox(height: 8),
        DropdownButtonFormField<Course>(
          value: sel,
          decoration: const InputDecoration(labelText: 'Course'),
          items: _courses.map((c) => DropdownMenuItem(value: c, child: Text(c.name))).toList(),
          onChanged: (v) => ss(() => sel = v)),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ElevatedButton(onPressed: () async {
          if (n.text.isEmpty || r.text.isEmpty || sel == null) return;
          await _store.addStudent(Student(id: _uid(), name: n.text.trim(), roll: r.text.trim(), courseId: sel!.id));
          if (!ctx.mounted) return;
          Navigator.pop(ctx); load();
        }, child: const Text('Enroll')),
      ],
    )));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: _loading ? const Center(child: CircularProgressIndicator())
      : _list.isEmpty ? const Center(child: Text('No students. Tap + to enroll.'))
      : ListView.builder(itemCount: _list.length, itemBuilder: (_, i) => ListTile(
          title: Text(_list[i].name),
          subtitle: Text('Roll: ${_list[i].roll}  •  ${_cname(_list[i].courseId)}'),
          trailing: IconButton(icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: () async { await _store.delStudent(_list[i].id); load(); }),
        )),
    floatingActionButton: FloatingActionButton(onPressed: _enroll, child: const Icon(Icons.add)),
  );
}

// ── TEACHER PAGE ──────────────────────────────────

class TeacherPage extends StatefulWidget {
  final Teacher teacher;
  const TeacherPage({super.key, required this.teacher});
  @override State<TeacherPage> createState() => _TeacherPageState();
}
class _TeacherPageState extends State<TeacherPage> {
  int _tab = 0;
  final _ck = GlobalKey<_MyCoursesTabState>();
  final _rk = GlobalKey<_RecordsTabState>();

  void _onTab(int i) {
    setState(() => _tab = i);
    switch(i) {
      case 0: _ck.currentState?.load(); break;
      case 1: _rk.currentState?.load(); break;
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.teacher.name),
      actions: [IconButton(icon: const Icon(Icons.logout), onPressed: () =>
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginPage())))],
    ),
    body: IndexedStack(index: _tab, children: [
      MyCoursesTab(key: _ck, teacher: widget.teacher),
      RecordsTab(key: _rk, teacher: widget.teacher),
    ]),
    bottomNavigationBar: BottomNavigationBar(
      currentIndex: _tab, onTap: _onTab,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.book), label: 'My Courses'),
        BottomNavigationBarItem(icon: Icon(Icons.list), label: 'Records'),
      ]),
  );
}

// ── Teacher: My Courses ───────────────────────────

class MyCoursesTab extends StatefulWidget {
  final Teacher teacher;
  const MyCoursesTab({super.key, required this.teacher});
  @override State<MyCoursesTab> createState() => _MyCoursesTabState();
}
class _MyCoursesTabState extends State<MyCoursesTab> {
  List<Course> _list = []; Map<String, int> _counts = {}; bool _loading = true;
  @override void initState() { super.initState(); load(); }

  Future<void> load() async {
    setState(() => _loading = true);
    final all = await _store.courses();
    _list = all.where((c) => c.teacherId == widget.teacher.id).toList();
    for (final c in _list) _counts[c.id] = (await _store.students(courseId: c.id)).length;
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_list.isEmpty) return const Center(child: Text('No courses assigned to you'));
    return ListView.builder(itemCount: _list.length, itemBuilder: (_, i) {
      final c = _list[i];
      return ListTile(
        title: Text(c.name),
        subtitle: Text('${_counts[c.id] ?? 0} students'),
        trailing: ElevatedButton(
          onPressed: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => AttendancePage(course: c))).then((_) => load()),
          child: const Text('Attendance')),
      );
    });
  }
}

// ── Attendance Page ───────────────────────────────

class AttendancePage extends StatefulWidget {
  final Course course;
  const AttendancePage({super.key, required this.course});
  @override State<AttendancePage> createState() => _AttendancePageState();
}
class _AttendancePageState extends State<AttendancePage> {
  List<Student> _students = []; Map<String, S?> _status = {};
  DateTime _date = DateTime.now(); bool _loading = true;

  String get _dk => '${_date.year}-${_date.month.toString().padLeft(2,'0')}-${_date.day.toString().padLeft(2,'0')}';

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    _students = await _store.students(courseId: widget.course.id);
    final all = await _store.recs(courseId: widget.course.id);
    _status = { for (final s in _students) s.id:
      all.cast<Rec?>().firstWhere((r) => r?.studentId == s.id && r?.date == _dk, orElse: () => null)?.status };
    setState(() => _loading = false);
  }

  Future<void> _mark(String sid, S s) async { await _store.mark(Rec(studentId: sid, date: _dk, status: s)); _load(); }
  Future<void> _markAll(S s) async { for (final st in _students) await _store.mark(Rec(studentId: st.id, date: _dk, status: s)); _load(); }

  Future<void> _pickDate() async {
    final d = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime(2020), lastDate: DateTime(2100));
    if (d != null) { _date = d; await _load(); }
  }

  String _label(S s) => s == S.present ? 'P' : s == S.absent ? 'A' : 'L';
  Color _color(S s) => s == S.present ? Colors.green : s == S.absent ? Colors.red : Colors.orange;

  @override
  Widget build(BuildContext context) {
    final marked = _status.values.where((v) => v != null).length;
    return Scaffold(
      appBar: AppBar(title: Text(widget.course.name)),
      body: Column(children: [
        // Date bar
        ListTile(
          leading: const Icon(Icons.calendar_today),
          title: Text('${_date.day}/${_date.month}/${_date.year}  ($marked/${_students.length} marked)'),
          trailing: TextButton(onPressed: _pickDate, child: const Text('Change Date')),
        ),
        const Divider(height: 1),
        // Students
        Expanded(child: _loading ? const Center(child: CircularProgressIndicator())
          : _students.isEmpty ? const Center(child: Text('No students in this course'))
          : ListView.builder(itemCount: _students.length, itemBuilder: (_, i) {
              final s = _students[i]; final st = _status[s.id];
              return ListTile(
                title: Text(s.name),
                subtitle: Text('Roll: ${s.roll}'),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: S.values.map((v) =>
                  Padding(padding: const EdgeInsets.only(left: 4), child: ElevatedButton(
                    onPressed: () => _mark(s.id, v),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: st == v ? _color(v) : Colors.grey[300],
                      foregroundColor: st == v ? Colors.white : Colors.black,
                      minimumSize: const Size(36, 36), padding: EdgeInsets.zero),
                    child: Text(_label(v)),
                  ))).toList(),
              );
            })),
        // Mark all bar
        if (_students.isNotEmpty) Padding(
          padding: const EdgeInsets.all(8),
          child: Row(children: [
            const Text('Mark All: '),
            ...S.values.map((v) => Padding(padding: const EdgeInsets.only(left: 8),
              child: ElevatedButton(
                onPressed: () => _markAll(v),
                style: ElevatedButton.styleFrom(backgroundColor: _color(v), foregroundColor: Colors.white),
                child: Text(_label(v))))),
          ]),
        ),
      ]),
    );
  }
}

// ── Teacher: Records ──────────────────────────────

class RecordsTab extends StatefulWidget {
  final Teacher teacher;
  const RecordsTab({super.key, required this.teacher});
  @override State<RecordsTab> createState() => _RecordsTabState();
}
class _RecordsTabState extends State<RecordsTab> {
  List<Rec> _recs = []; List<Student> _students = []; List<Course> _courses = [];
  String? _filterCourse; bool _loading = true;
  @override void initState() { super.initState(); load(); }

  Future<void> load() async {
    setState(() => _loading = true);
    final allCourses = await _store.courses();
    _courses = allCourses.where((c) => c.teacherId == widget.teacher.id).toList();
    final myIds = _courses.map((c) => c.id).toSet();
    final allStudents = await _store.students();
    _students = allStudents.where((s) => myIds.contains(s.courseId)).toList();
    final sIds = _students.map((s) => s.id).toSet();
    final all = await _store.recs();
    _recs = all.where((r) => sIds.contains(r.studentId)).toList()..sort((a,b) => b.date.compareTo(a.date));
    setState(() => _loading = false);
  }

  List<Rec> get _filtered {
    if (_filterCourse == null) return _recs;
    final ids = _students.where((s) => s.courseId == _filterCourse).map((s) => s.id).toSet();
    return _recs.where((r) => ids.contains(r.studentId)).toList();
  }
  String _name(String id) => _students.firstWhere((s) => s.id == id, orElse: () => Student(id:'',name:'?',roll:'',courseId:'')).name;
  String _roll(String id) => _students.firstWhere((s) => s.id == id, orElse: () => Student(id:'',name:'',roll:'?',courseId:'')).roll;
  String _sLabel(S s) => s == S.present ? 'PRESENT' : s == S.absent ? 'ABSENT' : 'LATE';
  Color _sColor(S s) => s == S.present ? Colors.green : s == S.absent ? Colors.red : Colors.orange;

  @override
  Widget build(BuildContext context) {
    final f = _filtered;
    return Column(children: [
      // Course filter
      if (_courses.isNotEmpty) SingleChildScrollView(scrollDirection: Axis.horizontal,
        child: Row(children: [
          Padding(padding: const EdgeInsets.all(4), child: ChoiceChip(label: const Text('All'),
            selected: _filterCourse == null, onSelected: (_) => setState(() => _filterCourse = null))),
          ..._courses.map((c) => Padding(padding: const EdgeInsets.all(4), child: ChoiceChip(
            label: Text(c.name), selected: _filterCourse == c.id,
            onSelected: (_) => setState(() => _filterCourse = c.id)))),
        ])),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Text('${f.length} record(s)', style: const TextStyle(color: Colors.grey))),
      Expanded(child: _loading ? const Center(child: CircularProgressIndicator())
        : f.isEmpty ? const Center(child: Text('No records yet'))
        : ListView.builder(itemCount: f.length, itemBuilder: (_, i) {
            final r = f[i];
            return ListTile(
              title: Text(_name(r.studentId)),
              subtitle: Text('Roll: ${_roll(r.studentId)}  •  ${r.date}'),
              trailing: Text(_sLabel(r.status), style: TextStyle(color: _sColor(r.status), fontWeight: FontWeight.bold)),
            );
          })),
    ]);
  }
}
