import 'dart:async';

import 'package:atompay_mobile/core/format/dates.dart';
import 'package:atompay_mobile/core/format/input_formatters.dart';
import 'package:atompay_mobile/core/format/money.dart';
import 'package:atompay_mobile/core/format/pk.dart';
import 'package:atompay_mobile/core/network/api_exception.dart';
import 'package:atompay_mobile/core/router/routes.dart';
import 'package:atompay_mobile/core/theme/tokens.dart';
import 'package:atompay_mobile/core/utils/app_clock.dart';
import 'package:atompay_mobile/core/widgets/buttons.dart';
import 'package:atompay_mobile/core/widgets/dialogs.dart';
import 'package:atompay_mobile/core/widgets/fields.dart';
import 'package:atompay_mobile/core/widgets/form_parts.dart';
import 'package:atompay_mobile/core/widgets/picker.dart';
import 'package:atompay_mobile/core/widgets/pressable.dart';
import 'package:atompay_mobile/core/widgets/states.dart';
import 'package:atompay_mobile/core/widgets/ui.dart';
import 'package:atompay_mobile/features/application/application/apply_controller.dart';
import 'package:atompay_mobile/features/application/data/application_models.dart';
import 'package:atompay_mobile/features/application/data/capture_doc.dart';
import 'package:atompay_mobile/features/application/data/kyc_status.dart';
import 'package:atompay_mobile/features/application/presentation/application_widgets.dart';
import 'package:atompay_mobile/features/launch/data/app_config.dart';
import 'package:atompay_mobile/features/launch/data/config_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// The four-step application (brief §9, "Apply"): personal details,
/// identity documents, income, review. Each step is its own page, so back
/// goes to the previous step with everything kept. With [edit], the step
/// was opened from Review and returns there.
class ApplyScreen extends ConsumerStatefulWidget {
  const new({required this.step, this.edit = false, super.key});

  final int step;
  final bool edit;

  @override
  ConsumerState<ApplyScreen> createState() => _ApplyScreenState();
}

class _ApplyScreenState extends ConsumerState<ApplyScreen> {
  Object? _loadError;

  /// Opened on a later step than the draft supports: on the way to the
  /// first incomplete one.
  bool _redirecting = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() => _loadError = null);
    final flow = ref.read(applyFlowProvider.notifier);
    try {
      await flow.load();
    } on Object catch (e) {
      if (mounted) setState(() => _loadError = e);
      return;
    }
    if (!mounted || widget.edit) return;
    // A link can open any step ("apply", Account's income row). Steps are
    // only reachable in order, so start at the first one not done yet.
    final first = flow.firstIncompleteStep();
    if (first < widget.step.clamp(1, 4)) {
      setState(() => _redirecting = true);
      context.replace(Routes.applicationStep(first));
    }
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(applyFlowProvider);
    final step = widget.step.clamp(1, 4);
    final title = draft.isReview
        ? 'Request a limit review'
        : 'Apply for your limit';
    Widget body;
    if (_loadError != null) {
      body = ErrorStateView(error: _loadError!, onRetry: _load);
    } else if (!draft.loaded || _redirecting) {
      body = const LoadingShape(
        label: 'Loading your details',
        child: Padding(
          padding: EdgeInsets.all(Space.gutter),
          child: Column(
            children: [SkeletonCard(), Gap.s14, SkeletonCard(lines: 5)],
          ),
        ),
      );
    } else {
      body = switch (step) {
        1 => _PersonalStep(edit: widget.edit),
        2 => _DocumentsStep(edit: widget.edit),
        3 => _IncomeStep(edit: widget.edit),
        _ => const _ReviewStep(),
      };
    }
    // Leaving the wizard from its first page asks before dropping edits.
    final first = step == 1 && !widget.edit;
    return FormExitGuard(
      dirty: first && draft.dirty,
      busy: false,
      child: Scaffold(
        backgroundColor: context.colors.surface,
        // Canvas `.topw`: the bar and the step progress share one white
        // header, with the hairline under the progress.
        appBar: AppTopBar(title: title, bottomBorder: false),
        body: Column(
          children: [
            _StepBar(step: step),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }
}

const _stepNames = [
  'Personal details',
  'Identity documents',
  'Income & financials',
  'Review & submit',
];

/// Canvas wizard progress, in the white header under the app bar: four
/// bars (done green, current royal), then "Step 1 of 4" and the step name.
class _StepBar extends StatelessWidget {
  const new({required this.step});

  final int step;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final name = _stepNames[step - 1];
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: c.white,
        border: Border(bottom: BorderSide(color: c.line)),
      ),
      padding: const EdgeInsets.fromLTRB(
        Space.gutter,
        0,
        Space.gutter,
        Space.s14,
      ),
      child: Semantics(
        label: 'Step $step of 4, $name',
        excludeSemantics: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                for (var i = 1; i <= 4; i++) ...[
                  if (i > 1) const SizedBox(width: Space.s6),
                  Expanded(
                    child: Container(
                      height: 6,
                      decoration: BoxDecoration(
                        color: i < step
                            ? c.green
                            : (i == step ? c.primary : c.line),
                        borderRadius: BorderRadius.circular(Radii.pill),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            Gap.s8,
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Step $step of 4', style: t.tiny),
                const SizedBox(width: Space.s12),
                Expanded(
                  child: Text(
                    name,
                    textAlign: TextAlign.right,
                    style: t.tiny.copyWith(
                      color: c.ink,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The step's heading and its one-line explanation.
class _StepHeader extends StatelessWidget {
  const new({required this.title, required this.lead});

  final String title;
  final String lead;

  @override
  Widget build(BuildContext context) {
    final t = context.text;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(header: true, child: Text(title, style: t.h2)),
        Gap.s6,
        Text(lead, style: t.small),
        Gap.s16,
      ],
    );
  }
}

/// Back and Continue under each step (canvas `.actionbar`: Back at its
/// natural width, Continue takes the rest).
class _StepFooter extends StatelessWidget {
  const new({
    required this.onContinue,
    this.continueLabel = 'Continue',
    this.showBack = true,
  });

  final VoidCallback onContinue;
  final String continueLabel;
  final bool showBack;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      if (showBack) ...[
        AppButton.ghost(
          'Back',
          large: true,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        const SizedBox(width: Space.s10),
      ],
      Expanded(
        child: AppButton.primary(
          continueLabel,
          large: true,
          block: true,
          onPressed: onContinue,
        ),
      ),
    ],
  );
}

/// Moves on, or back to Review when the step was opened to edit.
void _next(BuildContext context, int step, {required bool edit}) {
  if (edit) {
    context.pop();
  } else {
    unawaited(context.push(Routes.applicationStep(step + 1)));
  }
}

// ---- step 1: personal details ----------------------------------------------

class _PersonalStep extends ConsumerStatefulWidget {
  const new({required this.edit});

  final bool edit;

  @override
  ConsumerState<_PersonalStep> createState() => _PersonalStepState();
}

class _PersonalStepState extends ConsumerState<_PersonalStep> {
  late final TextEditingController _name;
  late final TextEditingController _cnic;
  late final TextEditingController _mobile;
  late final TextEditingController _address;
  final _focus = {
    for (final f in ApplyFields.step1) f: FocusNode(debugLabel: f),
  };

  ApplyFlow get _flow => ref.read(applyFlowProvider.notifier);

  @override
  void initState() {
    super.initState();
    final d = ref.read(applyFlowProvider);
    _name = TextEditingController(text: d.fullName);
    _cnic = TextEditingController(text: d.cnic);
    _mobile = TextEditingController(text: d.mobile);
    _address = TextEditingController(text: d.address);
  }

  @override
  void dispose() {
    for (final c in [_name, _cnic, _mobile, _address]) {
      c.dispose();
    }
    for (final f in _focus.values) {
      f.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate() async {
    final d = ref.read(applyFlowProvider);
    final now = AppClock.now();
    final latest = DateTime(now.year - 18, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: d.dateOfBirth ?? DateTime(latest.year - 10),
      firstDate: DateTime(1920),
      lastDate: latest,
      initialEntryMode: DatePickerEntryMode.calendarOnly,
      helpText: 'Date of birth',
    );
    if (picked != null) {
      _flow.update(
        (x) => x.copyWith(dateOfBirth: picked),
        field: 'date_of_birth',
      );
    }
  }

  void _continue(bool cityHasAreas) {
    final errors = _flow.check(1, cityHasAreas: cityHasAreas);
    if (errors.isEmpty) {
      _next(context, 1, edit: widget.edit);
      return;
    }
    for (final f in ApplyFields.step1) {
      if (errors.containsKey(f)) {
        _focus[f]!.requestFocus();
        break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(applyFlowProvider);
    final cities = ref.watch(citiesProvider);
    final cityId = d.city?.id;
    final areas = cityId == null ? null : ref.watch(areasProvider(cityId));
    final areaList = areas?.value ?? const <Place>[];
    final cityHasAreas = areaList.isNotEmpty;
    final cityName = d.city?.name;

    return FormPage(
      footer: _StepFooter(
        showBack: false,
        continueLabel: widget.edit ? 'Save' : 'Continue',
        onContinue: () => _continue(cityHasAreas),
      ),
      children: [
        const _StepHeader(
          title: 'Personal details',
          lead:
              'Enter these exactly as they appear on your CNIC — the visit '
              'team checks them against the card.',
        ),
        AppTextField(
          label: 'Full name',
          controller: _name,
          focusNode: _focus['full_name'],
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.name],
          error: d.errors['full_name'],
          onChanged: (v) =>
              _flow.update((x) => x.copyWith(fullName: v), field: 'full_name'),
        ),
        Gap.s14,
        AppTextField(
          label: 'CNIC number',
          controller: _cnic,
          focusNode: _focus['cnic'],
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.next,
          inputFormatters: [CnicInputFormatter()],
          hint: '13 digits. The dashes are added for you.',
          error: d.errors['cnic'],
          onChanged: (v) =>
              _flow.update((x) => x.copyWith(cnic: v), field: 'cnic'),
        ),
        Gap.s14,
        TwoUp(
          first: AppTextField(
            label: 'Mobile number',
            controller: _mobile,
            focusNode: _focus['mobile'],
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.telephoneNumber],
            error: d.errors['mobile'],
            onChanged: (v) =>
                _flow.update((x) => x.copyWith(mobile: v), field: 'mobile'),
          ),
          second: _DateField(
            label: 'Date of birth',
            value: d.dateOfBirth,
            error: d.errors['date_of_birth'],
            focusNode: _focus['date_of_birth'],
            onTap: _pickDate,
          ),
        ),
        Gap.s14,
        PickerField<int>(
          label: 'City',
          sheetTitle: 'Choose your city',
          searchPlaceholder: 'Type to search, e.g. Multan',
          noun: 'cities',
          focusNode: _focus['city_id'],
          loading: cities.isLoading && !cities.hasValue,
          options: [
            for (final c in cities.value ?? const <Place>[])
              PickerOption(c.id, c.name),
          ],
          value: cityId,
          error:
              d.errors['city_id'] ??
              (cities.hasError && !cities.hasValue
                  ? "We couldn't load the cities. Pull down or try again."
                  : null),
          onChanged: (id) {
            final city = cities.value?.firstWhere((c) => c.id == id);
            if (city != null) _flow.setCity(city);
          },
        ),
        Gap.s14,
        PickerField<int>(
          label: 'Area',
          sheetTitle: 'Choose your area',
          searchPlaceholder: 'Type to search, e.g. DHA',
          noun: cityName == null ? 'areas' : 'areas in $cityName',
          searchIcon: areaList.isNotEmpty,
          focusNode: _focus['area_id'],
          placeholder: areaList.isEmpty
              ? 'Choose'
              : 'Search ${areaList.length} areas in $cityName',
          disabledText: cityId == null
              ? 'Choose a city first'
              : (areas!.hasValue && areaList.isEmpty
                    ? 'No areas listed for $cityName'
                    : null),
          loading: areas?.isLoading ?? false,
          options: [for (final a in areaList) PickerOption(a.id, a.name)],
          value: d.area?.id,
          error: d.errors['area_id'],
          onChanged: (id) {
            final area = areaList.firstWhere((a) => a.id == id);
            _flow.update((x) => x.copyWith(area: area), field: 'area_id');
          },
        ),
        if (cityName != null) ...[
          Gap.s6,
          Text(
            'Helps us deliver to the right part of $cityName.',
            // Canvas `.field .hint`, as under every field.
            style: context.text.tiny.copyWith(fontWeight: FontWeight.w500),
          ),
        ],
        Gap.s14,
        AppTextField(
          label: 'Residential address',
          controller: _address,
          focusNode: _focus['residential_address'],
          maxLines: 3,
          minLines: 2,
          textCapitalization: TextCapitalization.words,
          autofillHints: const [AutofillHints.fullStreetAddress],
          error: d.errors['residential_address'],
          onChanged: (v) => _flow.update(
            (x) => x.copyWith(address: v),
            field: 'residential_address',
          ),
        ),
      ],
    );
  }
}

/// Looks like a picker; opens the date picker (brief §6: date of birth is
/// a date picker, not a list).
class _DateField extends StatelessWidget {
  const new({
    required this.label,
    required this.value,
    required this.onTap,
    this.error,
    this.focusNode,
  });

  final String label;
  final DateTime? value;
  final VoidCallback onTap;
  final String? error;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final shown = value == null ? 'Choose' : dayMonthYear(value!);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ExcludeSemantics(child: Text(label, style: t.label)),
        Gap.s6,
        Pressable(
          onTap: onTap,
          focusNode: focusNode,
          scaleOnPress: false,
          borderRadius: BorderRadius.circular(Radii.input),
          semanticLabel: '$label, ${value == null ? 'not chosen' : shown}',
          excludeChildSemantics: true,
          child: Container(
            constraints: const BoxConstraints(minHeight: Sizes.target),
            padding: const EdgeInsets.symmetric(horizontal: Space.s14),
            decoration: BoxDecoration(
              color: error != null ? c.dangerWash : c.field,
              borderRadius: BorderRadius.circular(Radii.input),
              border: Border.all(color: error != null ? c.danger : c.line2),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    shown,
                    style: t.body.copyWith(
                      color: value == null ? c.muted : c.ink,
                    ),
                  ),
                ),
                Icon(Icons.calendar_today_outlined, size: 18, color: c.body),
              ],
            ),
          ),
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: Space.s6),
            child: Semantics(
              liveRegion: true,
              child: Text(error!, style: t.small.copyWith(color: c.rose)),
            ),
          ),
      ],
    );
  }
}

// ---- step 2: identity documents --------------------------------------------

class _DocumentsStep extends ConsumerWidget {
  const new({required this.edit});

  final bool edit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(applyFlowProvider);
    final flow = ref.read(applyFlowProvider.notifier);

    Future<void> capture(CaptureDoc doc) async {
      final bytes = await context.push<Uint8List>(Routes.capture(doc.key));
      if (bytes != null) flow.setPhoto(doc, bytes);
    }

    Widget tile(CaptureDoc doc) => _DocTile(
      doc: doc,
      taken: d.photos.containsKey(doc),
      onFile: d.profile?.uploaded(doc.key) ?? false,
      error: d.errors[doc.key],
      onTap: () => capture(doc),
    );

    return FormPage(
      footer: _StepFooter(
        continueLabel: edit ? 'Save' : 'Continue',
        showBack: !edit,
        onContinue: () {
          if (flow.check(2, cityHasAreas: false).isEmpty) {
            _next(context, 2, edit: edit);
          }
        },
      ),
      children: [
        const _StepHeader(
          title: 'Identity documents',
          lead:
              'Taken with the camera here — we never open your gallery. '
              'Clear, well-lit, all four corners visible. Stored privately and '
              'seen only by the verification team.',
        ),
        // Canvas `.docs`: CNIC front and back side by side, then the
        // selfie across the full width.
        TwoUp(
          first: tile(CaptureDoc.cnicFront),
          second: tile(CaptureDoc.cnicBack),
        ),
        Gap.s12,
        tile(CaptureDoc.selfie),
        Gap.s16,
        const Note(
          tone: NoteTone.blue,
          icon: Icons.verified_user_outlined,
          text:
              'Your documents are used only to verify your identity for '
              'AtomPay and are never shown on Atomshop.',
        ),
      ],
    );
  }
}

/// Canvas `.doc`: a dashed tile to photograph one document; solid green
/// once taken (or already on file).
class _DocTile extends StatelessWidget {
  const new({
    required this.doc,
    required this.taken,
    required this.onFile,
    required this.onTap,
    this.error,
  });

  final CaptureDoc doc;
  final bool taken;
  final bool onFile;
  final VoidCallback onTap;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final hasError = error != null;
    // A photo with an error (say the server refused it) isn't done.
    final done = (taken || onFile) && !hasError;
    final summary = !done
        ? (doc == CaptureDoc.selfie
              ? 'Hold your CNIC next to your face'
              : 'Tap to take a photo')
        : taken
        ? 'Taken · tap to retake'
        : 'On file · tap to replace';
    final radius = BorderRadius.circular(Radii.note);
    // Dashed while empty; a solid edge once taken or when in error.
    final solid = done || hasError;
    final box = Container(
      constraints: const BoxConstraints(minHeight: 150),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(Space.s16),
      decoration: BoxDecoration(
        color: hasError ? c.dangerWash : (done ? c.greenWash : c.surface2),
        borderRadius: radius,
        border: solid
            ? Border.all(color: hasError ? c.danger : c.greenLine, width: 1.5)
            : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: c.white,
              borderRadius: BorderRadius.circular(Radii.tile),
            ),
            child: Icon(
              done
                  ? Icons.check
                  : (doc == CaptureDoc.selfie
                        ? Icons.person_outline
                        : Icons.photo_camera_outlined),
              size: 22,
              color: done ? c.green : c.body,
            ),
          ),
          Gap.s8,
          Text(
            doc.title,
            textAlign: TextAlign.center,
            style: t.base.copyWith(color: c.ink, fontWeight: FontWeight.w700),
          ),
          Text(
            summary,
            textAlign: TextAlign.center,
            style: t.tiny.copyWith(fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Pressable(
          onTap: onTap,
          scaleOnPress: false,
          borderRadius: radius,
          pressedColor: c.primarySoft,
          semanticLabel:
              '${doc.title}, ${done ? 'done' : 'not taken'}. $summary',
          excludeChildSemantics: true,
          child: solid
              ? box
              : CustomPaint(
                  foregroundPainter: DashedOutlinePainter(
                    color: c.line3,
                    radius: Radii.note,
                  ),
                  child: box,
                ),
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: Space.s6),
            child: Semantics(
              liveRegion: true,
              child: Text(error!, style: t.small.copyWith(color: c.rose)),
            ),
          ),
      ],
    );
  }
}

// ---- step 3: income ---------------------------------------------------------

class _IncomeStep extends ConsumerStatefulWidget {
  const new({required this.edit});

  final bool edit;

  @override
  ConsumerState<_IncomeStep> createState() => _IncomeStepState();
}

class _IncomeStepState extends ConsumerState<_IncomeStep> {
  late final TextEditingController _employer;
  late final TextEditingController _income;
  late final TextEditingController _existing;
  late final TextEditingController _expenses;
  final _focus = {
    for (final f in ApplyFields.step3) f: FocusNode(debugLabel: f),
  };
  Timer? _debounce;
  int? _estimateFor;

  ApplyFlow get _flow => ref.read(applyFlowProvider.notifier);

  @override
  void initState() {
    super.initState();
    final d = ref.read(applyFlowProvider);
    String money(int? v) => v == null ? '' : grouped(v);
    _employer = TextEditingController(text: d.employer);
    _income = TextEditingController(text: money(d.income));
    _existing = TextEditingController(text: money(d.existing));
    _expenses = TextEditingController(text: money(d.expenses));
    _estimateFor = d.income;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    for (final c in [_employer, _income, _existing, _expenses]) {
      c.dispose();
    }
    for (final f in _focus.values) {
      f.dispose();
    }
    super.dispose();
  }

  void _onIncome(String text) {
    final v = parseRupees(text);
    _flow.update(
      (x) => v == null ? x.copyWith(clearIncome: true) : x.copyWith(income: v),
      field: 'monthly_income',
    );
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (mounted) setState(() => _estimateFor = v);
    });
  }

  void _continue(FormOptions options) {
    final d = ref.read(applyFlowProvider);
    final needsEmployer = options.employmentStatuses
        .where((e) => e.value == d.employment)
        .any((e) => e.hasEmployer);
    final errors = _flow.check(3, cityHasAreas: false);
    if (needsEmployer && d.employer.trim().isEmpty) {
      errors['employer_name'] = 'Enter the name of your employer or business.';
      _flow.setErrors({...ref.read(applyFlowProvider).errors, ...errors});
    }
    if (errors.isEmpty) {
      _next(context, 3, edit: widget.edit);
      return;
    }
    for (final f in ApplyFields.step3) {
      if (errors.containsKey(f)) {
        _focus[f]!.requestFocus();
        break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(applyFlowProvider);
    final options = ref.watch(formOptionsProvider);
    final opts = options.value ?? const FormOptions();
    final employment = opts.employmentStatuses
        .where((e) => e.value == d.employment)
        .firstOrNull;
    final estimateFor = _estimateFor;
    final estimate = estimateFor == null || estimateFor < 1000
        ? null
        : ref.watch(estimateProvider(estimateFor));

    return FormPage(
      footer: _StepFooter(
        continueLabel: widget.edit ? 'Save' : 'Continue',
        showBack: !widget.edit,
        onContinue: () => _continue(opts),
      ),
      children: [
        const _StepHeader(
          title: 'Income & financial profile',
          lead:
              'Honest figures get you the right limit — they are checked '
              'during verification.',
        ),
        TwoUp(
          first: PickerField<String>(
            label: 'Employment status',
            sheetTitle: 'Employment status',
            searchPlaceholder: 'Search, e.g. retired',
            noun: 'options',
            focusNode: _focus['employment_status'],
            loading: options.isLoading && !options.hasValue,
            options: [
              for (final e in opts.employmentStatuses)
                PickerOption(e.value, e.label),
            ],
            value: d.employment,
            error: d.errors['employment_status'],
            onChanged: (v) => _flow.update(
              (x) => x.copyWith(employment: v),
              field: 'employment_status',
            ),
          ),
          second: PickerField<String>(
            label: 'Income source',
            sheetTitle: 'Main income source',
            searchPlaceholder: 'Search, e.g. rental',
            noun: 'options',
            focusNode: _focus['income_source'],
            loading: options.isLoading && !options.hasValue,
            options: [
              for (final e in opts.incomeSources)
                PickerOption(e.value, e.label),
            ],
            value: d.source,
            error: d.errors['income_source'],
            onChanged: (v) => _flow.update(
              (x) => x.copyWith(source: v),
              field: 'income_source',
            ),
          ),
        ),
        if (employment?.hasEmployer ?? false) ...[
          Gap.s14,
          AppTextField(
            label: 'Employer or business name',
            controller: _employer,
            focusNode: _focus['employer_name'],
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            hint: 'Asked because you are ${employment!.label.toLowerCase()}.',
            error: d.errors['employer_name'],
            onChanged: (v) => _flow.update(
              (x) => x.copyWith(employer: v),
              field: 'employer_name',
            ),
          ),
        ],
        Gap.s14,
        _MoneyField(
          label: 'Monthly income',
          controller: _income,
          focusNode: _focus['monthly_income'],
          error: d.errors['monthly_income'],
          onChanged: _onIncome,
        ),
        Gap.s14,
        TwoUp(
          first: _MoneyField(
            label: 'Existing instalments',
            controller: _existing,
            focusNode: _focus['existing_instalments'],
            error: d.errors['existing_instalments'],
            onChanged: (t) {
              final v = parseRupees(t);
              _flow.update(
                (x) => v == null
                    ? x.copyWith(clearExisting: true)
                    : x.copyWith(existing: v),
                field: 'existing_instalments',
              );
            },
          ),
          second: _MoneyField(
            label: 'Household expenses',
            controller: _expenses,
            focusNode: _focus['monthly_expenses'],
            error: d.errors['monthly_expenses'],
            onChanged: (t) {
              final v = parseRupees(t);
              _flow.update(
                (x) => v == null
                    ? x.copyWith(clearExpenses: true)
                    : x.copyWith(expenses: v),
                field: 'monthly_expenses',
              );
            },
          ),
        ),
        if (estimate != null) ...[Gap.s16, _EstimateCard(estimate: estimate)],
      ],
    );
  }
}

class _MoneyField extends StatelessWidget {
  const new({
    required this.label,
    required this.controller,
    required this.onChanged,
    this.focusNode,
    this.error,
  });

  final String label;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final FocusNode? focusNode;
  final String? error;

  @override
  Widget build(BuildContext context) => AppTextField(
    label: label,
    controller: controller,
    focusNode: focusNode,
    prefixText: 'Rs. ',
    error: error,
    keyboardType: TextInputType.number,
    textInputAction: TextInputAction.next,
    inputFormatters: [
      FilteringTextInputFormatter.digitsOnly,
      LengthLimitingTextInputFormatter(9),
      GroupedDigitsFormatter(),
    ],
    onChanged: onChanged,
  );
}

/// `POST /estimate`, shown as the canvas's provisional limit.
class _EstimateCard extends StatelessWidget {
  const new({required this.estimate});

  final AsyncValue<Estimate> estimate;

  @override
  Widget build(BuildContext context) {
    final e = estimate.value;
    if (e == null) {
      return estimate.hasError
          ? const SizedBox.shrink()
          : const LoadingShape(
              label: 'Working out an estimate',
              child: SkeletonCard(height: 120),
            );
    }
    return ProvisionalLimitCard(
      label: 'Provisional purchase limit',
      limit: e.estimatedLimit,
      monthlyCap: e.estimatedMaxInstalment,
    );
  }
}

// ---- step 4: review ---------------------------------------------------------

class _ReviewStep extends ConsumerStatefulWidget {
  const new();

  @override
  ConsumerState<_ReviewStep> createState() => _ReviewStepState();
}

class _ReviewStepState extends ConsumerState<_ReviewStep> {
  bool _declared = false;

  Future<void> _submit() async {
    final outcome = await ref.read(submitApplicationProvider.notifier).submit();
    if (!mounted) return;
    switch (outcome) {
      case SubmitOutcome.sent:
        showToast('Application sent');
        // The wizard is removed; back from the status screen goes Home.
        context.go(Routes.applicationStatus);
      case SubmitOutcome.fixStep1:
        unawaited(context.push(Routes.applicationEdit(1)));
      case SubmitOutcome.fixStep2:
        unawaited(context.push(Routes.applicationEdit(2)));
      case SubmitOutcome.fixStep3:
        unawaited(context.push(Routes.applicationEdit(3)));
      case SubmitOutcome.failed:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(applyFlowProvider);
    final status = ref.watch(submitApplicationProvider);
    final offline = ref.watch(isOfflineProvider);
    final options = ref.watch(formOptionsProvider).value ?? const FormOptions();
    final t = context.text;
    final employmentLabel =
        options.employmentStatuses
            .where((o) => o.value == d.employment)
            .firstOrNull
            ?.label ??
        d.employment ??
        '';
    final sourceLabel =
        options.incomeSources
            .where((o) => o.value == d.source)
            .firstOrNull
            ?.label ??
        d.source ??
        '';
    final work = [
      employmentLabel,
      if (d.employer.trim().isNotEmpty) d.employer.trim(),
    ].join(' · ');

    Widget section(String title, int step, Widget body) => AppCard(
      // Canvas `.card.u-pad-row`.
      padding: const EdgeInsets.symmetric(
        horizontal: Space.s18,
        vertical: Space.s16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(
            title,
            action: 'Edit',
            onAction: () => context.push(Routes.applicationEdit(step)),
          ),
          Gap.s12,
          body,
        ],
      ),
    );

    final verifiedChange =
        d.profile?.kyc == KycStatus.verified && d.identityChanged;

    return FormExitGuard(
      dirty: false,
      busy: status.busy,
      child: FormPage(
        footer: SubmitSection(
          label: !_declared
              ? 'Tick the declaration to submit'
              // The server couldn't scan a photo just now: same form, same
              // photos, its message in the note above.
              : status.error is CheckUnavailable
              ? 'Try again'
              : (d.isReview ? 'Request limit review' : 'Submit application'),
          status: status,
          offline: offline,
          enabled: _declared,
          onSubmit: _submit,
          onRetryReady: () => setState(() {}),
        ),
        children: [
          const _StepHeader(
            title: 'Review & submit',
            lead:
                'Check everything once — you can jump back to any step to '
                'change it.',
          ),
          section(
            'Personal details',
            1,
            KeyValueList([
              KeyValue('Name', d.fullName),
              KeyValue('CNIC', Pk.formatCnic(d.cnic)),
              KeyValue('Mobile', Pk.formatMobile(d.mobile)),
              KeyValue(
                'Born',
                d.dateOfBirth == null ? '' : dayMonthYear(d.dateOfBirth!),
              ),
              KeyValue(
                'City · Area',
                [?d.city?.name, ?d.area?.name].join(' · '),
              ),
              KeyValue('Address', d.address),
            ]),
          ),
          Gap.s12,
          section(
            'Identity documents',
            2,
            Wrap(
              spacing: Space.s8,
              runSpacing: Space.s8,
              children: [
                for (final doc in CaptureDoc.values)
                  if (d.hasPhoto(doc))
                    AppBadge.green(
                      doc == CaptureDoc.selfie ? 'Selfie' : doc.title,
                    )
                  else
                    AppBadge.rose(
                      doc == CaptureDoc.selfie ? 'Selfie' : doc.title,
                    ),
              ],
            ),
          ),
          Gap.s12,
          section(
            'Income & financials',
            3,
            KeyValueList([
              KeyValue('Work', work),
              KeyValue(
                'Income',
                '${rs(d.income ?? 0)} · ${sourceLabel.toLowerCase()}',
                spoken: rsSpoken(d.income ?? 0),
              ),
              KeyValue(
                'Instalments',
                rs(d.existing ?? 0),
                spoken: rsSpoken(d.existing ?? 0),
              ),
              KeyValue(
                'Expenses',
                rs(d.expenses ?? 0),
                spoken: rsSpoken(d.expenses ?? 0),
              ),
            ]),
          ),
          if (verifiedChange) ...[
            Gap.s12,
            const Note(
              tone: NoteTone.amber,
              text:
                  'You changed details we have already verified. Your identity '
                  'will be checked again, and your limit stays as it is '
                  'meanwhile.',
            ),
          ],
          Gap.s12,
          ConsentRow(
            value: _declared,
            onChanged: status.busy
                ? null
                : (v) => setState(() => _declared = v),
            child: Text(
              'I confirm these details are accurate and I authorise AtomPay '
              'to verify them, including a one-time visit to my residential '
              'address, for the purpose of setting my purchase limit.',
              style: t.base,
            ),
          ),
        ],
      ),
    );
  }
}
