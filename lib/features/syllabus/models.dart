/// The exam-preparation tree:
///   Exam → Unit → Chapter → Topic → SubTopic
/// Every node carries its own status, revision count,
/// scheduled revision and total test attempts.
library;

enum NodeStatus { notDone, doing, partial, done }

class ExamNode {
  ExamNode({
    required this.id,
    required this.name,
    this.status = NodeStatus.notDone,
    this.revisions = 0,
    this.attempts = 0,
    this.nextRevision,
    this.locked = false,
    this.lockedBy,
    List<ExamNode>? children,
  }) : children = children ?? [];

  final String id;
  String name;
  NodeStatus status;
  int revisions;
  int attempts;
  DateTime? nextRevision;
  bool locked;
  String? lockedBy;
  final List<ExamNode> children;

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'status': status.index,
        'rev': revisions,
        'att': attempts,
        'rr': nextRevision?.toIso8601String(),
        if (locked) 'locked': locked,
        if (lockedBy != null) 'lockedBy': lockedBy,
        'ch': children.map((c) => c.toJson()).toList(),
      };

  static ExamNode fromJson(Map<String, Object?> j) => ExamNode(
        id: j['id'] as String,
        name: j['name'] as String,
        status: NodeStatus.values[j['status'] as int],
        revisions: j['rev'] as int? ?? 0,
        attempts: j['att'] as int? ?? 0,
        nextRevision: j['rr'] == null
            ? null
            : DateTime.tryParse(j['rr'] as String),
        locked: j['locked'] as bool? ?? false,
        lockedBy: j['lockedBy'] as String?,
        children: (j['ch'] as List<dynamic>? ?? [])
            .map((e) => fromJson(e as Map<String, Object>))
            .toList(),
      );
}

/// Recursively finds a node by id.
ExamNode? findNode(List<ExamNode> roots, String id) {
  for (final r in roots) {
    if (r.id == id) return r;
    final hit = findNode(r.children, id);
    if (hit != null) return hit;
  }
  return null;
}

/// Adds [child] to the node whose id matches [parentId].
bool addChildTo(List<ExamNode> roots, String parentId, ExamNode child) {
  for (final r in roots) {
    if (r.id == parentId) {
      r.children.add(child);
      return true;
    }
    if (addChildTo(r.children, parentId, child)) return true;
  }
  return false;
}

/// Removes the node with [id] (and its subtree).
bool removeNodeFrom(List<ExamNode> roots, String id) {
  for (final r in roots) {
    if (r.id == id) return roots.remove(r);
    if (removeNodeFrom(r.children, id)) return true;
  }
  return false;
}

int totalAttempts(ExamNode n) =>
    n.attempts + n.children.fold(0, (s, c) => s + totalAttempts(c));

int totalDone(ExamNode n) =>
    (n.status == NodeStatus.done ? 1 : 0) +
    n.children.fold(0, (s, c) => s + totalDone(c));

int totalNodes(ExamNode n) =>
    1 + n.children.fold(0, (s, c) => s + totalNodes(c));

/// Count of nodes per status within a subtree (including [n] itself).
Map<NodeStatus, int> statusCounts(ExamNode n) {
  final counts = {for (final s in NodeStatus.values) s: 0};
  void walk(ExamNode x) {
    counts[x.status] = counts[x.status]! + 1;
    for (final c in x.children) {
      walk(c);
    }
  }

  walk(n);
  return counts;
}

/// done / total for a subtree (excluding the node itself unless counted).
double completionRatio(ExamNode n) {
  final nodes = totalNodes(n);
  return nodes == 0 ? 0.0 : totalDone(n) / nodes;
}
