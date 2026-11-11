import 'package:atompay_mobile/core/config/env.dart';
import 'package:atompay_mobile/core/format/dates.dart';
import 'package:atompay_mobile/core/router/routes.dart';
import 'package:atompay_mobile/core/theme/tokens.dart';
import 'package:atompay_mobile/core/utils/links.dart';
import 'package:atompay_mobile/core/widgets/brand.dart';
import 'package:atompay_mobile/core/widgets/buttons.dart';
import 'package:atompay_mobile/core/widgets/form_parts.dart';
import 'package:atompay_mobile/core/widgets/ui.dart';
import 'package:atompay_mobile/features/launch/application/launch_controller.dart';
import 'package:atompay_mobile/features/launch/data/app_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Shown while app-config and `/me` load. Continues the native launch
/// screen exactly (the mark on a white disc, on nucleus), so there is no
/// jump between them. Disc sizes match tool/brand/generate_icons.py.
class SplashScreen extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    // Light status-bar icons on the dark splash.
    value: SystemUiOverlayStyle.light,
    child: Scaffold(
      backgroundColor: LaunchBrand.nucleus,
      body: Center(
        child: Semantics(
          label: 'AtomPay is starting',
          liveRegion: true,
          excludeSemantics: true,
          child: Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              color: context.colors.white,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Image.asset(BrandAssets.markClear, width: 100),
          ),
        ),
      ),
    ),
  );
}

/// Signed out: create an account or sign in (canvas "Splash").
class WelcomeScreen extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    // Canvas `.terms`: three separate white tiles.
    Widget term(String big, String small) => Expanded(
      child: Semantics(
        label: '$big $small',
        excludeSemantics: true,
        child: Container(
          padding: const EdgeInsets.symmetric(
            vertical: Space.s14,
            horizontal: Space.s10,
          ),
          decoration: BoxDecoration(
            color: c.white,
            borderRadius: BorderRadius.circular(Radii.row),
            border: Border.all(color: c.line),
          ),
          child: Column(
            children: [
              Text(
                big,
                style: t.h3.copyWith(letterSpacing: -0.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: Space.s2),
              Text(small, style: t.tiny, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
    const gap = SizedBox(height: Space.s18);
    final top = Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.s28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Dev and staging: long-press for the gallery. A developer
          // shortcut, hidden from screen readers.
          GestureDetector(
            excludeFromSemantics: true,
            onLongPress: Env.isProd ? null : () => context.push(Routes.gallery),
            child: Container(
              decoration: BoxDecoration(
                color: c.white,
                borderRadius: BorderRadius.circular(26),
                boxShadow: [
                  BoxShadow(
                    color: c.ink.withValues(alpha: 0.08),
                    blurRadius: 40,
                    offset: const Offset(0, 16),
                  ),
                ],
              ),
              child: const AtomPayMark(size: 96),
            ),
          ),
          gap,
          Semantics(
            label: 'AtomPay, pay in steps',
            excludeSemantics: true,
            child: Column(
              children: [
                Text(
                  'ATOMPAY',
                  style: t.h1.copyWith(letterSpacing: -0.8, height: 1),
                ),
                Gap.s6,
                Text('PAY IN STEPS', style: t.xs.copyWith(letterSpacing: 3.4)),
              ],
            ),
          ),
          gap,
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 300),
            child: Text(
              'Buy on Atomshop.pk now and pay the cash price over three '
              'months.',
              style: t.lead,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
    final bottom = Padding(
      padding: const EdgeInsets.fromLTRB(
        Space.s20,
        Space.s24,
        Space.s20,
        Space.s18,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                term('Rs. 0', 'advance'),
                const SizedBox(width: Space.s8),
                term('0%', 'markup'),
                const SizedBox(width: Space.s8),
                term('3', 'months'),
              ],
            ),
          ),
          Gap.s14,
          AppButton.primary(
            'Create an account',
            large: true,
            block: true,
            onPressed: () => context.push(Routes.register),
          ),
          Gap.s14,
          AppButton.ghost(
            'Sign in',
            large: true,
            block: true,
            onPressed: () => context.push(Routes.login),
          ),
          Gap.s14,
          Padding(
            padding: const EdgeInsets.only(bottom: Space.s14),
            child: Text(
              'Part of the Atom ecosystem: Atomshop · AtomPay · Atom Seller · '
              'AtomBrand',
              style: t.tiny,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
    return Scaffold(
      backgroundColor: c.surface,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, box) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: box.maxHeight),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  // The brand sits centred in the space above the actions
                  // (the empty first child takes the other half of it); at
                  // large text the page simply scrolls.
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [const SizedBox.shrink(), top, bottom],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Disclosures, shown once before sign-in (canvas "Before you start"):
/// Google Play's prominent disclosure and SECP's minimum disclosures.
class FirstRunScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<FirstRunScreen> createState() => _FirstRunScreenState();
}

class _FirstRunScreenState extends ConsumerState<FirstRunScreen> {
  bool _ok = false;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final config = ref.watch(appConfigProvider);
    final bold = TextStyle(color: c.ink, fontWeight: FontWeight.w700);
    const gap = SizedBox(height: Space.s18);
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: c.white,
        body: SafeArea(
          child: FormPage(
            footer: AppButton.primary(
              'Continue',
              large: true,
              block: true,
              onPressed: _ok
                  ? () => ref.read(consentProvider.notifier).accept()
                  : null,
            ),
            children: [
              const PageIntro(
                eyebrow: 'Before you start',
                title: 'What AtomPay asks for, and why',
              ),
              gap,
              AppCard(
                color: c.apayWash,
                borderColor: c.apayLine,
                padding: const EdgeInsets.symmetric(
                  horizontal: Space.s18,
                  vertical: Space.s16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(
                        'WHO PROVIDES YOUR CREDIT',
                        style: t.tiny.copyWith(
                          color: c.rose,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    Gap.s10,
                    TbdText('[LICENSED ENTITY NAME]', style: t.body),
                    Gap.s4,
                    Text.rich(
                      TextSpan(
                        style: t.small,
                        children: [
                          const TextSpan(
                            text: 'Licensed by the SECP · licence ',
                          ),
                          placeholderSpan(context, '[LICENCE NO.]'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              gap,
              const SectionLabel('We ask for'),
              TickList(
                [
                  TextSpan(
                    children: [
                      TextSpan(text: 'Camera', style: bold),
                      const TextSpan(
                        text:
                            ' — only while you photograph your CNIC and take '
                            'a selfie. Never in the background.',
                      ),
                    ],
                  ),
                  TextSpan(
                    children: [
                      TextSpan(text: 'Notifications', style: bold),
                      const TextSpan(
                        text:
                            ' — optional, for payment reminders and '
                            'decisions.',
                      ),
                    ],
                  ),
                  TextSpan(
                    children: [
                      TextSpan(text: 'Microphone', style: bold),
                      const TextSpan(
                        text:
                            ' — optional, only if you ask Atom by voice. We '
                            'keep the text, not the recording.',
                      ),
                    ],
                  ),
                  TextSpan(
                    children: [
                      TextSpan(
                        text: 'Your CNIC, address and income',
                        style: bold,
                      ),
                      const TextSpan(
                        text:
                            ' — to verify you and set your limit, as the law '
                            'requires.',
                      ),
                    ],
                  ),
                ],
                icons: const [
                  Icons.photo_camera_outlined,
                  Icons.notifications_none_rounded,
                  Icons.mic_none_rounded,
                  Icons.shield_outlined,
                ],
                color: c.primary,
              ),
              gap,
              const SectionLabel('We never access'),
              const TickList([
                TextSpan(
                  text:
                      'Your contacts, photo gallery, files, call logs, '
                      'messages or location — not even with your permission.',
                ),
              ]),
              gap,
              // The canvas links "privacy policy" and "terms" inline; they
              // stay separate links here for their 48 dp targets.
              Note(
                tone: NoteTone.blue,
                icon: Icons.language,
                spans: [
                  const TextSpan(text: 'Your data is stored in Pakistan '),
                  placeholderSpan(context, '[CONFIRM HOSTING]'),
                  TextSpan(
                    text: config.termsUrl == null
                        ? '. Read the privacy policy.'
                        : '. Read the privacy policy and terms.',
                  ),
                ],
                action: Wrap(
                  spacing: Space.s16,
                  children: [
                    TextLink(
                      'Privacy policy',
                      external: true,
                      onPressed: () => Links.open(config.privacyUrl),
                    ),
                    if (config.termsUrl != null)
                      TextLink(
                        'Terms',
                        external: true,
                        onPressed: () => Links.open(config.termsUrl),
                      ),
                  ],
                ),
              ),
              gap,
              ConsentRow(
                value: _ok,
                onChanged: (v) => setState(() => _ok = v),
                child: Text(
                  config.termsUrl == null
                      ? 'I have read the privacy policy.'
                      : 'I have read the privacy policy and the terms.',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Blocking: this version is below `min_version`.
class UpdateRequiredScreen extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);
    final store = platformKey == 'ios'
        ? config.storeUrl.ios
        : config.storeUrl.android;
    final storeName = platformKey == 'ios' ? 'the App Store' : 'Google Play';
    return PopScope(
      canPop: false,
      child: _BlockingPage(
        icon: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Radii.card - 2),
            boxShadow: [
              BoxShadow(
                color: context.colors.ink.withValues(alpha: 0.08),
                blurRadius: 40,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: const AtomPayMark(size: 80),
        ),
        title: 'Time to update',
        body:
            'A new version of AtomPay is available. Please update to '
            'continue.',
        badge: const AppBadge.grey('This version is no longer supported'),
        actions: [
          if (store != null)
            AppButton.primary(
              'Update on $storeName',
              large: true,
              block: true,
              trailingIcon: Icons.north_east,
              onPressed: () => Links.open(store),
            )
          else
            ..._supportButtons(config.support),
        ],
      ),
    );
  }
}

/// Blocking: the app-config flag, or any 503.
class MaintenanceScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<MaintenanceScreen> createState() => _MaintenanceScreenState();
}

class _MaintenanceScreenState extends ConsumerState<MaintenanceScreen> {
  bool _busy = false;

  Future<void> _retry() async {
    setState(() => _busy = true);
    await ref.read(launchProvider.notifier).retry();
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(appConfigProvider);
    final until = config.maintenance.until;
    return PopScope(
      canPop: false,
      child: _BlockingPage(
        icon: Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: context.colors.amberSoft,
            borderRadius: BorderRadius.circular(Radii.card),
          ),
          child: Icon(
            Icons.build_outlined,
            size: 36,
            color: context.colors.amberInk,
          ),
        ),
        title: "We'll be right back",
        body:
            config.maintenance.message ??
            'AtomPay is being updated. Your limit, orders and payments are '
                'safe and unchanged.',
        badge: until == null
            ? null
            : AppBadge.amber('Back by about ${clock(until.toLocal())}'),
        actions: [
          AppButton.primary(
            'Try again',
            large: true,
            block: true,
            busy: _busy,
            onPressed: _retry,
          ),
          ..._supportButtons(config.support, whatsappOnly: true),
        ],
      ),
    );
  }
}

List<Widget> _supportButtons(Support s, {bool whatsappOnly = false}) => [
  if (s.whatsapp != null)
    AppButton.ghost(
      'WhatsApp support',
      block: true,
      trailingIcon: Icons.north_east,
      onPressed: () => Links.whatsapp(s.whatsapp!),
    ),
  if (!whatsappOnly && s.phone != null)
    AppButton.ghost(
      'Call support',
      block: true,
      trailingIcon: Icons.north_east,
      onPressed: () => Links.call(s.phone!),
    ),
  if (!whatsappOnly && s.email != null)
    AppButton.ghost(
      'Email support',
      block: true,
      trailingIcon: Icons.north_east,
      onPressed: () => Links.email(s.email!),
    ),
];

class _BlockingPage extends StatelessWidget {
  const new({
    required this.icon,
    required this.title,
    required this.body,
    required this.actions,
    this.badge,
  });

  final Widget icon;
  final String title;
  final String body;
  final Widget? badge;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final t = context.text;
    const gap = SizedBox(height: Space.s18);
    return Scaffold(
      backgroundColor: context.colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Space.s28,
                    vertical: Space.s24,
                  ),
                  child: Column(
                    children: [
                      icon,
                      gap,
                      Semantics(
                        header: true,
                        child: Text(
                          title,
                          style: t.h2,
                          textAlign: TextAlign.center,
                        ),
                      ),
                      gap,
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 300),
                        child: Text(
                          body,
                          style: t.lead,
                          textAlign: TextAlign.center,
                        ),
                      ),
                      if (badge != null) ...[gap, badge!],
                    ],
                  ),
                ),
              ),
            ),
            if (actions.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Space.s20,
                  0,
                  Space.s20,
                  Space.s20,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < actions.length; i++) ...[
                      if (i > 0) Gap.s12,
                      actions[i],
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
