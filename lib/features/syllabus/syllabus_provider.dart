import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../reminders/reminders_provider.dart';
import 'models.dart';
import 'revision_reminders.dart';

/// Persists the whole exam → unit → chapter → topic → subtopic tree
/// in SharedPreferences as a JSON document.
class SyllabusTreeNotifier extends StateNotifier<List<ExamNode>> {
  SyllabusTreeNotifier({this.onStatusChanged}) : super(_seed()) {
    _load();
  }

  /// Fired after a node's status changed (with the previous one) so
  /// spaced-revision reminders can follow DONE transitions.
  final void Function(ExamNode node, NodeStatus prev)? onStatusChanged;

  static const _prefsKey = 'syllabus_tree_v3';
  static int _idSeq = 0;

  static String _id() => 'n${DateTime.now().microsecondsSinceEpoch}${_idSeq++}';

  static List<ExamNode> _seed() => [
        ExamNode(
          id: _id(),
          name: 'ISI · CMI',
          status: NodeStatus.doing,
          children: [
            for (final (unit, chapters) in _seedUnits)
              ExamNode(
                id: _id(),
                name: unit,
                children: [
                  for (final ch in chapters)
                    ExamNode(id: _id(), name: ch),
                ],
              ),
          ],
        ),
      ];

  static const _seedUnits = <(String, List<String>)>[
    ('Algebra', [
      'Quadratic equations & polynomials',
      'Complex numbers',
      'Binomial theorem',
      'Sequences & series',
      'Matrices & determinants',
      'Permutations & combinations',
      'Inequalities (AM-GM, Cauchy)',
    ]),
    ('Calculus', [
      'Limits & continuity',
      'Differentiability',
      'Derivatives & applications',
      'Indefinite integration',
      'Definite integrals & areas',
      'Differential equations',
    ]),
    ('Geometry & Trigonometry', [
      'Coordinate geometry',
      'Circles & conics',
      'Trigonometric identities',
      'Triangles & Euclidean geometry',
    ]),
    ('Number Theory', [
      'Divisibility & GCD–LCM',
      'Primes & factorization',
      'Modular arithmetic',
      'Diophantine equations',
      'Floor & ceiling functions',
    ]),
    ('Combinatorics', [
      'Counting & bijections',
      'Pigeonhole principle',
      'Recurrence relations',
      'Inclusion–exclusion',
    ]),
    ('Probability & Statistics', [
      'Probability axioms',
      'Random variables & distributions',
      'Expectation & variance',
    ]),
  ];

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final list = (jsonDecode(raw) as List<dynamic>)
          .map((e) => ExamNode.fromJson(e as Map<String, Object>))
          .toList();
      // An empty saved list is valid (user deleted every exam) — restore
      // it as-is instead of falling back to the seed.
      state = list;
    } catch (_) {
      // corrupted payload — keep seed
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _prefsKey,
      jsonEncode(state.map((n) => n.toJson()).toList()),
    );
  }

  // ------------------------------------------------------------------ CRUD

  Future<void> addChild(String parentId, String name, {String childLevel = ''}) async {
    if (name.trim().isEmpty) return;
    final child = ExamNode(id: _id(), name: name.trim());
    addChildTo(state, parentId, child);
    state = [...state];
    await _save();
  }

  Future<void> addExam(String name) async {
    if (name.trim().isEmpty) return;
    state = [
      ...state,
      ExamNode(id: _id(), name: name.trim()),
    ];
    await _save();
  }

  Future<void> remove(String id) async {
    removeNodeFrom(state, id);
    state = [...state];
    await _save();
  }

  Future<void> rename(String id, String name) async {
    if (name.trim().isEmpty) return;
    final n = findNode(state, id);
    if (n == null) return;
    n.name = name.trim();
    state = [...state];
    await _save();
  }

  Future<void> cycleStatus(String id) async {
    final n = findNode(state, id);
    if (n == null) return;
    final prev = n.status;
    n.status = switch (n.status) {
      NodeStatus.notDone => NodeStatus.doing,
      NodeStatus.doing => NodeStatus.partial,
      NodeStatus.partial => NodeStatus.done,
      NodeStatus.done => NodeStatus.notDone,
    };
    state = [...state];
    await _save();
    onStatusChanged?.call(n, prev);
  }

  Future<void> setStatus(String id, NodeStatus status) async {
    final n = findNode(state, id);
    if (n == null) return;
    final prev = n.status;
    n.status = status;
    state = [...state];
    await _save();
    onStatusChanged?.call(n, prev);
  }

  Future<void> bumpAttempts(String id, int delta) async {
    final n = findNode(state, id);
    if (n == null) return;
    n.attempts = (n.attempts + delta).clamp(0, 9999);
    state = [...state];
    await _save();
  }

  Future<void> setRevisions(String id, int count) async {
    final n = findNode(state, id);
    if (n == null) return;
    n.revisions = count.clamp(0, 99);
    state = [...state];
    await _save();
  }

  Future<void> scheduleRevision(String id, DateTime? date) async {
    final n = findNode(state, id);
    if (n == null) return;
    n.nextRevision = date;
    state = [...state];
    await _save();
  }

  /// Restores a fresh seed tree (profile "Reset all data").
  Future<void> clear() async {
    state = _seed();
    await _save();
  }
}

final syllabusProvider = StateNotifierProvider<SyllabusTreeNotifier, List<ExamNode>>(
  (ref) => SyllabusTreeNotifier(
    onStatusChanged: (node, prev) {
      // Spaced revision: marking a leaf item DONE schedules +3/+7/+14
      // day reminders; un-marking it cancels them.
      if (node.children.isNotEmpty) return;
      final reminders = ref.read(remindersProvider.notifier);
      if (node.status == NodeStatus.done) {
        unawaited(RevisionReminders.scheduleFor(node, reminders));
      } else if (prev == NodeStatus.done) {
        unawaited(RevisionReminders.cancelFor(node.id, reminders));
      }
    },
  ),
);

/// Live stats derived from the syllabus tree — single source of truth
/// that every "stat" widget (dashboard, rails, top bar) reads from.
class AppStats {
  const AppStats({
    required this.nodes,
    required this.done,
    required this.doing,
    required this.partial,
    required this.notDone,
    required this.attempts,
    required this.scheduled,
    required this.exams,
  });

  final int nodes;
  final int done;
  final int doing;
  final int partial;
  final int notDone;
  final int attempts;
  final int scheduled;
  final int exams;

  double get coverage => nodes == 0 ? 0 : done / nodes;
  int get pending => nodes - done;
}

final appStatsProvider = Provider<AppStats>((ref) {
  final roots = ref.watch(syllabusProvider);

  var nodes = 0, done = 0, doing = 0, partial = 0, notDone = 0;
  var attempts = 0, scheduled = 0;

  void walk(ExamNode n) {
    nodes++;
    switch (n.status) {
      case NodeStatus.done:
        done++;
      case NodeStatus.doing:
        doing++;
      case NodeStatus.partial:
        partial++;
      case NodeStatus.notDone:
        notDone++;
    }
    attempts += n.attempts;
    if (n.nextRevision != null) scheduled++;
    for (final c in n.children) {
      walk(c);
    }
  }

  for (final r in roots) {
    walk(r);
  }

  return AppStats(
    nodes: nodes,
    done: done,
    doing: doing,
    partial: partial,
    notDone: notDone,
    attempts: attempts,
    scheduled: scheduled,
    exams: roots.length,
  );
});