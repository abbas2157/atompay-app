import 'package:atompay_mobile/core/network/api_client.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A complaint as `POST /complaints` returns it (brief §7.2).
@immutable
class ComplaintReceipt {
  const new({required this.id, required this.reference, required this.status});

  factory fromJson(Map<String, dynamic> json) => ComplaintReceipt(
    id: (json['id'] as num).toInt(),
    reference: '${json['reference']}',
    status: '${json['status'] ?? 'open'}',
  );

  final int id;

  /// "CMP-1042": the number the customer quotes.
  final String reference;
  final String status;
}

/// The shortest and longest complaint the server takes.
const minComplaintLength = 10;
const maxComplaintLength = 2000;

/// The in-app grievance route (SECP Circular 15/2022).
class ComplaintsRepository {
  new(this._dio);

  final Dio _dio;

  /// Throttled 5/hour. [topic] is a `complaint_topics` value; [orderId] is
  /// null when it isn't about an order.
  Future<ComplaintReceipt> send({
    required String topic,
    required String message,
    int? orderId,
  }) => guard(() async {
    final r = await _dio.post<dynamic>(
      '/complaints',
      data: {'topic': topic, 'order_id': orderId, 'message': message},
    );
    return ComplaintReceipt.fromJson(dataOf(r));
  });
}

final complaintsRepositoryProvider = Provider<ComplaintsRepository>(
  (ref) => ComplaintsRepository(ref.watch(dioProvider)),
);
