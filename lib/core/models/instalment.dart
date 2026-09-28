// freezed needs the classic `factory Name(...)` form; fields follow the API's
// JSON order rather than required-first.
// ignore_for_file: unnecessary_type_name_in_constructor
// ignore_for_file: always_put_required_named_parameters_first

import 'package:freezed_annotation/freezed_annotation.dart';

part 'instalment.freezed.dart';
part 'instalment.g.dart';

/// One scheduled repayment (handbook §8.10b). Shared by the dashboard's
/// `next_due` and the plan schedule.
@freezed
abstract class Instalment with _$Instalment {
  const factory Instalment({
    required int id,
    required int orderId,
    required String label,

    /// `YYYY-MM-DD`.
    required String dueDate,
    required int amount,
    int? paidAmount,
    String? paidOn,

    /// `paid` · `late` · `due` · `upcoming` (or newer values).
    required String state,

    /// Only on the dashboard's `next_due`.
    String? orderReference,
    String? productTitle,
  }) = _Instalment;

  factory Instalment.fromJson(Map<String, dynamic> json) =>
      _$InstalmentFromJson(json);
}
