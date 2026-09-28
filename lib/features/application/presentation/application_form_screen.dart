import 'package:atompay_mobile/core/forms/submit_section.dart';
import 'package:atompay_mobile/core/network/api_exception.dart';
import 'package:atompay_mobile/core/router/routes.dart';
import 'package:atompay_mobile/core/theme/tokens.dart';
import 'package:atompay_mobile/core/utils/money.dart';
import 'package:atompay_mobile/core/widgets/app_text_field.dart';
import 'package:atompay_mobile/core/widgets/buttons.dart';
import 'package:atompay_mobile/core/widgets/picker_field.dart';
import 'package:atompay_mobile/core/widgets/states.dart';
import 'package:atompay_mobile/core/widgets/ui.dart';
import 'package:atompay_mobile/features/application/data/application_models.dart';
import 'package:atompay_mobile/features/application/domain/application_controllers.dart';
import 'package:atompay_mobile/features/application/presentation/application_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// KYC section 3: income (handbook §5.8). Loads the application (for
/// `can_apply` and pre-fill) and the picker options first.
class ApplicationFormScreen extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final overview = ref.watch(applicationProvider);
    final options = ref.watch(formOptionsProvider);

    Widget failed(Object error) => MessageView(
      message: error is ApiException
          ? apiErrorText(l10n, error)
          : l10n.genericError,
      actionLabel: l10n.tryAgain,
      onAction: () => ref
        ..invalidate(applicationProvider)
        ..invalidate(formOptionsProvider),
    );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.applicationFormTitle)),
      body: switch ((overview, options)) {
        (AsyncData(value: final o), AsyncData(value: final opts)) =>
          o.canApply
              ? _ApplicationForm(latest: o.latest, options: opts)
              : const _ProfileFirst(),
        (AsyncError(:final error), _) ||
        (_, AsyncError(:final error)) => failed(error),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

/// `can_apply: false` (`requires: profile`): identity comes first.
class _ProfileFirst extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.all(Space.gutter),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.verifyIdentityFirstTitle, style: context.text.headline),
          const SizedBox(height: Space.x8),
          Text(l10n.verifyIdentityFirstText, style: context.text.body),
          const SizedBox(height: Space.x24),
          PrimaryButton(
            label: l10n.completeProfileCta,
            onPressed: () =>
                context.pushReplacement(Routes.profileEditThenApply),
          ),
        ],
      ),
    );
  }
}

class _ApplicationForm extends ConsumerStatefulWidget {
  const new({required this.latest, required this.options});

  final Assessment? latest;
  final FormOptions options;

  @override
  ConsumerState<_ApplicationForm> createState() => _ApplicationFormState();
}

class _ApplicationFormState extends ConsumerState<_ApplicationForm> {
  late String? _employment = _known(
    widget.latest?.employmentStatus,
    widget.options.employmentStatuses.map((o) => o.value),
  );
  late String? _source = _known(
    widget.latest?.incomeSource,
    widget.options.incomeSources.map((o) => o.value),
  );
  late final _employer = TextEditingController(
    text: widget.latest?.employerName,
  );
  late final _income = TextEditingController(
    text: MoneyInputFormatter.format(widget.latest?.monthlyIncome),
  );
  late final _instalments = TextEditingController(
    text: MoneyInputFormatter.format(widget.latest?.existingInstalments),
  );
  late final _expenses = TextEditingController(
    text: MoneyInputFormatter.format(widget.latest?.monthlyExpenses),
  );
  Map<String, String?> _local = const {};

  /// Pre-fill only with a value the current options still offer.
  static String? _known(String? value, Iterable<String> allowed) =>
      value != null && allowed.contains(value) ? value : null;

  @override
  void dispose() {
    _employer.dispose();
    _income.dispose();
    _instalments.dispose();
    _expenses.dispose();
    super.dispose();
  }

  EmploymentOption? get _employmentOption {
    for (final o in widget.options.employmentStatuses) {
      if (o.value == _employment) return o;
    }
    return null;
  }

  bool get _needsEmployer => _employmentOption?.hasEmployer ?? false;

  String? _error(String field) =>
      _local[field] ??
      ref.read(applicationSubmitControllerProvider).field(field);

  void _edited(String field) {
    ref.read(applicationSubmitControllerProvider.notifier).clearField(field);
    if (_local[field] != null) {
      setState(() => _local = {..._local, field: null});
    }
  }

  Future<String?> _pick(
    String title,
    List<({String value, String label})> items,
    String? selected,
  ) {
    return showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Space.gutter,
                0,
                Space.gutter,
                Space.x8,
              ),
              child: Text(title, style: context.text.title),
            ),
            for (final item in items)
              ListTile(
                title: Text(item.label),
                selected: item.value == selected,
                trailing: item.value == selected
                    ? const Icon(Icons.check)
                    : null,
                onTap: () => Navigator.of(context).pop(item.value),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickEmployment() async {
    final l10n = context.l10n;
    final value = await _pick(l10n.employmentStatusLabel, [
      for (final o in widget.options.employmentStatuses)
        (value: o.value, label: o.label),
    ], _employment);
    if (value == null) return;
    setState(() => _employment = value);
    _edited('employment_status');
  }

  Future<void> _pickSource() async {
    final l10n = context.l10n;
    final value = await _pick(l10n.incomeSourceLabel, [
      for (final o in widget.options.incomeSources)
        (value: o.value, label: o.label),
    ], _source);
    if (value == null) return;
    setState(() => _source = value);
    _edited('income_source');
  }

  Future<void> _submit() async {
    final l10n = context.l10n;
    final income = MoneyInputFormatter.parse(_income.text);
    setState(() {
      _local = {
        'employment_status': _employment == null ? l10n.fieldRequired : null,
        'employer_name': _needsEmployer && _employer.text.trim().isEmpty
            ? l10n.fieldRequired
            : null,
        'income_source': _source == null ? l10n.fieldRequired : null,
        'monthly_income': income == null
            ? l10n.fieldRequired
            : (income < 1000 ? l10n.incomeTooLow : null),
      };
    });
    if (_local.values.any((e) => e != null)) return;
    FocusScope.of(context).unfocus();

    final ok = await ref
        .read(applicationSubmitControllerProvider.notifier)
        .submit(
          ApplicationInput(
            employmentStatus: _employment!,
            employerName: _needsEmployer ? _employer.text : null,
            incomeSource: _source!,
            monthlyIncome: income!,
            existingInstalments: MoneyInputFormatter.parse(_instalments.text),
            monthlyExpenses: MoneyInputFormatter.parse(_expenses.text),
          ),
        );
    if (ok && mounted) {
      showToast(l10n.applicationSubmitted);
      context.pushReplacement(Routes.applicationStatus);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final status = ref.watch(applicationSubmitControllerProvider);

    // No profile yet (e.g. it was withdrawn meanwhile): identity first.
    ref.listen(applicationSubmitControllerProvider, (_, next) {
      if (next.error case Conflict(code: 'profile_required')) {
        context.pushReplacement(Routes.profileEditThenApply);
      }
    });

    String? labelOf(Iterable<({String value, String label})> items, String? v) {
      for (final i in items) {
        if (i.value == v) return i.label;
      }
      return null;
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        Space.gutter,
        Space.x8,
        Space.gutter,
        Space.x40,
      ),
      children: [
        Text(l10n.applicationIntro, style: context.text.body),
        const SizedBox(height: Space.x24),
        PickerField(
          label: l10n.employmentStatusLabel,
          value: _employmentOption?.label,
          placeholder: l10n.choose,
          icon: Icons.expand_more,
          errorText: _error('employment_status'),
          onTap: _pickEmployment,
        ),
        if (_needsEmployer) ...[
          const SizedBox(height: Space.x16),
          AppTextField(
            label: l10n.employerLabel,
            controller: _employer,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            maxLength: 255,
            errorText: _error('employer_name'),
            onChanged: (_) => _edited('employer_name'),
          ),
        ],
        const SizedBox(height: Space.x16),
        PickerField(
          label: l10n.incomeSourceLabel,
          value: labelOf([
            for (final o in widget.options.incomeSources)
              (value: o.value, label: o.label),
          ], _source),
          placeholder: l10n.choose,
          icon: Icons.expand_more,
          errorText: _error('income_source'),
          onTap: _pickSource,
        ),
        const SizedBox(height: Space.x16),
        MoneyField(
          label: l10n.monthlyIncomeLabel,
          controller: _income,
          errorText: _error('monthly_income'),
          onChanged: (_) => _edited('monthly_income'),
        ),
        const SizedBox(height: Space.x16),
        MoneyField(
          label: '${l10n.existingInstalmentsLabel} · ${l10n.optional}',
          controller: _instalments,
          errorText: _error('existing_instalments'),
          onChanged: (_) => _edited('existing_instalments'),
        ),
        const SizedBox(height: Space.x16),
        MoneyField(
          label: '${l10n.monthlyExpensesLabel} · ${l10n.optional}',
          controller: _expenses,
          textInputAction: TextInputAction.done,
          errorText: _error('monthly_expenses'),
          onChanged: (_) => _edited('monthly_expenses'),
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: Space.x32),
        SubmitSection(
          status: status,
          label: l10n.submitApplication,
          onPressed: _submit,
        ),
      ],
    );
  }
}
