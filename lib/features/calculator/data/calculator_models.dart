// freezed needs the classic `factory Name(...)` form.
// ignore_for_file: unnecessary_type_name_in_constructor

import 'package:freezed_annotation/freezed_annotation.dart';

part 'calculator_models.freezed.dart';
part 'calculator_models.g.dart';

/// `GET /calculator`: control bounds from AtomShop's admin (handbook
/// §8.10). Fetched each time the calculator opens.
@freezed
abstract class CalculatorConfig with _$CalculatorConfig {
  const factory CalculatorConfig({
    required List<int> tenures,

    /// May be a decimal, e.g. 3.5.
    required double perMonthPercentage,
    required AdvanceRatio advance,
    required PriceBounds price,
  }) = _CalculatorConfig;

  factory CalculatorConfig.fromJson(Map<String, dynamic> json) =>
      _$CalculatorConfigFromJson(json);
}

@freezed
abstract class AdvanceRatio with _$AdvanceRatio {
  const factory AdvanceRatio({
    required double minRatio,
    required double maxRatio,
  }) = _AdvanceRatio;

  factory AdvanceRatio.fromJson(Map<String, dynamic> json) =>
      _$AdvanceRatioFromJson(json);
}

@freezed
abstract class PriceBounds with _$PriceBounds {
  const factory PriceBounds({
    required int min,
    required int max,
    required int step,
  }) = _PriceBounds;

  factory PriceBounds.fromJson(Map<String, dynamic> json) =>
      _$PriceBoundsFromJson(json);
}

/// `POST /quote`: the server's figures. The app never computes these.
@freezed
abstract class Quote with _$Quote {
  const factory Quote({
    required int price,
    required int advance,
    required int months,
    required double perMonthPercentage,
    required int financed,
    required int markup,
    required int total,
    required int monthly,
    required AdvanceBounds advanceBounds,
  }) = _Quote;

  factory Quote.fromJson(Map<String, dynamic> json) => _$QuoteFromJson(json);
}

@freezed
abstract class AdvanceBounds with _$AdvanceBounds {
  const factory AdvanceBounds({required int min, required int max}) =
      _AdvanceBounds;

  factory AdvanceBounds.fromJson(Map<String, dynamic> json) =>
      _$AdvanceBoundsFromJson(json);
}
