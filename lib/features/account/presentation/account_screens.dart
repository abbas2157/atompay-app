import 'package:atompay_mobile/core/forms/submit_section.dart';
import 'package:atompay_mobile/core/forms/validators.dart';
import 'package:atompay_mobile/core/network/api_exception.dart';
import 'package:atompay_mobile/core/router/routes.dart';
import 'package:atompay_mobile/core/theme/tokens.dart';
import 'package:atompay_mobile/core/utils/dates.dart';
import 'package:atompay_mobile/core/widgets/app_text_field.dart';
import 'package:atompay_mobile/core/widgets/buttons.dart';
import 'package:atompay_mobile/core/widgets/states.dart';
import 'package:atompay_mobile/core/widgets/ui.dart';
import 'package:atompay_mobile/features/account/domain/account_controllers.dart';
import 'package:atompay_mobile/features/account/presentation/settings_sheet.dart';
import 'package:atompay_mobile/features/auth/data/auth_models.dart';
import 'package:atompay_mobile/features/auth/domain/auth_controller.dart';
import 'package:atompay_mobile/features/launch/domain/launch_controller.dart';
import 'package:atompay_mobile/features/profile/presentation/profile_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Handbook §5.12.
class AccountScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen> {
  bool _signingOut = false;

  Future<void> _signOut({required bool everywhere}) async {
    final l10n = context.l10n;
    final go = await confirmDialog(
      context,
      title: l10n.signOutTitle,
      message: everywhere ? l10n.signOutEverywhereText : null,
      confirmLabel: everywhere ? l10n.signOutEverywhere : l10n.signOut,
      destructive: true,
    );
    if (!go || !mounted) return;
    setState(() => _signingOut = true);
    final auth = ref.read(authControllerProvider.notifier);
    try {
      if (everywhere) {
        await auth.signOutEverywhere();
      } else {
        await auth.signOut();
      }
    } on ApiException catch (e) {
      showToast(apiErrorText(l10n, e));
      if (mounted) setState(() => _signingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final auth = ref.watch(authControllerProvider);
    final config = ref.watch(appConfigProvider);
    final user = auth is SignedIn ? auth.user : null;
    if (user == null) return const Scaffold();

    final support = config.support;
    final hasSupport =
        support.phone != null ||
        support.whatsapp != null ||
        support.email != null;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.accountTitle)),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: Space.x8),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                InfoRow(label: l10n.nameLabel, value: user.name),
                if (user.email case final email?)
                  InfoRow(label: l10n.emailLabel, value: email),
                if (user.phoneFormatted case final phone?)
                  InfoRow(label: l10n.phoneLabel, value: phone),
                if (Dates.parseDate(user.memberSince) case final since?)
                  InfoRow(
                    label: l10n.memberSinceLabel,
                    value: Dates.short(since),
                  ),
                Text(l10n.changeOnAtomShop, style: context.text.bodySmall),
              ],
            ),
          ),
          const SizedBox(height: Space.x16),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.tune),
            title: Text(l10n.settingsTitle),
            subtitle: Text(l10n.settingsSubtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => showSettingsSheet(context),
          ),
          ListTile(
            leading: const Icon(Icons.devices_outlined),
            title: Text(l10n.devicesTitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(Routes.accountDevices),
          ),
          // Mobile-only accounts get no email at all (handbook §8.6).
          if (user.email != null)
            ListTile(
              leading: const Icon(Icons.notifications_outlined),
              title: Text(l10n.notificationSettingsTitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(Routes.accountNotifications),
            ),
          ListTile(
            leading: const Icon(Icons.lock_reset),
            title: Text(l10n.changePassword),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(
              Routes.forgot,
              extra: user.email ?? user.phoneFormatted,
            ),
          ),
          if (hasSupport) ...[
            const Divider(),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Space.gutter,
                Space.x16,
                Space.gutter,
                Space.x4,
              ),
              child: Text(
                l10n.supportTitle.toUpperCase(),
                style: context.text.eyebrow,
              ),
            ),
            if (support.phone case final phone?)
              ListTile(
                leading: const Icon(Icons.call_outlined),
                title: Text(l10n.supportPhone),
                subtitle: Text(phone),
                onTap: () => openLink(context, Uri(scheme: 'tel', path: phone)),
              ),
            if (support.whatsapp case final wa?)
              ListTile(
                leading: const Icon(Icons.chat_outlined),
                title: Text(l10n.supportWhatsapp),
                subtitle: Text(wa),
                onTap: () => openLink(
                  context,
                  Uri.https('wa.me', '/${wa.replaceAll(RegExp(r'\D'), '')}'),
                ),
              ),
            if (support.email case final email?)
              ListTile(
                leading: const Icon(Icons.mail_outline),
                title: Text(l10n.supportEmail),
                subtitle: Text(email),
                onTap: () =>
                    openLink(context, Uri(scheme: 'mailto', path: email)),
              ),
          ],
          const Divider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Space.gutter,
              Space.x16,
              Space.gutter,
              Space.x4,
            ),
            child: Text(
              l10n.legalTitle.toUpperCase(),
              style: context.text.eyebrow,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: Text(l10n.privacyPolicy),
            trailing: const Icon(Icons.open_in_new),
            onTap: () => openLink(context, Uri.parse(config.privacyUrl)),
          ),
          if (config.termsUrl case final terms?)
            ListTile(
              leading: const Icon(Icons.description_outlined),
              title: Text(l10n.termsOfUse),
              trailing: const Icon(Icons.open_in_new),
              onTap: () => openLink(context, Uri.parse(terms)),
            ),
          ListTile(
            leading: const Icon(Icons.person_remove_outlined),
            iconColor: AppColors.coral,
            textColor: AppColors.coral,
            title: Text(l10n.deleteAccount),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(Routes.accountDelete),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(Space.gutter),
            child: Column(
              children: [
                GhostButton(
                  label: l10n.signOut,
                  loading: _signingOut,
                  onPressed: () => _signOut(everywhere: false),
                ),
                const SizedBox(height: Space.x12),
                DestructiveButton(
                  label: l10n.signOutEverywhere,
                  onPressed: _signingOut
                      ? null
                      : () => _signOut(everywhere: true),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// `GET /auth/sessions` with per-device sign-out.
class DevicesScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends ConsumerState<DevicesScreen> {
  int? _revoking;

  Future<void> _revoke(DeviceSession s) async {
    final l10n = context.l10n;
    final name = s.deviceName ?? l10n.unnamedDevice;
    final go = await confirmDialog(
      context,
      title: l10n.signOutDeviceTitle,
      message: l10n.signOutDeviceText(name),
      confirmLabel: l10n.signOut,
      destructive: true,
    );
    if (!go || !mounted) return;
    setState(() => _revoking = s.id);
    try {
      await revokeSession(ref, s);
    } on ApiException catch (e) {
      showToast(apiErrorText(l10n, e));
      ref.invalidate(sessionsProvider);
    } finally {
      if (mounted) setState(() => _revoking = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final sessions = ref.watch(sessionsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.devicesTitle)),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(sessionsProvider.future),
        child: switch (sessions) {
          AsyncData(:final value) when value.isEmpty => ListView(
            children: [MessageView(message: l10n.noDevices)],
          ),
          AsyncData(:final value) => ListView.separated(
            itemCount: value.length,
            separatorBuilder: (_, _) => const Divider(),
            itemBuilder: (context, i) {
              final s = value[i];
              final used = s.lastUsedAt ?? s.signedInAt;
              return ListTile(
                leading: Icon(
                  s.current ? Icons.smartphone : Icons.devices_other_outlined,
                ),
                title: Text(s.deviceName ?? l10n.unnamedDevice),
                subtitle: Text(
                  s.current
                      ? l10n.thisDevice
                      : l10n.lastUsed(Dates.short(used)),
                ),
                trailing: _revoking == s.id
                    ? const SizedBox.square(
                        dimension: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : TextButton(
                        onPressed: _revoking == null ? () => _revoke(s) : null,
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.coral,
                        ),
                        child: Text(l10n.signOut),
                      ),
              );
            },
          ),
          AsyncError(:final error) => ListView(
            children: [
              MessageView(
                message: error is ApiException
                    ? apiErrorText(l10n, error)
                    : l10n.genericError,
                actionLabel: l10n.tryAgain,
                onAction: () => ref.invalidate(sessionsProvider),
              ),
            ],
          ),
          _ => const Center(child: CircularProgressIndicator()),
        },
      ),
    );
  }
}

/// Email alerts switch. Push on/off arrives with push in Phase 4.
class NotificationSettingsScreen extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final alerts = ref.watch(emailAlertsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.notificationSettingsTitle)),
      body: switch (alerts) {
        AsyncError(:final error) when !alerts.hasValue => MessageView(
          message: error is ApiException
              ? apiErrorText(l10n, error)
              : l10n.genericError,
          actionLabel: l10n.tryAgain,
          onAction: () => ref.invalidate(emailAlertsProvider),
        ),
        AsyncValue(:final value?) => ListView(
          children: [
            SwitchListTile(
              title: Text(l10n.emailAlerts),
              subtitle: Text(l10n.emailAlertsHelp),
              value: value,
              onChanged: (v) async {
                try {
                  await ref.read(emailAlertsProvider.notifier).set(enabled: v);
                } on ApiException catch (e) {
                  showToast(apiErrorText(l10n, e));
                }
              },
            ),
          ],
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

/// In-app account deletion (App Store 5.1.1(v), Google Play account
/// deletion policy). The password confirms it's the owner holding the phone.
class DeleteAccountScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<DeleteAccountScreen> createState() =>
      _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends ConsumerState<DeleteAccountScreen> {
  final _password = TextEditingController();
  String? _local;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = context.l10n;
    setState(() => _local = Validators(l10n).required(_password.text));
    if (_local != null) return;
    FocusScope.of(context).unfocus();
    final go = await confirmDialog(
      context,
      title: l10n.deleteAccountConfirmTitle,
      message: l10n.deleteAccountConfirmText,
      confirmLabel: l10n.deleteAccountButton,
      destructive: true,
    );
    if (!go || !mounted) return;
    final ok = await ref
        .read(deleteAccountControllerProvider.notifier)
        .delete(_password.text);
    // The router leaves this screen once signed out.
    if (ok) showToast(l10n.accountDeletedToast);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = context.text;
    final status = ref.watch(deleteAccountControllerProvider);
    final controller = ref.read(deleteAccountControllerProvider.notifier);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.deleteAccount)),
      body: ListView(
        padding: const EdgeInsets.all(Space.gutter),
        children: [
          Text(l10n.deleteAccountHeadline, style: text.headline),
          const SizedBox(height: Space.x12),
          Text(l10n.deleteAccountIntro),
          const SizedBox(height: Space.x12),
          Text(l10n.deleteAccountKept, style: text.bodySmall),
          const SizedBox(height: Space.x8),
          Text(l10n.deleteAccountOwed, style: text.bodySmall),
          const SizedBox(height: Space.x24),
          AppTextField(
            label: l10n.deleteAccountPasswordLabel,
            controller: _password,
            obscure: true,
            showPasswordLabel: l10n.showPassword,
            hidePasswordLabel: l10n.hidePassword,
            autofillHints: const [AutofillHints.password],
            textInputAction: TextInputAction.done,
            errorText: _local ?? status.field('password'),
            onChanged: (_) {
              controller.clearField('password');
              if (_local != null) setState(() => _local = null);
            },
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: Space.x24),
          SubmitSection(
            status: status,
            label: l10n.deleteAccountButton,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}
