import 'dart:async';

import 'package:atompay_mobile/core/theme/tokens.dart';
import 'package:atompay_mobile/core/widgets/buttons.dart';
import 'package:atompay_mobile/core/widgets/form_parts.dart';
import 'package:atompay_mobile/core/widgets/pressable.dart';
import 'package:atompay_mobile/core/widgets/secure_screen.dart';
import 'package:atompay_mobile/core/widgets/ui.dart';
import 'package:atompay_mobile/features/application/data/camera_service.dart';
import 'package:atompay_mobile/features/application/data/capture_doc.dart';
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
              onRetake: () => setState(() {
                _photo = null;
                _problem = null;
                _stage = _session == null ? _Stage.failed : _Stage.live;
              }),
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
    final t = context.text;
    return Scaffold(
      backgroundColor: context.colors.white,
      appBar: const AppTopBar(white: true),
      body: FormPage(
        footer: blocked
            ? AppButton.primary(
                'Open settings',
                large: true,
                block: true,
                onPressed: onSettings,
              )
            : AppButton.primary(
                'Allow camera',
                large: true,
                block: true,
                onPressed: onAllow,
              ),
        children: [
          PageIntro(
            title: doc.isCnic ? 'Photograph your CNIC' : 'Take a selfie',
            lead:
                'AtomPay needs the camera to take your CNIC photos and a '
                'selfie.',
          ),
          Gap.s20,
          if (blocked) ...[
            Note(
              tone: NoteTone.rose,
              spans: [
                TextSpan(
                  text: 'The camera is off for AtomPay\n',
                  style: t.base.copyWith(fontWeight: FontWeight.w800),
                ),
                const TextSpan(
                  text:
                      'To photograph your CNIC, turn it on in Settings › '
                      'Apps › AtomPay › Permissions › Camera.',
                ),
              ],
            ),
            Gap.s16,
          ],
          const AppCard(
            child: TickList([
              TextSpan(text: 'Used only while you take the photo.'),
              TextSpan(
                text:
                    'Photos go straight to verification and are not saved on '
                    'your phone.',
              ),
              TextSpan(text: 'We never open your gallery.'),
            ]),
          ),
          Gap.s16,
          const Note(
            tone: NoteTone.blue,
            text:
                "Can't use the camera? Contact us from Help and we will tell "
                'you what else we can accept.',
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
          IgnorePointer(child: _Frame(selfie: doc == CaptureDoc.selfie)),
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

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // Dark screen: light status-bar icons.
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: c.cam,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Space.s4,
                  Space.s4,
                  Space.gutter,
                  Space.s8,
                ),
                child: Row(
                  children: [
                    AppIconButton(
                      icon: Icons.close,
                      label: 'Close',
                      color: c.white,
                      onPressed: () => context.pop(),
                    ),
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: Text(doc.title, style: t.h4.merge(onDark)),
                      ),
                    ),
                    if (doc.isCnic)
                      AppBadge.grey(
                        doc == CaptureDoc.cnicFront ? '1 of 2' : '2 of 2',
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
                child: Text(
                  reviewing
                      ? 'Check it is sharp and every corner shows'
                      : _prompt,
                  textAlign: TextAlign.center,
                  style: t.base.merge(onDark),
                ),
              ),
              Gap.s12,
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(Radii.card),
                    child: ColoredBox(color: c.ink, child: viewfinder),
                  ),
                ),
              ),
              Gap.s12,
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
                Text(
                  doc.isCnic
                      ? 'Good light · No glare · All 4 corners'
                      : 'Front camera · face and card in view · no hat or dark '
                            'glasses',
                  textAlign: TextAlign.center,
                  style: t.small.copyWith(color: c.onDark2),
                ),
              Gap.s12,
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
                child: reviewing
                    ? Row(
                        children: [
                          Expanded(
                            child: AppButton.ghost(
                              'Retake',
                              large: true,
                              block: true,
                              onPressed: onRetake,
                            ),
                          ),
                          const SizedBox(width: Space.s12),
                          Expanded(
                            child: AppButton.primary(
                              'Use photo',
                              large: true,
                              block: true,
                              onPressed: onUse,
                            ),
                          ),
                        ],
                      )
                    : SizedBox(
                        height: 76,
                        child: Row(
                          children: [
                            Expanded(
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: session?.hasFlash ?? false
                                    ? AppIconButton(
                                        icon: flash
                                            ? Icons.flash_on
                                            : Icons.flash_off,
                                        label: flash ? 'Flash on' : 'Flash off',
                                        color: c.white,
                                        onPressed: onFlash,
                                      )
                                    : const SizedBox.shrink(),
                              ),
                            ),
                            _Shutter(
                              label: doc == CaptureDoc.selfie
                                  ? 'Take selfie'
                                  : 'Take photo',
                              busy: taking,
                              onTap: stage == _Stage.live ? onTake : null,
                            ),
                            const Spacer(),
                          ],
                        ),
                      ),
              ),
              Gap.s12,
              Text(
                'Camera only · screenshots are blocked on this screen',
                style: t.xs.copyWith(color: c.onDark2),
              ),
              Gap.s8,
            ],
          ),
        ),
      ),
    );
  }
}

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
        width: 72,
        height: 72,
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
                  padding: const EdgeInsets.all(Space.s18),
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

/// The card outline (CNIC, 85.6 × 54 mm) or the face oval.
class _Frame extends StatelessWidget {
  const new({required this.selfie});

  final bool selfie;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final c = context.colors;
      final w = box.maxWidth * (selfie ? 0.62 : 0.86);
      final h = selfie ? w * 1.3 : w / 1.586;
      return Center(
        child: Container(
          width: w,
          height: h,
          decoration: BoxDecoration(
            border: Border.all(color: c.white, width: 3),
            borderRadius: selfie
                ? BorderRadius.all(Radius.elliptical(w / 2, h / 2))
                : BorderRadius.circular(Radii.tile),
          ),
        ),
      );
    },
  );
}
