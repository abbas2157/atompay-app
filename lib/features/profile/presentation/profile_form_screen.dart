import 'dart:async';

import 'dart:io';

import 'package:atompay_mobile/core/forms/validators.dart';
import 'package:atompay_mobile/core/models/kyc_status.dart';
import 'package:atompay_mobile/core/network/api_exception.dart';
import 'package:atompay_mobile/core/router/routes.dart';
import 'package:atompay_mobile/core/theme/tokens.dart';
import 'package:atompay_mobile/core/utils/dates.dart';
import 'package:atompay_mobile/core/utils/pk_formatters.dart';
import 'package:atompay_mobile/core/widgets/app_text_field.dart';
import 'package:atompay_mobile/core/widgets/buttons.dart';
import 'package:atompay_mobile/core/widgets/countdown.dart';
import 'package:atompay_mobile/core/widgets/picker_field.dart';
import 'package:atompay_mobile/core/widgets/secure_screen.dart';
import 'package:atompay_mobile/core/widgets/states.dart';
import 'package:atompay_mobile/core/widgets/ui.dart';
import 'package:atompay_mobile/features/profile/data/photo_service.dart';
import 'package:atompay_mobile/features/profile/data/profile_models.dart';
import 'package:atompay_mobile/features/profile/data/profile_repository.dart';
import 'package:atompay_mobile/features/profile/domain/profile_controllers.dart';
import 'package:atompay_mobile/features/profile/presentation/city_picker.dart';
import 'package:atompay_mobile/features/profile/presentation/profile_screen.dart';
import 'package:atompay_mobile/features/profile/presentation/profile_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// KYC section 1 form (handbook §5.7). Loads the profile first so it can
/// pre-fill, then hands off to the form body.
class ProfileFormScreen extends ConsumerWidget {
  const new({super.key, this.thenApply = false});

  /// Continue to the income form after a successful save (banner `apply`).
  final bool thenApply;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final profile = ref.watch(profileProvider);
    return SecureScreen(
      child: Scaffold(
        appBar: AppBar(title: Text(l10n.profileFormTitle)),
        body: switch (profile) {
          AsyncData(:final value) => _ProfileForm(
            initial: value,
            thenApply: thenApply,
          ),
          AsyncError(:final error) => MessageView(
            message: error is ApiException
                ? apiErrorText(l10n, error)
                : l10n.genericError,
            actionLabel: l10n.tryAgain,
            onAction: () => ref.invalidate(profileProvider),
          ),
          _ => const Center(child: CircularProgressIndicator()),
        },
      ),
    );
  }
}

class _ProfileForm extends ConsumerStatefulWidget {
  const new({required this.initial, required this.thenApply});

  final Profile initial;
  final bool thenApply;

  @override
  ConsumerState<_ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends ConsumerState<_ProfileForm> {
  late final Profile _p = widget.initial;
  late final _name = TextEditingController(text: _p.fullName);
  late final _cnic = TextEditingController(text: Pk.formatCnic(_p.cnic));
  late final _mobile = TextEditingController(text: Pk.formatMobile(_p.mobile));
  late final _address = TextEditingController(text: _p.residentialAddress);
  late DateTime? _dob = Dates.parseDate(_p.dateOfBirth);
  late City? _city = _p.city;

  late final PhotoService _photos;

  /// Newly picked images (temp files), by document.
  final Map<ProfileDocument, String> _picked = {};
  Map<String, String?> _local = const {};

  @override
  void initState() {
    super.initState();
    _photos = ref.read(photoServiceProvider);
  }

  @override
  void dispose() {
    _name.dispose();
    _cnic.dispose();
    _mobile.dispose();
    _address.dispose();
    // Unsubmitted photos never linger on disk.
    unawaited(_photos.discard(_picked.values));
    super.dispose();
  }

  bool _hasImage(ProfileDocument d) =>
      _picked.containsKey(d) || _p.documents.of(d).uploaded;

  String? _error(String field) =>
      _local[field] ?? ref.read(profileSubmitControllerProvider).field(field);

  void _edited(String field) {
    ref.read(profileSubmitControllerProvider.notifier).clearField(field);
    if (_local[field] != null) {
      setState(() => _local = {..._local, field: null});
    }
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final latest = DateTime(now.year - 18, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(latest.year - 7),
      firstDate: DateTime(1900),
      lastDate: latest,
      initialEntryMode: DatePickerEntryMode.calendarOnly,
    );
    if (picked != null) {
      setState(() => _dob = picked);
      _edited('date_of_birth');
    }
  }

  Future<void> _pickCity() async {
    final result = await showCityPicker(context, selected: _city);
    if (result == null) return;
    setState(() => _city = result.city);
    _edited('city_id');
  }

  Future<void> _pickPhoto(ProfileDocument doc) async {
    final l10n = context.l10n;
    final camera = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(l10n.useCamera),
              onTap: () => Navigator.of(context).pop(true),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(l10n.chooseFromGallery),
              onTap: () => Navigator.of(context).pop(false),
            ),
          ],
        ),
      ),
    );
    if (camera == null) return;

    final photos = _photos;
    try {
      final path = await photos.pick(doc, camera: camera);
      if (path == null || !mounted) return;
      final old = _picked[doc];
      setState(() => _picked[doc] = path);
      if (old != null) await photos.discard([old]);
      _edited(doc.apiName);
    } on PhotoTooLarge {
      showToast(l10n.photoTooLarge);
    } on Object {
      showToast(l10n.photoFailed);
    }
  }

  Map<String, String?> _validate() {
    final l10n = context.l10n;
    final v = Validators(l10n);
    final dob = _dob;
    return {
      'full_name': v.required(_name.text),
      'cnic': v.cnic(_cnic.text),
      'mobile': v.mobile(_mobile.text),
      'date_of_birth': dob == null
          ? l10n.fieldRequired
          : (isAdult(dob) ? null : l10n.mustBeAdult),
      'residential_address': v.required(_address.text),
      for (final d in ProfileDocument.values)
        d.apiName: _hasImage(d) ? null : l10n.photoRequired,
    };
  }

  Future<void> _submit() async {
    final l10n = context.l10n;
    setState(() => _local = _validate());
    if (_local.values.any((e) => e != null)) {
      showToast(l10n.fixErrorsBelow);
      return;
    }
    if (_p.status == KycStatus.verified) {
      final go = await confirmDialog(
        context,
        title: l10n.verifiedEditTitle,
        message: l10n.verifiedEditWarning,
        confirmLabel: l10n.continueLabel,
      );
      if (!go || !mounted) return;
    }
    FocusScope.of(context).unfocus();

    final files = Map.of(_picked);
    final ok = await ref
        .read(profileSubmitControllerProvider.notifier)
        .submit(
          ProfileInput(
            fullName: _name.text,
            cnic: _cnic.text,
            mobile: _mobile.text,
            dateOfBirth: Dates.api(_dob!),
            residentialAddress: _address.text,
            cityId: _city?.id,
          ),
          files: files,
        );
    if (!ok) {
      if (ref.read(profileSubmitControllerProvider).error is Validation) {
        showToast(l10n.fixErrorsBelow);
      }
      return;
    }
    if (!mounted) return;
    _picked.clear(); // Already deleted by the controller.
    showToast(l10n.profileSubmitted);
    if (widget.thenApply) {
      context.pushReplacement(Routes.application);
    } else {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = context.text;
    final status = ref.watch(profileSubmitControllerProvider);
    final progress = ref.watch(profileUploadProgressProvider);
    final repo = ref.watch(profileRepositoryProvider);

    Widget section(String title) => Padding(
      padding: const EdgeInsets.only(top: Space.x24, bottom: Space.x12),
      child: Text(title, style: text.title),
    );

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              Space.gutter,
              0,
              Space.gutter,
              Space.x24,
            ),
            children: [
              section(l10n.sectionIdentity),
              AppTextField(
                label: l10n.fullNameLabel,
                controller: _name,
                helperText: l10n.fullNameHelper,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                errorText: _error('full_name'),
                onChanged: (_) => _edited('full_name'),
              ),
              const SizedBox(height: Space.x16),
              CnicField(
                label: l10n.cnicLabel,
                controller: _cnic,
                errorText: _error('cnic'),
                onChanged: (_) => _edited('cnic'),
              ),
              const SizedBox(height: Space.x16),
              MobileField(
                label: l10n.mobileLabel,
                controller: _mobile,
                errorText: _error('mobile'),
                onChanged: (_) => _edited('mobile'),
              ),
              const SizedBox(height: Space.x16),
              PickerField(
                label: l10n.dobLabel,
                value: _dob == null ? null : Dates.short(_dob!),
                placeholder: l10n.dobHint,
                icon: Icons.calendar_today_outlined,
                errorText: _error('date_of_birth'),
                onTap: _pickDob,
              ),
              section(l10n.sectionAddress),
              AppTextField(
                label: l10n.addressLabel,
                controller: _address,
                maxLines: 4,
                minLines: 2,
                maxLength: 1000,
                keyboardType: TextInputType.streetAddress,
                textCapitalization: TextCapitalization.sentences,
                errorText: _error('residential_address'),
                onChanged: (_) => _edited('residential_address'),
              ),
              const SizedBox(height: Space.x16),
              PickerField(
                label: '${l10n.cityLabel} · ${l10n.optional}',
                value: _city?.name,
                placeholder: l10n.cityPickerTitle,
                icon: Icons.expand_more,
                errorText: _error('city_id'),
                onTap: _pickCity,
              ),
              section(l10n.sectionDocuments),
              LayoutBuilder(
                builder: (context, c) {
                  final w = (c.maxWidth - Space.x16) / 2;
                  return Wrap(
                    spacing: Space.x16,
                    runSpacing: Space.x20,
                    children: [
                      for (final doc in ProfileDocument.values)
                        SizedBox(width: w, child: _formTile(doc, repo)),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
        _StickySubmit(
          busy: status.busy,
          progress: progress,
          blockedUntil: status.blockedUntil,
          generalError: status.hasGeneralError
              ? apiErrorText(l10n, status.error!)
              : null,
          onSubmit: _submit,
        ),
      ],
    );
  }

  Widget _formTile(ProfileDocument doc, ProfileRepository repo) {
    final l10n = context.l10n;
    final picked = _picked[doc];
    final existing = _p.documents.of(doc).uploaded;
    final has = picked != null || existing;
    return DocumentTile(
      label: documentLabel(l10n, doc),
      uploaded: has,
      statusLabel: has ? l10n.uploaded : l10n.notUploaded,
      errorText: _error(doc.apiName),
      onTap: () => _pickPhoto(doc),
      image: picked != null
          ? Image.file(File(picked), fit: BoxFit.cover)
          : existing
          ? AuthImage(uri: repo.documentUri(doc), headers: repo.authHeaders)
          : null,
      action: TextButton.icon(
        onPressed: () => _pickPhoto(doc),
        icon: Icon(has ? Icons.refresh : Icons.photo_camera_outlined, size: 18),
        label: Text(has ? l10n.retakePhoto : l10n.takePhoto),
      ),
    );
  }
}

class _StickySubmit extends StatelessWidget {
  const new({
    required this.busy,
    required this.progress,
    required this.blockedUntil,
    required this.generalError,
    required this.onSubmit,
  });

  final bool busy;
  final double? progress;
  final DateTime? blockedUntil;
  final String? generalError;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.tokens;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: t.paper,
        border: Border(top: BorderSide(color: t.line)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            Space.gutter,
            Space.x12,
            Space.gutter,
            Space.x12,
          ),
          child: CountdownBuilder(
            until: blockedUntil,
            builder: (context, left) => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (left > 0)
                  FormErrorText(l10n.rateLimited(left))
                else if (generalError != null)
                  FormErrorText(generalError!),
                if (busy && progress != null) ...[
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      l10n.uploading((progress! * 100).round()),
                      style: context.text.bodySmall,
                    ),
                  ),
                  const SizedBox(height: Space.x8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(Radii.pill),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                    ),
                  ),
                  const SizedBox(height: Space.x12),
                ],
                PrimaryButton(
                  label: l10n.submitForReview,
                  loading: busy,
                  onPressed: left > 0 ? null : onSubmit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
