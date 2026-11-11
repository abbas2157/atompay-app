import 'package:atompay_mobile/core/network/api_client.dart';
import 'package:atompay_mobile/core/network/api_exception.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// One answer from `POST /ask-atom` (brief §7.2). Rules-based: no model.
@immutable
class AtomAnswer {
  const new({
    required this.paragraphs,
    this.table,
    this.actions = const [],
    this.chips = const [],
  });

  factory fromJson(Map<String, dynamic> json) => AtomAnswer(
    paragraphs: [for (final p in json['paragraphs'] as List? ?? []) '$p'],
    table: json['table'] is List
        ? [
            for (final row in json['table'] as List)
              AtomRow.fromJson((row as Map).cast<String, dynamic>()),
          ]
        : null,
    actions: [
      for (final a in json['actions'] as List? ?? [])
        AtomAction.fromJson((a as Map).cast<String, dynamic>()),
    ],
    chips: [for (final c in json['chips'] as List? ?? []) '$c'],
  );

  /// Plain text; `**bold**` spans may appear and are the only markup.
  final List<String> paragraphs;

  /// Money rows ("Month 1 · Rs. 15,666"), or null.
  final List<AtomRow>? table;
  final List<AtomAction> actions;

  /// Follow-up questions.
  final List<String> chips;
}

@immutable
class AtomRow {
  const new({required this.label, required this.value});

  factory fromJson(Map<String, dynamic> json) =>
      AtomRow(label: '${json['label']}', value: (json['value'] as num).toInt());

  final String label;

  /// Rupees.
  final int value;
}

/// A button under an answer; [route] is an app path from brief §5.
@immutable
class AtomAction {
  const new({required this.label, required this.route});

  factory fromJson(Map<String, dynamic> json) =>
      AtomAction(label: '${json['label']}', route: '${json['route']}');

  final String label;
  final String route;
}

/// The longest question the server takes.
const maxQuestionLength = 300;

class AskAtomRepository {
  new(this._dio);

  final Dio _dio;

  /// Suggested questions for the start screen. Auth optional.
  Future<List<String>> chips() => guard(() async {
    final body = (await _dio.get<dynamic>('/ask-atom/chips')).data;
    if (body is Map && body['data'] is List) {
      return [for (final c in body['data'] as List) '$c'];
    }
    throw const Server(statusCode: 0);
  });

  /// Throttled 20/min; 422 when empty or over 300 characters.
  Future<AtomAnswer> ask(String question) => guard(() async {
    final r = await _dio.post<dynamic>(
      '/ask-atom',
      data: {'question': question},
    );
    return AtomAnswer.fromJson(dataOf(r));
  });
}

final askAtomRepositoryProvider = Provider<AskAtomRepository>(
  (ref) => AskAtomRepository(ref.watch(dioProvider)),
);
