import 'dart:async';

import 'package:atompay_mobile/core/format/dates.dart';
import 'package:atompay_mobile/core/format/money.dart';
import 'package:atompay_mobile/core/theme/tokens.dart';
import 'package:atompay_mobile/core/widgets/buttons.dart';
import 'package:atompay_mobile/core/widgets/form_parts.dart';
import 'package:atompay_mobile/core/widgets/secure_screen.dart';
import 'package:atompay_mobile/core/widgets/states.dart';
import 'package:atompay_mobile/core/widgets/ui.dart';
import 'package:atompay_mobile/features/plans/application/plans_controller.dart';
import 'package:atompay_mobile/features/plans/data/plan_models.dart';
import 'package:atompay_mobile/features/plans/data/plans_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

/// Placeholders until the business supplies the facts (brief §0, §11).
abstract final class KfsPlaceholders {
  static const lender = '[LICENSED ENTITY NAME]';
  static const licence = '[NO.]';
  static const feeCharged = '[confirm it is charged]';
  static const aprIfNoFee = '[0% if no fee is charged]';
  static const late = '[CHARGES, IF ANY]';
  static const early = '[EARLY SETTLEMENT TERMS]';
}

/// The Key Fact Statement (SECP Circular 15/2022; Apple 3.2.2(ix)).
/// Screenshots are blocked; a copy goes by email or SMS, or through the
/// system share sheet as text. Nothing is saved to the phone.
class KfsScreen extends ConsumerStatefulWidget {
  const new({required this.orderId, super.key});

  final int orderId;

  @override
  ConsumerState<KfsScreen> createState() => _KfsScreenState();
}

class _KfsScreenState extends ConsumerState<KfsScreen> {
  bool _sending = false;

  Future<void> _send() async {
    final channel = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListRow(
              title: 'Email me a copy',
              icon: Icons.mail_outline,
              onTap: () => Navigator.of(context).pop('email'),
            ),
            ListRow(
              title: 'Send me an SMS',
              icon: Icons.sms_outlined,
              onTap: () => Navigator.of(context).pop('sms'),
            ),
            Gap.s16,
          ],
        ),
      ),
    );
    if (channel == null || !mounted) return;
    setState(() => _sending = true);
    try {
      await ref.read(plansRepositoryProvider).sendKfs(widget.orderId, channel);
      showToast(
        channel == 'email'
            ? 'We have emailed you a copy'
            : 'We have sent you an SMS',
      );
    } on Object {
      showToast("We couldn't send it. Try again.", error: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _share(Kfs k, Rect origin) => SharePlus.instance.share(
    ShareParams(
      text: kfsText(k),
      subject: 'AtomPay Key Fact Statement · ${k.orderNumber}',
      sharePositionOrigin: origin,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final kfs = ref.watch(kfsProvider(widget.orderId));
    return SecureScreen(
      child: Scaffold(
        backgroundColor: context.colors.surface,
        appBar: const AppTopBar(
          title: 'Key Fact Statement',
          bottomBorder: true,
        ),
        body: AsyncBody(
          value: kfs,
          loading: const LoadingShape(
            label: 'Loading the Key Fact Statement',
            child: Padding(
              padding: EdgeInsets.all(Space.gutter),
              child: SkeletonCard(lines: 10),
            ),
          ),
          onRetry: () => ref.invalidate(kfsProvider(widget.orderId)),
          notFound: "We can't find this order",
          data: (k) => FormPage(
            footer: Builder(
              builder: (context) => Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppButton.primary(
                    'Email or SMS me a copy',
                    block: true,
                    busy: _sending,
                    onPressed: _sending ? null : _send,
                  ),
                  Gap.s8,
                  AppButton.ghost(
                    'Share',
                    block: true,
                    icon: Icons.ios_share,
                    onPressed: () {
                      final box = context.findRenderObject() as RenderBox?;
                      final origin = box == null
                          ? Rect.zero
                          : box.localToGlobal(Offset.zero) & box.size;
                      unawaited(_share(k, origin));
                    },
                  ),
                ],
              ),
            ),
            children: [KfsCard(kfs: k)],
          ),
        ),
      ),
    );
  }
}

/// The statement's rows. Null facts render as visible placeholders.
class KfsCard extends StatelessWidget {
  const new({required this.kfs, super.key});

  final Kfs kfs;

  @override
  Widget build(BuildContext context) {
    final t = context.text;
    final k = kfs;
    final lender = k.lender;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Order ${k.orderNumber}', style: t.h4),
              if (k.product != null) Text(k.product!, style: t.small),
              Gap.s12,
              KeyValueList([
                KeyValue(
                  'Lender',
                  '${lender.name ?? KfsPlaceholders.lender} · SECP licence '
                      '${lender.licence ?? KfsPlaceholders.licence}',
                  placeholder: lender.name == null || lender.licence == null,
                ),
                if (lender.address != null)
                  KeyValue('Address', lender.address!),
                const KeyValue('Product', 'AtomPay instalment plan'),
                KeyValue(
                  'Amount financed',
                  '${rs(k.amountFinanced)} (cash price)',
                  spoken: '${rsSpoken(k.amountFinanced)}, the cash price',
                ),
                KeyValue('Advance', rs(k.advance), spoken: rsSpoken(k.advance)),
                KeyValue('Markup', '${k.markupPercent}%'),
                KeyValue(
                  'Processing fee',
                  '${k.processingFeePercent}% · ${rs(k.processingFee)}',
                  spoken:
                      '${k.processingFeePercent} percent, '
                      '${rsSpoken(k.processingFee)}',
                  pending: KfsPlaceholders.feeCharged,
                ),
                KeyValue(
                  'Annual percentage rate (APR)',
                  k.aprPercent == null
                      ? '[APR]'
                      : '${k.aprPercent}% including the fee',
                  placeholder: k.aprPercent == null,
                  pending: KfsPlaceholders.aprIfNoFee,
                ),
                KeyValue('Tenor', '${k.months} months'),
                for (final i in k.instalments)
                  KeyValue(
                    i.number == 1 ? 'Instalments' : '',
                    '${dayMonthYear(i.dueDate)} · ${rs(i.amount)}',
                    spoken:
                        'Instalment ${i.number}, ${dayMonthYear(i.dueDate)}, '
                        '${rsSpoken(i.amount)}',
                  ),
                KeyValue(
                  'Total you repay',
                  '${rs(k.totalRepayable)} in instalments',
                  spoken: rsSpoken(k.totalRepayable),
                ),
                const KeyValue('Delivery', 'Charges apply, shown at checkout'),
                KeyValue(
                  'Late payment',
                  k.latePayment ?? KfsPlaceholders.late,
                  placeholder: k.latePayment == null,
                ),
                KeyValue(
                  'Paying early',
                  k.earlySettlement ?? KfsPlaceholders.early,
                  placeholder: k.earlySettlement == null,
                ),
                KeyValue(
                  'Complaints',
                  k.complaints ??
                      'In the app: Help › Complaints. Then the SECP.',
                ),
              ]),
            ],
          ),
        ),
        Gap.s14,
        if (k.issuedAt != null)
          Text('Issued ${dayMonthYear(k.issuedAt!)}.', style: t.small),
      ],
    );
  }
}

/// The statement as plain text for the share sheet, placeholders kept.
String kfsText(Kfs k) {
  final l = k.lender;
  const complaints = 'In the app: Help › Complaints. Then the SECP.';
  final fee =
      'Processing fee: ${k.processingFeePercent}% · ${rs(k.processingFee)} '
      '${KfsPlaceholders.feeCharged}';
  final apr =
      'APR: ${k.aprPercent == null ? '[APR]' : '${k.aprPercent}%'} '
      'including the fee ${KfsPlaceholders.aprIfNoFee}';
  final lender =
      'Lender: ${l.name ?? KfsPlaceholders.lender} · SECP licence '
      '${l.licence ?? KfsPlaceholders.licence}';
  return [
    'AtomPay Key Fact Statement',
    'Order ${k.orderNumber}${k.product == null ? '' : ' · ${k.product}'}',
    lender,
    'Amount financed: ${rs(k.amountFinanced)} (cash price)',
    'Advance: ${rs(k.advance)}',
    'Markup: ${k.markupPercent}%',
    fee,
    apr,
    'Tenor: ${k.months} months',
    for (final i in k.instalments)
      'Instalment ${i.number}: ${dayMonthYear(i.dueDate)} · ${rs(i.amount)}',
    'Total you repay: ${rs(k.totalRepayable)}',
    'Delivery: charges apply, shown at checkout',
    'Late payment: ${k.latePayment ?? KfsPlaceholders.late}',
    'Paying early: ${k.earlySettlement ?? KfsPlaceholders.early}',
    'Complaints: ${k.complaints ?? complaints}',
  ].join('\n');
}
