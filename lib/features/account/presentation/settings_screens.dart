import 'dart:async';

import 'package:atompay_mobile/core/config/device.dart';
import 'package:atompay_mobile/core/format/dates.dart';
import 'package:atompay_mobile/core/format/money.dart';
import 'package:atompay_mobile/core/network/api_exception.dart';
import 'package:atompay_mobile/core/router/navigation.dart';
import 'package:atompay_mobile/core/router/routes.dart';
import 'package:atompay_mobile/core/theme/tokens.dart';
import 'package:atompay_mobile/core/utils/links.dart';
import 'package:atompay_mobile/core/widgets/brand.dart';
import 'package:atompay_mobile/core/widgets/buttons.dart';
import 'package:atompay_mobile/core/widgets/dialogs.dart';
import 'package:atompay_mobile/core/widgets/fields.dart';
import 'package:atompay_mobile/core/widgets/form_parts.dart';
import 'package:atompay_mobile/core/widgets/pressable.dart';
import 'package:atompay_mobile/core/widgets/states.dart';
import 'package:atompay_mobile/core/widgets/ui.dart';
import 'package:atompay_mobile/features/account/application/account_controllers.dart';
import 'package:atompay_mobile/features/account/data/device_permissions.dart';
import 'package:atompay_mobile/features/application/data/camera_service.dart';
import 'package:atompay_mobile/features/application/data/kyc_status.dart';
import 'package:atompay_mobile/features/auth/application/session_controller.dart';
import 'package:atompay_mobile/features/auth/data/auth_models.dart';
import 'package:atompay_mobile/features/auth/data/auth_repository.dart';
import 'package:atompay_mobile/features/home/application/home_controller.dart';
import 'package:atompay_mobile/features/launch/application/launch_controller.dart';
import 'package:atompay_mobile/features/notifications/application/push_controller.dart';
import 'package:atompay_mobile/features/plans/data/plan_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart'
    show openAppSettings;

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
                badge: user?.kyc == KycStatus.verified
                    ? const AppBadge.green('Verified')
                    : null,
                onTap: () => context.pushOnce(Routes.applicationStatus),
              ),
              ListRow(
                title: 'Notifications',
                summary: notifSummary,
                icon: Icons.notifications_none,
                onTap: () => context.pushOnce(Routes.notificationSettings),
              ),
            ],
          ),
          const SizedBox(height: Space.s20),
          ListGroup(
            title: 'Security',
            children: [
              ListRow(
                title: 'Account security',
                summary: 'Password, sign-out everywhere',
                icon: Icons.verified_user_outlined,
                tileTone: TileTone.green,
                onTap: () => context.pushOnce(Routes.security),
              ),
              ListRow(
                title: 'Change password',
                summary: 'Also changes it on Atomshop.pk',
                icon: Icons.lock_outline,
                tileTone: TileTone.grey,
                onTap: () => context.pushOnce(Routes.password),
              ),
              ListRow(
                title: 'Active sessions',
                summary: sessions == null
                    ? 'Phones and browsers signed in'
                    : '${sessions.length} '
                          '${sessions.length == 1 ? 'device' : 'devices'} '
                          'signed in',
                icon: Icons.smartphone,
                tileTone: TileTone.grey,
                onTap: () => context.pushOnce(Routes.devices),
              ),
            ],
          ),
          const SizedBox(height: Space.s20),
          ListGroup(
            title: 'Privacy',
            children: [
              ListRow(
                title: 'Permissions',
                summary: 'Camera · notifications · microphone',
                icon: Icons.tune,
                tileTone: TileTone.grey,
                onTap: () => context.pushOnce(Routes.permissions),
              ),
              ListRow(
                title: 'Privacy policy',
                summary: 'How we use and keep your data',
                icon: Icons.shield_outlined,
                tileTone: TileTone.grey,
                external: true,
                onTap: () => unawaited(Links.open(config.privacyUrl)),
              ),
              // Brief §6: hidden while app-config.terms_url is null.
              if (config.termsUrl case final terms?)
                ListRow(
                  title: 'Terms and conditions',
                  icon: Icons.description_outlined,
                  tileTone: TileTone.grey,
                  external: true,
                  onTap: () => unawaited(Links.open(terms)),
                ),
            ],
          ),
          const SizedBox(height: Space.s20),
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
          _ExportNote(onHelp: () => context.pushOnce(Routes.help)),
          const SizedBox(height: Space.s20),
          AppButton.ghostDanger(
            'Sign out',
            block: true,
            icon: Icons.logout,
            onPressed: () => unawaited(_signOut(context, ref)),
          ),
          const SizedBox(height: Space.s20),
          Semantics(
            container: true,
            label: 'AtomPay, ${versionLabel(info)}',
            child: ExcludeSemantics(
              child: Column(
                children: [
                  const AtomPayMark(size: 36),
                  Gap.s4,
                  Text(
                    'AtomPay · ${versionLabel(info)}',
                    style: t.tiny,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          Gap.s8,
        ],
      ),
    );
  }
}

/// "Need a copy of your data? Ask through Help." One paragraph (canvas
/// `.tiny u-mt8 u-lh`) with "Help" styled as the link. The whole paragraph
/// is the target, so it keeps a 48 dp hit area.
class _ExportNote extends StatelessWidget {
  const new({required this.onHelp});

  final VoidCallback onHelp;

  @override
  Widget build(BuildContext context) {
    final t = context.text;
    return Pressable(
      onTap: onHelp,
      isButton: false,
      scaleOnPress: false,
      borderRadius: BorderRadius.circular(Radii.tile),
      minSize: const Size(0, Sizes.target),
      semanticLabel:
          "Need a copy of your data? Ask through Help. There's no "
          'self-service export yet.',
      excludeChildSemantics: true,
      child: Semantics(
        link: true,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text.rich(
            TextSpan(
              style: t.tiny.copyWith(height: 1.5),
              children: [
                const TextSpan(text: 'Need a copy of your data? Ask through '),
                TextSpan(
                  text: 'Help',
                  style: TextStyle(
                    color: context.colors.primary,
                    fontWeight: FontWeight.w700,
                    decoration: TextDecoration.underline,
                  ),
                ),
                const TextSpan(text: ". There's no self-service export yet."),
              ],
            ),
          ),
        ),
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
          const Note(
            tone: NoteTone.green,
            icon: Icons.verified_user_outlined,
            text:
                'One account for AtomPay and Atomshop.pk. Changes here apply '
                'to both.',
          ),
          const SizedBox(height: Space.s20),
          ListGroup(
            title: 'Sign-in',
            children: [
              ListRow(
                title: 'Password',
                summary: 'Change it, or reset with a code',
                icon: Icons.lock_outline,
                tileTone: TileTone.grey,
                onTap: () => context.pushOnce(Routes.password),
              ),
              ListRow(
                title: 'Email and mobile',
                summary: contact.isEmpty ? null : contact,
                icon: Icons.mail_outline,
                tileTone: TileTone.grey,
              ),
            ],
          ),
          Gap.s8,
          Text(
            'Email and mobile are changed on Atomshop.pk, where the account '
            'lives.',
            style: t.tiny.copyWith(height: 1.5),
          ),
          const SizedBox(height: Space.s20),
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
                icon: Icons.smartphone,
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
          const SizedBox(height: Space.s20),
          const SectionLabel('On this phone'),
          const AppCard(
            padding: EdgeInsets.symmetric(
              horizontal: Space.s18,
              vertical: Space.s16,
            ),
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
            ]),
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
    PermissionView.off => AppBadge.grey(v.label),
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
      alignTop: true,
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
            style: t.small,
          ),
          const SizedBox(height: Space.s20),
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
          Gap.s14,
          AppButton.primary(
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
            style: t.tiny.copyWith(height: 1.5),
          ),
          const SizedBox(height: Space.s20),
          const SectionLabel('Never asked for'),
          Wrap(
            spacing: Space.s8,
            runSpacing: Space.s8,
            children: [
              for (final label in _neverAsked)
                // A label, not a control (canvas `.never span`).
                Container(
                  // 13 px text at 1.3 plus 10 + 10: the canvas's 36 high.
                  padding: const EdgeInsets.symmetric(
                    horizontal: Space.s12,
                    vertical: Space.s10,
                  ),
                  decoration: BoxDecoration(
                    color: c.surface,
                    border: Border.all(color: c.line),
                    borderRadius: BorderRadius.circular(Radii.pill),
                  ),
                  child: Text(
                    label,
                    style: t.small.copyWith(
                      color: c.body,
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                    ),
                  ),
                ),
            ],
          ),
          Gap.s8,
          Text(
            'Lending apps in Pakistan may not read these, even with your '
            'consent (Google Play rules).',
            style: t.tiny.copyWith(height: 1.5),
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
    // Push shows once this build has Firebase and the server sends pushes.
    final pushLive =
        PushSupport.ready && ref.watch(appConfigProvider).features.push;
    final push = pushLive
        ? ref.watch(permissionsProvider).value?.notifications
        : null;

    Future<void> setPush() async {
      final permission = ref.read(notificationPermissionProvider);
      if (push == PermissionView.notAsked) {
        await permission.request();
        unawaited(ref.read(pushControllerProvider).syncRegistration());
      } else {
        // Android and iOS only let the phone's settings turn it on or off.
        await openAppSettings();
      }
      ref.invalidate(permissionsProvider);
    }

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
          if (hasEmail || pushLive)
            ListGroup(
              title: 'Notifications',
              children: [
                if (pushLive)
                  ListRow(
                    title: 'Push notifications',
                    summary: 'On this phone',
                    trailing: Semantics(
                      label: 'Push notifications',
                      child: Switch.adaptive(
                        value: push == PermissionView.allowed,
                        onChanged: push == null
                            ? null
                            : (_) => unawaited(setPush()),
                      ),
                    ),
                    onTap: push == null ? null : () => unawaited(setPush()),
                  ),
                if (hasEmail)
                  ListRow(
                    title: 'Email alerts',
                    summary: 'To the email on your account',
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
          Gap.s8,
          Text(
            'The inbox in the app always shows everything. Accounts with only '
            'a mobile number get no email, so that switch is hidden for them.',
            style: t.tiny.copyWith(height: 1.5),
          ),
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
        backgroundColor: context.colors.white,
        appBar: const AppTopBar(
          title: 'Change password',
          white: true,
          bottomBorder: false,
        ),
        body: AutofillGroup(
          child: FormPage(
            padding: const EdgeInsets.fromLTRB(
              Space.gutter,
              Space.s4,
              Space.gutter,
              Space.gutter,
            ),
            children: [
              Text(
                'This is your AtomShop password too — it changes on '
                'Atomshop.pk as well. Your other devices are signed out.',
                style: context.text.small,
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
                    style: context.text.tiny.copyWith(
                      color: context.colors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                    onPressed: () => unawaited(Links.open(resetUrl)),
                  ),
                ),
              Gap.s14,
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
              Gap.s14,
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
              Gap.s20,
              // Inline under the form, as on the canvas (not a pinned bar).
              SubmitSection(
                label: 'Change password',
                status: status,
                offline: ref.watch(isOfflineProvider),
                fieldsOnScreen: _focus.keys.toSet(),
                onSubmit: () => unawaited(_submit()),
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
                  style: t.small,
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
                        tileTone: TileTone.grey,
                        badge: s.current
                            ? const AppBadge.green('This device')
                            : null,
                        trailing: s.current
                            ? null
                            : AppButton.ghostDanger(
                                'Sign out',
                                compact: true,
                                busy: _ending.contains(s.id),
                                semanticLabel: 'Sign out ${s.deviceName}',
                                onPressed: _ending.isEmpty
                                    ? () => unawaited(_end([s]))
                                    : null,
                              ),
                      ),
                  ],
                ),
                if (others.isNotEmpty) ...[
                  Gap.s16,
                  AppButton.ghostDanger(
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
            const Note(
              tone: NoteTone.rose,
              spans: [
                TextSpan(text: 'This closes your '),
                TextSpan(
                  text: 'Atomshop.pk account too',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                TextSpan(
                  text:
                      ". AtomPay and Atomshop share one account. It can't be "
                      'undone.',
                ),
              ],
            ),
            Gap.s14,
            _DeleteCard(
              title: 'Before you can delete',
              child: Text(
                'Every instalment plan must be fully repaid, and no order can '
                'be waiting for approval.',
                style: t.small.copyWith(color: c.body),
              ),
            ),
            Gap.s14,
            _DeleteCard(
              title: 'Deleted straight away',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final (i, line) in _deletedNow.indexed) ...[
                    if (i > 0) Gap.s6,
                    // Canvas `.lst`: a disc list, 18 in.
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: Space.s18,
                          child: ExcludeSemantics(
                            child: Text('•', style: t.base),
                          ),
                        ),
                        Expanded(child: Text(line, style: t.base)),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            Gap.s14,
            _DeleteCard(
              title: 'What we keep, and why',
              child: Text(
                'The law requires us to keep financial records. Past orders, '
                'schedules and payments stay, linked only to an anonymous '
                'closed account. Nothing left in them names you.',
                style: t.small.copyWith(color: c.body),
              ),
            ),
            Gap.s14,
            PasswordField(
              label: 'Enter your password to confirm',
              controller: _password,
              focusNode: _passwordFocus,
              error: status.field('password'),
              onChanged: (_) => ref
                  .read(deleteAccountFormProvider.notifier)
                  .clearField('password'),
            ),
            Gap.s14,
            ConsentRow(
              value: _understood,
              onChanged: (v) => setState(() => _understood = v),
              child: const Text(
                'I understand this deletes my AtomPay and Atomshop.pk '
                'account.',
              ),
            ),
            Gap.s14,
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
            if (webUrl != null) ...[Gap.s6, _WebDeleteLink(url: webUrl)],
          ],
        ),
      ),
    );
  }
}

/// A Delete-account card: canvas `.card u-pad` with an `.h3` title.
class _DeleteCard extends StatelessWidget {
  const new({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => AppCard(
    padding: const EdgeInsets.all(Space.s18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(header: true, child: Text(title, style: context.text.h4)),
        Gap.s10,
        child,
      ],
    ),
  );
}

/// "Can't sign in? Delete on the web at atompay.shop/delete-account." The
/// canvas's centred `.tiny` line, kept tappable with a 48 dp target.
class _WebDeleteLink extends StatelessWidget {
  const new({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    final t = context.text;
    final uri = Uri.tryParse(url);
    final shown = uri == null || uri.host.isEmpty
        ? url
        : '${uri.host}${uri.path}';
    return Pressable(
      onTap: () => unawaited(Links.open(url)),
      isButton: false,
      scaleOnPress: false,
      borderRadius: BorderRadius.circular(Radii.tile),
      minSize: const Size(0, Sizes.target),
      semanticLabel: "Can't sign in? Delete on the web, opens outside the app",
      excludeChildSemantics: true,
      child: Semantics(
        link: true,
        child: Center(
          child: Text.rich(
            TextSpan(
              style: t.tiny.copyWith(height: 1.5),
              children: [
                const TextSpan(text: "Can't sign in? Delete on the web at "),
                TextSpan(
                  text: shown,
                  style: TextStyle(
                    color: context.colors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const TextSpan(text: '.'),
              ],
            ),
            textAlign: TextAlign.center,
          ),
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
        if (!p.status.isClosed) p,
    ];
    return Scaffold(
      backgroundColor: c.white,
      appBar: const AppTopBar(white: true, bottomBorder: false),
      body: Column(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, box) => SingleChildScrollView(
                padding: const EdgeInsets.all(Space.gutter),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: box.maxHeight > Space.gutter * 2
                        ? box.maxHeight - Space.gutter * 2
                        : 0,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Center(
                            child: Container(
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                color: c.amberSoft,
                                borderRadius: BorderRadius.circular(22),
                              ),
                              child: Icon(
                                Icons.schedule,
                                size: 32,
                                color: c.amberInk,
                              ),
                            ),
                          ),
                          Gap.s20,
                          Semantics(
                            header: true,
                            liveRegion: true,
                            child: Text(
                              "You can delete once it's repaid",
                              style: t.h2,
                              textAlign: TextAlign.center,
                            ),
                          ),
                          Gap.s8,
                          Text(
                            'Your account is still open. Nothing has been '
                            'deleted.',
                            style: t.lead,
                            textAlign: TextAlign.center,
                          ),
                          for (final p in owing) ...[
                            Gap.s20,
                            AppCard(
                              padding: const EdgeInsets.symmetric(
                                horizontal: Space.s18,
                                vertical: Space.s16,
                              ),
                              onTap: () =>
                                  context.pushOnce(Routes.plan(p.order.id)),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          p.product?.title ?? p.order.reference,
                                          style: t.body.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
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
                                  if (p.progress.remainingAmount > 0) ...[
                                    const SizedBox(width: Space.s12),
                                    Text(
                                      rs(p.progress.remainingAmount),
                                      style: t.h4,
                                      semanticsLabel: rsSpoken(
                                        p.progress.remainingAmount,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                          Gap.s20,
                          Text(
                            'When the last payment is recorded, come back here '
                            'and it will go through.',
                            style: t.small,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Canvas `.actionbar`.
          Container(
            decoration: BoxDecoration(
              color: c.white,
              border: Border(top: BorderSide(color: c.line)),
            ),
            padding: const EdgeInsets.fromLTRB(
              Space.s16,
              Space.s12,
              Space.s16,
              Space.s16,
            ),
            child: SafeArea(
              top: false,
              child: AppButton.ghost(
                'Back to account',
                large: true,
                block: true,
                onPressed: () => context.go(Routes.account),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Canvas "DeleteAccount": what goes straight away.
const _deletedNow = [
  'Your sign-ins on every phone and browser, and push tokens.',
  'Your CNIC number, date of birth, address, CNIC photos and selfie.',
  'Your inbox, preferences and any codes.',
  'Your name, email, mobile and password on the Atomshop account.',
];
