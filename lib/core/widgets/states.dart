import 'dart:async';

import 'package:atompay_mobile/core/format/dates.dart';
import 'package:atompay_mobile/core/network/api_exception.dart';
import 'package:atompay_mobile/core/router/routes.dart';
import 'package:atompay_mobile/core/theme/tokens.dart';
import 'package:atompay_mobile/core/widgets/buttons.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;
import 'package:go_router/go_router.dart';

/// One shimmering block. Shimmer stops under reduced motion.
///
/// Inside a [LoadingShape] every block follows that shape's single clock
/// and only repaints (no rebuilds); on its own it runs its own clock.
class Skeleton extends StatefulWidget {
  const new({
    this.width,
    this.height = 12,
    this.radius = Radii.pill,
    super.key,
  });

  final double? width;
  final double height;
  final double radius;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton>
    with SingleTickerProviderStateMixin {
  /// Only when there is no [LoadingShape] above.
  AnimationController? _own;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_ShimmerScope.of(context) != null) {
      _own?.dispose();
      _own = null;
      return;
    }
    final own = _own ??= AnimationController(
      vsync: this,
      duration: _ShimmerScope.period,
    );
    if (context.reduceMotion) {
      own.stop();
    } else if (!own.isAnimating) {
      own.repeat();
    }
  }

  @override
  void dispose() {
    _own?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final clock = _ShimmerScope.of(context) ?? _own!;
    final block = SizedBox(
      width: widget.width ?? double.infinity,
      height: widget.height,
      child: CustomPaint(
        painter: _SkeletonPainter(
          clock: clock,
          radius: widget.radius,
          base: c.skel,
          shine: c.greySoft,
        ),
      ),
    );
    // Without a width it fills the row, or is 0 wide where the width is
    // unbounded (as an empty Container was).
    return widget.width == null ? LimitedBox(maxWidth: 0, child: block) : block;
  }
}

class _SkeletonPainter extends CustomPainter {
  new({
    required this.clock,
    required this.radius,
    required this.base,
    required this.shine,
  }) : super(repaint: clock);

  final Animation<double> clock;
  final double radius;
  final Color base;
  final Color shine;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final x = -1 + 3 * clock.value;
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment(x - 1, 0),
        end: Alignment(x, 0),
        colors: [base, shine, base],
      ).createShader(rect);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(radius)),
      paint,
    );
  }

  @override
  bool shouldRepaint(_SkeletonPainter old) =>
      old.clock != clock ||
      old.radius != radius ||
      old.base != base ||
      old.shine != shine;
}

/// The one shimmer clock a [LoadingShape] shares with its [Skeleton]s.
class _ShimmerScope extends InheritedWidget {
  const new({required this.clock, required super.child});

  static const period = Duration(milliseconds: 1400);

  final Animation<double> clock;

  static Animation<double>? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_ShimmerScope>()?.clock;

  @override
  bool updateShouldNotify(_ShimmerScope old) => old.clock != clock;
}

/// A white card full of skeleton lines.
class SkeletonCard extends StatelessWidget {
  const new({this.lines = 3, this.height, super.key});

  final int lines;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      height: height,
      padding: const EdgeInsets.all(Space.s18),
      decoration: BoxDecoration(
        color: c.white,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: c.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < lines; i++) ...[
            if (i > 0) const SizedBox(height: Space.s12),
            Skeleton(width: i == 0 ? 140 : (i.isEven ? 200 : null)),
          ],
        ],
      ),
    );
  }
}

/// A skeleton list row: tile, two lines.
class SkeletonRow extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(horizontal: Space.s16, vertical: Space.s12),
    child: Row(
      children: [
        Skeleton(width: 40, height: 40, radius: Radii.tile),
        SizedBox(width: Space.s12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Skeleton(width: 160),
              SizedBox(height: Space.s8),
              Skeleton(width: 100, height: 10),
            ],
          ),
        ),
      ],
    ),
  );
}

/// Wraps a screen-shaped skeleton with the label screen readers announce.
class LoadingShape extends StatefulWidget {
  const new({required this.label, required this.child, super.key});

  /// "Loading your orders".
  final String label;
  final Widget child;

  @override
  State<LoadingShape> createState() => _LoadingShapeState();
}

/// One shimmer clock for every block inside, and a repaint boundary so the
/// shimmer never repaints the rest of the screen.
class _LoadingShapeState extends State<LoadingShape>
    with SingleTickerProviderStateMixin {
  late final _clock = AnimationController(
    vsync: this,
    duration: _ShimmerScope.period,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (context.reduceMotion) {
      _clock.stop();
    } else if (!_clock.isAnimating) {
      _clock.repeat();
    }
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: widget.label,
    liveRegion: true,
    child: ExcludeSemantics(
      child: RepaintBoundary(
        child: _ShimmerScope(clock: _clock, child: widget.child),
      ),
    ),
  );
}

/// Icon, title, body, actions and an optional reference. Used for errors,
/// empty lists and full-screen outcomes.
class StateView extends StatelessWidget {
  const new({
    required this.title,
    this.body,
    this.icon,
    this.iconTone = StateTone.grey,
    this.image,
    this.actions = const [],
    this.reference,
    this.child,
    this.titleStyle,
    super.key,
  });

  final String title;

  /// Defaults to h4 (17); full-screen outcomes use h2.
  final TextStyle? titleStyle;
  final String? body;
  final IconData? icon;
  final StateTone iconTone;

  /// Replaces the icon (the AtomPay mark on errors).
  final Widget? image;
  final List<Widget> actions;

  /// Shown under the body for support ("Reference E-7K2Q9").
  final String? reference;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final (bg, fg) = switch (iconTone) {
      StateTone.grey => (c.greySoft, c.body),
      StateTone.green => (c.greenSoft, c.green),
      StateTone.amber => (c.amberSoft, c.amberInk),
      StateTone.rose => (c.roseSoft, c.rose),
      StateTone.blue => (c.primarySoft, c.primary),
    };
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: Space.s28,
          vertical: Space.s40,
        ),
        // Canvas `.state`: 12 between items, body at most 290 wide, the
        // buttons at most 300 and 20 below the text.
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 300),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (image != null)
                image!
              else if (icon != null)
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Icon(icon, size: 32, color: fg),
                ),
              const SizedBox(height: Space.s12),
              Semantics(
                header: true,
                liveRegion: true,
                child: Text(
                  title,
                  style: titleStyle ?? t.h4,
                  textAlign: TextAlign.center,
                ),
              ),
              if (body != null) ...[
                const SizedBox(height: Space.s12),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 290),
                  child: Text(
                    body!,
                    style: t.small,
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
              ?child,
              if (actions.isNotEmpty) ...[
                const SizedBox(height: Space.s20),
                for (var i = 0; i < actions.length; i++) ...[
                  if (i > 0) const SizedBox(height: Space.s10),
                  SizedBox(width: double.infinity, child: actions[i]),
                ],
              ],
              if (reference != null) ...[
                const SizedBox(height: Space.s12),
                Text(
                  'Ref $reference',
                  style: t.tiny.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

enum StateTone { grey, green, amber, rose, blue }

/// The error screen for each [ApiException] type (brief §8). [notFound]
/// lets a screen say what is missing ("We can't find this order");
/// [offlineBody] says what will load once back online.
class ErrorStateView extends StatelessWidget {
  const new({
    required this.error,
    required this.onRetry,
    this.notFound = "We can't find this",
    this.notFoundBody,
    this.notFoundAction,
    this.offlineBody,
    this.serverBody,
    super.key,
  });

  final Object error;
  final VoidCallback onRetry;
  final String notFound;
  final String? notFoundBody;
  final Widget? notFoundAction;
  final String? offlineBody;
  final String? serverBody;

  @override
  Widget build(BuildContext context) {
    // Canvas `.state .acts .btn-p`: retry is the primary action.
    final retry = AppButton.primary(
      'Try again',
      block: true,
      onPressed: onRetry,
    );
    final support = AppButton.ghost(
      'Contact support',
      block: true,
      onPressed: () => context.push(Routes.help),
    );
    return switch (error) {
      Offline() => StateView(
        icon: Icons.wifi_off_rounded,
        title: "You're offline",
        body:
            offlineBody ??
            "Connect to Wi-Fi or mobile data and we'll load this for you.",
        actions: [retry],
      ),
      Timeout() => StateView(
        icon: Icons.schedule,
        iconTone: StateTone.amber,
        title: 'This is taking too long',
        body:
            "Atomshop.pk didn't answer in time. Check your connection and "
            'try again.',
        actions: [retry],
      ),
      final Server s => StateView(
        icon: Icons.error_outline,
        iconTone: StateTone.rose,
        title: 'Something went wrong on our side',
        body:
            serverBody ??
            'Your orders and payments are safe. Please try again in a moment.',
        reference: s.reference,
        actions: [retry, support],
      ),
      NotFound() => StateView(
        icon: Icons.search_off,
        title: notFound,
        body: notFoundBody ?? 'It may have been removed, or the link is old.',
        actions: [?notFoundAction],
      ),
      final RateLimited r => StateView(
        icon: Icons.schedule,
        iconTone: StateTone.amber,
        title: 'Too many tries',
        body: 'Please wait, then try again.',
        child: RetryCountdown(
          retryAfter: r.retryAfter,
          onDone: onRetry,
          large: true,
        ),
      ),
      Unauthenticated() || Forbidden() => const StateView(
        icon: Icons.lock_outline,
        title: "You've been signed out",
        body: 'For your security, please sign in again.',
      ),
      final ApiException e => StateView(
        icon: Icons.error_outline,
        iconTone: StateTone.rose,
        title: "We couldn't load this",
        body: e.message.isEmpty ? null : e.message,
        actions: [retry],
      ),
      _ => StateView(
        icon: Icons.wifi_off_rounded,
        title: "We couldn't load this",
        body: 'Check your connection and try again.',
        actions: [retry],
      ),
    };
  }
}

/// Counts down from a 429's `Retry-After`. Calls [onDone] at zero.
class RetryCountdown extends StatefulWidget {
  const new({
    required this.retryAfter,
    this.onDone,
    this.large = false,
    this.prefix = 'Try again in',
    super.key,
  });

  final Duration retryAfter;
  final VoidCallback? onDone;
  final bool large;
  final String prefix;

  @override
  State<RetryCountdown> createState() => _RetryCountdownState();
}

class _RetryCountdownState extends State<RetryCountdown> {
  late DateTime _until = DateTime.now().add(widget.retryAfter);
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (!DateTime.now().isBefore(_until)) {
        _timer?.cancel();
        widget.onDone?.call();
      }
      setState(() {});
    });
  }

  @override
  void didUpdateWidget(RetryCountdown old) {
    super.didUpdateWidget(old);
    if (old.retryAfter != widget.retryAfter) {
      _until = DateTime.now().add(widget.retryAfter);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final left = _until.difference(DateTime.now());
    final t = context.text;
    if (widget.large) {
      return Padding(
        padding: const EdgeInsets.only(top: Space.s12),
        child: Text(countdown(left), style: t.h1),
      );
    }
    return Text(
      '${widget.prefix} ${countdown(left)}',
      style: t.small.copyWith(color: context.colors.amberInk),
    );
  }
}

/// Renders an [AsyncValue] with the screen's own skeleton. On a failed
/// refresh it keeps the last good data and shows a toast instead.
class AsyncBody<T> extends ConsumerWidget {
  const new({
    required this.value,
    required this.data,
    required this.loading,
    required this.onRetry,
    this.notFound = "We can't find this",
    this.notFoundBody,
    this.notFoundAction,
    this.offlineBody,
    super.key,
  });

  final String? notFoundBody;
  final String? offlineBody;
  final AsyncValue<T> value;
  final Widget Function(T data) data;
  final Widget loading;
  final VoidCallback onRetry;
  final String notFound;
  final Widget? notFoundAction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (value.hasValue) return data(value.requireValue);
    if (value.hasError) {
      return ErrorStateView(
        error: value.error!,
        onRetry: onRetry,
        notFound: notFound,
        notFoundBody: notFoundBody,
        notFoundAction: notFoundAction,
        offlineBody: offlineBody,
      );
    }
    return loading;
  }
}

/// Shows a toast when a refresh fails but old data is still on screen.
void listenForRefreshErrors<T>(
  WidgetRef ref,
  ProviderListenable<AsyncValue<T>> provider,
) {
  ref.listen(provider, (prev, next) {
    if (next.hasError && next.hasValue && !next.isLoading) {
      // A 401/403 signs the customer out; Sign in's dialog says so.
      if (next.error is Unauthenticated || next.error is Forbidden) return;
      showToast(switch (next.error) {
        Offline() => "You're offline. Showing your last update.",
        Timeout() => 'This is taking too long. Showing what we had.',
        _ => "We couldn't refresh. Showing your last update.",
      }, error: true);
    }
  });
}

/// Whether the phone has any network. The API is still the judge: a call
/// can fail while this says online.
final connectivityProvider = StreamProvider<bool>((ref) async* {
  final c = Connectivity();
  bool online(List<ConnectivityResult> r) =>
      r.any((x) => x != ConnectivityResult.none);
  try {
    yield online(await c.checkConnectivity());
  } on PlatformException {
    yield true;
  } on MissingPluginException {
    yield true;
  }
  yield* c.onConnectivityChanged.map(online);
});

final isOfflineProvider = Provider<bool>(
  (ref) => ref.watch(connectivityProvider).value == false,
);

/// "You're offline. Showing your orders from 10:42 am."
class OfflineBanner extends ConsumerWidget {
  const new({
    this.what = 'your last update',
    this.since,
    this.fromCache = false,
    super.key,
  });

  final String what;
  final DateTime? since;

  /// The data on screen came from the cache (a call failed even though the
  /// phone reports a connection): show the banner anyway.
  final bool fromCache;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!fromCache && !ref.watch(isOfflineProvider)) {
      return const SizedBox.shrink();
    }
    final c = context.colors;
    final when = since == null ? '' : ' from ${clock(since!)}';
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        color: c.ink,
        padding: const EdgeInsets.symmetric(
          horizontal: Space.s16,
          vertical: Space.s10,
        ),
        child: Row(
          children: [
            Icon(Icons.wifi_off, size: 16, color: c.white),
            const SizedBox(width: Space.s10),
            Expanded(
              child: Text(
                "You're offline. Showing $what$when.",
                style: context.text.small.copyWith(
                  color: c.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Lets toasts show from anywhere, including right after a navigation.
final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

/// A short confirmation. Errors belong on the field, not here, except for a
/// refresh that failed behind data that's still showing.
void showToast(String message, {bool error = false}) {
  final messenger = scaffoldMessengerKey.currentState;
  if (messenger == null) return;
  final ctx = scaffoldMessengerKey.currentContext!;
  final c = ctx.colors;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              error ? Icons.info_outline : Icons.check,
              size: 18,
              color: error ? c.onDark : c.greenOnDark,
            ),
            const SizedBox(width: Space.s10),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  unawaited(
    SemanticsService.sendAnnouncement(View.of(ctx), message, TextDirection.ltr),
  );
}
