import 'dart:async';

import 'package:atompay_mobile/core/format/money.dart';
import 'package:atompay_mobile/core/forms/form_controller.dart';
import 'package:atompay_mobile/core/network/api_exception.dart';
import 'package:atompay_mobile/core/router/routes.dart';
import 'package:atompay_mobile/core/theme/tokens.dart';
import 'package:atompay_mobile/core/widgets/buttons.dart';
import 'package:atompay_mobile/core/widgets/form_parts.dart';
import 'package:atompay_mobile/core/widgets/states.dart';
import 'package:atompay_mobile/core/widgets/ui.dart';
import 'package:atompay_mobile/features/application/application/apply_controller.dart';
import 'package:atompay_mobile/features/application/data/application_models.dart';
import 'package:atompay_mobile/features/home/application/home_controller.dart';
import 'package:atompay_mobile/features/plans/data/plan_models.dart';
import 'package:atompay_mobile/features/plans/presentation/kfs_screen.dart';
import 'package:atompay_mobile/features/shop/data/product_models.dart';
import 'package:atompay_mobile/features/shop/data/products_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// `GET /products/{id}/kfs`: the statement the customer accepts. A 409
/// here means they can't order this product, before they read anything.
final buyKfsProvider = FutureProvider.autoDispose.family<Kfs, int>(
  (ref, productId) => ref.watch(productsRepositoryProvider).kfs(productId),
);

/// `POST /orders`. Atomshop places it (docs/api/orders.md).
class PlaceOrderForm extends FormController {
  Future<PlacedOrder?> place({
    required int productId,
    required int kfsAmount,
  }) async {
    final placed = await run(
      () => ref
          .read(productsRepositoryProvider)
          .placeOrder(productId: productId, kfsAmount: kfsAmount),
    );
    if (placed != null) {
      // The order is in My orders at once, and the limit shrinks.
      ref
        ..invalidate(plansProvider)
        ..invalidate(dashboardProvider)
        ..invalidate(productsWithinLimitProvider);
    }
    return placed;
  }
}

final placeOrderProvider =
    NotifierProvider.autoDispose<PlaceOrderForm, FormStatus>(
      PlaceOrderForm.new,
    );

/// "Buy with AtomPay" (canvas `CheckoutDelivery`, `CheckoutReview`): two
/// steps, delivery then review & accept. Delivery goes to the verified KYC
/// address; nothing is paid in the app.
class BuyScreen extends ConsumerStatefulWidget {
  const new({required this.productId, super.key});

  final int productId;

  @override
  ConsumerState<BuyScreen> createState() => _BuyScreenState();
}

class _BuyScreenState extends ConsumerState<BuyScreen> {
  int _step = 1;
  bool _agreed = false;

  Future<void> _place(Kfs kfs) async {
    final placed = await ref
        .read(placeOrderProvider.notifier)
        .place(productId: widget.productId, kfsAmount: kfs.amountFinanced);
    if (placed == null || !mounted) return;
    final router = GoRouter.of(context);
    // The checkout may have been opened from another tab (Home's "Within
    // your limit"): close it and the product there, so no tab keeps a
    // ticked, ready-to-send checkout for an order already placed.
    Navigator.of(context).popUntil((route) => route.isFirst);
    // go(): Back from "Order placed" never returns to the checkout.
    router.go(
      Routes.orderPlaced(
        placed.orderId,
        number: placed.orderNumber,
        first: placed.instalments.isEmpty ? 0 : placed.instalments.first,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final kfs = ref.watch(buyKfsProvider(widget.productId));
    final busy = ref.watch(placeOrderProvider).busy;
    return PopScope(
      canPop: _step == 1 && !busy,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _step == 2 && !busy) setState(() => _step = 1);
      },
      child: Scaffold(
        backgroundColor: context.colors.surface,
        appBar: const AppTopBar(title: 'Buy with AtomPay'),
        body: switch (kfs) {
          // 409: they can't order this product (no limit, over it, …).
          AsyncError(error: final Conflict c) when !kfs.hasValue =>
            _CannotOrder(conflict: c),
          _ => AsyncBody(
            value: kfs,
            loading: const LoadingShape(
              label: 'Getting your order ready',
              child: Padding(
                padding: EdgeInsets.all(Space.gutter),
                child: SkeletonCard(lines: 8),
              ),
            ),
            onRetry: () => ref.invalidate(buyKfsProvider(widget.productId)),
            data: (k) => _step == 1
                ? _DeliveryStep(
                    kfs: k,
                    onContinue: () => setState(() => _step = 2),
                  )
                : _ReviewStep(
                    kfs: k,
                    agreed: _agreed,
                    onAgreed: (v) => setState(() => _agreed = v),
                    onPlace: () => _place(k),
                  ),
          ),
        },
      ),
    );
  }
}

/// Step indicator, as in the apply wizard: two bars and "Step n of 2".
class _Steps extends StatelessWidget {
  const new({required this.step, required this.label});

  final int step;
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    return Semantics(
      label: 'Step $step of 2, $label',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              for (var i = 1; i <= 2; i++) ...[
                if (i > 1) const SizedBox(width: Space.s6),
                Expanded(
                  child: Container(
                    height: 6,
                    decoration: BoxDecoration(
                      color: i < step
                          ? c.green
                          : i == step
                          ? c.primary
                          : c.line,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
              ],
            ],
          ),
          Gap.s8,
          Row(
            children: [
              Expanded(child: Text('Step $step of 2', style: t.tiny)),
              Text(
                label,
                style: t.tiny.copyWith(
                  color: c.ink,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DeliveryStep extends ConsumerWidget {
  const new({required this.kfs, required this.onContinue});

  final Kfs kfs;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.text;
    final profile = ref.watch(profileProvider).value;
    return FormPage(
      footer: AppButton.primary(
        'Continue',
        large: true,
        block: true,
        onPressed: profile == null ? null : onContinue,
      ),
      children: [
        const _Steps(step: 1, label: 'Delivery'),
        Gap.s16,
        Semantics(
          header: true,
          child: Text('Where should it go?', style: t.h2),
        ),
        Gap.s6,
        Text(
          'Atomshop delivers it and calls you before the rider comes.',
          style: t.small,
        ),
        Gap.s16,
        _ProductLine(kfs: kfs),
        Gap.s12,
        if (profile == null)
          const LoadingShape(
            label: 'Loading your address',
            child: SkeletonCard(),
          )
        else
          _AddressCard(profile: profile),
        Gap.s12,
        const Note(
          tone: NoteTone.blue,
          icon: Icons.info_outline,
          text:
              'We deliver to the address we verified. To use another one, '
              'update your details in Account › KYC & verification first.',
        ),
        Gap.s12,
        const Note(
          tone: NoteTone.wash,
          icon: Icons.local_shipping_outlined,
          text: 'Delivery charges apply, in addition to this plan.',
        ),
      ],
    );
  }
}

class _ProductLine extends StatelessWidget {
  const new({required this.kfs});

  final Kfs kfs;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    return AppCard(
      padding: const EdgeInsets.all(Space.s16),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(Radii.tile),
            ),
            child: Icon(Icons.shopping_bag_outlined, color: c.glyph),
          ),
          const SizedBox(width: Space.s14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  kfs.product ?? 'Your product',
                  style: t.base.copyWith(
                    color: c.ink,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text('Qty 1 · ${rs(kfs.amountFinanced)}', style: t.small),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AddressCard extends StatelessWidget {
  const new({required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final address = profile.residentialAddress ?? '';
    // Many addresses already end with the area and city: don't repeat them.
    final place = [
      ?profile.area?.name,
      ?profile.city?.name,
    ].where((p) => !address.toLowerCase().contains(p.toLowerCase())).join(', ');
    return Container(
      padding: const EdgeInsets.all(Space.s16),
      decoration: BoxDecoration(
        color: c.primarySoft,
        borderRadius: BorderRadius.circular(Radii.note),
        border: Border.all(color: c.primary, width: 2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.radio_button_checked, color: c.primary, size: 22),
          const SizedBox(width: Space.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'My verified address',
                  style: t.base.copyWith(
                    color: c.ink,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Gap.s4,
                Text(
                  [?profile.fullName, ?profile.mobileFormatted].join(' · '),
                  style: t.small,
                ),
                Text(
                  [
                    if (address.isNotEmpty) address,
                    if (place.isNotEmpty) place,
                  ].join(', '),
                  style: t.small,
                ),
              ],
            ),
          ),
          const AppBadge.green('Verified'),
        ],
      ),
    );
  }
}

class _ReviewStep extends ConsumerWidget {
  const new({
    required this.kfs,
    required this.agreed,
    required this.onAgreed,
    required this.onPlace,
  });

  final Kfs kfs;
  final bool agreed;
  final ValueChanged<bool> onAgreed;
  final VoidCallback onPlace;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final t = context.text;
    final status = ref.watch(placeOrderProvider);
    final offline = ref.watch(isOfflineProvider);
    final profile = ref.watch(profileProvider).value;
    final problem = _problem(status.error);
    return FormPage(
      footer: SubmitSection(
        label: agreed ? 'Place order' : 'Tick to accept the terms',
        // Our own note above: a timeout must not invite a second order.
        status: FormStatus(
          busy: status.busy,
          blockedUntil: status.blockedUntil,
        ),
        offline: offline,
        enabled: agreed,
        onSubmit: onPlace,
      ),
      children: [
        const _Steps(step: 2, label: 'Review & accept'),
        Gap.s16,
        Semantics(header: true, child: Text('Review your order', style: t.h2)),
        Gap.s6,
        Text(
          'Nothing is charged today. Check the terms, then place the order.',
          style: t.small,
        ),
        Gap.s16,
        AppCard(
          padding: const EdgeInsets.symmetric(
            horizontal: Space.s18,
            vertical: Space.s16,
          ),
          child: KeyValueList([
            KeyValue('Product', kfs.product ?? ''),
            KeyValue(
              'Cash price',
              rs(kfs.amountFinanced),
              spoken: rsSpoken(kfs.amountFinanced),
            ),
            KeyValue('Advance', rs(kfs.advance), spoken: rsSpoken(kfs.advance)),
            if (profile != null)
              KeyValue('Deliver to', profile.residentialAddress ?? ''),
          ]),
        ),
        Gap.s12,
        AppCard(
          padding: const EdgeInsets.symmetric(
            horizontal: Space.s18,
            vertical: Space.s16,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                header: true,
                child: Text('You repay Atomshop', style: t.h4),
              ),
              Gap.s12,
              KeyValueList([
                for (final i in kfs.instalments)
                  KeyValue(kfsDue(i), rs(i.amount), spoken: rsSpoken(i.amount)),
              ]),
              Gap.s12,
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: Space.s16,
                  vertical: Space.s14,
                ),
                decoration: BoxDecoration(
                  color: c.greenSoft,
                  borderRadius: BorderRadius.circular(Radii.note),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Pay today',
                        style: t.base.copyWith(
                          color: c.green,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Text(
                      rs(0),
                      style: t.base.copyWith(
                        color: c.green,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              Gap.s8,
              Text(
                'Total ${rs(kfs.totalRepayable)} · '
                '${kfs.markupPercent}% markup · your first instalment is due '
                'a month after delivery.',
                style: t.tiny,
              ),
            ],
          ),
        ),
        Gap.s12,
        ListRow(
          title: 'Read the Key Fact Statement',
          icon: Icons.description_outlined,
          onTap: () => _showKfs(context, kfs),
        ),
        Gap.s12,
        ConsentRow(
          value: agreed,
          onChanged: status.busy ? null : onAgreed,
          child: Text(
            'I have read the Key Fact Statement. I am buying this from '
            'Atomshop on instalments and agree to pay '
            '${rs(kfs.totalRepayable)} in ${kfs.months} monthly instalments.',
            style: t.base,
          ),
        ),
        if (problem != null) ...[
          Gap.s12,
          Semantics(
            liveRegion: true,
            child: Note(tone: NoteTone.rose, text: problem),
          ),
        ],
      ],
    );
  }

  /// Every refusal in the server's words. A timeout or server fault may
  /// still have placed the order: send them to My orders, never "try again".
  static String? _problem(ApiException? e) => switch (e) {
    null || RateLimited() || Unauthenticated() => null,
    final Validation v =>
      v.first('order') ?? v.first('accept_kfs') ?? v.message,
    final Conflict c => c.message,
    Offline() => "You're offline. Connect and try again.",
    Timeout() || Server() =>
      "We couldn't confirm your order. Check My orders before you try again: "
          'it may have gone through.',
    final ApiException other => other.message,
  };

  static Future<void> _showKfs(BuildContext context, Kfs kfs) =>
      showModalBottomSheet<void>(
        context: context,
        // Above the tab bar, not under it.
        useRootNavigator: true,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (context) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.85,
          maxChildSize: 0.95,
          builder: (context, scroll) => ListView(
            controller: scroll,
            padding: const EdgeInsets.fromLTRB(
              Space.gutter,
              0,
              Space.gutter,
              Space.s24,
            ),
            children: [KfsCard(kfs: kfs)],
          ),
        ),
      );
}

/// The statement answered 409: the customer can't order this one.
class _CannotOrder extends StatelessWidget {
  const new({required this.conflict});

  final Conflict conflict;

  @override
  Widget build(BuildContext context) {
    final action = switch (conflict.code) {
      'limit_required' => AppButton.primary(
        'Apply for your limit',
        block: true,
        onPressed: () => context.go(Routes.application),
      ),
      'address_required' => AppButton.primary(
        'Update my details',
        block: true,
        onPressed: () => context.go(Routes.applicationEdit(1)),
      ),
      'order_in_progress' => AppButton.primary(
        'See my orders',
        block: true,
        onPressed: () => context.go(Routes.plans),
      ),
      _ => AppButton.primary(
        'Back to the product',
        block: true,
        onPressed: () => Navigator.of(context).maybePop(),
      ),
    };
    return StateView(
      icon: Icons.info_outline,
      iconTone: StateTone.amber,
      title: "You can't order this one yet",
      body: conflict.message,
      actions: [action],
    );
  }
}

/// Canvas `OrderPlaced`: the order number and what happens next. Reached
/// with go(), so Back goes to the shop.
class OrderPlacedScreen extends StatelessWidget {
  const new({
    required this.orderId,
    required this.number,
    required this.first,
    super.key,
  });

  final int orderId;
  final String number;
  final int first;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: number));
    showToast('Order number copied');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    Widget step(int n, String text) => Padding(
      padding: const EdgeInsets.only(bottom: Space.s10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: c.primarySoft,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$n',
              style: t.tiny.copyWith(
                color: c.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: Space.s12),
          Expanded(child: Text(text, style: t.small)),
        ],
      ),
    );
    return Scaffold(
      backgroundColor: c.white,
      body: SafeArea(
        child: StateView(
          icon: Icons.check,
          iconTone: StateTone.green,
          title: 'Order placed',
          titleStyle: t.h2,
          body: 'Nothing to pay today. Your order is now in My orders.',
          actions: [
            AppButton.primary(
              'See your order',
              block: true,
              onPressed: () => context.go(Routes.plan(orderId)),
            ),
            AppButton.ghost(
              'Go to Home',
              block: true,
              onPressed: () => context.go(Routes.home),
            ),
          ],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: Space.s16,
                  vertical: Space.s12,
                ),
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(Radii.note),
                  border: Border.all(color: c.line3),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Your order', style: t.tiny),
                          Text(number, style: t.h4),
                        ],
                      ),
                    ),
                    AppButton.ghost(
                      'Copy',
                      semanticLabel: 'Copy order number',
                      onPressed: () => unawaited(_copy()),
                    ),
                  ],
                ),
              ),
              Gap.s16,
              step(1, 'Atomshop confirms the order and calls you.'),
              step(2, 'The rider delivers to your verified address.'),
              if (first > 0)
                step(
                  3,
                  'First instalment ${rs(first)} a month after delivery. '
                  'We remind you before.',
                ),
            ],
          ),
        ),
      ),
    );
  }
}
