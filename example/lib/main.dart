import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dock_panel/dock_panel.dart';

// ─── Entry Point ─────────────────────────────────────────────

void main() {
  runApp(const ProviderScope(child: DockPanelDemoApp()));
}

class DockPanelDemoApp extends StatelessWidget {
  const DockPanelDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dock Panel Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF1E1E1E),
      ),
      home: const DemoDockScreen(),
    );
  }
}

// ─── Main Screen ─────────────────────────────────────────────

class DemoDockScreen extends ConsumerStatefulWidget {
  const DemoDockScreen({super.key});

  @override
  ConsumerState<DemoDockScreen> createState() => _DemoDockScreenState();
}

class _DemoDockScreenState extends ConsumerState<DemoDockScreen> {
  int _panelCounter = 0;
  bool _isDark = true;
  final _storage = MemoryDockStorage();
  int _snapshotCount = 0;

  // ─── Theme data ───────────────────────────────────────────

  static const _darkTheme = DockThemeData();
  static const _lightTheme = DockThemeData.light;

  DockThemeData get _currentTheme => _isDark ? _darkTheme : _lightTheme;

  // ─── Lifecycle ────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    final manager = ref.read(dockManagerProvider.notifier);
    manager.setStorage(_storage);
    WidgetsBinding.instance.addPostFrameCallback((_) => _setupLayout());
  }

  void _setupLayout() {
    final manager = ref.read(dockManagerProvider.notifier);

    // ─── Panel definitions ──────────────────────────────────
    final panels = [
      DockPanel(
        id: 'file_explorer',
        title: 'Explorer',
        icon: Icons.folder_outlined,
        closable: false,
        builder: (_) => _FileExplorerPanel(onFileOpen: _openFileInEditor),
      ),
      DockPanel(
        id: 'editor_main',
        title: 'main.dart',
        icon: Icons.code,
        builder: (_) => const _CodeEditorPanel(filename: 'main.dart'),
      ),
      DockPanel(
        id: 'editor_model',
        title: 'model.dart',
        icon: Icons.data_object,
        builder: (_) => const _CodeEditorPanel(filename: 'model.dart'),
      ),
      DockPanel(
        id: 'terminal',
        title: 'Terminal',
        icon: Icons.terminal,
        builder: (_) => const _TerminalPanel(),
      ),
      DockPanel(
        id: 'output',
        title: 'Output',
        icon: Icons.output,
        builder: (_) => const _OutputPanel(),
      ),
      DockPanel(
        id: 'problems',
        title: 'Problems',
        icon: Icons.warning_amber,
        builder: (_) => const _ProblemsPanel(),
      ),
      DockPanel(
        id: 'outline',
        title: 'Outline',
        icon: Icons.account_tree_outlined,
        builder: (_) => const _OutlinePanel(),
      ),
      DockPanel(
        id: 'welcome',
        title: 'Welcome',
        icon: Icons.emoji_objects,
        builder: (_) => const _WelcomePanel(),
      ),
    ];

    for (final p in panels) {
      manager.addPanel(p);
    }

    // ─── Build IDE layout ───────────────────────────────────
    // Bottom row: terminal + output + problems
    manager.movePanel('terminal', 'welcome', DockPosition.bottom);
    manager.movePanel('output', 'terminal', DockPosition.center);
    manager.movePanel('problems', 'terminal', DockPosition.center);

    // Left: explorer
    manager.movePanel('file_explorer', 'welcome', DockPosition.left);

    // Center: editors
    manager.movePanel('editor_main', 'welcome', DockPosition.center);
    manager.movePanel('editor_model', 'editor_main', DockPosition.center);

    // Right: outline
    manager.movePanel('outline', 'welcome', DockPosition.right);

    // Close welcome after building layout
    manager.removePanel('welcome');
  }

  // ─── Actions ──────────────────────────────────────────────

  void _addNewPanel() {
    _panelCounter++;
    final manager = ref.read(dockManagerProvider.notifier);
    manager.addPanel(DockPanel(
      id: 'dynamic_$_panelCounter',
      title: 'Tab $_panelCounter',
      icon: Icons.tab,
      builder: (_) => _DemoContent(
        title: 'Dynamic Panel $_panelCounter',
        color: Colors.primaries[_panelCounter % Colors.primaries.length],
      ),
    ));
    setState(() {}); // trigger status bar rebuild
  }

  /// Demonstrate copyWith(): duplicate the active panel in the first group.
  void _duplicateActivePanel() {
    final manager = ref.read(dockManagerProvider.notifier);
    final layout = ref.read(dockManagerProvider);
    final firstGroup = _findFirstGroup(layout.root);
    if (firstGroup == null || firstGroup.activePanel == null) return;

    _panelCounter++;
    final source = firstGroup.activePanel!;
    final dup = source.copyWith(
      id: 'copy_$_panelCounter',
      title: '${source.title} (copy)',
    );
    manager.addPanel(dup, targetGroupId: firstGroup.id);
    setState(() {});
  }

  DockGroup? _findFirstGroup(DockNode? node) {
    return switch (node) {
      DockGroup() => node,
      DockSplit(:final children) => children
          .map(_findFirstGroup)
          .where((g) => g != null)
          .firstOrNull,
      _ => null,
    };
  }

  void _openFileInEditor(String filename) {
    _panelCounter++;
    final manager = ref.read(dockManagerProvider.notifier);
    final id = 'editor_$filename';
    // Check if already open.
    if (manager.getPanel(id) != null) return;

    manager.addPanel(DockPanel(
      id: id,
      title: filename,
      icon: Icons.code,
      builder: (_) => _CodeEditorPanel(filename: filename),
    ));
    setState(() {});
  }

  void _toggleTheme() {
    setState(() => _isDark = !_isDark);
  }

  void _resetLayout() {
    ref.read(dockManagerProvider.notifier).setLayout(const DockLayout());
    _panelCounter = 0;
    WidgetsBinding.instance.addPostFrameCallback((_) => _setupLayout());
    setState(() {});
  }

  Future<void> _restoreLayout() async {
    final manager = ref.read(dockManagerProvider.notifier);
    // Re-register core panels so restore can find them.
    for (final panel in _allCorePanels()) {
      manager.registerPanel(panel);
    }
    await manager.restore();
    setState(() {});
  }

  List<DockPanel> _allCorePanels() {
    return [
      DockPanel(id: 'file_explorer', title: 'Explorer', icon: Icons.folder_outlined, closable: false, builder: (_) => _FileExplorerPanel(onFileOpen: _openFileInEditor)),
      DockPanel(id: 'editor_main', title: 'main.dart', icon: Icons.code, builder: (_) => const _CodeEditorPanel(filename: 'main.dart')),
      DockPanel(id: 'editor_model', title: 'model.dart', icon: Icons.data_object, builder: (_) => const _CodeEditorPanel(filename: 'model.dart')),
      DockPanel(id: 'terminal', title: 'Terminal', icon: Icons.terminal, builder: (_) => const _TerminalPanel()),
      DockPanel(id: 'output', title: 'Output', icon: Icons.output, builder: (_) => const _OutputPanel()),
      DockPanel(id: 'problems', title: 'Problems', icon: Icons.warning_amber, builder: (_) => const _ProblemsPanel()),
      DockPanel(id: 'outline', title: 'Outline', icon: Icons.account_tree_outlined, builder: (_) => const _OutlinePanel()),
    ];
  }

  void _snapshotLayout() {
    _snapshotCount++;
    final layout = ref.read(dockManagerProvider);
    final desc = _describeLayout(layout.root);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Snapshot #$_snapshotCount: $desc'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        width: 400,
      ),
    );
  }

  String _describeLayout(DockNode? node) {
    if (node == null) return 'empty';
    return switch (node) {
      DockGroup(:final panels) => '${panels.length} tab(s)',
      DockSplit(:final children) => children.map(_describeLayout).join(' | '),
    };
  }

  /// Count total panels across the layout tree.
  int _countPanels(DockNode? node) {
    return switch (node) {
      DockGroup(:final panels) => panels.length,
      DockSplit(:final children) =>
        children.fold(0, (sum, c) => sum + _countPanels(c)),
      _ => 0,
    };
  }

  // ─── Build ────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final layout = ref.watch(dockManagerProvider);
    final totalPanels = _countPanels(layout.root);

    return Scaffold(
      body: Column(
        children: [
          _buildToolbar(),
          Expanded(
            child: DockTheme(
              data: _currentTheme,
              child: DockArea(
                emptyBuilder: (_) => _buildEmptyState(),
              ),
            ),
          ),
          _buildStatusBar(totalPanels),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final fg = _currentTheme.tabTextColor;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.dashboard_customize, size: 64, color: fg.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          Text('No panels open', style: TextStyle(color: fg, fontSize: 18, fontWeight: FontWeight.w300)),
          const SizedBox(height: 8),
          Text('Use the toolbar to add panels or restore a saved layout.',
              style: TextStyle(color: fg.withValues(alpha: 0.5), fontSize: 13)),
          const SizedBox(height: 24),
          _DemoButton(
            label: 'Restore Default Layout',
            icon: Icons.restart_alt,
            onPressed: _resetLayout,
          ),
        ],
      ),
    );
  }

  // ─── Toolbar ──────────────────────────────────────────────

  Widget _buildToolbar() {
    final barBg = _isDark ? const Color(0xFF252526) : const Color(0xFFDDDDDD);
    final fg = _isDark ? Colors.white70 : Colors.black87;

    return Container(
      height: 40,
      color: barBg,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          // Brand
          Row(
            children: [
              Icon(Icons.space_dashboard, size: 18, color: const Color(0xFF4FC3F7)),
              const SizedBox(width: 6),
              Text('Dock Panel', style: TextStyle(color: fg, fontSize: 13, fontWeight: FontWeight.w600)),
            ],
          ),
          _ToolbarSeparator(color: fg),
          // Panel management
          _ToolbarButton(icon: Icons.add, tooltip: 'New Tab', onPressed: _addNewPanel, color: fg),
          _ToolbarButton(icon: Icons.copy, tooltip: 'Duplicate Active Tab (copyWith demo)', onPressed: _duplicateActivePanel, color: fg),
          _ToolbarSeparator(color: fg),
          // Layout
          _ToolbarButton(icon: Icons.camera_alt_outlined, tooltip: 'Snapshot Layout', onPressed: _snapshotLayout, color: fg),
          _ToolbarButton(icon: Icons.history, tooltip: 'Restore Last Saved', onPressed: _restoreLayout, color: fg),
          _ToolbarButton(icon: Icons.restart_alt, tooltip: 'Reset Layout', onPressed: _resetLayout, color: fg),
          _ToolbarSeparator(color: fg),
          // Theme
          _ToolbarButton(icon: _isDark ? Icons.light_mode : Icons.dark_mode, tooltip: 'Toggle Theme', onPressed: _toggleTheme, color: fg),
          const Spacer(),
          // Version badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _isDark ? Colors.white10 : Colors.black12,
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text('v0.0.2', style: TextStyle(color: Color(0xFF4FC3F7), fontSize: 11, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  // ─── Status Bar ───────────────────────────────────────────

  Widget _buildStatusBar(int totalPanels) {
    final bg = _isDark ? const Color(0xFF007ACC) : const Color(0xFF1565C0);
    return Container(
      height: 24,
      color: bg,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          const Icon(Icons.check_circle, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Text('Ready', style: const TextStyle(color: Colors.white, fontSize: 11)),
          const SizedBox(width: 12),
          _StatusBarChip(label: '$totalPanels panel${totalPanels == 1 ? '' : 's'}'),
          _StatusBarChip(label: _isDark ? 'Dark' : 'Light'),
          const Spacer(),
          Text(
            _storage.read() != null ? 'Layout saved' : 'Layout unsaved',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 11),
          ),
        ],
      ),
    );
  }
}

// ─── Toolbar Widgets ─────────────────────────────────────────

class _ToolbarButton extends StatelessWidget {
  const _ToolbarButton({required this.icon, required this.tooltip, required this.onPressed, required this.color});
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 600),
      child: IconButton(
        icon: Icon(icon, size: 16, color: color),
        onPressed: onPressed,
        splashRadius: 14,
        padding: const EdgeInsets.all(4),
        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
      ),
    );
  }
}

class _ToolbarSeparator extends StatelessWidget {
  const _ToolbarSeparator({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4),
    child: Container(width: 1, height: 20, color: color.withValues(alpha: 0.2)),
  );
}

class _StatusBarChip extends StatelessWidget {
  const _StatusBarChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 10),
    child: Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 11)),
  );
}

class _DemoButton extends StatelessWidget {
  const _DemoButton({required this.label, required this.icon, required this.onPressed});
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// Demo Panel Widgets
// ══════════════════════════════════════════════════════════════

class _DemoContent extends StatelessWidget {
  const _DemoContent({required this.title, required this.color});
  final String title;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: color.withValues(alpha: 0.2),
      alignment: Alignment.center,
      child: Text(title,
          style: const TextStyle(color: Colors.white54, fontSize: 20, fontWeight: FontWeight.w300)),
    );
  }
}

// ─── File Explorer ──────────────────────────────────────────

class _FileExplorerPanel extends StatefulWidget {
  const _FileExplorerPanel({required this.onFileOpen});
  final void Function(String filename) onFileOpen;

  @override
  State<_FileExplorerPanel> createState() => _FileExplorerPanelState();
}

class _FileExplorerPanelState extends State<_FileExplorerPanel> {
  static const _items = [
    _FileItem('lib/', Icons.folder, true),
    _FileItem('main.dart', Icons.code, false),
    _FileItem('dock_panel.dart', Icons.code, false),
    _FileItem('models/', Icons.folder, true),
    _FileItem('  dock_node.dart', Icons.data_object, false),
    _FileItem('  dock_panel.dart', Icons.data_object, false),
    _FileItem('  dock_layout.dart', Icons.data_object, false),
    _FileItem('providers/', Icons.folder, true),
    _FileItem('  dock_manager.dart', Icons.settings, false),
    _FileItem('widgets/', Icons.folder, true),
    _FileItem('  dock_area.dart', Icons.widgets, false),
    _FileItem('  dock_tab_bar.dart', Icons.widgets, false),
    _FileItem('test/', Icons.folder, true),
    _FileItem('  widget_test.dart', Icons.bug_report, false),
    _FileItem('pubspec.yaml', Icons.settings, false),
    _FileItem('CHANGELOG.md', Icons.description, false),
    _FileItem('README.md', Icons.description, false),
  ];

  String? _hovered;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF1E1E1E),
      child: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: _items.length,
        itemBuilder: (context, index) {
          final item = _items[index];
          final isHovered = _hovered == item.name;
          final fg = item.isFolder ? const Color(0xFFDCB67A) : const Color(0xFF6AADCE);

          return MouseRegion(
            cursor: item.isFolder ? SystemMouseCursors.basic : SystemMouseCursors.click,
            onEnter: (_) => setState(() => _hovered = item.name),
            onExit: (_) => setState(() => _hovered = null),
            child: GestureDetector(
              onTap: item.isFolder ? null : () => widget.onFileOpen(item.name.trimLeft()),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 100),
                padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 4),
                decoration: BoxDecoration(
                  color: isHovered && !item.isFolder ? Colors.white.withValues(alpha: 0.06) : Colors.transparent,
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Row(
                  children: [
                    Icon(item.icon, size: 16, color: fg),
                    const SizedBox(width: 6),
                    Text(item.name, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white70, fontSize: 13, fontFamily: 'monospace')),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _FileItem {
  final String name;
  final IconData icon;
  final bool isFolder;
  const _FileItem(this.name, this.icon, this.isFolder);
}

// ─── Welcome Panel (v0.0.2 features showcase) ──────────────

class _WelcomePanel extends StatelessWidget {
  const _WelcomePanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF1E1E1E),
      padding: const EdgeInsets.all(32),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.space_dashboard, size: 48, color: Color(0xFF4FC3F7)),
            const SizedBox(height: 16),
            const Text('Welcome to Dock Panel',
                style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w300)),
            const SizedBox(height: 8),
            Text('An IDE-like docking panel system for Flutter.',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 14)),
            const SizedBox(height: 32),
            _FeatureCard(icon: Icons.drag_indicator, title: 'Drag & Drop', desc: 'Drag tabs to dock left/right/top/bottom/center. Reorder tabs within groups.'),
            const SizedBox(height: 12),
            _FeatureCard(icon: Icons.vertical_split, title: 'Resizable Splits', desc: 'Hover over dividers to highlight, drag to resize. Clamp to min 5% per panel.'),
            const SizedBox(height: 12),
            _FeatureCard(icon: Icons.fullscreen, title: 'Maximize / Restore', desc: 'Click the fullscreen icon on any tab to maximize. Click again to restore.'),
            const SizedBox(height: 12),
            _FeatureCard(icon: Icons.palette, title: 'Themeable', desc: 'DockThemeData.dark & .light presets. Customize every color, shape, and thickness.'),
            const SizedBox(height: 12),
            _FeatureCard(icon: Icons.save, title: 'Persistent Layout', desc: 'Pluggable DockStorage interface. Memory backend included — swap for files/SQLite/etc.'),
            const SizedBox(height: 12),
            _FeatureCard(icon: Icons.copy, title: 'copyWith() New in v0.0.2!', desc: 'Duplicate or tweak panels without full rebuild. Try the Duplicate button in the toolbar.'),
          ],
        ),
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({required this.icon, required this.title, required this.desc});
  final IconData icon;
  final String title;
  final String desc;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: const Color(0xFF4FC3F7)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(desc, style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Code Editor ────────────────────────────────────────────

class _CodeEditorPanel extends StatelessWidget {
  const _CodeEditorPanel({required this.filename});
  final String filename;

  static const _files = <String, List<String>>{
    'main.dart': [
      "import 'package:flutter/material.dart';",
      '',
      'void main() {',
      '  runApp(const MyApp());',
      '}',
      '',
      'class MyApp extends StatelessWidget {',
      '  const MyApp({super.key});',
      '',
      '  @override',
      '  Widget build(BuildContext context) {',
      '    return MaterialApp(',
      '      home: const HomePage(),',
      '    );',
      '  }',
      '}',
    ],
    'model.dart': [
      'class User {',
      '  final String id;',
      '  final String name;',
      '  final String email;',
      '',
      '  const User({',
      '    required this.id,',
      '    required this.name,',
      '    required this.email,',
      '  });',
      '',
      '  Map<String, dynamic> toJson() => {',
      "    'id': id,",
      "    'name': name,",
      "    'email': email,",
      '  };',
      '}',
    ],
    'dock_panel.dart': [
      "import 'package:flutter/material.dart';",
      "import 'package:flutter_riverpod/flutter_riverpod.dart';",
      '',
      "import '../models/models.dart';",
      "import '../providers/dock_manager.dart';",
      "import '../theme/dock_theme.dart';",
      "import 'dock_group_view.dart';",
      "import 'dock_divider.dart';",
      '',
      '/// The root widget that renders the entire dock layout tree.',
      'class DockArea extends ConsumerWidget {',
      '  const DockArea({super.key, this.theme, this.emptyBuilder});',
      '',
      '  final DockThemeData? theme;',
      '  final WidgetBuilder? emptyBuilder;',
      '',
      '  @override',
      '  Widget build(BuildContext context, WidgetRef ref) {',
      '    final layout = ref.watch(dockManagerProvider);',
      '    // ... renders DockSplit or DockGroup',
      '  }',
      '}',
    ],
    'dock_node.dart': [
      "import 'dock_panel.dart';",
      '',
      'enum DockAxis { horizontal, vertical }',
      'enum DockPosition { top, bottom, left, right, center }',
      '',
      'sealed class DockNode {',
      '  DockNode({required this.id});',
      '  final String id;',
      '}',
      '',
      'class DockGroup extends DockNode {',
      '  DockGroup({required super.id, required this.panels, this.activeIndex = 0});',
      '  final List<DockPanel> panels;',
      '  int activeIndex;',
      '}',
      '',
      'class DockSplit extends DockNode {',
      '  DockSplit({required super.id, required this.axis, required this.children, List<double>? flexes})',
      '    : flexes = flexes ?? List.filled(children.length, 1.0 / children.length);',
      '  final DockAxis axis;',
      '  final List<DockNode> children;',
      '  final List<double> flexes;',
      '}',
    ],
    'dock_manager.dart': [
      "import 'package:flutter_riverpod/flutter_riverpod.dart';",
      '',
      'class DockManager extends Notifier<DockLayout> {',
      '  DockStorage? _storage;',
      '  final Map<String, DockPanel> _registry = {};',
      '',
      '  @override',
      '  DockLayout build() => const DockLayout();',
      '',
      '  void setStorage(DockStorage storage) => _storage = storage;',
      '  void registerPanel(DockPanel panel) => _registry[panel.id] = panel;',
      '',
      '  void addPanel(DockPanel panel, {String? targetGroupId}) { /* ... */ }',
      '  void removePanel(String panelId) { /* ... */ }',
      '  void movePanel(String id, String target, DockPosition pos) { /* ... */ }',
      '}',
      '',
      'final dockManagerProvider = NotifierProvider<DockManager, DockLayout>(DockManager.new);',
    ],
    'widget_test.dart': [
      "import 'package:flutter_test/flutter_test.dart';",
      "import 'package:dock_panel/dock_panel.dart';",
      '',
      'void main() {',
      "  test('DockPanel equality by id', () {",
      "    final a = DockPanel(id: 'x', title: 'A', builder: (_) => const SizedBox());",
      "    final b = DockPanel(id: 'x', title: 'B', builder: (_) => const SizedBox());",
      "    expect(a, equals(b));",
      '  });',
      '}',
    ],
  };

  @override
  Widget build(BuildContext context) {
    final lines = _files[filename] ?? ['// File: $filename', '', '// (no preview available)'];

    return Container(
      color: const Color(0xFF1E1E1E),
      padding: const EdgeInsets.all(12),
      child: SelectionArea(
        child: ListView.builder(
          itemCount: lines.length,
          itemBuilder: (context, index) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 36,
                  child: Text('${index + 1}', textAlign: TextAlign.right,
                      style: const TextStyle(color: Colors.white24, fontSize: 13, fontFamily: 'monospace')),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(lines[index],
                      style: const TextStyle(color: Color(0xFFD4D4D4), fontSize: 13, fontFamily: 'monospace', height: 1.5)),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ─── Terminal ───────────────────────────────────────────────

class _TerminalPanel extends StatelessWidget {
  const _TerminalPanel();

  @override
  Widget build(BuildContext context) {
    final lines = [
      r'$ flutter run -d windows',
      'Launching example/lib/main.dart on Windows...',
      'Building Windows application...',
      r'✓ Built build\windows\x64\runner\Debug\dock_panel.exe',
      'Syncing files to device Windows...  45ms',
      '',
      'Flutter run key commands:',
      '  r  Hot reload 🔥',
      '  R  Hot restart',
      '  q  Quit',
      '',
      '─── dock_panel v0.0.2 ───',
      r'$ _',
    ];

    return Container(
      color: const Color(0xFF181818),
      padding: const EdgeInsets.all(12),
      child: ListView.builder(
        itemCount: lines.length,
        itemBuilder: (context, index) {
          final line = lines[index];
          Color c = const Color(0xFFCCCCCC);
          if (line.startsWith(r'$')) c = const Color(0xFF4EC9B0);
          else if (line.startsWith('✓')) c = const Color(0xFF6A9955);
          else if (line.startsWith('───')) c = const Color(0xFF569CD6);
          return Text(line, style: TextStyle(color: c, fontSize: 12, fontFamily: 'monospace', height: 1.6));
        },
      ),
    );
  }
}

// ─── Output ─────────────────────────────────────────────────

class _OutputPanel extends StatelessWidget {
  const _OutputPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF181818),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _LogLine('[14:30:22] Build completed successfully.', Colors.green),
          const SizedBox(height: 2),
          _LogLine('[14:30:22] 0 errors, 0 warnings.', Colors.white70),
          const SizedBox(height: 2),
          _LogLine('[14:30:23] Hot reload applied in 245ms.', const Color(0xFF569CD6)),
          const SizedBox(height: 2),
          _LogLine('[14:31:05] Storage: layout auto-saved via _persist().', Colors.white54),
          const SizedBox(height: 2),
          _LogLine('[14:31:06] copyWith(): panel duplicated successfully.', Colors.white54),
        ],
      ),
    );
  }
}

class _LogLine extends StatelessWidget {
  const _LogLine(this.text, this.color);
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) => Text(text, style: TextStyle(color: color, fontSize: 12, fontFamily: 'monospace'));
}

// ─── Problems ───────────────────────────────────────────────

class _ProblemsPanel extends StatelessWidget {
  const _ProblemsPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF181818),
      padding: const EdgeInsets.all(12),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ProblemRow(Icons.warning, Color(0xFFCCA700), "Unused import: 'dart:io' (line 3)"),
          SizedBox(height: 6),
          _ProblemRow(Icons.info, Color(0xFF569CD6), 'Prefer const with constant constructors (line 15)'),
        ],
      ),
    );
  }
}

class _ProblemRow extends StatelessWidget {
  const _ProblemRow(this.icon, this.color, this.text);
  final IconData icon;
  final Color color;
  final String text;
  @override
  Widget build(BuildContext context) => Row(children: [
    Icon(icon, size: 14, color: color),
    const SizedBox(width: 8),
    Expanded(child: Text(text, overflow: TextOverflow.ellipsis,
        style: TextStyle(color: color, fontSize: 12, fontFamily: 'monospace'))),
  ]);
}

// ─── Outline ────────────────────────────────────────────────

class _OutlinePanel extends StatelessWidget {
  const _OutlinePanel();

  @override
  Widget build(BuildContext context) {
    final items = [
      ('MyApp', Icons.class_, 0),
      ('build()', Icons.functions, 1),
      ('HomePage', Icons.class_, 0),
      ('_counter', Icons.data_usage, 1),
      ('_increment()', Icons.functions, 1),
      ('build()', Icons.functions, 1),
    ];

    return Container(
      color: const Color(0xFF1E1E1E),
      child: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final (name, icon, indent) = items[index];
          return Padding(
            padding: EdgeInsets.only(left: indent * 16.0 + 4, top: 4, bottom: 4),
            child: Row(children: [
              Icon(icon, size: 14, color: const Color(0xFF4EC9B0)),
              const SizedBox(width: 8),
              Text(name, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ]),
          );
        },
      ),
    );
  }
}
