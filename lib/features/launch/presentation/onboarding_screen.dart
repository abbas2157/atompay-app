import 'dart:async';

import 'package:atompay_mobile/core/theme/tokens.dart';
import 'package:atompay_mobile/core/widgets/brand.dart';
import 'package:atompay_mobile/core/widgets/buttons.dart';
import 'package:atompay_mobile/core/widgets/form_parts.dart';
import 'package:atompay_mobile/core/widgets/ui.dart';
import 'package:atompay_mobile/features/launch/application/launch_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// One intro slide.
@immutable
class OnboardingSlide {
  const new({
    required this.icon,
    required this.tone,
    required this.eyebrow,
    required this.title,
    required this.lead,
    this.points = const [],
    this.photo,
    this.focus = Alignment.center,
  });

  /// Shown when there is no [photo]. Null shows Ask Atom's avatar.
  final IconData? icon;

  /// A photo for the top of the slide (`assets/images/`).
  final String? photo;

  /// Which part of the photo stays in view when it is cropped.
  final Alignment focus;
  final TileTone tone;
  final String eyebrow;
  final String title;
  final String lead;
  final List<String> points;
}

/// What a new install sees first, once. Plain facts only: no promise of
/// approval or a limit (the decision is the lender's).
const onboardingSlides = [
  OnboardingSlide(
    icon: Icons.shopping_bag_outlined,
    photo: 'assets/images/onboarding_shop.jpg',
    focus: Alignment(0.35, 0),
    tone: TileTone.blue,
    eyebrow: 'Buy now, pay in steps',
    title: 'Shop on Atomshop.pk, pay over three months',
    lead: 'Pay the cash price in three monthly instalments.',
    points: ['Rs. 0 advance', '0% markup', 'Every date shown up front'],
  ),
  OnboardingSlide(
    icon: Icons.verified_user_outlined,
    photo: 'assets/images/onboarding_apply.jpg',
    focus: Alignment(0.45, -0.2),
    tone: TileTone.green,
    eyebrow: 'Apply once',
    title: 'One application, then a spending limit',
    lead:
        'Tell us about yourself and photograph your CNIC. If approved, '
        'your limit works for every order after that.',
    points: [
      'About five minutes on your phone',
      'We tell you the decision in the app',
    ],
  ),
  OnboardingSlide(
    icon: null,
    photo: 'assets/images/onboarding_help.jpg',
    focus: Alignment(0.25, -0.3),
    tone: TileTone.amber,
    eyebrow: 'Help when you need it',
    title: 'Ask Atom, by text or voice',
    lead:
        'Questions about an order, a payment date or your limit? Ask Atom '
        'any time, or raise a complaint from Help.',
    points: ['Payment reminders before each date', 'Your plan, in one place'],
  ),
];

/// The intro slides (route `/onboarding`). "Skip" and "Get started" both
/// finish, and the guard moves on to First run.
class OnboardingScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pages = PageController();
  int _page = 0;

  bool get _last => _page == onboardingSlides.length - 1;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _finish() => unawaited(ref.read(onboardedProvider.notifier).finish());

  void _goTo(int page) {
    if (context.reduceMotion) {
      _pages.jumpToPage(page);
    } else {
      _pages.animateToPage(
        page,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final count = onboardingSlides.length;
    return PopScope(
      // Back steps through the slides before leaving the app.
      canPop: _page == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _goTo(_page - 1);
      },
      child: Scaffold(
        backgroundColor: c.white,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Space.gutter,
                  Space.s8,
                  Space.s8,
                  0,
                ),
                // Same height with or without Skip, so the mark stays put.
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: Row(
                    children: [
                      const AtomPayMark(size: 32),
                      const Spacer(),
                      if (!_last) TextLink('Skip', onPressed: _finish),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _pages,
                  itemCount: count,
                  onPageChanged: (p) => setState(() => _page = p),
                  itemBuilder: (_, i) => _SlideView(
                    slide: onboardingSlides[i],
                    position: i + 1,
                    count: count,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Space.gutter,
                  Space.s8,
                  Space.gutter,
                  Space.gutter,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Dots(page: _page, count: count),
                    Gap.s20,
                    AppButton.primary(
                      _last ? 'Get started' : 'Next',
                      large: true,
                      block: true,
                      onPressed: _last ? _finish : () => _goTo(_page + 1),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SlideView extends StatelessWidget {
  const new({required this.slide, required this.position, required this.count});

  final OnboardingSlide slide;
  final int position;
  final int count;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    return LayoutBuilder(
      builder: (context, box) => SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: box.maxHeight),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Semantics(
                container: true,
                label: 'Page $position of $count',
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Gap.s24,
                    _Hero(slide: slide),
                    Gap.s32,
                    Text(slide.eyebrow.toUpperCase(), style: t.eyebrow),
                    Gap.s8,
                    Text(
                      slide.title,
                      style: t.h1b,
                      semanticsLabel: slide.title,
                    ),
                    Gap.s12,
                    Text(slide.lead, style: t.lead),
                    if (slide.points.isNotEmpty) ...[
                      Gap.s16,
                      for (final p in slide.points)
                        Padding(
                          padding: const EdgeInsets.only(bottom: Space.s8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Icon(
                                  Icons.check_circle,
                                  size: 18,
                                  color: c.green,
                                ),
                              ),
                              const SizedBox(width: Space.s10),
                              Expanded(child: Text(p, style: t.body)),
                            ],
                          ),
                        ),
                    ],
                    Gap.s24,
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A soft wash panel with the slide's icon (or Ask Atom) in the middle.
class _Hero extends StatelessWidget {
  const new({required this.slide});

  final OnboardingSlide slide;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final wash = switch (slide.tone) {
      TileTone.green => c.greenWash,
      TileTone.amber => c.amberWash,
      _ => c.primarySoft,
    };
    final ink = switch (slide.tone) {
      TileTone.green => c.green,
      TileTone.amber => c.amberInk,
      _ => c.primary,
    };
    if (slide.photo case final photo?) {
      return ExcludeSemantics(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(Space.s24),
          child: Image.asset(
            photo,
            // Decoded at screen size, not the photo's 1600 px.
            cacheWidth:
                (MediaQuery.sizeOf(context).width *
                        MediaQuery.devicePixelRatioOf(context))
                    .round(),
            height: 240,
            width: double.infinity,
            fit: BoxFit.cover,
            alignment: slide.focus,
          ),
        ),
      );
    }
    return ExcludeSemantics(
      child: Container(
        height: 200,
        width: double.infinity,
        decoration: BoxDecoration(
          color: wash,
          borderRadius: BorderRadius.circular(Space.s24),
          border: Border.all(color: c.line),
        ),
        alignment: Alignment.center,
        child: slide.icon == null
            ? const AtomAvatar(size: 104, ring: true)
            : Container(
                width: 104,
                height: 104,
                decoration: BoxDecoration(
                  color: c.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: c.line),
                  boxShadow: [
                    BoxShadow(
                      color: c.shadow,
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Icon(slide.icon, size: 48, color: ink),
              ),
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const new({required this.page, required this.count});

  final int page;
  final int count;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ExcludeSemantics(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < count; i++)
            AnimatedContainer(
              duration: context.reduceMotion
                  ? Duration.zero
                  : const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: Space.s4),
              width: i == page ? 24 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: i == page ? c.primary : c.line3,
                borderRadius: BorderRadius.circular(Space.s4),
              ),
            ),
        ],
      ),
    );
  }
}
