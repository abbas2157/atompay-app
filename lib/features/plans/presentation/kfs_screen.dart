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

/// Placeholders until the business supplies the facts in Atomshop's admin
/// panel (brief §0, §11).
abstract final class KfsPlaceholders {
  /// Atomshop's registered company. It sells on instalments itself: there
  /// is no lender and no SECP licence to show.
  static const company = '[COMPANY NAME]';
  static const feeCharged = '[confirm it is charged]';
  static const aprIfNoFee = '[0% if no fee is charged]';
  static const late = '[CHARGES, IF ANY]';
  static const early = '[EARLY SETTLEMENT TERMS]';
}

/// The Key Fact Statement: every term of the instalment plan up front
/// (Apple 3.2.2(ix), Google Play financial features).
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
      subject: 'AtomPay Key Fact Statement · ${kfsTitle(k)}',
      sharePositionOrigin: origin,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final kfs = ref.watch(kfsProvider(widget.orderId));
    return SecureScreen(
      child: Scaffold(
        backgroundColor: context.colors.surface,
        appBar: const AppTopBar(title: 'Key Fact Statement'),
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
          notFoundBody:
              'It may belong to another account, or the link is out of date.',
          data: (k) => ListView(
            padding: const EdgeInsets.all(Space.gutter),
            children: [
              KfsCard(kfs: k),
              Gap.s14,
              _CheckoutNote(acceptedAt: k.acceptedAt),
              Gap.s14,
              AppButton.primary(
                'Email or SMS me a copy',
                block: true,
                busy: _sending,
                onPressed: _sending ? null : _send,
              ),
              Gap.s14,
              Builder(
                builder: (context) => AppButton.ghost(
                  'Share',
                  block: true,
                  onPressed: () {
                    final box = context.findRenderObject() as RenderBox?;
                    final origin = box == null
                        ? Rect.zero
                        : box.localToGlobal(Offset.zero) & box.size;
                    unawaited(_share(k, origin));
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "These terms must be shown and accepted at Atomshop checkout…".
class _CheckoutNote extends StatelessWidget {
  const new({this.acceptedAt});

  /// From the server, once checkout records the acceptance.
  final DateTime? acceptedAt;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (acceptedAt case final at?) {
      return Note(
        tone: NoteTone.green,
        icon: Icons.verified_outlined,
        text:
            'You accepted these terms when you ordered, on '
            '${dayMonthYear(at)}. This copy stays here for you.',
      );
    }
    return Note(
      tone: NoteTone.blue,
      spans: [
        const TextSpan(
          text:
              'These terms must be shown and accepted at Atomshop checkout '
              'before the order is approved ',
        ),
        TextSpan(
          text: '[not built yet]',
          style: TextStyle(color: c.rose, fontWeight: FontWeight.w700),
        ),
        const TextSpan(text: '. This copy stays here for you.'),
      ],
    );
  }
}

/// The statement's rows. Null facts render as visible placeholders, in
/// rose, inline with the fact they belong to.
class KfsCard extends StatelessWidget {
  const new({required this.kfs, super.key});

  final Kfs kfs;

  @override
  Widget build(BuildContext context) {
    final t = context.text;
    final c = context.colors;
    final k = kfs;
    final lender = k.lender;
    final value = t.base.copyWith(color: c.ink, fontWeight: FontWeight.w700);
    final tbd = value.copyWith(color: c.rose);

    Widget text(String s, {bool placeholder = false}) =>
        Text(s, style: placeholder ? tbd : value);

    // A value with its rose note after it, on the same line when it fits.
    Widget withPending(Widget v, String pending) => Wrap(
      spacing: Space.s4,
      children: [
        v,
        Text(pending, style: tbd),
      ],
    );

    final rows = <_KfsRow>[
      // Atomshop sells on instalments itself: the seller, no lender.
      _KfsRow(
        'Sold by',
        text(
          lender.name ?? KfsPlaceholders.company,
          placeholder: lender.name == null,
        ),
      ),
      if (lender.address != null) _KfsRow('Address', text(lender.address!)),
      _KfsRow('Product', text('AtomPay instalment plan')),
      _KfsRow(
        'Amount financed',
        text('${rs(k.amountFinanced)} (cash price)'),
        spoken: '${rsSpoken(k.amountFinanced)}, the cash price',
      ),
      _KfsRow('Advance', text(rs(k.advance)), spoken: rsSpoken(k.advance)),
      _KfsRow('Markup', text('${k.markupPercent}%')),
      _KfsRow(
        'Processing fee',
        withPending(
          text('${k.processingFeePercent}% · ${rs(k.processingFee)}'),
          KfsPlaceholders.feeCharged,
        ),
        spoken:
            '${k.processingFeePercent} percent, '
            '${rsSpoken(k.processingFee)}, ${KfsPlaceholders.feeCharged}',
      ),
      _KfsRow(
        'Annual percentage rate (APR)',
        withPending(
          k.aprPercent == null
              ? text('[APR]', placeholder: true)
              : text('${k.aprPercent}% including the fee'),
          KfsPlaceholders.aprIfNoFee,
        ),
      ),
      _KfsRow('Tenor', text('${k.months} months')),
      if (k.instalments.isNotEmpty)
        _KfsRow(
          'Instalments',
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final i in k.instalments)
                text('${kfsDue(i)} · ${rs(i.amount)}'),
            ],
          ),
          spoken: [
            for (final i in k.instalments)
              [
                'Instalment ${i.number}',
                kfsDue(i),
                rsSpoken(i.amount),
              ].join(', '),
          ].join('. '),
        ),
      _KfsRow(
        'Total you repay',
        text('${rs(k.totalRepayable)} in instalments'),
        spoken: '${rsSpoken(k.totalRepayable)} in instalments',
      ),
      _KfsRow('Delivery', text('Charges apply, in addition to this plan')),
      _KfsRow(
        'Late payment',
        text(
          k.latePayment ?? KfsPlaceholders.late,
          placeholder: k.latePayment == null,
        ),
      ),
      _KfsRow(
        'Paying early',
        text(
          k.earlySettlement ?? KfsPlaceholders.early,
          placeholder: k.earlySettlement == null,
        ),
      ),
      _KfsRow('Complaints', text(k.complaints ?? _complaints)),
    ];

    return AppCard(
      padding: const EdgeInsets.all(Space.s18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(kfsTitle(k), style: t.h4),
                ),
              ),
              if (k.product != null) ...[
                const SizedBox(width: Space.s12),
                Flexible(
                  child: Text(
                    k.product!,
                    style: t.tiny,
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ],
          ),
          Gap.s12,
          for (var i = 0; i < rows.length; i++)
            _KfsRowView(row: rows[i], first: i == 0),
        ],
      ),
    );
  }
}

/// One fact: its name and its value.
class _KfsRow {
  const new(this.label, this.value, {this.spoken});

  final String label;
  final Widget value;

  /// What a screen reader says for the value ("Rupees 47,000").
  final String? spoken;
}

/// Canvas `.kfs`: a 42 / 58 grid, the name muted in sentence case, the
/// value left-aligned, a hairline between rows.
class _KfsRowView extends StatelessWidget {
  const new({required this.row, required this.first});

  final _KfsRow row;
  final bool first;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    return MergeSemantics(
      child: Container(
        padding: EdgeInsets.only(top: first ? 0 : Space.s10, bottom: Space.s10),
        decoration: BoxDecoration(
          border: first ? null : Border(top: BorderSide(color: c.line)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 42,
              child: Text(
                row.label,
                style: t.small.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: Space.s10),
            Expanded(
              flex: 58,
              child: Semantics(
                label: row.spoken,
                excludeSemantics: row.spoken != null,
                child: row.value,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// The statement as plain text for the share sheet, placeholders kept.
String kfsText(Kfs k) {
  final l = k.lender;
  final fee =
      'Processing fee: ${k.processingFeePercent}% · ${rs(k.processingFee)} '
      '${KfsPlaceholders.feeCharged}';
  final apr =
      'APR: ${k.aprPercent == null ? '[APR]' : '${k.aprPercent}%'} '
      'including the fee ${KfsPlaceholders.aprIfNoFee}';
  final seller = 'Sold by: ${l.name ?? KfsPlaceholders.company}';
  return [
    'AtomPay Key Fact Statement',
    '${kfsTitle(k)}${k.product == null ? '' : ' · ${k.product}'}',
    seller,
    'Amount financed: ${rs(k.amountFinanced)} (cash price)',
    'Advance: ${rs(k.advance)}',
    'Markup: ${k.markupPercent}%',
    fee,
    apr,
    'Tenor: ${k.months} months',
    for (final i in k.instalments)
      'Instalment ${i.number}: ${kfsDue(i)} · ${rs(i.amount)}',
    'Total you repay: ${rs(k.totalRepayable)}',
    'Delivery: charges apply, in addition to this plan',
    'Late payment: ${k.latePayment ?? KfsPlaceholders.late}',
    'Paying early: ${k.earlySettlement ?? KfsPlaceholders.early}',
    'Complaints: ${k.complaints ?? _complaints}',
  ].join('\n');
}

const _complaints = 'In the app: Help › Complaints.';

/// "Order AS-01280", or "Before you order" for a product's statement.
String kfsTitle(Kfs k) =>
    k.orderNumber == null ? 'Before you order' : 'Order ${k.orderNumber}';

/// The date, or when it will be set: Atomshop dates the months on delivery.
String kfsDue(KfsInstalment i) => i.dueDate == null
    ? 'Month ${i.number} · set on delivery'
    : dayMonthYear(i.dueDate!);
