import 'dart:async';

import 'package:atompay_mobile/core/network/api_client.dart';
import 'package:atompay_mobile/core/network/api_exception.dart';
import 'package:atompay_mobile/features/calculator/data/calculator_models.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Bounds come from AtomShop's admin and can change: refetched every time
/// the calculator opens (handbook §5.10).
final calculatorConfigProvider = FutureProvider.autoDispose<CalculatorConfig>((
  ref,
) async {
  final data = await ref.watch(apiClientProvider).get('/calculator');
  return CalculatorConfig.fromJson((data as Map).cast<String, dynamic>());
});

@immutable
class QuoteState {
  const new({this.quote, this.loading = false, this.error});

  /// The last good quote; kept on screen while a new one loads.
  final Quote? quote;
  final bool loading;
  final ApiException? error;

  /// A `422` message for `price`, `months` or `advance`.
  String? field(String name) => switch (error) {
    final Validation v => v.first(name),
    _ => null,
  };
}

final quoteControllerProvider =
    NotifierProvider.autoDispose<QuoteController, QuoteState>(
      QuoteController.new,
    );

/// Debounced `POST /quote` (300 ms, the endpoint allows 60/min). Replies
/// that arrive after a newer request are dropped.
class QuoteController extends Notifier<QuoteState> {
  static const debounce = Duration(milliseconds: 300);

  Timer? _timer;
  int _latest = 0;

  @override
  QuoteState build() {
    ref.onDispose(() => _timer?.cancel());
    return const QuoteState();
  }

  void request({
    required int price,
    required int months,
    required int advance,
  }) {
    _timer?.cancel();
    state = QuoteState(quote: state.quote, loading: true);
    _timer = Timer(
      debounce,
      () => unawaited(_fetch(price: price, months: months, advance: advance)),
    );
  }

  Future<void> _fetch({
    required int price,
    required int months,
    required int advance,
  }) async {
    final id = ++_latest;
    try {
      final data = await ref
          .read(apiClientProvider)
          .post(
            '/quote',
            data: {'price': price, 'months': months, 'advance': advance},
          );
      if (!ref.mounted || id != _latest) return;
      state = QuoteState(
        quote: Quote.fromJson((data as Map).cast<String, dynamic>()),
      );
    } on ApiException catch (e) {
      if (!ref.mounted || id != _latest) return;
      state = QuoteState(quote: state.quote, error: e);
    }
  }
}
