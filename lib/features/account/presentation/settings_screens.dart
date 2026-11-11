import 'dart:async';

import 'package:atompay_mobile/core/config/device.dart';
import 'package:atompay_mobile/core/format/dates.dart';
import 'package:atompay_mobile/core/format/money.dart';
import 'package:atompay_mobile/core/network/api_exception.dart';
import 'package:atompay_mobile/core/router/navigation.dart';
import 'package:atompay_mobile/core/router/routes.dart';
import 'package:atompay_mobile/core/theme/tokens.dart';
import 'package:atompay_mobile/core/utils/links.dart';
import 'package:atompay_mobile/core/widgets/buttons.dart';
import 'package:atompay_mobile/core/widgets/dialogs.dart';
import 'package:atompay_mobile/core/widgets/fields.dart';
import 'package:atompay_mobile/core/widgets/form_parts.dart';
import 'package:atompay_mobile/core/widgets/states.dart';
import 'package:atompay_mobile/core/widgets/ui.dart';
import 'package:atompay_mobile/features/account/application/account_controllers.dart';
import 'package:atompay_mobile/features/account/data/device_permissions.dart';
import 'package:atompay_mobile/features/application/data/camera_service.dart';
import 'package:atompay_mobile/features/auth/application/session_controller.dart';
import 'package:atompay_mobile/features/auth/data/auth_models.dart';
import 'package:atompay_mobile/features/auth/data/auth_repository.dart';
import 'package:atompay_mobile/features/home/application/home_controller.dart';
import 'package:atompay_mobile/features/launch/application/launch_controller.dart';
import 'package:atompay_mobile/features/plans/data/plan_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Settings (canvas "Settings"), opened from Account.
class SettingsScreen extends ConsumerWidget {
  const new({super.key});

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final router = GoRouter.of(context);
    final sure = await showAppDialog(
      context: context,
      title: 'Sign out of AtomPay?',
      body:
          "You'll need your AtomShop email or mobile and password to sign "
          'back in. Your limit and orders stay as they are.',
      confirm: 'Sign out',
      cancel: 'Stay signed in',
      destructive: true,
      cancelIsDefault: true,
    );
    if (!sure) return;
    await ref.read(sessionProvider.notifier).signOut();
    router.go(Routes.login);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final t = context.text;
    final user = ref.watch(currentUserProvider);
    final config = ref.watch(appConfigProvider);
    final sessions = ref.watch(sessionsProvider).value;
    final emailOn = ref.watch(emailAlertsProvider).value;
    final info = ref.watch(packageInfoProvider);

    final notifSummary = user?.email == null
        ? 'In the app'
        : 'Email ${emailOn == null ? 'alerts' : (emailOn ? 'on' : 'off')}';

    return Scaffold(
      backgroundColor: c.surface,
      appBar: const AppTopBar(title: 'Settings'),
      body: FormPage(
        children: [
          ListGroup(
            title: 'Account',
            children: [
              ListRow(
                title: 'Personal details',
                summary: 'Name, CNIC, mobile, city and area',
                icon: Icons.person_outline,
                badge: user?.kycStatus == 'verified'
                    ? const AppBadge.green('Verified')
                    : null,
                onTap: () => context.pushOnce(Routes.applicationStatus),
              ),
              ListRow(
                title: 'Notifications',
                summary: notifSummary,
                icon: Icons.notifications_none,
                tileTone: TileTone.amber,
                onTap: () => context.pushOnce(Routes.notificationSettings),
              ),
            ],
          ),
          Gap.s16,
          ListGroup(
            title: 'Security',
            children: [
              ListRow(
                title: 'Account security',
                summary: 'Password, sign-out everywhere',
                icon: Icons.shield_outlined,
                tileTone: TileTone.green,
                onTap: () => context.pushOnce(Routes.security),
              ),
              ListRow(
                title: 'Change password',
                summary: 'Also changes it on Atomshop.pk',
                icon: Icons.key_outlined,
                onTap: () => context.pushOnce(Routes.password),
              ),
              ListRow(
                title: 'Active sessions',
                summary: sessions == null
                    ? 'Phones and browsers signed in'
                    : '${sessions.length} '
                          '${sessions.length == 1 ? 'device' : 'devices'} '
                          'signed in',
                icon: Icons.devices_outlined,
                tileTone: TileTone.grey,
                onTap: () => context.pushOnce(Routes.devices),
              ),
            ],
          ),
          Gap.s16,
          ListGroup(
            title: 'Privacy',
            children: [
              ListRow(
                title: 'Permissions',
                summary: 'Camera · notifications · microphone',
                icon: Icons.lock_outline,
                tileTone: TileTone.grey,
                onTap: () => context.pushOnce(Routes.permissions),
              ),
              ListRow(
                title: 'Privacy policy',
                summary: 'How we use and keep your data',
                icon: Icons.privacy_tip_outlined,
                tileTone: TileTone.grey,
                external: true,
                onTap: () => unawaited(Links.open(config.privacyUrl)),
              ),
              if (config.termsUrl case final terms?)
                ListRow(
                  title: 'Terms and conditions',
                  icon: Icons.gavel_outlined,
                  tileTone: TileTone.grey,
                  external: true,
                  onTap: () => unawaited(Links.open(terms)),
                ),
            ],
          ),
          Gap.s16,
          ListGroup(
            title: 'Your data',
            children: [
              ListRow(
                title: 'Delete account',
                summary: 'Closes your Atomshop.pk account too',
                icon: Icons.delete_outline,
                tileTone: TileTone.rose,
                titleColor: c.rose,
                onTap: () => context.pushOnce(Routes.deleteAccount),
              ),
            ],
          ),
          Gap.s8,
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('Need a copy of your data? Ask through ', style: t.small),
              TextLink('Help', onPressed: () => context.pushOnce(Routes.help)),
              Text(". There's no self-service export yet.", style: t.small),
            ],
          ),
          Gap.s16,
          ListGroup(
            children: [
              ListRow(
                title: 'Sign out',
                icon: Icons.logout,
                tileTone: TileTone.rose,
                titleColor: c.rose,
                showChevron: false,
                onTap: () => unawaited(_signOut(context, ref)),
              ),
            ],
          ),
          Gap.s24,
          Center(child: Text('AtomPay · ${versionLabel(info)}', style: t.tiny)),
          Gap.s16,
        ],
      ),
    );
  }
}

/// Account security: password, masked email and mobile, devices, and
/// Sign out everywhere.
class SecurityScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends ConsumerState<SecurityScreen> {
  bool _busy = false;

  Future<void> _everywhere() async {
    final router = GoRouter.of(context);
    final sure = await showAppDialog(
      context: context,
      title: 'Sign out everywhere?',
      body:
          'Every phone and browser signed in to your AtomShop account is '
          'signed out, including this one, and their notifications stop.',
      confirm: 'Sign out everywhere',
      cancel: 'Cancel',
      destructive: true,
      cancelIsDefault: true,
    );
    if (!sure || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(sessionProvider.notifier).signOutEverywhere();
      router.go(Routes.login);
    } on ApiException catch (e) {
      showToast(switch (e) {
        Offline() => "You're offline. Try again when you're connected.",
        _ => "We couldn't sign you out everywhere. Try again.",
      }, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final user = ref.watch(currentUserProvider);
    final sessions = ref.watch(sessionsProvider).value;
    final others = sessions?.where((s) => !s.current).length;
    final contact = [
      if (user?.email != null) 'Email on file',
      ?(user == null ? null : maskedMobile(user)),
    ].join(' · ');

    return Scaffold(
      backgroundColor: c.surface,
      appBar: const AppTopBar(title: 'Account security'),
      body: FormPage(
        children: [
          Text(
            'One account for AtomPay and Atomshop.pk. Changes here apply to '
            'both.',
            style: t.lead,
          ),
          Gap.s16,
          ListGroup(
            title: 'Sign-in',
            children: [
              ListRow(
                title: 'Password',
                summary: 'Change it, or reset with a code',
                icon: Icons.key_outlined,
                onTap: () => context.pushOnce(Routes.password),
              ),
              ListRow(
                title: 'Email and mobile',
                summary: contact.isEmpty ? null : contact,
                icon: Icons.alternate_email,
                tileTone: TileTone.grey,
              ),
            ],
          ),
          Gap.s8,
          Text(
            'Email and mobile are changed on Atomshop.pk, where the account '
            'lives.',
            style: t.small,
          ),
          Gap.s16,
          ListGroup(
            title: 'Sessions',
            children: [
              ListRow(
                title: 'Signed-in devices',
                summary: switch (others) {
                  null => 'Phones and browsers signed in',
                  0 => 'Only this phone',
                  1 => 'This phone and 1 other',
                  final n => 'This phone and $n others',
                },
                icon: Icons.devices_outlined,
                tileTone: TileTone.grey,
                onTap: () => context.pushOnce(Routes.devices),
              ),
              ListRow(
                title: 'Sign out everywhere',
                summary: 'Every device, this one too',
                icon: Icons.logout,
                tileTone: TileTone.rose,
                titleColor: c.rose,
                showChevron: false,
                trailing: _busy
                    ? SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: c.rose,
                        ),
                      )
                    : null,
                onTap: _busy ? null : () => unawaited(_everywhere()),
              ),
            ],
          ),
          Gap.s24,
          const SectionLabel('On this phone'),
          const AppCard(
            child: TickList([
              TextSpan(
                text:
                    "Your sign-in is kept in the phone's secure storage, "
                    'never in plain files.',
              ),
              TextSpan(
                text:
                    "CNIC and selfie screens can't be screenshotted or shown "
                    'in the app switcher.',
              ),
            ], icon: Icons.lock_outline),
          ),
        ],
      ),
    );
  }
}

/// Live status of camera, notifications and microphone (canvas
/// "Permissions"). Re-read when the app comes back from phone settings.
class PermissionsScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends ConsumerState<PermissionsScreen> {
  late final AppLifecycleListener _lifecycle;

  static const _neverAsked = [
    'Contacts',
    'Photos and files',
    'Location',
    'Calls and call logs',
    'SMS',
    'Phone number',
    'Other apps',
  ];

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onResume: () => ref.invalidate(permissionsProvider),
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  Widget _badge(PermissionView? v) => switch (v) {
    null => const AppBadge.grey('…'),
    PermissionView.allowed => AppBadge.green(v.label),
    PermissionView.off => AppBadge.rose(v.label),
    PermissionView.notAsked => AppBadge.grey(v.label),
  };

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final p = ref.watch(permissionsProvider).value;

    ListRow row(
      String title,
      String summary,
      IconData icon,
      PermissionView? v,
    ) => ListRow(
      title: title,
      summary: summary,
      icon: icon,
      badge: _badge(v),
      semanticLabel: '$title, ${v?.label ?? 'checking'}. $summary',
    );

    return Scaffold(
      backgroundColor: c.surface,
      appBar: const AppTopBar(title: 'Permissions'),
      body: FormPage(
        children: [
          Text(
            'AtomPay asks for three things, only when you use the feature '
            'that needs them. You can change any of them at any time in your '
            "phone's settings.",
            style: t.lead,
          ),
          Gap.s16,
          ListGroup(
            title: 'What AtomPay can use',
            children: [
              row(
                'Camera',
                'To photograph your CNIC and take a selfie. Never in the '
                    'background.',
                Icons.photo_camera_outlined,
                p?.camera,
              ),
              row(
                'Notifications',
                'Payment reminders and decisions on your limit.',
                Icons.notifications_none,
                p?.notifications,
              ),
              row(
                'Microphone',
                'Only to ask Atom a question by voice. Recordings are never '
                    'kept.',
                Icons.mic_none,
                p?.microphone,
              ),
            ],
          ),
          Gap.s16,
          AppButton.ghost(
            'Open phone settings',
            block: true,
            trailingIcon: Icons.north_east,
            onPressed: () =>
                unawaited(ref.read(cameraServiceProvider).openSettings()),
          ),
          Gap.s8,
          Text(
            'Turned something off? The app keeps working; it asks again only '
            'when you use that feature.',
            style: t.small,
          ),
          Gap.s24,
          const SectionLabel('Never asked for'),
          Wrap(
            spacing: Space.s8,
            runSpacing: Space.s8,
            children: [
              for (final label in _neverAsked)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Space.s12,
                    vertical: Space.s6,
                  ),
                  decoration: BoxDecoration(
                    color: c.greySoft,
                    borderRadius: BorderRadius.circular(Radii.pill),
                  ),
                  child: Text(label, style: t.small.copyWith(color: c.body)),
                ),
            ],
          ),
          Gap.s12,
          Text(
            'Lending apps in Pakistan may not read these, even with your '
            'consent (Google Play and SECP rules).',
            style: t.small,
          ),
        ],
      ),
    );
  }
}

/// Notification settings. Push needs FCM, which the server switches on
/// with `features.push`; until then only email alerts show.
class NotificationSettingsScreen extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final t = context.text;
    final user = ref.watch(currentUserProvider);
    final email = ref.watch(emailAlertsProvider);
    final hasEmail = user?.email != null;

    Future<void> setEmail({required bool on}) async {
      try {
        await ref.read(emailAlertsProvider.notifier).set(on: on);
      } on ApiException {
        showToast("We couldn't save that. Try again.", error: true);
      }
    }

    return Scaffold(
      backgroundColor: c.surface,
      appBar: const AppTopBar(title: 'Notifications'),
      body: FormPage(
        children: [
          if (hasEmail)
            ListGroup(
              title: 'Notifications',
              children: [
                ListRow(
                  title: 'Email alerts',
                  summary: 'To the email on your account',
                  icon: Icons.mail_outline,
                  trailing: switch (email) {
                    AsyncData(:final value) => Semantics(
                      label: 'Email alerts',
                      child: Switch.adaptive(
                        value: value,
                        onChanged: (v) => unawaited(setEmail(on: v)),
                      ),
                    ),
                    AsyncError() => TextLink(
                      'Retry',
                      onPressed: () => ref.invalidate(emailAlertsProvider),
                    ),
                    _ => SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: c.muted,
                      ),
                    ),
                  },
                  onTap: email.hasValue
                      ? () => unawaited(setEmail(on: !email.requireValue))
                      : null,
                ),
              ],
            ),
          Gap.s12,
          Text('The inbox in the app always shows everything.', style: t.small),
        ],
      ),
    );
  }
}

/// Change password (`POST /me/password`). Other devices are signed out.
class ChangePasswordScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() =>
      _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _current = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _focus = {
    'current_password': FocusNode(),
    'password': FocusNode(),
    'password_confirmation': FocusNode(),
  };

  bool get _dirty =>
      _current.text.isNotEmpty ||
      _password.text.isNotEmpty ||
      _confirm.text.isNotEmpty;

  @override
  void initState() {
    super.initState();
    for (final c in [_current, _password, _confirm]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    for (final c in [_current, _password, _confirm]) {
      c.dispose();
    }
    for (final f in _focus.values) {
      f.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    final router = GoRouter.of(context);
    FocusScope.of(context).unfocus();
    final ok = await ref
        .read(changePasswordFormProvider.notifier)
        .submit(
          current: _current.text,
          password: _password.text,
          confirmation: _confirm.text,
        );
    if (!mounted) return;
    if (!ok) {
      focusFirstError(ref.read(changePasswordFormProvider), _focus);
      return;
    }
    ref.invalidate(sessionsProvider);
    router.go(Routes.settings);
    showToast('Password changed. It works on AtomShop.pk too.');
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(changePasswordFormProvider);
    final form = ref.read(changePasswordFormProvider.notifier);
    final resetUrl = ref.watch(appConfigProvider).passwordResetUrl;
    return FormExitGuard(
      dirty: _dirty,
      busy: status.busy,
      child: Scaffold(
        backgroundColor: context.colors.surface,
        appBar: const AppTopBar(title: 'Change password'),
        body: AutofillGroup(
          child: FormPage(
            footer: SubmitSection(
              label: 'Change password',
              status: status,
              offline: ref.watch(isOfflineProvider),
              fieldsOnScreen: _focus.keys.toSet(),
              onSubmit: () => unawaited(_submit()),
            ),
            children: [
              Text(
                'This is your AtomShop password too: it changes on '
                'Atomshop.pk as well. Your other devices are signed out.',
                style: context.text.lead,
              ),
              Gap.s20,
              PasswordField(
                label: 'Current password',
                controller: _current,
                focusNode: _focus['current_password'],
                error: status.field('current_password'),
                textInputAction: TextInputAction.next,
                onChanged: (_) => form.clearField('current_password'),
              ),
              if (resetUrl != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextLink(
                    'Forgotten it? Reset with a code',
                    external: true,
                    onPressed: () => unawaited(Links.open(resetUrl)),
                  ),
                ),
              Gap.s12,
              PasswordField(
                label: 'New password',
                controller: _password,
                focusNode: _focus['password'],
                hint: 'At least 8 characters.',
                error: status.field('password'),
                autofillHints: const [AutofillHints.newPassword],
                textInputAction: TextInputAction.next,
                onChanged: (_) => form.clearField('password'),
              ),
              Gap.s16,
              PasswordField(
                label: 'Confirm new password',
                controller: _confirm,
                focusNode: _focus['password_confirmation'],
                error: status.field('password_confirmation'),
                autofillHints: const [AutofillHints.newPassword],
                textInputAction: TextInputAction.done,
                onChanged: (_) => form.clearField('password_confirmation'),
                onSubmitted: (_) => unawaited(_submit()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Signed-in devices (`GET /auth/sessions`, `DELETE /auth/sessions/{id}`).
class DevicesScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends ConsumerState<DevicesScreen> {
  final _ending = <int>{};

  Future<void> _end(List<DeviceSession> sessions) async {
    setState(() => _ending.addAll(sessions.map((s) => s.id)));
    try {
      for (final s in sessions) {
        await ref.read(authRepositoryProvider).endSession(s.id);
      }
      showToast(
        sessions.length == 1
            ? 'Signed out of ${sessions.single.deviceName}'
            : 'Signed out of every other device',
      );
    } on ApiException {
      showToast("We couldn't sign that device out. Try again.", error: true);
    } finally {
      if (mounted) setState(_ending.clear);
      ref.invalidate(sessionsProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final sessions = ref.watch(sessionsProvider);
    listenForRefreshErrors(ref, sessionsProvider);

    return Scaffold(
      backgroundColor: c.surface,
      appBar: const AppTopBar(title: 'Signed-in devices'),
      body: AsyncBody(
        value: sessions,
        onRetry: () => ref.invalidate(sessionsProvider),
        loading: const LoadingShape(
          label: 'Loading your devices',
          child: Column(
            children: [SkeletonRow(), SkeletonRow(), SkeletonRow()],
          ),
        ),
        data: (list) {
          final others = list.where((s) => !s.current).toList();
          return RefreshIndicator(
            onRefresh: () => ref.refresh(sessionsProvider.future),
            child: ListView(
              padding: const EdgeInsets.all(Space.gutter),
              children: [
                Text(
                  "Where your AtomPay account is signed in. Don't recognise "
                  'one? Sign it out and change your password.',
                  style: t.lead,
                ),
                Gap.s16,
                ListGroup(
                  children: [
                    for (final s in list)
                      ListRow(
                        title: s.deviceName,
                        summary: s.current
                            ? 'Active now'
                            : s.lastUsedAt == null
                            ? null
                            : 'Last used ${dayMonth(s.lastUsedAt!)}',
                        icon: Icons.smartphone,
                        tileTone: s.current ? TileTone.green : TileTone.grey,
                        badge: s.current
                            ? const AppBadge.green('This device')
                            : null,
                        trailing: s.current
                            ? null
                            : AppButton.ghost(
                                'Sign out',
                                busy: _ending.contains(s.id),
                                semanticLabel: 'Sign out ${s.deviceName}',
                                onPressed: _ending.isEmpty
                                    ? () => unawaited(_end([s]))
                                    : null,
                              ),
                      ),
                  ],
                ),
                if (others.length > 1) ...[
                  Gap.s16,
                  AppButton.ghost(
                    'Sign out of all other devices',
                    block: true,
                    onPressed: _ending.isEmpty
                        ? () => unawaited(_end(others))
                        : null,
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Delete account (`POST /me/delete`). 409 shows "Can't delete yet".
class DeleteAccountScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<DeleteAccountScreen> createState() =>
      _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends ConsumerState<DeleteAccountScreen> {
  final _password = TextEditingController();
  final _passwordFocus = FocusNode();
  bool _understood = false;
  bool _blocked = false;

  @override
  void initState() {
    super.initState();
    _password.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _password.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final router = GoRouter.of(context);
    FocusScope.of(context).unfocus();
    final outcome = await ref
        .read(deleteAccountFormProvider.notifier)
        .submit(_password.text);
    if (!mounted) return;
    switch (outcome) {
      case DeleteOutcome.deleted:
        router.go(Routes.welcome);
        showToast('Your account has been deleted.');
      case DeleteOutcome.blocked:
        ref.invalidate(plansProvider);
        setState(() => _blocked = true);
      case null:
        if (ref.read(deleteAccountFormProvider).field('password') != null) {
          _passwordFocus.requestFocus();
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_blocked) return const _DeleteBlocked();
    final c = context.colors;
    final t = context.text;
    final status = ref.watch(deleteAccountFormProvider);
    final webUrl = ref.watch(appConfigProvider).accountDeletionUrl;

    return FormExitGuard(
      dirty: false,
      busy: status.busy,
      child: Scaffold(
        backgroundColor: c.surface,
        appBar: const AppTopBar(title: 'Delete your account'),
        body: FormPage(
          children: [
            Semantics(
              header: true,
              child: Text('Delete your account', style: t.h1),
            ),
            Gap.s8,
            Text.rich(
              TextSpan(
                style: t.lead,
                children: [
                  const TextSpan(text: 'This closes your '),
                  TextSpan(
                    text: 'Atomshop.pk account too',
                    style: TextStyle(color: c.ink, fontWeight: FontWeight.w800),
                  ),
                  const TextSpan(
                    text:
                        ". AtomPay and Atomshop share one account. It can't be "
                        'undone.',
                  ),
                ],
              ),
            ),
            Gap.s16,
            const Note(
              tone: NoteTone.amber,
              spans: [
                TextSpan(
                  text: 'Before you can delete\n',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                TextSpan(
                  text:
                      'Every instalment plan must be fully repaid, and no '
                      'order can be waiting for approval.',
                ),
              ],
            ),
            Gap.s16,
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Deleted straight away', style: t.h4),
                  Gap.s12,
                  TickList(
                    const [
                      TextSpan(
                        text:
                            'Your sign-ins on every phone and browser, and '
                            'push tokens.',
                      ),
                      TextSpan(
                        text:
                            'Your CNIC number, date of birth, address, CNIC '
                            'photos and selfie.',
                      ),
                      TextSpan(text: 'Your inbox, preferences and any codes.'),
                      TextSpan(
                        text:
                            'Your name, email, mobile and password on the '
                            'Atomshop account.',
                      ),
                    ],
                    icon: Icons.close,
                    color: c.rose,
                  ),
                  Gap.s8,
                  Text('What we keep, and why', style: t.h4),
                  Gap.s8,
                  Text(
                    'The law requires us to keep financial records. Past '
                    'orders, schedules and payments stay, linked only to an '
                    'anonymous closed account. Nothing left in them names '
                    'you.',
                    style: t.base,
                  ),
                ],
              ),
            ),
            Gap.s20,
            PasswordField(
              label: 'Enter your password to confirm',
              controller: _password,
              focusNode: _passwordFocus,
              error: status.field('password'),
              onChanged: (_) => ref
                  .read(deleteAccountFormProvider.notifier)
                  .clearField('password'),
            ),
            Gap.s12,
            ConsentRow(
              value: _understood,
              onChanged: (v) => setState(() => _understood = v),
              child: const Text(
                'I understand this deletes my AtomPay and Atomshop.pk '
                'account.',
              ),
            ),
            Gap.s16,
            if (status.generalMessage({'password'}) case final m?) ...[
              Semantics(
                liveRegion: true,
                child: Note(tone: NoteTone.rose, text: m),
              ),
              Gap.s12,
            ],
            AppButton.danger(
              'Delete my account',
              large: true,
              block: true,
              busy: status.busy,
              onPressed:
                  _understood &&
                      _password.text.isNotEmpty &&
                      !status.blocked &&
                      !ref.watch(isOfflineProvider)
                  ? () => unawaited(_submit())
                  : null,
            ),
            if (status.blocked) ...[
              Gap.s8,
              Center(
                child: RetryCountdown(
                  retryAfter: status.retryIn,
                  prefix: 'Too many tries. Try again in',
                  onDone: () => setState(() {}),
                ),
              ),
            ],
            if (webUrl != null) ...[
              Gap.s12,
              Center(
                child: TextLink(
                  "Can't sign in? Delete on the web",
                  external: true,
                  onPressed: () => unawaited(Links.open(webUrl)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Payments still to make on a plan (a count, not money).
int _left(Plan p) => p.progress.totalCount - p.progress.paidCount;

/// 409 `outstanding_balance`: nothing was deleted.
class _DeleteBlocked extends ConsumerWidget {
  const new();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final t = context.text;
    final owing = [
      for (final p in ref.watch(plansProvider).value?.data ?? const <Plan>[])
        if (p.state != 'completed' && p.state != 'cancelled') p,
    ];
    return Scaffold(
      backgroundColor: c.surface,
      appBar: const AppTopBar(title: "Can't delete yet"),
      body: FormPage(
        footer: AppButton.primary(
          'Back to account',
          large: true,
          block: true,
          onPressed: () => context.go(Routes.account),
        ),
        children: [
          Semantics(
            header: true,
            liveRegion: true,
            child: Text("You can delete once it's repaid", style: t.h1),
          ),
          Gap.s8,
          Text(
            'Your account is still open. Nothing has been deleted.',
            style: t.lead,
          ),
          Gap.s16,
          for (final p in owing) ...[
            AppCard(
              padding: const EdgeInsets.all(Space.s16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.product?.title ?? p.order.reference,
                          style: t.body.copyWith(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          p.progress.totalCount == 0
                              ? p.order.reference
                              : '${p.order.reference} · '
                                    '${_left(p)} payments left',
                          style: t.small,
                        ),
                      ],
                    ),
                  ),
                  if (p.progress.remainingAmount > 0)
                    Text(
                      rs(p.progress.remainingAmount),
                      style: t.h4,
                      semanticsLabel: rsSpoken(p.progress.remainingAmount),
                    ),
                ],
              ),
            ),
            Gap.s12,
          ],
          Text(
            'When the last payment is recorded, come back here and it will go '
            'through.',
            style: t.small,
          ),
        ],
      ),
    );
  }
}
