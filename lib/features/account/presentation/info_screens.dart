import 'dart:async';
import 'dart:io';

import 'package:atompay_mobile/core/config/device.dart';
import 'package:atompay_mobile/core/router/navigation.dart';
import 'package:atompay_mobile/core/router/routes.dart';
import 'package:atompay_mobile/core/theme/tokens.dart';
import 'package:atompay_mobile/core/utils/links.dart';
import 'package:atompay_mobile/core/widgets/brand.dart';
import 'package:atompay_mobile/core/widgets/buttons.dart';
import 'package:atompay_mobile/core/widgets/form_parts.dart';
import 'package:atompay_mobile/core/widgets/pressable.dart';
import 'package:atompay_mobile/core/widgets/states.dart';
import 'package:atompay_mobile/core/widgets/ui.dart';
import 'package:atompay_mobile/features/account/application/account_controllers.dart';
import 'package:atompay_mobile/features/launch/application/launch_controller.dart';
import 'package:atompay_mobile/features/launch/data/app_config.dart';
import 'package:atompay_mobile/features/plans/presentation/kfs_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_review/in_app_review.dart';

/// Shown in rose while `/app-config.business` lacks a fact. The facts are
/// set in Atomshop's admin panel.
abstract final class AboutPlaceholders {
  static const address = '[REGISTERED ADDRESS]';
  static const dataLocation = '[CONFIRM]';
}

bool get _isIos => !kIsWeb && Platform.isIOS;

/// About and legal (canvas "About and legal").
class AboutScreen extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final t = context.text;
    final config = ref.watch(appConfigProvider);
    final version = versionLabel(ref.watch(packageInfoProvider));
    final privacy = Uri.tryParse(config.privacyUrl);
    return Scaffold(
      backgroundColor: c.surface,
      appBar: const AppTopBar(title: 'About and legal'),
      body: FormPage(
        children: [
          // Canvas: a card with the mark, name and version in a row.
          Semantics(
            container: true,
            label: 'AtomPay, $version, Pay in steps',
            child: ExcludeSemantics(
              child: AppCard(
                padding: const EdgeInsets.all(Space.s18),
                child: Row(
                  children: [
                    const AtomPayMark(size: 52),
                    const SizedBox(width: Space.s14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'AtomPay',
                            style: t.h4.copyWith(fontWeight: FontWeight.w700),
                          ),
                          Text('$version · Pay in steps', style: t.small),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: Space.s18),
          const SectionLabel('Who offers your instalments'),
          AppCard(
            padding: const EdgeInsets.symmetric(
              horizontal: Space.s18,
              vertical: Space.s16,
            ),
            child: _FactList([
              _Fact(
                'Company',
                known: config.business.companyName,
                tbd: KfsPlaceholders.company,
              ),
              _Fact(
                'Address',
                known: config.business.registeredAddress,
                tbd: AboutPlaceholders.address,
              ),
              switch (config.business.dataHosting) {
                final where? => _Fact('Your data', known: 'Stored in $where'),
                null => const _Fact(
                  'Your data',
                  value: 'Stored in Pakistan ',
                  tbd: AboutPlaceholders.dataLocation,
                ),
              },
            ]),
          ),
          const SizedBox(height: Space.s18),
          ListGroup(
            title: 'Documents',
            children: [
              ListRow(
                title: 'Privacy policy',
                summary: privacy == null || privacy.host.isEmpty
                    ? null
                    : '${privacy.host}${privacy.path}',
                external: true,
                onTap: () => unawaited(Links.open(config.privacyUrl)),
              ),
              // Brief §6: hidden while app-config.terms_url is null.
              if (config.termsUrl case final terms?)
                ListRow(
                  title: 'Terms',
                  external: true,
                  onTap: () => unawaited(Links.open(terms)),
                ),
              ListRow(
                title: 'Key Fact Statements',
                summary: 'One for each order',
                onTap: () => context.pushOnce(Routes.plans),
              ),
              ListRow(
                title: 'Open-source licences',
                summary: "Flutter's built-in licence list",
                onTap: () => showLicensePage(
                  context: context,
                  applicationName: 'AtomPay',
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.s18),
          const SectionLabel('Permissions this app uses'),
          AppCard(
            padding: const EdgeInsets.symmetric(
              horizontal: Space.s18,
              vertical: Space.s16,
            ),
            child: Text(
              'Camera, while you photograph your CNIC. Notifications, if you '
              'turn them on. Microphone, only if you ask Atom by voice. '
              'Nothing else — no contacts, gallery, files, location, calls or '
              'messages.',
              style: t.small.copyWith(color: c.body),
            ),
          ),
          Gap.s16,
        ],
      ),
    );
  }
}

/// One About fact: an optional lead-in ([value]) in ink, then the fact
/// from the server ([known]) in ink, or its placeholder ([tbd]) in rose
/// while the server doesn't send it ("Stored in Pakistan [CONFIRM]").
@immutable
class _Fact {
  const new(this.label, {this.tbd = '', this.value, this.known});

  final String label;
  final String? value;
  final String? known;
  final String tbd;
}

/// Canvas `.kv` with inline placeholders. The label keeps its width; the
/// value takes the rest, right-aligned, and wraps at large text.
class _FactList extends StatelessWidget {
  const new(this.facts);

  final List<_Fact> facts;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    return Column(
      children: [
        for (var i = 0; i < facts.length; i++)
          MergeSemantics(
            child: Container(
              padding: EdgeInsets.only(
                top: i == 0 ? 0 : Space.s10 + 1,
                bottom: i == facts.length - 1 ? 0 : Space.s10 + 1,
              ),
              decoration: BoxDecoration(
                border: i == 0 ? null : Border(top: BorderSide(color: c.line)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    facts[i].label.toUpperCase(),
                    style: t.tiny.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(width: Space.s16),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        style: t.base.copyWith(
                          color: c.ink,
                          fontWeight: FontWeight.w700,
                        ),
                        children: [
                          if (facts[i].value case final v?) TextSpan(text: v),
                          if (facts[i].known case final k?)
                            TextSpan(text: k)
                          else
                            placeholderSpan(context, facts[i].tbd),
                        ],
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// One app in the ecosystem.
@immutable
class _EcoApp {
  const new({
    required this.role,
    required this.name,
    required this.icon,
    required this.description,
    required this.links,
    this.webLabel,
    this.here = false,
  });

  final String role;
  final String name;
  final String icon;
  final String description;
  final AppLinks links;
  final String? webLabel;
  final bool here;
}

/// Our ecosystem (canvas "Our ecosystem"). Every link leaves AtomPay; a
/// missing store link shows "soon" instead of linking nowhere.
class EcosystemScreen extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final t = context.text;
    final apps = ref.watch(appConfigProvider).apps;
    final list = [
      _EcoApp(
        role: 'For shoppers',
        name: 'Atomshop.pk',
        icon: BrandAssets.atomshop,
        description:
            'The marketplace. The order, the delivery and the warranty all '
            'sit here.',
        links: apps.atomshop,
        webLabel: 'atomshop.pk',
      ),
      _EcoApp(
        role: 'For financing',
        name: 'AtomPay',
        icon: BrandAssets.mark,
        description:
            'A verified spending limit for eligible products. Three months, '
            'no advance, 0% markup.',
        links: apps.atompay,
        here: true,
      ),
      _EcoApp(
        role: 'For local sellers',
        name: 'Atom Seller',
        icon: BrandAssets.atomseller,
        description:
            'Leads, deals, deliveries and collections, run by a verified '
            'seller in your area.',
        links: apps.atomseller,
        webLabel: 'Smart Seller',
      ),
      _EcoApp(
        role: 'For brand partners',
        name: 'AtomBrand',
        icon: BrandAssets.atombrand,
        description:
            "A brand's own storefront and stock on Atomshop, with each order "
            'handed to a seller.',
        links: apps.atombrand,
        webLabel: 'Brand Partners',
      ),
    ];

    return Scaffold(
      backgroundColor: c.surface,
      appBar: const AppTopBar(title: 'Our ecosystem'),
      body: FormPage(
        children: [
          Text(
            'Four products, one marketplace and one account. AtomPay is the '
            'financing part — it never sells you anything itself.',
            style: t.small,
          ),
          for (final app in list) ...[
            Gap.s14,
            AppCard(
              padding: const EdgeInsets.all(Space.s18),
              color: app.here ? c.apayWash : null,
              borderColor: app.here ? c.apayLine : null,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(Radii.note),
                    child: Image.asset(
                      app.icon,
                      width: Sizes.target,
                      height: Sizes.target,
                      excludeFromSemantics: true,
                    ),
                  ),
                  const SizedBox(width: Space.s14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          app.role.toUpperCase(),
                          style: t.tiny.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1,
                          ),
                        ),
                        Gap.s4,
                        Semantics(
                          header: true,
                          child: Text(
                            app.name,
                            style: t.h4.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        Gap.s4,
                        Text(
                          app.description,
                          style: t.small.copyWith(
                            color: c.body,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Gap.s12,
                        Wrap(
                          spacing: Space.s8,
                          runSpacing: Space.s8,
                          children: [
                            if (app.here) const _StoreChip.here(),
                            _StoreChip(
                              label: 'Google Play',
                              soon: 'Android soon',
                              icon: Icons.play_arrow_rounded,
                              url: app.links.android,
                              name: app.name,
                            ),
                            _StoreChip(
                              label: 'App Store',
                              soon: 'iOS soon',
                              icon: Icons.apple,
                              url: app.links.ios,
                              name: app.name,
                            ),
                            if (app.webLabel case final web?)
                              if (app.links.web case final url?)
                                _StoreChip.web(label: web, url: url),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          Gap.s14,
          Text(
            'Every link leaves AtomPay.',
            style: t.tiny.copyWith(height: 1.5),
            textAlign: TextAlign.center,
          ),
          Gap.s16,
        ],
      ),
    );
  }
}

enum _ChipKind { store, here, web }

/// Canvas `.stores a` / `span`: a 48 dp pill with a 16 px icon and a
/// 13 px label. A store without a link shows "soon" and isn't a control.
class _StoreChip extends StatelessWidget {
  const new({
    required this.label,
    required this.soon,
    required IconData this.icon,
    required this.url,
    required this.name,
  }) : kind = _ChipKind.store;

  const new here()
    : label = 'You are here',
      soon = '',
      icon = null,
      url = null,
      name = 'AtomPay',
      kind = _ChipKind.here;

  const new web({required this.label, required String this.url})
    : soon = '',
      icon = Icons.language,
      name = label,
      kind = _ChipKind.web;

  final String label;
  final String soon;
  final IconData? icon;
  final String? url;
  final String name;
  final _ChipKind kind;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final link = url;
    final live = kind != _ChipKind.here && link != null;
    final (Color bg, Color fg, Color border) = switch (kind) {
      _ChipKind.here => (c.amberSoft, c.amberInk, c.amber),
      _ChipKind.web => (Colors.transparent, c.primary, Colors.transparent),
      _ChipKind.store when live => (c.white, c.ink, c.line2),
      _ChipKind.store => (c.surface, c.muted, c.line2),
    };
    final chip = Container(
      constraints: const BoxConstraints(minHeight: Sizes.target),
      padding: EdgeInsets.symmetric(
        horizontal: kind == _ChipKind.web ? Space.s6 : Space.s14,
        vertical: Space.s6,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(Radii.pill),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: fg),
            const SizedBox(width: Space.s6),
          ],
          Flexible(
            child: Text(
              kind == _ChipKind.store && !live ? soon : label,
              style: t.small.copyWith(color: fg, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
    if (!live) {
      return Semantics(
        label: kind == _ChipKind.here ? label : '$name, $soon',
        excludeSemantics: true,
        child: chip,
      );
    }
    return Pressable(
      onTap: () => unawaited(Links.open(link)),
      scaleOnPress: false,
      pressedColor: c.primarySoft,
      semanticLabel: kind == _ChipKind.web
          ? '$label website, opens outside the app'
          : '$name on $label, opens outside the app',
      excludeChildSemantics: true,
      child: chip,
    );
  }
}

/// Rate AtomPay (canvas "Rate AtomPay"). An honest ask: both buttons for
/// everyone, no "do you like us?" gate, no stars as input, no reward.
class RateUsScreen extends ConsumerWidget {
  const new({super.key});

  Future<void> _rate(AppLinks atompay) async {
    if (_isIos) {
      final ios = atompay.ios;
      if (ios == null) {
        showToast("The App Store page isn't ready yet.", error: true);
        return;
      }
      final join = ios.contains('?') ? '&' : '?';
      await Links.open('$ios${join}action=write-review');
      return;
    }
    try {
      // Never requestReview() from a button (store rules).
      await InAppReview.instance.openStoreListing();
    } on Object {
      await Links.open(atompay.android);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final t = context.text;
    final atompay = ref.watch(appConfigProvider).apps.atompay;
    final version = versionLabel(ref.watch(packageInfoProvider));
    final store = _isIos ? 'the App Store' : 'Google Play';
    const pad = EdgeInsets.fromLTRB(
      Space.gutter,
      Space.s8,
      Space.gutter,
      Space.s32,
    );
    return Scaffold(
      backgroundColor: c.white,
      appBar: const AppTopBar(
        title: 'Rate AtomPay',
        white: true,
        bottomBorder: false,
      ),
      body: SafeArea(
        top: false,
        // The ask at the top, the buttons at the bottom (canvas
        // `margin-top:auto`); it scrolls when large text needs the room.
        child: LayoutBuilder(
          builder: (context, box) => SingleChildScrollView(
            padding: pad,
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 560,
                  minHeight: box.maxHeight > pad.vertical
                      ? box.maxHeight - pad.vertical
                      : 0,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Gap.s12,
                        Semantics(
                          container: true,
                          label: 'AtomPay, Pay in steps, $version',
                          child: ExcludeSemantics(
                            child: Column(
                              children: [
                                DecoratedBox(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(
                                      Radii.card,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: c.ink.withValues(alpha: 0.1),
                                        blurRadius: 40,
                                        offset: const Offset(0, 16),
                                      ),
                                    ],
                                  ),
                                  child: const AtomPayMark(size: 88),
                                ),
                                Gap.s10,
                                Text(
                                  'AtomPay',
                                  style: t.h3.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  'Pay in steps · $version',
                                  style: t.tiny,
                                  textAlign: TextAlign.center,
                                ),
                                Gap.s10,
                                // Decoration, not an input.
                                Wrap(
                                  spacing: Space.s6,
                                  children: [
                                    for (var i = 0; i < 5; i++)
                                      Icon(
                                        Icons.star_rounded,
                                        size: 26,
                                        color: c.amber,
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: Space.s22),
                        Semantics(
                          header: true,
                          child: Text(
                            'Tell others what you think',
                            style: t.h2,
                            textAlign: TextAlign.center,
                          ),
                        ),
                        Gap.s8,
                        Text(
                          'A review on $store helps other shoppers decide '
                          'whether AtomPay is right for them. Good or bad, '
                          "it's your honest view we want.",
                          style: t.lead,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: Space.s22),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AppButton.primary(
                          'Rate on $store',
                          large: true,
                          block: true,
                          trailingIcon: Icons.north_east,
                          onPressed: () => unawaited(_rate(atompay)),
                        ),
                        Gap.s10,
                        AppButton.ghost(
                          'Send us feedback',
                          block: true,
                          onPressed: () => context.pushOnce(Routes.help),
                        ),
                        Gap.s10,
                        Text(
                          _isIos
                              ? 'Opens the App Store. Reviews are public and '
                                    'go to Apple, not to your AtomPay account.'
                              : 'Opens the Play Store. Reviews are public and '
                                    'go to Google, not to your AtomPay '
                                    'account.',
                          style: t.tiny.copyWith(height: 1.5),
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
    );
  }
}
