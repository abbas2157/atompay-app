import 'dart:io';

import 'package:atompay_mobile/core/config/device.dart';
import 'package:atompay_mobile/core/format/money.dart';
import 'package:atompay_mobile/core/router/navigation.dart';
import 'package:atompay_mobile/core/router/routes.dart';
import 'package:atompay_mobile/core/theme/tokens.dart';
import 'package:atompay_mobile/core/widgets/brand.dart';
import 'package:atompay_mobile/core/widgets/buttons.dart';
import 'package:atompay_mobile/core/widgets/form_parts.dart';
import 'package:atompay_mobile/core/widgets/ui.dart';
import 'package:atompay_mobile/features/account/application/account_controllers.dart';
import 'package:atompay_mobile/features/application/application/apply_controller.dart';
import 'package:atompay_mobile/features/application/data/application_models.dart';
import 'package:atompay_mobile/features/auth/application/session_controller.dart';
import 'package:atompay_mobile/features/auth/data/auth_models.dart';
import 'package:atompay_mobile/features/home/application/home_controller.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The Account tab (canvas "Account"): profile, Your AtomPay, Settings,
/// Help, ecosystem, Rate AtomPay, About, and the app's version.
class AccountScreen extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final t = context.text;
    final user = ref.watch(currentUserProvider);
    final city = ref.watch(profileProvider).value?.city?.name;
    final limit = ref.watch(dashboardProvider).value?.data.limit;
    final history = ref.watch(applicationHistoryProvider).value;
    final info = ref.watch(packageInfoProvider);
    final ios = !kIsWeb && Platform.isIOS;

    return Scaffold(
      backgroundColor: c.surface,
      appBar: AppTopBar(
        title: 'Account',
        leading: null,
        actions: [
          AppIconButton(
            icon: Icons.settings_outlined,
            label: 'Settings',
            onPressed: () => context.pushOnce(Routes.settings),
          ),
        ],
      ),
      body: FormPage(
        children: [
          if (user != null) ...[
            _ProfileCard(user: user, city: city),
            const SizedBox(height: Space.s18),
          ],
          ListGroup(
            title: 'Your AtomPay',
            children: [
              ListRow(
                title: 'KYC & verification',
                summary: _kycSummary(user?.kycStatus),
                icon: Icons.verified_user_outlined,
                tileTone: TileTone.green,
                onTap: () => context.pushOnce(Routes.applicationStatus),
              ),
              ListRow(
                title: 'My applications',
                summary: _historySummary(history),
                icon: Icons.description_outlined,
                onTap: () => context.pushOnce(Routes.applicationHistory),
              ),
              if (limit != null && limit.hasLimit)
                ListRow(
                  title: 'Request a limit review',
                  summary:
                      'Earning more? Your ${rs(limit.approved)} stays '
                      'active meanwhile',
                  icon: Icons.edit_outlined,
                  tileTone: TileTone.wash,
                  onTap: () => context.pushOnce(Routes.applicationStep(3)),
                ),
              ListRow(
                title: 'Estimate a plan',
                summary: 'Any price, three months',
                icon: Icons.calculate_outlined,
                onTap: () => context.pushOnce(Routes.calculator),
              ),
            ],
          ),
          const SizedBox(height: Space.s18),
          ListGroup(
            children: [
              ListRow(
                title: 'Settings',
                summary: 'Security, sessions, permissions, privacy, sign out',
                icon: Icons.settings_outlined,
                onTap: () => context.pushOnce(Routes.settings),
              ),
            ],
          ),
          const SizedBox(height: Space.s18),
          ListGroup(
            title: 'Help',
            children: [
              ListRow(
                title: 'Help and Ask Atom',
                icon: Icons.help_outline,
                tileTone: TileTone.wash,
                onTap: () => context.pushOnce(Routes.help),
              ),
              ListRow(
                title: 'Our ecosystem',
                summary: 'Atomshop, AtomPay, Atom Seller, AtomBrand',
                icon: Icons.hub_outlined,
                tileTone: TileTone.grey,
                onTap: () => context.pushOnce(Routes.ecosystem),
              ),
              ListRow(
                title: 'Raise a complaint',
                summary: 'A person reads every one',
                icon: Icons.feedback_outlined,
                tileTone: TileTone.grey,
                onTap: () => context.pushOnce(Routes.complaint),
              ),
              ListRow(
                title: 'Rate AtomPay',
                summary: ios
                    ? 'Leave a review on the App Store'
                    : 'Leave a review on Google Play',
                icon: Icons.star_outline,
                tileTone: TileTone.grey,
                onTap: () => context.pushOnce(Routes.rate),
              ),
              ListRow(
                title: 'About, privacy and legal',
                summary: 'Licence, policies, Key Fact Statements',
                icon: Icons.info_outline,
                tileTone: TileTone.grey,
                onTap: () => context.pushOnce(Routes.about),
              ),
            ],
          ),
          const SizedBox(height: Space.s18 + Space.s6),
          Center(
            child: Semantics(
              container: true,
              label: 'AtomPay, ${versionLabel(info)}',
              child: ExcludeSemantics(
                child: Column(
                  children: [
                    const AtomPayMark(),
                    Gap.s6,
                    Text(
                      'AtomPay',
                      style: t.base.copyWith(
                        color: c.ink,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Gap.s6,
                    Text(versionLabel(info), style: t.tiny),
                  ],
                ),
              ),
            ),
          ),
          Gap.s16,
        ],
      ),
    );
  }

  static String _kycSummary(String? status) => switch (status) {
    'verified' => 'Identity and address verified',
    'pending' => 'Under review',
    'rejected' => 'Needs attention',
    _ => 'Not started',
  };

  /// "1 approved · 1 under review", from the server's own labels.
  static String _historySummary(List<Assessment>? history) {
    if (history == null) return 'Your applications and decisions';
    if (history.isEmpty) return 'None yet';
    final counts = <String, int>{};
    for (final a in history) {
      final label = (a.statusLabel ?? a.status).toLowerCase();
      counts[label] = (counts[label] ?? 0) + 1;
    }
    return counts.entries.map((e) => '${e.value} ${e.key}').join(' · ');
  }
}

class _ProfileCard extends StatelessWidget {
  const new({required this.user, this.city});

  final User user;
  final String? city;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final line = [?user.phoneFormatted ?? user.phone, ?city].join(' · ');
    final badge = switch (user.kycStatus) {
      'verified' => const AppBadge.green('Verified'),
      'pending' => const AppBadge.amber('Under review'),
      'rejected' => const AppBadge.rose('Needs attention'),
      _ => null,
    };
    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: Space.s18,
        vertical: Space.s16,
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: c.primarySoft,
              shape: BoxShape.circle,
            ),
            child: ExcludeSemantics(
              child: Text(
                user.initials,
                style: t.h4.copyWith(color: c.primary),
              ),
            ),
          ),
          const SizedBox(width: Space.s14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.name,
                  style: t.h4.copyWith(fontWeight: FontWeight.w700),
                ),
                if (line.isNotEmpty) Text(line, style: t.small),
              ],
            ),
          ),
          if (badge != null) ...[const SizedBox(width: Space.s12), badge],
        ],
      ),
    );
  }
}
