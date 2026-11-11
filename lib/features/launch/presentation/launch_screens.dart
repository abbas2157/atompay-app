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
    Widget term(String big, String small) => Expanded(
      child: Semantics(
        label: '$big $small',
        excludeSemantics: true,
        child: Column(
          children: [
            Text(big, style: t.h2),
            Text(small, style: t.small),
          ],
        ),
      ),
    );
    return Scaffold(
      backgroundColor: c.surface,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, box) => SingleChildScrollView(
            padding: const EdgeInsets.all(Space.gutter),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: box.maxHeight - Space.gutter * 2,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Column(
                        children: [
                          Gap.s32,
                          // Dev and staging: long-press for the gallery. A
                          // developer shortcut, hidden from screen readers.
                          GestureDetector(
                            excludeFromSemantics: true,
                            onLongPress: Env.isProd
                                ? null
                                : () => context.push(Routes.gallery),
                            child: const AtomPayLogo(height: 140),
                          ),
                          Gap.s24,
                          Text(
                            'Buy on Atomshop.pk now and pay the cash price '
                            'over three months.',
                            style: t.lead,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Gap.s24,
                          AppCard(
                            child: Row(
                              children: [
                                term('Rs. 0', 'advance'),
                                term('0%', 'markup'),
                                term('3', 'months'),
                              ],
                            ),
                          ),
                          Gap.s16,
                          AppButton.primary(
                            'Create an account',
                            large: true,
                            block: true,
                            onPressed: () => context.push(Routes.register),
                          ),
                          Gap.s12,
                          AppButton.ghost(
                            'Sign in',
                            large: true,
                            block: true,
                            onPressed: () => context.push(Routes.login),
                          ),
                          Gap.s16,
                          Text(
                            'Part of the Atom ecosystem: Atomshop · AtomPay · '
                            'Atom Seller · AtomBrand',
                            style: t.tiny,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ],
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
              Gap.s20,
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionLabel('Who provides your credit'),
                    const TbdText('[LICENSED ENTITY NAME]'),
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
              Gap.s20,
              const SectionLabel('We ask for'),
              TickList([
                TextSpan(
                  children: [
                    TextSpan(text: 'Camera', style: bold),
                    const TextSpan(
                      text:
                          ': only while you photograph your CNIC and take a '
                          'selfie. Never in the background.',
                    ),
                  ],
                ),
                TextSpan(
                  children: [
                    TextSpan(text: 'Notifications', style: bold),
                    const TextSpan(
                      text: ': optional, for payment reminders and decisions.',
                    ),
                  ],
                ),
                TextSpan(
                  children: [
                    TextSpan(text: 'Microphone', style: bold),
                    const TextSpan(
                      text:
                          ': optional, only if you ask Atom by voice. We '
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
                          ': to verify you and set your limit, as the law '
                          'requires.',
                    ),
                  ],
                ),
              ]),
              Gap.s8,
              const SectionLabel('We never access'),
              TickList(
                const [
                  TextSpan(
                    text:
                        'Your contacts, photo gallery, files, call logs, '
                        'messages or location, not even with your permission.',
                  ),
                ],
                icon: Icons.block,
                color: c.rose,
              ),
              Gap.s8,
              Note(
                tone: NoteTone.blue,
                spans: [
                  const TextSpan(text: 'Your data is stored in Pakistan '),
                  placeholderSpan(context, '[CONFIRM HOSTING]'),
                  const TextSpan(text: '.'),
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
              Gap.s16,
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
        icon: const AtomPayMark(size: 72),
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
        icon: const IconTile(
          Icons.build_outlined,
          tone: TileTone.amber,
          size: 72,
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
    return Scaffold(
      backgroundColor: context.colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Space.gutter),
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        icon,
                        Gap.s20,
                        Semantics(
                          header: true,
                          child: Text(
                            title,
                            style: t.h2,
                            textAlign: TextAlign.center,
                          ),
                        ),
                        Gap.s8,
                        Text(body, style: t.lead, textAlign: TextAlign.center),
                        if (badge != null) ...[Gap.s16, badge!],
                      ],
                    ),
                  ),
                ),
              ),
              for (var i = 0; i < actions.length; i++) ...[
                if (i > 0) Gap.s12,
                actions[i],
              ],
            ],
          ),
        ),
      ),
    );
  }
}
