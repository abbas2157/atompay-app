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

/// Facts for About the business hasn't supplied (SECP Circular 15/2022).
abstract final class AboutPlaceholders {
  static const licence = '[LICENCE NO.]';
  static const address = '[REGISTERED ADDRESS]';
  static const dataLocation = '[CONFIRM]';
}

bool get _isIos => !kIsWeb && Platform.isIOS;

/// The logo, name and version block on About and Rate AtomPay.
class _AppIdentity extends ConsumerWidget {
  const new({this.tagline});

  final String? tagline;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.text;
    final version = versionLabel(ref.watch(packageInfoProvider));
    final line = [?tagline, version].join(' · ');
    return Semantics(
      container: true,
      label: 'AtomPay, $line',
      child: ExcludeSemantics(
        child: Column(
          children: [
            const AtomPayMark(size: 64),
            Gap.s12,
            Text('AtomPay', style: t.h2),
            Gap.s4,
            Text(line, style: t.small, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

/// About and legal (canvas "About and legal").
class AboutScreen extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final t = context.text;
    final config = ref.watch(appConfigProvider);
    return Scaffold(
      backgroundColor: c.surface,
      appBar: const AppTopBar(title: 'About and legal'),
      body: FormPage(
        children: [
          const _AppIdentity(tagline: 'Pay in steps'),
          Gap.s24,
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Who provides your credit', style: t.h4),
                Gap.s12,
                const KeyValueList([
                  KeyValue(
                    'Company',
                    KfsPlaceholders.lender,
                    placeholder: true,
                  ),
                  KeyValue(
                    'Licence',
                    'SECP · ${AboutPlaceholders.licence}',
                    placeholder: true,
                  ),
                  KeyValue(
                    'Address',
                    AboutPlaceholders.address,
                    placeholder: true,
                  ),
                ]),
                Gap.s16,
                Text('Your data', style: t.h4),
                Gap.s12,
                const KeyValueList([
                  KeyValue(
                    'Stored in',
                    'Pakistan',
                    pending: AboutPlaceholders.dataLocation,
                  ),
                ]),
              ],
            ),
          ),
          Gap.s16,
          ListGroup(
            title: 'Documents',
            children: [
              ListRow(
                title: 'Privacy policy',
                summary: Uri.tryParse(config.privacyUrl)?.host,
                icon: Icons.privacy_tip_outlined,
                tileTone: TileTone.grey,
                external: true,
                onTap: () => unawaited(Links.open(config.privacyUrl)),
              ),
              if (config.termsUrl case final terms?)
                ListRow(
                  title: 'Terms',
                  icon: Icons.gavel_outlined,
                  tileTone: TileTone.grey,
                  external: true,
                  onTap: () => unawaited(Links.open(terms)),
                ),
              ListRow(
                title: 'Key Fact Statements',
                summary: 'One for each order',
                icon: Icons.receipt_long_outlined,
                onTap: () => context.pushOnce(Routes.plans),
              ),
              ListRow(
                title: 'Open-source licences',
                summary: "Flutter's built-in licence list",
                icon: Icons.code,
                tileTone: TileTone.grey,
                onTap: () => showLicensePage(
                  context: context,
                  applicationName: 'AtomPay',
                ),
              ),
            ],
          ),
          Gap.s16,
          const SectionLabel('Permissions this app uses'),
          Text(
            'Camera, while you photograph your CNIC. Notifications, if you '
            'turn them on. Microphone, only if you ask Atom by voice. Nothing '
            'else: no contacts, gallery, files, location, calls or messages.',
            style: t.base,
          ),
          Gap.s16,
        ],
      ),
    );
  }
}

/// One app in the ecosystem.
@immutable
class _EcoApp {
  const new({
    required this.eyebrow,
    required this.name,
    required this.description,
    required this.links,
    this.webLabel,
    this.here = false,
  });

  final String eyebrow;
  final String name;
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
        eyebrow: 'For shoppers',
        name: 'Atomshop.pk',
        description:
            'The marketplace. The order, the delivery and the warranty all '
            'sit here.',
        links: apps.atomshop,
        webLabel: 'atomshop.pk',
      ),
      _EcoApp(
        eyebrow: 'For financing',
        name: 'AtomPay',
        description:
            'A verified spending limit for eligible products. Three months, '
            'no advance, 0% markup.',
        links: apps.atompay,
        here: true,
      ),
      _EcoApp(
        eyebrow: 'For local sellers',
        name: 'Atom Seller',
        description:
            'Leads, deals, deliveries and collections, run by a verified '
            'seller in your area.',
        links: apps.atomseller,
        webLabel: 'Smart Seller',
      ),
      _EcoApp(
        eyebrow: 'For brand partners',
        name: 'AtomBrand',
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
            'financing part: it never sells you anything itself.',
            style: t.lead,
          ),
          Gap.s16,
          for (final app in list) ...[
            AppCard(
              color: app.here ? c.apayWash : null,
              borderColor: app.here ? c.apayLine : null,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Eyebrow(app.eyebrow, atomPay: app.here)),
                      if (app.here) const AppBadge.rose('You are here'),
                    ],
                  ),
                  Gap.s6,
                  Semantics(header: true, child: Text(app.name, style: t.h3)),
                  Gap.s4,
                  Text(app.description, style: t.base),
                  Gap.s12,
                  Wrap(
                    spacing: Space.s8,
                    runSpacing: Space.s8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _StoreButton(
                        label: 'Google Play',
                        soon: 'Android soon',
                        url: app.links.android,
                        name: app.name,
                      ),
                      _StoreButton(
                        label: 'App Store',
                        soon: 'iOS soon',
                        url: app.links.ios,
                        name: app.name,
                      ),
                      if (app.webLabel != null && app.links.web != null)
                        TextLink(
                          app.webLabel!,
                          external: true,
                          onPressed: () => unawaited(Links.open(app.links.web)),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            Gap.s12,
          ],
          Text('Every link leaves AtomPay.', style: t.small),
        ],
      ),
    );
  }
}

class _StoreButton extends StatelessWidget {
  const new({
    required this.label,
    required this.soon,
    required this.url,
    required this.name,
  });

  final String label;
  final String soon;
  final String? url;
  final String name;

  @override
  Widget build(BuildContext context) => AppButton.ghost(
    url == null ? soon : label,
    trailingIcon: url == null ? null : Icons.north_east,
    semanticLabel: url == null
        ? '$name, $soon'
        : '$name on $label, opens outside the app',
    onPressed: url == null ? null : () => unawaited(Links.open(url)),
  );
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
    final store = _isIos ? 'the App Store' : 'Google Play';
    return Scaffold(
      backgroundColor: c.surface,
      appBar: const AppTopBar(title: 'Rate AtomPay'),
      body: FormPage(
        footer: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppButton.primary(
              'Rate on $store',
              large: true,
              block: true,
              trailingIcon: Icons.north_east,
              onPressed: () => unawaited(_rate(atompay)),
            ),
            Gap.s8,
            AppButton.ghost(
              'Send us feedback',
              block: true,
              onPressed: () => context.pushOnce(Routes.help),
            ),
          ],
        ),
        children: [
          Gap.s16,
          const _AppIdentity(tagline: 'Pay in steps'),
          Gap.s16,
          // Decoration, not an input.
          ExcludeSemantics(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < 5; i++)
                  Icon(Icons.star_rounded, size: 28, color: c.amber),
              ],
            ),
          ),
          Gap.s20,
          Semantics(
            header: true,
            child: Text(
              'Tell others what you think',
              style: t.h3,
              textAlign: TextAlign.center,
            ),
          ),
          Gap.s8,
          Text(
            'A review on $store helps other shoppers decide whether AtomPay '
            "is right for them. Good or bad, it's your honest view we want.",
            style: t.lead,
            textAlign: TextAlign.center,
          ),
          Gap.s16,
          Text(
            _isIos
                ? 'Opens the App Store. Reviews are public and go to Apple, '
                      'not to your AtomPay account.'
                : 'Opens the Play Store. Reviews are public and go to Google, '
                      'not to your AtomPay account.',
            style: t.small,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
