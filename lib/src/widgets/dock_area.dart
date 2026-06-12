import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../providers/dock_manager.dart';
import '../theme/dock_theme.dart';
import 'dock_group_view.dart';
import 'dock_divider.dart';

/// The root widget that renders the entire dock layout tree.
class DockArea extends ConsumerWidget {
  const DockArea({
    super.key,
    this.theme,
    this.emptyBuilder,
  });

  /// Optional theme override.
  final DockThemeData? theme;

  /// Builder for the empty state when no panels exist.
  final WidgetBuilder? emptyBuilder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final layout = ref.watch(dockManagerProvider);
    final themeData = theme ?? DockTheme.of(context);

    Widget child;
    if (layout.root == null) {
      child = emptyBuilder?.call(context) ??
          Center(
            child: Text(
              'No panels',
              style: TextStyle(color: themeData.tabTextColor),
            ),
          );
    } else if (layout.isMaximized) {
      // Maximized mode: show only the maximized panel.
      final panel = ref
          .read(dockManagerProvider.notifier)
          .getPanel(layout.maximizedPanelId!);
      if (panel != null) {
        child = _MaximizedView(panel: panel);
      } else {
        child = _buildNode(context, layout.root!, ref);
      }
    } else {
      child = _buildNode(context, layout.root!, ref);
    }

    return DockTheme(
      data: themeData,
      child: ColoredBox(
        color: themeData.backgroundColor,
        child: child,
      ),
    );
  }

  Widget _buildNode(BuildContext context, DockNode node, WidgetRef ref) {
    return switch (node) {
      DockGroup() => DockGroupView(group: node),
      DockSplit() => _DockSplitView(split: node),
    };
  }
}

/// Renders a split node with resizable dividers between children.
class _DockSplitView extends ConsumerStatefulWidget {
  const _DockSplitView({required this.split});

  final DockSplit split;

  @override
  ConsumerState<_DockSplitView> createState() => _DockSplitViewState();
}

class _DockSplitViewState extends ConsumerState<_DockSplitView> {
  late List<double> _flexes;

  @override
  void initState() {
    super.initState();
    _flexes = List.of(widget.split.flexes);
  }

  @override
  void didUpdateWidget(_DockSplitView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.split.id != widget.split.id ||
        oldWidget.split.flexes.length != widget.split.flexes.length) {
      _flexes = List.of(widget.split.flexes);
    }
  }

  void _onDividerDrag(int index, double delta, double totalSize) {
    if (totalSize <= 0) return;
    final deltaFlex = delta / totalSize;
    setState(() {
      _flexes[index] += deltaFlex;
      _flexes[index + 1] -= deltaFlex;
      // Clamp minimum.
      const minFlex = 0.05;
      if (_flexes[index] < minFlex) {
        _flexes[index + 1] -= (minFlex - _flexes[index]);
        _flexes[index] = minFlex;
      }
      if (_flexes[index + 1] < minFlex) {
        _flexes[index] -= (minFlex - _flexes[index + 1]);
        _flexes[index + 1] = minFlex;
      }
    });
  }

  void _onDividerDragEnd() {
    ref.read(dockManagerProvider.notifier).resizeSplit(widget.split.id, List.of(_flexes));
  }

  @override
  Widget build(BuildContext context) {
    final theme = DockTheme.of(context);
    final isHorizontal = widget.split.axis == DockAxis.horizontal;

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalSize =
            isHorizontal ? constraints.maxWidth : constraints.maxHeight;
        final dividerTotal =
            theme.dividerThickness * (widget.split.children.length - 1);
        final availableSize = totalSize - dividerTotal;

        final children = <Widget>[];
        for (var i = 0; i < widget.split.children.length; i++) {
          final childSize = availableSize * _flexes[i];
          children.add(
            SizedBox(
              width: isHorizontal ? childSize : null,
              height: isHorizontal ? null : childSize,
              child: _buildChildNode(widget.split.children[i]),
            ),
          );
          if (i < widget.split.children.length - 1) {
            children.add(
              DockDivider(
                axis: widget.split.axis,
                thickness: theme.dividerThickness,
                color: theme.dividerColor,
                onDrag: (delta) => _onDividerDrag(i, delta, totalSize),
                onDragEnd: _onDividerDragEnd,
              ),
            );
          }
        }

        return isHorizontal
            ? Row(children: children)
            : Column(children: children);
      },
    );
  }

  Widget _buildChildNode(DockNode node) {
    return switch (node) {
      DockGroup() => DockGroupView(group: node),
      DockSplit() => _DockSplitView(split: node),
    };
  }
}

/// Fullscreen view for a maximized panel with a restore button.
class _MaximizedView extends ConsumerWidget {
  const _MaximizedView({required this.panel});

  final DockPanel panel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = DockTheme.of(context);

    return Column(
      children: [
        // Minimal title bar with restore button.
        Container(
          height: theme.tabHeight,
          color: theme.tabBarColor,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              if (panel.icon != null) ...[
                Icon(panel.icon, size: 14, color: theme.activeTabTextColor),
                const SizedBox(width: 8),
              ],
              Text(
                panel.title,
                style: TextStyle(
                  color: theme.activeTabTextColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              _RestoreButton(
                panelId: panel.id,
                color: theme.tabTextColor,
              ),
            ],
          ),
        ),
        Expanded(
          child: panel.builder(context),
        ),
      ],
    );
  }
}

class _RestoreButton extends ConsumerWidget {
  const _RestoreButton({required this.panelId, required this.color});

  final String panelId;
  final Color color;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      icon: Icon(Icons.fullscreen_exit, size: 18, color: color),
      onPressed: () {
        ref.read(dockManagerProvider.notifier).restoreFromMaximized();
      },
      tooltip: 'Restore',
      splashRadius: 14,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
    );
  }
}
