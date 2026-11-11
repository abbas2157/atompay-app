import 'package:atompay_mobile/core/forms/form_controller.dart';
import 'package:atompay_mobile/features/help/data/complaints_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final complaintFormProvider =
    NotifierProvider.autoDispose<ComplaintForm, FormStatus>(ComplaintForm.new);

/// "Raise a complaint". Returns the reference on success.
class ComplaintForm extends FormController {
  Future<String?> send({
    required String? topic,
    required int? orderId,
    required String message,
  }) async {
    final text = message.trim();
    final errors = {
      if (topic == null) 'topic': 'Choose what it is about.',
      if (text.length < minComplaintLength)
        'message': 'Tell us a little more: at least 10 characters.',
    };
    if (errors.isNotEmpty) {
      fail(errors);
      return null;
    }
    final receipt = await run(
      () => ref
          .read(complaintsRepositoryProvider)
          .send(topic: topic!, orderId: orderId, message: text),
    );
    return receipt?.reference;
  }
}
