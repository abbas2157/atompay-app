import 'package:atompay_mobile/core/network/api_exception.dart';
import 'package:atompay_mobile/core/theme/tokens.dart';
import 'package:atompay_mobile/core/utils/money.dart';
import 'package:atompay_mobile/core/widgets/guest_tray.dart';
import 'package:atompay_mobile/core/widgets/states.dart';
import 'package:atompay_mobile/core/widgets/ui.dart';
import 'package:atompay_mobile/features/application/presentation/application_widgets.dart';
import 'package:atompay_mobile/features/calculator/data/calculator_models.dart';
import 'package:atompay_mobile/features/calculator/domain/calculator_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Public plan calculator (handbook §5.10). Every figure comes from
/// `POST /quote`; the app only picks the inputs.
class CalculatorScreen extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final config = ref.watch(calculatorConfigProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.calculatorTitle)),
      // Public screen: sign-in / sign-up stay one tap away for guests.
      bottomNavigationBar: const GuestTray(),
      body: switch (config) {
        AsyncData(:final value) when value.tenures.isNotEmpty => _Calculator(
          config: value,
        ),
        AsyncError(:final error) => MessageView(
          message: error is ApiException
              ? apiErrorText(l10n, error)
              : l10n.genericError,
          actionLabel: l10n.tryAgain,
          onAction: () => ref.invalidate(calculatorConfigProvider),
        ),
        AsyncData() => MessageView(
          message: l10n.genericError,
          actionLabel: l10n.tryAgain,
          onAction: () => ref.invalidate(calculatorConfigProvider),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _Calculator extends ConsumerStatefulWidget {
  const new({required this.config});

  final CalculatorConfig config;

  @override
  ConsumerState<_Calculator> createState() => _CalculatorState();
}

class _CalculatorState extends ConsumerState<_Calculator> {
  late final PriceBounds _bounds = widget.config.price;
  late final AdvanceRatio _ratio = widget.config.advance;

  late int _price = _snap(
    (_bounds.min + (_bounds.max - _bounds.min) ~/ 3).clamp(
      _bounds.min,
      _bounds.max,
    ),
  );
  late double _advanceRatio = _ratio.minRatio;
  late int _months = widget.config.tenures.contains(6)
      ? 6
      : widget.config.tenures.first;
  late final _priceText = TextEditingController(
    text: MoneyInputFormatter.format(_price),
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _quote());
  }

  @override
  void dispose() {
    _priceText.dispose();
    super.dispose();
  }

  int _snap(int price) {
    final step = _bounds.step <= 0 ? 1 : _bounds.step;
    final snapped = ((price - _bounds.min) / step).round() * step + _bounds.min;
    return snapped.clamp(_bounds.min, _bounds.max);
  }

  /// Rounded to whole rupees; the server checks the exact bounds.
  int get _advance => (_price * _advanceRatio).round();

  void _quote() => ref
      .read(quoteControllerProvider.notifier)
      .request(price: _price, months: _months, advance: _advance);

  void _setPrice(int price, {bool fromText = false}) {
    setState(() => _price = price);
    if (!fromText) _priceText.text = MoneyInputFormatter.format(price);
    _quote();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = context.text;
    final state = ref.watch(quoteControllerProvider);
    final tenures = widget.config.tenures;
    final percent = (_advanceRatio * 100).round();
    final priceSteps = _bounds.step > 0
        ? ((_bounds.max - _bounds.min) ~/ _bounds.step)
        : null;
    final ratioSteps = ((_ratio.maxRatio - _ratio.minRatio) * 100).round();

    return ListView(
      padding: const EdgeInsets.all(Space.gutter),
      children: [
        Text(l10n.calculatorIntro, style: text.body),
        const SizedBox(height: Space.x24),
        MoneyField(
          label: l10n.priceLabel,
          controller: _priceText,
          errorText: state.field('price'),
          textInputAction: TextInputAction.done,
          onChanged: (v) {
            final typed = MoneyInputFormatter.parse(v);
            if (typed != null && typed >= _bounds.min && typed <= _bounds.max) {
              _setPrice(typed, fromText: true);
            }
          },
          onSubmitted: (v) =>
              _setPrice(_snap(MoneyInputFormatter.parse(v) ?? _price)),
        ),
        Slider(
          value: _price.toDouble(),
          min: _bounds.min.toDouble(),
          max: _bounds.max.toDouble(),
          divisions: priceSteps != null && priceSteps > 0 ? priceSteps : null,
          label: pkr(_price),
          semanticFormatterCallback: (v) => pkr(v.round()),
          onChanged: (v) => _setPrice(_snap(v.round())),
        ),
        const SizedBox(height: Space.x16),
        _Label(
          title: l10n.downPaymentWithPercent(percent),
          value: pkr(_advance),
        ),
        Slider(
          value: _advanceRatio,
          min: _ratio.minRatio,
          max: _ratio.maxRatio,
          divisions: ratioSteps > 0 ? ratioSteps : null,
          label: '$percent%',
          semanticFormatterCallback: (v) => '${(v * 100).round()}%',
          onChanged: (v) {
            setState(() => _advanceRatio = v);
            _quote();
          },
        ),
        if (state.field('advance') case final e?) _FieldError(e),
        const SizedBox(height: Space.x16),
        _Label(title: l10n.tenureLabel),
        const SizedBox(height: Space.x8),
        Wrap(
          spacing: Space.x8,
          runSpacing: Space.x8,
          children: [
            for (final m in tenures)
              ChoiceChip(
                label: Text(l10n.monthsCount(m)),
                selected: m == _months,
                selectedColor: AppColors.violet.withValues(alpha: 0.16),
                checkmarkColor: AppColors.violet,
                labelStyle: text.label.copyWith(
                  color: m == _months ? AppColors.violet : context.tokens.ink,
                ),
                onSelected: (_) {
                  setState(() => _months = m);
                  _quote();
                },
              ),
          ],
        ),
        if (state.field('months') case final e?) _FieldError(e),
        const SizedBox(height: Space.x24),
        _Result(state: state),
        const SizedBox(height: Space.x12),
        Text(l10n.quoteLabel, style: text.bodySmall),
      ],
    );
  }
}

class _Label extends StatelessWidget {
  const new({required this.title, this.value});

  final String title;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final text = context.text;
    return Row(
      children: [
        Expanded(child: Text(title.toUpperCase(), style: text.eyebrow)),
        if (value != null) Text(value!, style: text.figure(text.label)),
      ],
    );
  }
}

class _FieldError extends StatelessWidget {
  const new(this.message);

  final String message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: Space.x4),
    child: Text(
      message,
      style: context.text.bodySmall.copyWith(color: AppColors.coral),
    ),
  );
}

/// Nucleus card with the server's figures. Dims while a new quote loads.
class _Result extends StatelessWidget {
  const new({required this.state});

  final QuoteState state;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = context.text;
    final q = state.quote;
    const white = AppColors.white;
    final dim = white.withValues(alpha: 0.8);
    final general = state.error != null && state.error is! Validation
        ? apiErrorText(l10n, state.error!)
        : null;

    Widget row(String label, int amount) => Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.x4),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: text.body.copyWith(color: dim)),
          ),
          Text(
            pkr(amount),
            style: text.figure(text.label.copyWith(color: white)),
          ),
        ],
      ),
    );

    return Semantics(
      liveRegion: true,
      child: AnimatedOpacity(
        duration: Motion.short,
        opacity: state.loading ? 0.6 : 1,
        child: Container(
          padding: const EdgeInsets.all(Space.x24),
          decoration: BoxDecoration(
            color: context.tokens.nucleusCard,
            borderRadius: BorderRadius.circular(Radii.darkCard),
            border: Border.all(color: context.tokens.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.monthlyLabel.toUpperCase(),
                style: text.eyebrow.copyWith(color: dim),
              ),
              const SizedBox(height: Space.x8),
              if (q == null)
                const SizedBox(
                  height: 40,
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: SizedBox.square(
                      dimension: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.white,
                      ),
                    ),
                  ),
                )
              else ...[
                Text(
                  pkr(q.monthly),
                  style: text.display.copyWith(color: white),
                ),
                Text(l10n.perMonth, style: text.bodySmall.copyWith(color: dim)),
                const SizedBox(height: Space.x16),
                row(l10n.downPaymentLabel, q.advance),
                row(l10n.financedLabel, q.financed),
                row(l10n.markupLabel, q.markup),
                row(l10n.totalLabel, q.total),
              ],
              if (general != null) ...[
                const SizedBox(height: Space.x12),
                Text(general, style: text.bodySmall.copyWith(color: white)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
