import 'dart:isolate';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/repositories/providers.dart';

// ── Data Models ───────────────────────────────────────────────────────────────

enum NodeMastery { locked, learnt, inProgress, mastered }

class GraphNode {
  final int id;
  final String name;
  final String? category;
  final int problemCount;
  double x;
  double y;
  double vx;
  double vy;
  NodeMastery mastery;
  bool isWishlisted;

  GraphNode({
    required this.id,
    required this.name,
    this.category,
    required this.problemCount,
    required this.x,
    required this.y,
    this.vx = 0,
    this.vy = 0,
    this.mastery = NodeMastery.locked,
    this.isWishlisted = false,
  });

  double get radius => (8 + sqrt(problemCount.toDouble()) * 2.5).clamp(8.0, 36.0);

  Color get color {
    switch (mastery) {
      case NodeMastery.mastered:
        return AppColors.primary;
      case NodeMastery.inProgress:
        return AppColors.amber;
      case NodeMastery.learnt:
        return const Color(0xFF3A6EA5);
      case NodeMastery.locked:
        return const Color(0xFF2A2A3E);
    }
  }
}

class GraphEdge {
  final int fromId; // dependent
  final int toId;   // prerequisite (requires)
  GraphEdge({required this.fromId, required this.toId});
}

// ── Isolate payload ───────────────────────────────────────────────────────────

class _LayoutInput {
  final List<Map<String, dynamic>> nodes;
  final List<Map<String, int>> edges;
  final SendPort sendPort;
  _LayoutInput(this.nodes, this.edges, this.sendPort);
}

void _runLayout(_LayoutInput input) {
  final rng = Random(42);
  final nodes = input.nodes.map((n) {
    return {
      'id': n['id'] as int,
      'x': (rng.nextDouble() - 0.5) * 600,
      'y': (rng.nextDouble() - 0.5) * 600,
      'vx': 0.0,
      'vy': 0.0,
      'r': n['r'] as double,
    };
  }).toList();

  const iterations = 200;
  const kRepulsion = 8000.0;
  const kSpring = 0.04;
  const restLength = 140.0;
  const damping = 0.85;
  const gravity = 0.02;

  final idIndex = <int, int>{};
  for (int i = 0; i < nodes.length; i++) {
    idIndex[nodes[i]['id'] as int] = i;
  }

  for (int iter = 0; iter < iterations; iter++) {
    // Reset forces
    for (final n in nodes) {
      n['fx'] = 0.0;
      n['fy'] = 0.0;
    }

    // Repulsion between all pairs
    for (int i = 0; i < nodes.length; i++) {
      for (int j = i + 1; j < nodes.length; j++) {
        final dx = (nodes[i]['x'] as double) - (nodes[j]['x'] as double);
        final dy = (nodes[i]['y'] as double) - (nodes[j]['y'] as double);
        final dist = max(sqrt(dx * dx + dy * dy), 1.0);
        final force = kRepulsion / (dist * dist);
        final fx = dx / dist * force;
        final fy = dy / dist * force;
        nodes[i]['fx'] = (nodes[i]['fx'] as double) + fx;
        nodes[i]['fy'] = (nodes[i]['fy'] as double) + fy;
        nodes[j]['fx'] = (nodes[j]['fx'] as double) - fx;
        nodes[j]['fy'] = (nodes[j]['fy'] as double) - fy;
      }

      // Gravity toward center
      nodes[i]['fx'] = (nodes[i]['fx'] as double) - (nodes[i]['x'] as double) * gravity;
      nodes[i]['fy'] = (nodes[i]['fy'] as double) - (nodes[i]['y'] as double) * gravity;
    }

    // Spring forces along edges
    for (final edge in input.edges) {
      final ai = idIndex[edge['tagId']];
      final bi = idIndex[edge['requiresTagId']];
      if (ai == null || bi == null) continue;
      final a = nodes[ai];
      final b = nodes[bi];
      final dx = (a['x'] as double) - (b['x'] as double);
      final dy = (a['y'] as double) - (b['y'] as double);
      final dist = max(sqrt(dx * dx + dy * dy), 1.0);
      final force = kSpring * (dist - restLength);
      final fx = dx / dist * force;
      final fy = dy / dist * force;
      a['fx'] = (a['fx'] as double) - fx;
      a['fy'] = (a['fy'] as double) - fy;
      b['fx'] = (b['fx'] as double) + fx;
      b['fy'] = (b['fy'] as double) + fy;
    }

    // Integrate
    for (final n in nodes) {
      n['vx'] = ((n['vx'] as double) + (n['fx'] as double)) * damping;
      n['vy'] = ((n['vy'] as double) + (n['fy'] as double)) * damping;
      n['x'] = (n['x'] as double) + (n['vx'] as double);
      n['y'] = (n['y'] as double) + (n['vy'] as double);
    }
  }

  input.sendPort.send(
    nodes.map((n) => {'id': n['id'], 'x': n['x'], 'y': n['y']}).toList(),
  );
}

// ── State ─────────────────────────────────────────────────────────────────────

class _GraphState {
  final List<GraphNode> nodes;
  final List<GraphEdge> edges;
  final bool layoutReady;
  final int? selectedNodeId;
  final Set<int> highlightedNodes;
  final Set<int> highlightedEdgesFrom;
  final bool showLearntOnly;
  final bool showLegend;

  const _GraphState({
    this.nodes = const [],
    this.edges = const [],
    this.layoutReady = false,
    this.selectedNodeId,
    this.highlightedNodes = const {},
    this.highlightedEdgesFrom = const {},
    this.showLearntOnly = false,
    this.showLegend = false,
  });

  _GraphState copyWith({
    List<GraphNode>? nodes,
    List<GraphEdge>? edges,
    bool? layoutReady,
    int? selectedNodeId,
    bool clearSelected = false,
    Set<int>? highlightedNodes,
    Set<int>? highlightedEdgesFrom,
    bool? showLearntOnly,
    bool? showLegend,
  }) {
    return _GraphState(
      nodes: nodes ?? this.nodes,
      edges: edges ?? this.edges,
      layoutReady: layoutReady ?? this.layoutReady,
      selectedNodeId: clearSelected ? null : (selectedNodeId ?? this.selectedNodeId),
      highlightedNodes: highlightedNodes ?? this.highlightedNodes,
      highlightedEdgesFrom: highlightedEdgesFrom ?? this.highlightedEdgesFrom,
      showLearntOnly: showLearntOnly ?? this.showLearntOnly,
      showLegend: showLegend ?? this.showLegend,
    );
  }
}

// ── Screen ────────────────────────────────────────────────────────────────────

class ConceptGraphScreen extends ConsumerStatefulWidget {
  const ConceptGraphScreen({super.key});

  @override
  ConsumerState<ConceptGraphScreen> createState() => _ConceptGraphScreenState();
}

class _ConceptGraphScreenState extends ConsumerState<ConceptGraphScreen> {
  _GraphState _state = const _GraphState();
  final _transformController = TransformationController();

  @override
  void initState() {
    super.initState();
    _loadGraph();
  }

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  Future<void> _loadGraph() async {
    final repo = ref.read(localRepositoryProvider);
    final learntIds = ref.read(learntConceptsProvider).value ?? [];

    final tags = await repo.getAllTags();
    final edges = await repo.getAllEdges();
    final countMap = await repo.getProblemCountPerTag();

    if (tags.isEmpty) return;

    // Determine mastery per tag using rough heuristics
    // (solvedIds are problem IDs, not directly tag IDs — use learnt list for now)
    final learntSet = learntIds.toSet();

    final nodeMap = <int, GraphNode>{};
    for (final tag in tags) {
      final isLearnt = learntSet.contains(tag.id);
      nodeMap[tag.id] = GraphNode(
        id: tag.id,
        name: tag.name,
        category: tag.category,
        problemCount: countMap[tag.id] ?? 0,
        x: 0,
        y: 0,
        mastery: isLearnt ? NodeMastery.learnt : NodeMastery.locked,
      );
    }

    final graphEdges = edges
        .map((e) => GraphEdge(fromId: e['tagId']!, toId: e['requiresTagId']!))
        .where((e) => nodeMap.containsKey(e.fromId) && nodeMap.containsKey(e.toId))
        .toList();

    setState(() {
      _state = _state.copyWith(
        nodes: nodeMap.values.toList(),
        edges: graphEdges,
      );
    });

    // Run layout in Isolate
    final receivePort = ReceivePort();
    final input = _LayoutInput(
      nodeMap.values
          .map((n) => {'id': n.id, 'r': n.radius})
          .toList(),
      edges,
      receivePort.sendPort,
    );

    await Isolate.spawn(_runLayout, input);

    final result = await receivePort.first as List;
    final positions = {
      for (final item in result)
        (item as Map)['id'] as int: Offset(
          item['x'] as double,
          item['y'] as double,
        )
    };

    final updatedNodes = _state.nodes.map((n) {
      final pos = positions[n.id];
      if (pos != null) {
        n.x = pos.dx;
        n.y = pos.dy;
      }
      return n;
    }).toList();

    if (mounted) {
      setState(() {
        _state = _state.copyWith(nodes: updatedNodes, layoutReady: true);
      });
      _resetCamera();
    }
  }

  void _resetCamera() {
    _transformController.value = Matrix4.identity()..scale(0.5);
  }

  void _onNodeTap(GraphNode node) {
    setState(() {
      _state = _state.copyWith(selectedNodeId: node.id);
    });
    _showNodeSheet(node);
  }

  void _onNodeLongPress(GraphNode node) {
    // Build reachable sets
    final prereqs = <int>{};
    final deps = <int>{};

    // BFS for prerequisites (backward)
    final queue = <int>[node.id];
    final visited = <int>{node.id};
    while (queue.isNotEmpty) {
      final current = queue.removeAt(0);
      for (final edge in _state.edges) {
        if (edge.fromId == current && !visited.contains(edge.toId)) {
          visited.add(edge.toId);
          prereqs.add(edge.toId);
          queue.add(edge.toId);
        }
      }
    }

    // BFS for dependents (forward)
    final queue2 = <int>[node.id];
    final visited2 = <int>{node.id};
    while (queue2.isNotEmpty) {
      final current = queue2.removeAt(0);
      for (final edge in _state.edges) {
        if (edge.toId == current && !visited2.contains(edge.fromId)) {
          visited2.add(edge.fromId);
          deps.add(edge.fromId);
          queue2.add(edge.fromId);
        }
      }
    }

    setState(() {
      _state = _state.copyWith(
        highlightedNodes: {node.id, ...prereqs, ...deps},
        highlightedEdgesFrom: {node.id, ...prereqs, ...deps},
        clearSelected: true,
      );
    });
  }

  void _clearHighlight() {
    setState(() {
      _state = _state.copyWith(
        highlightedNodes: const {},
        highlightedEdgesFrom: const {},
        clearSelected: true,
      );
    });
  }

  void _showNodeSheet(GraphNode node) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _NodeBottomSheet(
        node: node,
        onLearnTap: () {
          Navigator.pop(context);
          _markLearnt(node);
        },
        onDiscoverTap: () {
          Navigator.pop(context);
          context.push('/discover');
        },
      ),
    );
  }

  void _markLearnt(GraphNode node) {
    setState(() {
      node.mastery = NodeMastery.learnt;
    });
    // In full implementation: also write to Firestore via firestoreServiceProvider
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Concepts', style: AppTextStyles.screenTitle),
      ),
      body: Stack(
        children: [
          if (!_state.layoutReady)
            const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: AppColors.primary),
                  SizedBox(height: 16),
                  Text('Building concept graph…',
                      style: AppTextStyles.bodySecondary),
                ],
              ),
            )
          else
            GestureDetector(
              onTap: _clearHighlight,
              child: InteractiveViewer(
                transformationController: _transformController,
                minScale: 0.2,
                maxScale: 4.0,
                boundaryMargin: const EdgeInsets.all(double.infinity),
                child: _GraphCanvas(
                  state: _state,
                  onNodeTap: _onNodeTap,
                  onNodeLongPress: _onNodeLongPress,
                ),
              ),
            ),

          // Top control bar
          if (_state.layoutReady)
            Positioned(
              top: MediaQuery.of(context).padding.top + 60,
              right: 16,
              child: _ControlBar(
                showLearntOnly: _state.showLearntOnly,
                showLegend: _state.showLegend,
                onToggleLearntOnly: () => setState(() {
                  _state =
                      _state.copyWith(showLearntOnly: !_state.showLearntOnly);
                }),
                onToggleLegend: () => setState(() {
                  _state = _state.copyWith(showLegend: !_state.showLegend);
                }),
                onReset: _resetCamera,
              ),
            ),

          // Legend overlay
          if (_state.showLegend)
            Positioned(
              top: MediaQuery.of(context).padding.top + 120,
              right: 16,
              child: const _LegendCard(),
            ),
        ],
      ),
    );
  }
}

// ── Graph Canvas ──────────────────────────────────────────────────────────────

class _GraphCanvas extends StatelessWidget {
  final _GraphState state;
  final ValueChanged<GraphNode> onNodeTap;
  final ValueChanged<GraphNode> onNodeLongPress;

  const _GraphCanvas({
    required this.state,
    required this.onNodeTap,
    required this.onNodeLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final nodes = state.showLearntOnly
        ? state.nodes
            .where((n) => n.mastery != NodeMastery.locked)
            .toList()
        : state.nodes;

    final visibleIds = nodes.map((n) => n.id).toSet();

    return CustomPaint(
      painter: _GraphPainter(
        nodes: nodes,
        edges: state.edges
            .where((e) =>
                visibleIds.contains(e.fromId) && visibleIds.contains(e.toId))
            .toList(),
        highlightedNodes: state.highlightedNodes,
        highlightedEdgesFrom: state.highlightedEdgesFrom,
      ),
      child: Stack(
        children: nodes.map((node) {
          final isHighlighted = state.highlightedNodes.isEmpty ||
              state.highlightedNodes.contains(node.id);
          return Positioned(
            left: node.x + 500 - node.radius,
            top: node.y + 500 - node.radius,
            width: node.radius * 2,
            height: node.radius * 2,
            child: GestureDetector(
              onTap: () => onNodeTap(node),
              onLongPress: () => onNodeLongPress(node),
              child: Opacity(
                opacity: isHighlighted ? 1.0 : 0.2,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: node.color,
                    boxShadow: state.selectedNodeId == node.id
                        ? [
                            BoxShadow(
                              color: node.color.withValues(alpha: 0.6),
                              blurRadius: 12,
                              spreadRadius: 4,
                            ),
                          ]
                        : null,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _GraphPainter extends CustomPainter {
  final List<GraphNode> nodes;
  final List<GraphEdge> edges;
  final Set<int> highlightedNodes;
  final Set<int> highlightedEdgesFrom;

  _GraphPainter({
    required this.nodes,
    required this.edges,
    required this.highlightedNodes,
    required this.highlightedEdgesFrom,
  });

  static const double _offset = 500;

  Offset _pos(GraphNode n) => Offset(n.x + _offset, n.y + _offset);

  @override
  void paint(Canvas canvas, Size size) {
    final nodeMap = {for (final n in nodes) n.id: n};

    for (final edge in edges) {
      final from = nodeMap[edge.fromId];
      final to = nodeMap[edge.toId];
      if (from == null || to == null) continue;

      final isHighlighted = highlightedEdgesFrom.isEmpty ||
          (highlightedEdgesFrom.contains(edge.fromId) ||
              highlightedEdgesFrom.contains(edge.toId));

      final paint = Paint()
        ..strokeWidth = 1.0
        ..style = PaintingStyle.stroke
        ..color = Colors.white.withValues(
            alpha: isHighlighted ? 0.15 : 0.03);

      canvas.drawLine(_pos(from), _pos(to), paint);
    }

    // Node labels (small, below each node)
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    for (final node in nodes) {
      final isHighlighted = highlightedNodes.isEmpty ||
          highlightedNodes.contains(node.id);
      if (!isHighlighted) continue;
      if (node.problemCount < 5) continue; // Only show labels for larger nodes

      textPainter.text = TextSpan(
        text: node.name.split(' ').first,
        style: const TextStyle(
          color: Colors.white54,
          fontSize: 9,
          fontFamily: 'Inter',
        ),
      );
      textPainter.layout();
      final pos = _pos(node);
      textPainter.paint(
        canvas,
        Offset(
          pos.dx - textPainter.width / 2,
          pos.dy + node.radius + 2,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(_GraphPainter old) => true;
}

// ── Control Bar ───────────────────────────────────────────────────────────────

class _ControlBar extends StatelessWidget {
  final bool showLearntOnly;
  final bool showLegend;
  final VoidCallback onToggleLearntOnly;
  final VoidCallback onToggleLegend;
  final VoidCallback onReset;

  const _ControlBar({
    required this.showLearntOnly,
    required this.showLegend,
    required this.onToggleLearntOnly,
    required this.onToggleLegend,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          _ControlButton(
            icon: showLearntOnly
                ? Icons.visibility
                : Icons.visibility_off_outlined,
            tooltip: showLearntOnly ? 'Show all' : 'Learnt only',
            onTap: onToggleLearntOnly,
            active: showLearntOnly,
          ),
          const Divider(height: 1, color: AppColors.border),
          _ControlButton(
            icon: Icons.info_outline_rounded,
            tooltip: 'Legend',
            onTap: onToggleLegend,
            active: showLegend,
          ),
          const Divider(height: 1, color: AppColors.border),
          _ControlButton(
            icon: Icons.center_focus_strong_outlined,
            tooltip: 'Reset view',
            onTap: onReset,
          ),
        ],
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool active;

  const _ControlButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(
            icon,
            size: 20,
            color: active ? AppColors.primary : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

// ── Legend Card ───────────────────────────────────────────────────────────────

class _LegendCard extends StatelessWidget {
  const _LegendCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          _LegendItem(color: AppColors.primary, label: 'Mastered (80%+)'),
          SizedBox(height: 6),
          _LegendItem(color: AppColors.amber, label: 'In Progress'),
          SizedBox(height: 6),
          _LegendItem(color: Color(0xFF3A6EA5), label: 'Learnt'),
          SizedBox(height: 6),
          _LegendItem(color: Color(0xFF2A2A3E), label: 'Locked'),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(label,
            style: AppTextStyles.caption
                .copyWith(color: AppColors.textSecondary)),
      ],
    );
  }
}

// ── Node Bottom Sheet ─────────────────────────────────────────────────────────

class _NodeBottomSheet extends StatelessWidget {
  final GraphNode node;
  final VoidCallback onLearnTap;
  final VoidCallback onDiscoverTap;

  const _NodeBottomSheet({
    required this.node,
    required this.onLearnTap,
    required this.onDiscoverTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Title + category
          Text(node.name,
              style: AppTextStyles.sectionHeader
                  .copyWith(color: AppColors.textPrimary)),
          if (node.category != null)
            Text(node.category!,
                style: AppTextStyles.caption
                    .copyWith(color: AppColors.textMuted)),
          const SizedBox(height: 12),

          // Stats
          Text(
            '${node.problemCount} problems tagged',
            style: AppTextStyles.bodySecondary,
          ),
          const SizedBox(height: 4),

          // Mastery pill
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: node.color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              node.mastery.name[0].toUpperCase() +
                  node.mastery.name.substring(1),
              style: AppTextStyles.caption.copyWith(color: node.color),
            ),
          ),
          const SizedBox(height: 20),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.search_rounded, size: 16),
                  label: const Text('See Problems'),
                  onPressed: onDiscoverTap,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    side: const BorderSide(color: AppColors.border),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              if (node.mastery == NodeMastery.locked)
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: const Text('Mark Learnt'),
                    onPressed: onLearnTap,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.background,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
