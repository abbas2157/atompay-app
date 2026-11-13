import 'dart:async';
import 'dart:math' as math;

import 'package:atompay_mobile/core/theme/tokens.dart';
import 'package:atompay_mobile/core/widgets/buttons.dart';
import 'package:atompay_mobile/core/widgets/form_parts.dart';
import 'package:atompay_mobile/core/widgets/pressable.dart';
import 'package:atompay_mobile/core/widgets/secure_screen.dart';
import 'package:atompay_mobile/core/widgets/ui.dart';
import 'package:atompay_mobile/features/application/data/camera_service.dart';
import 'package:atompay_mobile/features/application/data/capture_doc.dart';
import 'package:atompay_mobile/features/application/presentation/application_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Photographs one identity document with the in-app camera (canvas
/// "Photograph your CNIC", "Selfie with CNIC", "Allow the camera").
/// Camera only, never the gallery. Pops with the JPEG bytes, or null.
class CaptureScreen extends ConsumerStatefulWidget {
  const new({required this.doc, super.key});

  final CaptureDoc doc;

  @override
  ConsumerState<CaptureScreen> createState() => _CaptureScreenState();
}

enum _Stage { checking, explain, blocked, starting, live, review, failed }

class _CaptureScreenState extends ConsumerState<CaptureScreen> {
  _Stage _stage = _Stage.checking;
  CameraSession? _session;
  Uint8List? _photo;
  bool _flash = false;
  bool _taking = false;
  String? _problem;
  late final AppLifecycleListener _lifecycle;

  CameraService get _camera => ref.read(cameraServiceProvider);

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onHide: _closeCamera,
      onShow: () {
        if (_stage == _Stage.live || _stage == _Stage.starting) {
          unawaited(_startCamera());
        } else if (_stage == _Stage.blocked) {
          // Back from Settings: maybe it's on now.
          unawaited(_check());
        }
      },
    );
    unawaited(_check());
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    unawaited(_session?.dispose());
    super.dispose();
  }

  Future<void> _check() async {
    final p = await _camera.status();
    if (!mounted) return;
    switch (p) {
      case CamPermission.granted:
        await _startCamera();
      case CamPermission.blocked:
        setState(() => _stage = _Stage.blocked);
      case CamPermission.notAsked || CamPermission.denied:
        setState(() => _stage = _Stage.explain);
    }
  }

  Future<void> _allow() async {
    final p = await _camera.request();
    if (!mounted) return;
    if (p == CamPermission.granted) {
      await _startCamera();
    } else {
      setState(
        () => _stage = p == CamPermission.blocked
            ? _Stage.blocked
            : _Stage.explain,
      );
    }
  }

  Future<void> _startCamera() async {
    setState(() => _stage = _Stage.starting);
    await _closeCamera();
    try {
      final s = await _camera.open(front: widget.doc == CaptureDoc.selfie);
      if (!mounted) {
        await s.dispose();
        return;
      }
      _flash = false;
      setState(() {
        _session = s;
        _stage = _photo == null ? _Stage.live : _Stage.review;
      });
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _stage = _Stage.failed;
        _problem = e is NoCamera
            ? "This phone doesn't have a camera we can use."
            : "We couldn't start the camera. Close other apps using it and "
                  'try again.';
      });
    }
  }

  Future<void> _closeCamera() async {
    final s = _session;
    _session = null;
    await s?.dispose();
  }

  Future<void> _take() async {
    final s = _session;
    if (s == null || _taking) return;
    setState(() => _taking = true);
    try {
      final bytes = await s.take();
      if (!mounted) return;
      setState(() {
        _photo = bytes;
        _stage = _Stage.review;
      });
    } on PhotoTooLarge {
      _say('That photo is too large. Please take it again.');
    } on Object {
      _say("We couldn't take the photo. Please try again.");
    } finally {
      if (mounted) setState(() => _taking = false);
    }
  }

  void _say(String message) {
    if (!mounted) return;
    setState(() => _problem = message);
  }

  Future<void> _toggleFlash() async {
    final s = _session;
    if (s == null) return;
    final next = !_flash;
    await s.setFlash(on: next);
    if (mounted) setState(() => _flash = next);
  }

  void _use() {
    final photo = _photo;
    if (photo == null) return;
    context.pop(photo);
  }

  @override
  Widget build(BuildContext context) {
    final explain = _stage == _Stage.explain || _stage == _Stage.blocked;
    return SecureScreen(
      child: explain
          ? _Explainer(
              doc: widget.doc,
              blocked: _stage == _Stage.blocked,
              onAllow: _allow,
              onSettings: _camera.openSettings,
            )
          : _CameraView(
              doc: widget.doc,
              stage: _stage,
              session: _session,
              photo: _photo,
              flash: _flash,
              taking: _taking,
              problem: _problem,
              onTake: _take,
              onFlash: _toggleFlash,
              onRetake: () {
                setState(() {
                  _photo = null;
                  _problem = null;
                  if (_session != null) _stage = _Stage.live;
                });
                // The camera was closed while reviewing (the app went to
                // the background): open it again rather than failing.
                if (_session == null) unawaited(_startCamera());
              },
              onUse: _use,
              onRetry: _startCamera,
            ),
    );
  }
}

/// "Allow the camera": why, before the system prompt; or how to turn it
/// back on in Settings.
class _Explainer extends StatelessWidget {
  const new({
    required this.doc,
    required this.blocked,
    required this.onAllow,
    required this.onSettings,
  });

  final CaptureDoc doc;
  final bool blocked;
  final Future<void> Function() onAllow;
  final Future<void> Function() onSettings;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    TextSpan bold(String text) => TextSpan(
      text: text,
      style: TextStyle(color: c.ink, fontWeight: FontWeight.w800),
    );
    final intro = blocked
        ? const (
            'The camera is off for AtomPay',
            'To photograph your CNIC, turn it on in Settings › Apps › '
                'AtomPay › Permissions › Camera.',
          )
        : (
            doc.isCnic ? 'Photograph your CNIC' : 'Take a selfie',
            'AtomPay needs the camera to take your CNIC photos and a selfie.',
          );
    final content = <Widget>[
      // Canvas: a 76 dp camera tile, centred above the heading.
      Center(
        child: Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            color: c.primarySoft,
            borderRadius: BorderRadius.circular(Radii.card),
          ),
          child: Icon(Icons.photo_camera_outlined, size: 36, color: c.primary),
        ),
      ),
      const SizedBox(height: Space.s22),
      Semantics(
        header: true,
        child: Text(intro.$1, textAlign: TextAlign.center, style: t.h2),
      ),
      Gap.s8,
      Text(intro.$2, textAlign: TextAlign.center, style: t.lead),
      const SizedBox(height: Space.s22),
      if (blocked)
        const Note(
          tone: NoteTone.blue,
          text:
              "Can't use the camera? Contact us from Help and we will tell "
              'you what else we can accept.',
        )
      else
        AppCard(
          padding: const EdgeInsets.all(Space.s18),
          child: TickList([
            TextSpan(
              children: [
                const TextSpan(text: 'Used '),
                bold('only while you take the photo'),
                const TextSpan(text: '.'),
              ],
            ),
            TextSpan(
              children: [
                const TextSpan(
                  text: 'Photos go straight to verification and are ',
                ),
                bold('not saved on your phone'),
                const TextSpan(text: '.'),
              ],
            ),
            TextSpan(
              children: [
                const TextSpan(text: 'We '),
                bold('never open your gallery'),
                const TextSpan(text: '.'),
              ],
            ),
          ]),
        ),
    ];
    return Scaffold(
      backgroundColor: c.white,
      appBar: const AppTopBar(white: true),
      body: Column(
        children: [
          Expanded(
            // Canvas: the explanation sits in the middle of the screen; it
            // scrolls when large text makes it taller than the space.
            child: LayoutBuilder(
              builder: (context, box) => SingleChildScrollView(
                padding: const EdgeInsets.all(Space.gutter),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: box.maxHeight > Space.gutter * 2
                        ? box.maxHeight - Space.gutter * 2
                        : 0.0,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: content,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: c.white,
              border: Border(top: BorderSide(color: c.line)),
            ),
            padding: const EdgeInsets.fromLTRB(
              Space.s16,
              Space.s12,
              Space.s16,
              Space.s16,
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (blocked)
                    AppButton.primary(
                      'Open settings',
                      large: true,
                      block: true,
                      onPressed: onSettings,
                    )
                  else
                    AppButton.primary(
                      'Allow camera',
                      large: true,
                      block: true,
                      onPressed: onAllow,
                    ),
                  Gap.s10,
                  // Canvas: a plain text button in the body colour.
                  Pressable(
                    onTap: () => Navigator.of(context).maybePop(),
                    semanticLabel: blocked ? 'Back' : 'Not now',
                    excludeChildSemantics: true,
                    child: SizedBox(
                      height: Sizes.target,
                      child: Center(
                        child: Text(
                          blocked ? 'Back' : 'Not now',
                          style: t.button.copyWith(color: c.body),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CameraView extends StatelessWidget {
  const new({
    required this.doc,
    required this.stage,
    required this.session,
    required this.photo,
    required this.flash,
    required this.taking,
    required this.problem,
    required this.onTake,
    required this.onFlash,
    required this.onRetake,
    required this.onUse,
    required this.onRetry,
  });

  final CaptureDoc doc;
  final _Stage stage;
  final CameraSession? session;
  final Uint8List? photo;
  final bool flash;
  final bool taking;
  final String? problem;
  final VoidCallback onTake;
  final VoidCallback onFlash;
  final VoidCallback onRetake;
  final VoidCallback onUse;
  final VoidCallback onRetry;

  String get _prompt => switch (doc) {
    CaptureDoc.cnicFront => 'Fit the front of your CNIC inside the frame',
    CaptureDoc.cnicBack => 'Fit the back of your CNIC inside the frame',
    CaptureDoc.selfie => 'Hold your CNIC next to your face',
  };

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final onDark = TextStyle(color: c.white);
    final reviewing = stage == _Stage.review && photo != null;
    final selfie = doc == CaptureDoc.selfie;

    Widget viewfinder;
    if (reviewing) {
      viewfinder = Semantics(
        image: true,
        label: 'Your photo of the ${doc.title}',
        child: Image.memory(photo!, fit: BoxFit.contain, gaplessPlayback: true),
      );
    } else if (stage == _Stage.live && session != null) {
      viewfinder = Stack(
        fit: StackFit.expand,
        children: [
          ExcludeSemantics(child: session!.preview()),
          IgnorePointer(child: _Frame(selfie: selfie)),
        ],
      );
    } else if (stage == _Stage.failed) {
      viewfinder = Center(
        child: Padding(
          padding: const EdgeInsets.all(Space.s24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                problem ?? "We couldn't start the camera.",
                textAlign: TextAlign.center,
                style: t.body.merge(onDark),
              ),
              Gap.s16,
              AppButton.primary('Try again', onPressed: onRetry),
            ],
          ),
        ),
      );
    } else {
      viewfinder = Center(
        child: Semantics(
          label: 'Starting the camera',
          child: CircularProgressIndicator(color: c.white),
        ),
      );
    }

    final tipStyle = t.tiny.copyWith(
      color: c.onDark2,
      fontWeight: FontWeight.w700,
    );
    Widget tip(IconData icon, String label) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: c.onDark2),
        const SizedBox(width: Space.s6),
        Text(label, style: tipStyle),
      ],
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // Dark screen: light status-bar icons.
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: c.cam,
        body: SafeArea(
          child: Column(
            children: [
              // Canvas app bar on the camera: leading, centred white title,
              // the "1 of 2" pill (or a spacer that keeps the title centred).
              SizedBox(
                height: Sizes.appBar,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Space.s8),
                  child: Row(
                    children: [
                      AppIconButton(
                        icon: selfie ? Icons.chevron_left : Icons.close,
                        size: selfie ? 28 : 22,
                        label: selfie ? 'Back' : 'Close',
                        color: c.white,
                        onPressed: () => context.pop(),
                      ),
                      const SizedBox(width: Space.s6),
                      Expanded(
                        child: Semantics(
                          header: true,
                          child: Text(
                            doc.title,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: t.h4.merge(onDark),
                          ),
                        ),
                      ),
                      const SizedBox(width: Space.s6),
                      SizedBox(
                        width: 56,
                        child: doc.isCnic
                            ? Center(
                                child: _StepPill(
                                  doc == CaptureDoc.cnicFront
                                      ? '1 of 2'
                                      : '2 of 2',
                                ),
                              )
                            : null,
                      ),
                    ],
                  ),
                ),
              ),
              Gap.s8,
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
                child: Text(
                  reviewing ? 'Can you read every line clearly?' : _prompt,
                  textAlign: TextAlign.center,
                  style: t.h4.merge(onDark),
                ),
              ),
              Gap.s16,
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(Radii.card),
                    child: ColoredBox(color: c.ink, child: viewfinder),
                  ),
                ),
              ),
              Gap.s16,
              if (problem != null && stage != _Stage.failed)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Space.gutter,
                    0,
                    Space.gutter,
                    Space.s8,
                  ),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      problem!,
                      textAlign: TextAlign.center,
                      style: t.small.copyWith(color: c.white),
                    ),
                  ),
                ),
              if (!reviewing)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
                  child: doc.isCnic
                      ? Wrap(
                          alignment: WrapAlignment.center,
                          spacing: Space.s18,
                          runSpacing: Space.s6,
                          children: [
                            tip(Icons.wb_sunny_outlined, 'Good light'),
                            tip(Icons.block, 'No glare'),
                            tip(Icons.crop_free, 'All 4 corners'),
                          ],
                        )
                      : Text(
                          'Front camera · your face and the card both in view '
                          '· no hat or dark glasses',
                          textAlign: TextAlign.center,
                          style: t.small.copyWith(color: c.onDark2),
                        ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Space.s24,
                  Space.s18,
                  Space.s24,
                  Space.s24,
                ),
                child: reviewing
                    ? Row(
                        children: [
                          Expanded(
                            child: AppButton.dark(
                              'Retake',
                              block: true,
                              onPressed: onRetake,
                            ),
                          ),
                          const SizedBox(width: Space.s12),
                          Expanded(
                            child: AppButton.primary(
                              'Use photo',
                              block: true,
                              onPressed: onUse,
                            ),
                          ),
                        ],
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Canvas: flash beside the shutter, balanced by an
                          // empty slot on the other side.
                          SizedBox(
                            width: Sizes.target,
                            child: session?.hasFlash ?? false
                                ? AppIconButton(
                                    icon: flash
                                        ? Icons.flash_on
                                        : Icons.flash_off,
                                    label: flash ? 'Flash on' : 'Flash off',
                                    color: c.white,
                                    onPressed: onFlash,
                                  )
                                : null,
                          ),
                          const SizedBox(width: Space.s28),
                          _Shutter(
                            label: selfie ? 'Take selfie' : 'Take photo',
                            busy: taking,
                            onTap: stage == _Stage.live ? onTake : null,
                          ),
                          const SizedBox(width: Space.s28),
                          const SizedBox(width: Sizes.target),
                        ],
                      ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Space.gutter,
                  0,
                  Space.gutter,
                  Space.s18,
                ),
                child: Text(
                  'Camera only · screenshots are blocked on this screen',
                  textAlign: TextAlign.center,
                  style: t.tiny.copyWith(color: c.onDark2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Canvas camera badge: "1 OF 2" on ink-2, white text.
class _StepPill extends StatelessWidget {
  const new(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      label: label,
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: Space.s10,
          vertical: Space.s4,
        ),
        decoration: BoxDecoration(
          color: c.ink2,
          borderRadius: BorderRadius.circular(Radii.pill),
        ),
        child: Text(
          label.toUpperCase(),
          maxLines: 1,
          softWrap: false,
          style: context.text.xs.copyWith(
            color: c.white,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.6,
          ),
        ),
      ),
    );
  }
}

/// Canvas `.shutter`: 76 dp, a 4 dp white ring round a 60 dp disc.
class _Shutter extends StatelessWidget {
  const new({required this.label, required this.busy, required this.onTap});

  final String label;
  final bool busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Pressable(
      onTap: busy ? null : onTap,
      semanticLabel: label,
      focusRingColor: c.white,
      borderRadius: BorderRadius.circular(Radii.pill),
      excludeChildSemantics: true,
      child: Container(
        width: 76,
        height: 76,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: c.white, width: 4),
        ),
        padding: const EdgeInsets.all(Space.s4),
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: onTap == null ? c.onDark2 : c.white,
          ),
          child: busy
              ? Padding(
                  padding: const EdgeInsets.all(Space.s20),
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: c.ink,
                  ),
                )
              : null,
        ),
      ),
    );
  }
}

/// The guide over the preview: amber corner brackets round the card
/// (CNIC, 85.6 × 54 mm), or a dashed amber oval with a card beside the face.
class _Frame extends StatelessWidget {
  const new({required this.selfie});

  final bool selfie;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final c = context.colors;
      if (!selfie) {
        final w = math.min<double>(box.maxWidth * 0.86, 330);
        return Center(
          child: CustomPaint(
            size: Size(w, w / 1.586),
            painter: _CornersPainter(color: c.apayAmber),
          ),
        );
      }
      // Canvas: a 230 × 300 oval with a 96 × 62 card at its lower right.
      final w = math.min<double>(box.maxWidth * 0.62, 230);
      final h = w * 300 / 230;
      final k = w / 230;
      return Center(
        child: SizedBox(
          width: w,
          height: h,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: DashedOutlinePainter(
                    color: c.apayAmber,
                    strokeWidth: 4,
                    dash: 8,
                    gap: 6,
                    oval: true,
                  ),
                ),
              ),
              Positioned(
                right: -48 * k,
                bottom: 38 * k,
                width: 96 * k,
                height: 62 * k,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: c.apayAmber.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(Space.s10),
                    border: Border.all(color: c.apayAmber, width: 3),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// Canvas `.frame i`: four 34 dp corner brackets, 4 dp wide, 16 radius.
class _CornersPainter extends CustomPainter {
  const new({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const arm = 34.0;
    const r = 16.0;
    const inset = 2.0;
    const corner = Radius.circular(r);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    const l = inset;
    const t = inset;
    final rt = size.width - inset;
    final b = size.height - inset;
    final path = Path()
      // top left
      ..moveTo(l, t + arm)
      ..lineTo(l, t + r)
      ..arcToPoint(const Offset(l + r, t), radius: corner)
      ..lineTo(l + arm, t)
      // top right
      ..moveTo(rt - arm, t)
      ..lineTo(rt - r, t)
      ..arcToPoint(Offset(rt, t + r), radius: corner)
      ..lineTo(rt, t + arm)
      // bottom right
      ..moveTo(rt, b - arm)
      ..lineTo(rt, b - r)
      ..arcToPoint(Offset(rt - r, b), radius: corner)
      ..lineTo(rt - arm, b)
      // bottom left
      ..moveTo(l + arm, b)
      ..lineTo(l + r, b)
      ..arcToPoint(Offset(l, b - r), radius: corner)
      ..lineTo(l, b - arm);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_CornersPainter oldDelegate) => oldDelegate.color != color;
}
