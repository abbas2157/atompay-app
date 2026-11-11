import 'package:atompay_mobile/core/router/navigation.dart';
import 'package:atompay_mobile/core/router/routes.dart';
import 'package:atompay_mobile/core/theme/tokens.dart';
import 'package:atompay_mobile/core/widgets/brand.dart';
import 'package:atompay_mobile/core/widgets/pressable.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Tab indexes of the four branches. Ask Atom isn't a branch: it opens full
/// screen over the current tab.
abstract final class Tabs {
  static const home = 0;
  static const shop = 1;
  static const orders = 2;
  static const account = 3;
}

/// Tells a tab's root screen to scroll to the top (the current tab was
/// tapped again).
class TabReselect extends InheritedNotifier<ValueNotifier<int>> {
  const new({
    required super.notifier,
    required this.branch,
    required super.child,
    super.key,
  });

  final int branch;

  /// Rebuilds when the tab is tapped again at its root.
  static ValueNotifier<int>? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<TabReselect>()?.notifier;
}

/// Bottom bar under 600 dp, navigation rail from 600 dp (brief §4).
class AppShell extends StatefulWidget {
  const new({required this.shell, required this.children, super.key});

  final StatefulNavigationShell shell;

  /// The branch navigators, as `StatefulShellRoute.indexedStack` gives them.
  final List<Widget> children;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final _reselect = List.generate(4, (_) => ValueNotifier<int>(0));

  @override
  void dispose() {
    for (final n in _reselect) {
      n.dispose();
    }
    super.dispose();
  }

  void _onTab(int branch) {
    final shell = widget.shell;
    if (branch != shell.currentIndex) {
      shell.goBranch(branch);
      return;
    }
    // Same tab: at the root, scroll to the top; deeper, pop to the root.
    final location = GoRouter.of(context).state.uri.path;
    final root = const [
      Routes.home,
      Routes.shop,
      Routes.plans,
      Routes.account,
    ][branch];
    if (location == root) {
      _reselect[branch].value++;
    } else {
      shell.goBranch(branch, initialLocation: true);
    }
  }

  void _openAtom() => context.pushOnce(Routes.atom);

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 600;
    final index = widget.shell.currentIndex;
    final body = IndexedStack(
      index: index,
      children: [
        for (var i = 0; i < widget.children.length; i++)
          TickerMode(
            enabled: i == index,
            child: TabReselect(
              notifier: _reselect[i],
              branch: i,
              child: widget.children[i],
            ),
          ),
      ],
    );
    if (wide) {
      return Scaffold(
        body: Row(
          children: [
            _Rail(index: index, onTab: _onTab, onAtom: _openAtom),
            Expanded(child: body),
          ],
        ),
      );
    }
    return Scaffold(
      body: body,
      bottomNavigationBar: _BottomBar(
        index: index,
        onTab: _onTab,
        onAtom: _openAtom,
      ),
    );
  }
}

class _TabSpec {
  const new(this.label, this.icon, this.activeIcon, this.branch);

  final String label;
  final IconData icon;
  final IconData activeIcon;
  final int branch;
}

const _left = [
  _TabSpec('Home', Icons.home_outlined, Icons.home, Tabs.home),
  _TabSpec(
    'Shop',
    Icons.shopping_bag_outlined,
    Icons.shopping_bag_outlined,
    Tabs.shop,
  ),
];
const _right = [
  _TabSpec(
    'Orders',
    Icons.receipt_long_outlined,
    Icons.receipt_long,
    Tabs.orders,
  ),
  _TabSpec('Account', Icons.person_outline, Icons.person, Tabs.account),
];

class _BottomBar extends StatelessWidget {
  const new({required this.index, required this.onTab, required this.onAtom});

  final int index;
  final ValueChanged<int> onTab;
  final VoidCallback onAtom;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    // Tab labels scale to 130% at most, as Material's NavigationBar and
    // iOS tab bars do; each tab keeps its full label for screen readers.
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.3,
      child: _bar(context, c),
    );
  }

  Widget _bar(BuildContext context, AppColors c) {
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: 'Main',
      child: Container(
        decoration: BoxDecoration(
          color: c.white,
          border: Border(top: BorderSide(color: c.line)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              Space.s4,
              Space.s6,
              Space.s4,
              Space.s6,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final t in _left)
                  Expanded(
                    child: _TabButton(t, onTab, selected: index == t.branch),
                  ),
                Expanded(child: _AtomButton(onTap: onAtom)),
                for (final t in _right)
                  Expanded(
                    child: _TabButton(t, onTab, selected: index == t.branch),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const new(this.spec, this.onTab, {required this.selected});

  final _TabSpec spec;
  final bool selected;
  final ValueChanged<int> onTab;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = selected ? c.primary : c.muted;
    return Pressable(
      onTap: () => onTab(spec.branch),
      selected: selected,
      scaleOnPress: false,
      borderRadius: BorderRadius.circular(Radii.row),
      semanticLabel: '${spec.label} tab',
      excludeChildSemantics: true,
      child: SizedBox(
        height: 52,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Canvas: the selected tab keeps its outline icon, in primary.
            Icon(spec.icon, size: 22, color: color),
            const SizedBox(height: 3),
            Text(
              spec.label,
              style: context.text.xs.copyWith(color: color),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

/// The raised centre button: the Atomshop icon on a white disc.
class _AtomButton extends StatelessWidget {
  const new({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Pressable(
    onTap: onTap,
    semanticLabel: 'Ask Atom',
    excludeChildSemantics: true,
    child: Transform.translate(
      offset: const Offset(0, -Space.s22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const AtomAvatar(size: 60, ring: true),
          const SizedBox(height: Space.s4),
          Text(
            'Ask Atom',
            style: context.text.xs.copyWith(color: context.colors.muted),
            maxLines: 1,
          ),
        ],
      ),
    ),
  );
}

class _Rail extends StatelessWidget {
  const new({required this.index, required this.onTab, required this.onAtom});

  final int index;
  final ValueChanged<int> onTab;
  final VoidCallback onAtom;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    Widget item(_TabSpec t) {
      final on = index == t.branch;
      return Pressable(
        onTap: () => onTab(t.branch),
        selected: on,
        scaleOnPress: false,
        borderRadius: BorderRadius.circular(Radii.row),
        semanticLabel: '${t.label} tab',
        excludeChildSemantics: true,
        child: Container(
          width: 72,
          height: 56,
          decoration: BoxDecoration(
            color: on ? c.primarySoft : null,
            borderRadius: BorderRadius.circular(Radii.row),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(on ? t.activeIcon : t.icon, color: on ? c.primary : c.muted),
              Text(
                t.label,
                style: context.text.xs.copyWith(
                  color: on ? c.primary : c.muted,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      width: 88,
      decoration: BoxDecoration(
        color: c.white,
        border: Border(right: BorderSide(color: c.line)),
      ),
      child: SafeArea(
        right: false,
        child: Column(
          children: [
            const SizedBox(height: Space.s24),
            for (final t in _left) ...[
              item(t),
              const SizedBox(height: Space.s6),
            ],
            Pressable(
              onTap: onAtom,
              semanticLabel: 'Ask Atom',
              excludeChildSemantics: true,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: Space.s6),
                child: Column(
                  children: [
                    const AtomAvatar(size: 52, ring: true),
                    const SizedBox(height: Space.s4),
                    Text('Ask Atom', style: context.text.xs),
                  ],
                ),
              ),
            ),
            const SizedBox(height: Space.s6),
            for (final t in _right) ...[
              item(t),
              const SizedBox(height: Space.s6),
            ],
          ],
        ),
      ),
    );
  }
}

/// Wrap Shop, Orders and Account roots: back goes to the Home tab instead
/// of leaving the app.
class TabRootBack extends StatelessWidget {
  const new({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) StatefulNavigationShell.of(context).goBranch(Tabs.home);
    },
    child: child,
  );
}

/// Scrolls [controller] to the top when this tab is tapped again.
class ScrollToTopOnReselect extends StatefulWidget {
  const new({required this.controller, required this.child, super.key});

  final ScrollController controller;
  final Widget child;

  @override
  State<ScrollToTopOnReselect> createState() => _ScrollToTopOnReselectState();
}

class _ScrollToTopOnReselectState extends State<ScrollToTopOnReselect> {
  ValueNotifier<int>? _notifier;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final n = TabReselect.of(context);
    if (n != _notifier) {
      _notifier?.removeListener(_toTop);
      _notifier = n?..addListener(_toTop);
    }
  }

  void _toTop() {
    final c = widget.controller;
    if (!c.hasClients) return;
    if (context.reduceMotion) {
      c.jumpTo(0);
    } else {
      c.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void dispose() {
    _notifier?.removeListener(_toTop);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
