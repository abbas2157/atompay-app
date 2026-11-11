import 'dart:async';

import 'package:atompay_mobile/core/format/dates.dart';
import 'package:atompay_mobile/core/format/input_formatters.dart';
import 'package:atompay_mobile/core/format/money.dart';
import 'package:atompay_mobile/core/format/pk.dart';
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

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() => _loadError = null);
    try {
      await ref.read(applyFlowProvider.notifier).load();
    } on Object catch (e) {
      if (mounted) setState(() => _loadError = e);
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
    } else if (!draft.loaded) {
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
        backgroundColor: context.colors.white,
        appBar: AppTopBar(title: title, bottomBorder: true),
        body: body,
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

/// "Step 1 of 4 · Personal details", a four-part bar and the heading.
class _StepHeader extends StatelessWidget {
  const new({required this.step, required this.title, required this.lead});

  final int step;
  final String title;
  final String lead;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          label: 'Step $step of 4, ${_stepNames[step - 1]}',
          excludeSemantics: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'STEP $step OF 4 · ${_stepNames[step - 1].toUpperCase()}',
                style: t.eyebrow,
              ),
              Gap.s8,
              Row(
                children: [
                  for (var i = 1; i <= 4; i++) ...[
                    if (i > 1) const SizedBox(width: Space.s4),
                    Expanded(
                      child: Container(
                        height: 4,
                        decoration: BoxDecoration(
                          color: i <= step ? c.primary : c.line,
                          borderRadius: BorderRadius.circular(Radii.pill),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        Gap.s20,
        Semantics(header: true, child: Text(title, style: t.h2)),
        Gap.s8,
        Text(lead, style: t.lead),
        Gap.s20,
      ],
    );
  }
}

/// Back and Continue under each step.
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
        Expanded(
          child: AppButton.ghost(
            'Back',
            large: true,
            block: true,
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ),
        const SizedBox(width: Space.s12),
      ],
      Expanded(
        flex: 2,
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
          step: 1,
          title: 'Personal details',
          lead:
              'Enter these exactly as they appear on your CNIC. The visit team '
              'checks them against the card.',
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
        AppTextField(
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
        Gap.s14,
        _DateField(
          label: 'Date of birth',
          value: d.dateOfBirth,
          error: d.errors['date_of_birth'],
          focusNode: _focus['date_of_birth'],
          onTap: _pickDate,
        ),
        Gap.s14,
        PickerField<int>(
          label: 'City',
          sheetTitle: 'Choose your city',
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
          sheetTitle: cityName == null
              ? 'Choose your area'
              : 'Areas in $cityName',
          noun: cityName == null ? 'areas' : 'areas in $cityName',
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
            style: context.text.small,
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
                Icon(Icons.calendar_today_outlined, size: 18, color: c.ink),
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
          step: 2,
          title: 'Identity documents',
          lead:
              'Taken with the camera here: we never open your gallery. Clear, '
              'well-lit, all four corners visible. Stored privately and seen '
              'only by the verification team.',
        ),
        for (final doc in CaptureDoc.values) ...[
          _DocRow(
            doc: doc,
            taken: d.photos.containsKey(doc),
            onFile: d.profile?.uploaded(doc.key) ?? false,
            error: d.errors[doc.key],
            onTap: () => capture(doc),
          ),
          Gap.s12,
        ],
        Gap.s4,
        const Note(
          tone: NoteTone.blue,
          text:
              'Your documents are used only to verify your identity for '
              'AtomPay and are never shown on Atomshop.',
        ),
      ],
    );
  }
}

class _DocRow extends StatelessWidget {
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
    final done = taken || onFile;
    final summary = taken
        ? 'Taken · tap to retake'
        : onFile
        ? 'On file · tap to replace'
        : doc == CaptureDoc.selfie
        ? 'Hold your CNIC next to your face'
        : 'Tap to take a photo';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Pressable(
          onTap: onTap,
          scaleOnPress: false,
          borderRadius: BorderRadius.circular(Radii.row),
          pressedColor: c.primarySoft,
          semanticLabel:
              '${doc.title}, ${done ? 'done' : 'not taken'}. $summary',
          excludeChildSemantics: true,
          child: Container(
            padding: const EdgeInsets.all(Space.s14),
            decoration: BoxDecoration(
              color: done ? c.greenWash : c.field,
              borderRadius: BorderRadius.circular(Radii.row),
              border: Border.all(
                color: error != null
                    ? c.danger
                    : (done ? c.greenLine : c.line2),
              ),
            ),
            child: Row(
              children: [
                IconTile(
                  done
                      ? Icons.check
                      : (doc == CaptureDoc.selfie
                            ? Icons.face_outlined
                            : Icons.badge_outlined),
                  tone: done ? TileTone.green : TileTone.blue,
                ),
                const SizedBox(width: Space.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        doc.title,
                        style: t.body.copyWith(fontWeight: FontWeight.w700),
                      ),
                      Text(summary, style: t.small),
                    ],
                  ),
                ),
                Icon(Icons.photo_camera_outlined, color: c.ink),
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
          step: 3,
          title: 'Income & financial profile',
          lead:
              'Honest figures get you the right limit. They are checked during '
              'verification.',
        ),
        PickerField<String>(
          label: 'Employment status',
          sheetTitle: 'Employment status',
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
        Gap.s14,
        PickerField<String>(
          label: 'Income source',
          sheetTitle: 'Income source',
          noun: 'options',
          focusNode: _focus['income_source'],
          loading: options.isLoading && !options.hasValue,
          options: [
            for (final e in opts.incomeSources) PickerOption(e.value, e.label),
          ],
          value: d.source,
          error: d.errors['income_source'],
          onChanged: (v) => _flow.update(
            (x) => x.copyWith(source: v),
            field: 'income_source',
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
        _MoneyField(
          label: 'Existing instalments',
          hint: 'What you pay each month on other loans or instalments.',
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
        Gap.s14,
        _MoneyField(
          label: 'Household expenses',
          hint: 'A month.',
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
        if (estimate != null) ...[Gap.s20, _EstimateCard(estimate: estimate)],
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
    this.hint,
    this.error,
  });

  final String label;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final FocusNode? focusNode;
  final String? hint;
  final String? error;

  @override
  Widget build(BuildContext context) => AppTextField(
    label: label,
    controller: controller,
    focusNode: focusNode,
    prefixText: 'Rs. ',
    hint: hint,
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

/// `POST /estimate`, always labelled as an estimate.
class _EstimateCard extends StatelessWidget {
  const new({required this.estimate});

  final AsyncValue<Estimate> estimate;

  @override
  Widget build(BuildContext context) {
    final t = context.text;
    final c = context.colors;
    final e = estimate.value;
    if (e == null) {
      return estimate.hasError
          ? const SizedBox.shrink()
          : const LoadingShape(
              label: 'Working out an estimate',
              child: SkeletonCard(height: 120),
            );
    }
    return AppCard(
      color: c.primarySoft,
      borderColor: c.primaryLine,
      semanticLabel:
          'Estimated purchase limit ${rsSpoken(e.estimatedLimit)}, up to '
          '${rsSpoken(e.estimatedMaxInstalment)} a month. An estimate; '
          'final figures are set by our team after the risk assessment.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ESTIMATED PURCHASE LIMIT',
            style: t.tiny.copyWith(
              color: c.primary,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
          Gap.s6,
          Text(rs(e.estimatedLimit), style: t.h1b),
          Gap.s4,
          Text(
            'Up to ${rs(e.estimatedMaxInstalment)} a month · 30% of '
            'income',
            style: t.small.copyWith(color: c.ink),
          ),
          Gap.s8,
          Text(
            'An estimate from your income. Final figures are set by our team '
            'after the risk assessment.',
            style: t.small,
          ),
        ],
      ),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(
            title,
            action: 'Edit',
            onAction: () => context.push(Routes.applicationEdit(step)),
          ),
          Gap.s8,
          body,
        ],
      ),
    );

    final verifiedChange = d.profile?.status == 'verified' && d.identityChanged;

    return FormExitGuard(
      dirty: false,
      busy: status.busy,
      child: FormPage(
        footer: SubmitSection(
          label: !_declared
              ? 'Tick the declaration to submit'
              : (d.isReview ? 'Request limit review' : 'Submit application'),
          status: status,
          offline: offline,
          enabled: _declared,
          onSubmit: _submit,
          onRetryReady: () => setState(() {}),
        ),
        children: [
          const _StepHeader(
            step: 4,
            title: 'Review & submit',
            lead:
                'Check everything once. You can jump back to any step to '
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
          Gap.s14,
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
                      icon: Icons.check,
                    )
                  else
                    AppBadge.rose(
                      doc == CaptureDoc.selfie ? 'Selfie' : doc.title,
                    ),
              ],
            ),
          ),
          Gap.s14,
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
            Gap.s14,
            const Note(
              tone: NoteTone.amber,
              text:
                  'You changed details we have already verified. Your identity '
                  'will be checked again, and your limit stays as it is '
                  'meanwhile.',
            ),
          ],
          Gap.s16,
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
