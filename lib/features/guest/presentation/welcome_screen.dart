import 'package:atompay_mobile/core/network/api_client.dart';
import 'package:atompay_mobile/core/router/routes.dart';
import 'package:atompay_mobile/core/theme/tokens.dart';
import 'package:atompay_mobile/core/utils/money.dart';
import 'package:atompay_mobile/core/widgets/atom_logo.dart';
import 'package:atompay_mobile/core/widgets/buttons.dart';
import 'package:atompay_mobile/core/widgets/guest_tray.dart';
import 'package:atompay_mobile/core/widgets/ui.dart';
import 'package:atompay_mobile/features/account/presentation/settings_sheet.dart';
import 'package:atompay_mobile/features/auth/domain/auth_controller.dart';
import 'package:atompay_mobile/features/calculator/data/calculator_models.dart';
import 'package:atompay_mobile/features/launch/domain/launch_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// A sample plan for the calculator teaser, priced by the server exactly
/// like the website's homepage (PKR 100,000 over 6 months, minimum down
/// payment). Null when offline: the teaser then shows no figure.
final samplePlanProvider = FutureProvider.autoDispose<Quote?>((ref) async {
  final api = ref.watch(apiClientProvider);
  try {
    final config = CalculatorConfig.fromJson(
      (await api.get('/calculator') as Map).cast<String, dynamic>(),
    );
    final months = config.tenures.contains(6) ? 6 : config.tenures.first;
    final price = 100000.clamp(config.price.min, config.price.max);
    final data = await api.post(
      '/quote',
      data: {'price': price, 'months': months},
    );
    return Quote.fromJson((data as Map).cast<String, dynamic>());
  } on Object {
    return null;
  }
});

/// What a signed-out visitor sees: the website's homepage, section by
/// section, with sign-in / sign-up always in the bottom tray.
class WelcomeScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  final _howKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    // A 403 that ended the previous session (handbook §3.4).
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final auth = ref.read(authControllerProvider);
      if (auth case SignedOut(message: final m?) when m.isNotEmpty) {
        ref.read(authControllerProvider.notifier).clearMessage();
        if (!mounted) return;
        await showMessageDialog(
          context,
          title: context.l10n.signInBlockedTitle,
          message: m,
        );
      }
    });
  }

  void _scrollToHow() {
    final target = _howKey.currentContext;
    if (target != null) {
      Scrollable.ensureVisible(
        target,
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : Motion.medium,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final shopUrl = ref.watch(appConfigProvider).shopUrl;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: Space.gutter,
        title: Row(
          children: [
            const AtomLogo(size: 32),
            const SizedBox(width: Space.x8),
            Text(l10n.appTitle, style: context.text.title),
          ],
        ),
        actions: [
          IconButton(
            tooltip: l10n.settingsTitle,
            icon: const Icon(Icons.tune),
            onPressed: () => showSettingsSheet(context),
          ),
        ],
      ),
      bottomNavigationBar: const GuestTray(),
      body: ListView(
        padding: const EdgeInsets.only(bottom: Space.x40),
        children: [
          _Hero(
            onShop: () => openLink(context, Uri.parse(shopUrl)),
            onHow: _scrollToHow,
          ),
          const _Relation(),
          _How(key: _howKey),
          const _CalculatorTeaser(),
          const _Why(),
          const _Assess(),
          const _Faq(),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Space.gutter,
              Space.x24,
              Space.gutter,
              0,
            ),
            child: Text(
              l10n.guestFooter,
              textAlign: TextAlign.center,
              style: context.text.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

/// Eyebrow + title (+ optional text), like the website's `section-head`.
class _SectionHead extends StatelessWidget {
  const new({
    required this.eyebrow,
    required this.title,
    this.text,
    this.dark = false,
  });

  final String eyebrow;
  final String title;
  final String? text;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final styles = context.text;
    final muted = dark
        ? AppColors.white.withValues(alpha: 0.7)
        : context.tokens.muted;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eyebrow.toUpperCase(),
          style: styles.eyebrow.copyWith(color: muted),
        ),
        const SizedBox(height: Space.x8),
        Semantics(
          header: true,
          child: Text(
            title,
            style: styles.headline.copyWith(
              color: dark ? AppColors.white : null,
            ),
          ),
        ),
        if (text != null) ...[
          const SizedBox(height: Space.x8),
          Text(text!, style: styles.body.copyWith(color: muted)),
        ],
        const SizedBox(height: Space.x20),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const new({required this.child, this.tinted = false});

  final Widget child;

  /// White band with hairlines, like the site's alternating sections.
  final bool tinted;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tinted ? t.surface : null,
        border: tinted
            ? Border.symmetric(horizontal: BorderSide(color: t.line))
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Space.gutter,
          vertical: Space.x40,
        ),
        child: child,
      ),
    );
  }
}

class _Hero extends StatefulWidget {
  const new({required this.onShop, required this.onHow});

  final VoidCallback onShop;
  final VoidCallback onHow;

  @override
  State<_Hero> createState() => _HeroState();
}

class _HeroState extends State<_Hero> with SingleTickerProviderStateMixin {
  late final _orbit = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 12),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _orbit.stop();
    } else if (!_orbit.isAnimating) {
      _orbit.repeat();
    }
  }

  @override
  void dispose() {
    _orbit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = context.text;
    final t = context.tokens;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: t.line)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Space.gutter,
          Space.x16,
          Space.gutter,
          Space.x40,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: ExcludeSemantics(
                child: SizedBox(
                  height: 220,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      AnimatedBuilder(
                        animation: _orbit,
                        builder: (_, _) =>
                            AtomLogo(size: 200, orbit: _orbit.value),
                      ),
                      Container(
                        width: 128,
                        padding: const EdgeInsets.all(Space.x12),
                        decoration: BoxDecoration(
                          color: t.surface,
                          borderRadius: BorderRadius.circular(Radii.card),
                          border: Border.all(color: t.line),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              l10n.heroCardTitle,
                              textAlign: TextAlign.center,
                              style: text.label.copyWith(fontSize: 13),
                            ),
                            const SizedBox(height: Space.x4),
                            Text(
                              l10n.heroCardSubtitle.toUpperCase(),
                              textAlign: TextAlign.center,
                              style: text.eyebrow.copyWith(fontSize: 8.5),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: Space.x16),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: Space.x12,
                vertical: Space.x8,
              ),
              decoration: BoxDecoration(
                color: t.surface,
                borderRadius: BorderRadius.circular(Radii.pill),
                border: Border.all(color: t.line),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _Dot(color: t.ink),
                  const SizedBox(width: Space.x4),
                  const _Dot(gradient: AppColors.spectrum),
                  const SizedBox(width: Space.x8),
                  Text(
                    l10n.heroPill,
                    style: text.eyebrow.copyWith(color: t.ink),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Space.x20),
            Semantics(
              header: true,
              child: Text(
                l10n.heroTitle,
                style: text.display.copyWith(fontSize: 34),
              ),
            ),
            const SizedBox(height: Space.x16),
            Text(l10n.heroText, style: text.body),
            const SizedBox(height: Space.x24),
            PrimaryButton(label: l10n.browseAtomShop, onPressed: widget.onShop),
            const SizedBox(height: Space.x12),
            GhostButton(label: l10n.seeHowItWorks, onPressed: widget.onHow),
          ],
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const new({this.color, this.gradient});

  final Color? color;
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) => Container(
    width: 8,
    height: 8,
    decoration: BoxDecoration(
      color: color,
      gradient: gradient,
      shape: BoxShape.circle,
    ),
  );
}

class _Relation extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = context.text;
    return _Section(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionHead(
            eyebrow: l10n.relationEyebrow,
            title: l10n.relationTitle,
            text: l10n.relationText,
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(Space.x24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.relationShopTitle, style: text.title),
                  const SizedBox(height: Space.x8),
                  Text(l10n.relationShopText, style: text.bodySmall),
                ],
              ),
            ),
          ),
          const SizedBox(height: Space.x16),
          Container(
            padding: const EdgeInsets.all(Space.x24),
            decoration: BoxDecoration(
              color: context.tokens.nucleusCard,
              borderRadius: BorderRadius.circular(Radii.card),
              border: Border.all(color: context.tokens.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.relationPayTitle,
                  style: text.title.copyWith(color: AppColors.white),
                ),
                const SizedBox(height: Space.x8),
                Text(
                  l10n.relationPayText,
                  style: text.bodySmall.copyWith(
                    color: AppColors.white.withValues(alpha: 0.75),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _How extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = context.text;
    final steps = [
      (l10n.step1Title, l10n.step1Text),
      (l10n.step2Title, l10n.step2Text),
      (l10n.step3Title, l10n.step3Text),
      (l10n.step4Title, l10n.step4Text),
    ];
    return _Section(
      tinted: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionHead(eyebrow: l10n.howEyebrow, title: l10n.howTitle),
          for (final (i, (title, body)) in steps.indexed) ...[
            if (i > 0) const SizedBox(height: Space.x12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(Space.x20),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: context.tokens.nucleusCard,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${i + 1}',
                        style: text.label.copyWith(
                          color: AppColors.white,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(width: Space.x16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: text.label),
                          const SizedBox(height: Space.x4),
                          Text(body, style: text.bodySmall),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CalculatorTeaser extends ConsumerWidget {
  const new();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final text = context.text;
    final sample = ref.watch(samplePlanProvider).value;
    final dim = AppColors.white.withValues(alpha: 0.7);

    return _Section(
      child: Container(
        padding: const EdgeInsets.all(Space.x24),
        decoration: BoxDecoration(
          color: context.tokens.nucleusCard,
          borderRadius: BorderRadius.circular(Radii.darkCard),
          border: Border.all(color: context.tokens.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionHead(
              eyebrow: l10n.calcEyebrow,
              title: l10n.calcTitle,
              text: l10n.calcText,
              dark: true,
            ),
            if (sample != null) ...[
              Text(
                l10n.calcSample(pkr(sample.price), sample.months),
                style: text.bodySmall.copyWith(color: dim),
              ),
              const SizedBox(height: Space.x8),
              ShaderMask(
                shaderCallback: AppColors.spectrum.createShader,
                child: Text(
                  pkr(sample.monthly),
                  style: text.display.copyWith(color: AppColors.white),
                ),
              ),
              Text(
                l10n.estimatedPerMonth.toUpperCase(),
                style: text.eyebrow.copyWith(color: dim),
              ),
              const SizedBox(height: Space.x20),
            ],
            FilledButton(
              onPressed: () => context.push(Routes.calculator),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.white,
                foregroundColor: AppColors.nucleus,
                minimumSize: const Size.fromHeight(Sizes.buttonHeight),
                shape: const StadiumBorder(),
                textStyle: text.label,
              ),
              child: Text(l10n.openCalculator),
            ),
          ],
        ),
      ),
    );
  }
}

class _Why extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = context.text;
    final reasons = [
      (
        Icons.verified_user_outlined,
        AppColors.ok,
        l10n.why1Title,
        l10n.why1Text,
      ),
      (Icons.credit_card, AppColors.coral, l10n.why2Title, l10n.why2Text),
      (Icons.schedule, AppColors.violet, l10n.why3Title, l10n.why3Text),
    ];
    return _Section(
      tinted: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionHead(eyebrow: l10n.whyEyebrow, title: l10n.whyTitle),
          for (final (i, (icon, color, title, body)) in reasons.indexed) ...[
            if (i > 0) const SizedBox(height: Space.x12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(Space.x20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(icon, size: 19, color: color),
                    ),
                    const SizedBox(height: Space.x12),
                    Text(title, style: text.title),
                    const SizedBox(height: Space.x4),
                    Text(body, style: text.bodySmall),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Assess extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return _Section(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionHead(
            eyebrow: l10n.assessEyebrow,
            title: l10n.assessTitle,
            text: l10n.assessText,
          ),
          PrimaryButton(
            label: l10n.estimateMyLimit,
            onPressed: () => context.push(Routes.estimate),
          ),
        ],
      ),
    );
  }
}

class _Faq extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = context.text;
    final faqs = [
      (l10n.faq1Q, l10n.faq1A),
      (l10n.faq2Q, l10n.faq2A),
      (l10n.faq3Q, l10n.faq3A),
      (l10n.faq4Q, l10n.faq4A),
    ];
    return _Section(
      tinted: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionHead(eyebrow: l10n.faqEyebrow, title: l10n.faqTitle),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (final (i, (q, a)) in faqs.indexed) ...[
                  if (i > 0) const Divider(),
                  Theme(
                    // No extra dividers from ExpansionTile itself.
                    data: Theme.of(context)
                        .copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      title: Text(q, style: text.label),
                      childrenPadding: const EdgeInsets.fromLTRB(
                        Space.x16,
                        0,
                        Space.x16,
                        Space.x16,
                      ),
                      expandedAlignment: AlignmentDirectional.centerStart,
                      children: [Text(a, style: text.bodySmall)],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
