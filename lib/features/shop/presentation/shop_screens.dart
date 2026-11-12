import 'dart:async';

import 'package:atompay_mobile/core/format/input_formatters.dart';
import 'package:atompay_mobile/core/format/money.dart';
import 'package:atompay_mobile/core/network/api_exception.dart';
import 'package:atompay_mobile/core/router/app_shell.dart';
import 'package:atompay_mobile/core/router/navigation.dart';
import 'package:atompay_mobile/core/router/routes.dart';
import 'package:atompay_mobile/core/theme/tokens.dart';
import 'package:atompay_mobile/core/utils/links.dart';
import 'package:atompay_mobile/core/widgets/net_image.dart';
import 'package:atompay_mobile/core/widgets/buttons.dart';
import 'package:atompay_mobile/core/widgets/fields.dart';
import 'package:atompay_mobile/core/widgets/form_parts.dart';
import 'package:atompay_mobile/core/widgets/pressable.dart';
import 'package:atompay_mobile/core/widgets/product_card.dart';
import 'package:atompay_mobile/core/widgets/states.dart';
import 'package:atompay_mobile/core/widgets/ui.dart';
import 'package:atompay_mobile/features/home/application/home_controller.dart';
import 'package:atompay_mobile/features/launch/application/launch_controller.dart';
import 'package:atompay_mobile/features/shop/application/shop_controller.dart';
import 'package:atompay_mobile/features/shop/data/product_models.dart';
import 'package:atompay_mobile/features/shop/presentation/plan_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ---- Shop ---------------------------------------------------------------

/// Eligible products (canvas "Eligible products"): categories, search and
/// "fits my limit", two columns on a phone and up to four on a tablet.
class ShopScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends ConsumerState<ShopScreen> {
  final _scroll = ScrollController();
  final _search = TextEditingController();
  bool _searching = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _search.text = ref.read(productFilterProvider).query;
    _searching = _search.text.isNotEmpty;
    _scroll.addListener(_maybeLoadMore);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scroll.dispose();
    _search.dispose();
    super.dispose();
  }

  ProductFilter get _filter => ref.read(productFilterProvider);

  /// A new filter starts at the top of the list.
  void _setFilter(ProductFilter f) {
    ref.read(productFilterProvider.notifier).filter = f;
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  void _maybeLoadMore() {
    if (!_scroll.hasClients) return;
    if (_scroll.position.extentAfter < 600) {
      unawaited(ref.read(productListProvider(_filter).notifier).loadMore());
    }
  }

  void _onSearch(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      final f = _filter;
      _setFilter(
        ProductFilter(
          category: f.category,
          query: text.trim(),
          withinLimit: f.withinLimit,
        ),
      );
    });
  }

  Future<void> _refresh() async {
    final f = _filter;
    ref
      ..invalidate(productCategoriesProvider)
      ..invalidate(productListProvider(f));
    try {
      await ref.read(productListProvider(f).future);
    } on Object {
      // The error state or toast covers it.
    }
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(productFilterProvider);
    listenForRefreshErrors(ref, productListProvider(filter));
    final list = ref.watch(productListProvider(filter));
    final categories = ref.watch(productCategoriesProvider).value ?? const [];
    final hasLimit = ref.watch(dashboardHasLimitProvider) ?? false;
    final width = MediaQuery.sizeOf(context).width;
    final columns = width >= 1100
        ? 4
        : width >= 840
        ? 3
        : 2;
    final c = context.colors;
    final t = context.text;

    // Canvas `.segc`: one grey pill track; the chosen segment is white.
    Widget segment(
      String label, {
      required bool selected,
      required VoidCallback onTap,
    }) => Pressable(
      onTap: onTap,
      selected: selected,
      semanticLabel: label,
      excludeChildSemantics: true,
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: Space.s16),
        decoration: BoxDecoration(
          color: selected ? c.white : null,
          borderRadius: BorderRadius.circular(Radii.pill),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: c.ink.withValues(alpha: 0.12),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: t.base.copyWith(
            color: selected ? c.ink : c.body,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );

    final segments = [
      segment(
        'All',
        selected: filter.category == null,
        onTap: () => _setFilter(
          ProductFilter(query: filter.query, withinLimit: filter.withinLimit),
        ),
      ),
      for (final cat in categories)
        segment(
          cat.title,
          selected: filter.category == cat.id,
          onTap: () => _setFilter(
            ProductFilter(
              category: cat.id,
              query: filter.query,
              withinLimit: filter.withinLimit,
            ),
          ),
        ),
    ];

    // Not on the canvas: a toggle beside the categories, styled as a
    // canvas `.chip`.
    final fitsChip = Pressable(
      onTap: () => _setFilter(
        ProductFilter(
          category: filter.category,
          query: filter.query,
          withinLimit: !filter.withinLimit,
        ),
      ),
      selected: filter.withinLimit,
      semanticLabel: 'Fits my limit',
      excludeChildSemantics: true,
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: Space.s14),
        decoration: BoxDecoration(
          color: filter.withinLimit ? c.primarySoft : c.white,
          borderRadius: BorderRadius.circular(Radii.pill),
          border: Border.all(
            color: filter.withinLimit ? c.primaryLine : c.line2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (filter.withinLimit) ...[
              Icon(Icons.check, size: 16, color: c.primaryDark),
              const SizedBox(width: Space.s6),
            ],
            Text(
              'Fits my limit',
              style: t.small.copyWith(
                color: filter.withinLimit ? c.primaryDark : c.ink,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );

    final filters = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(Space.s4),
            decoration: BoxDecoration(
              color: c.greySoft,
              borderRadius: BorderRadius.circular(Radii.pill),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < segments.length; i++) ...[
                  if (i > 0) const SizedBox(width: Space.s4),
                  segments[i],
                ],
              ],
            ),
          ),
          if (hasLimit) ...[const SizedBox(width: Space.s8), fitsChip],
        ],
      ),
    );

    final intro = [
      const Eyebrow('Eligible products'),
      Gap.s6,
      Semantics(
        header: true,
        child: Text('Look for the badge on the listing.', style: t.h2),
      ),
      Gap.s6,
      Text(
        'AtomPay is offered on selected listed products only — never on '
        'custom orders or offers.',
        style: t.small,
      ),
      if (_searching) ...[
        Gap.s14,
        AppTextField(
          label: 'Search',
          controller: _search,
          placeholder: 'Brand or product',
          textInputAction: TextInputAction.search,
          onChanged: _onSearch,
        ),
      ],
      Gap.s14,
      filters,
    ];

    const gridPadding = EdgeInsets.fromLTRB(
      Space.gutter,
      Space.s14,
      Space.gutter,
      Space.s32,
    );

    Widget row(int start, int count, Widget Function(int) build) =>
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var j = 0; j < columns; j++) ...[
                if (j > 0) const SizedBox(width: Space.s12),
                Expanded(
                  child: start + j < count
                      ? build(start + j)
                      : const SizedBox.shrink(),
                ),
              ],
            ],
          ),
        );

    Widget content(ProductPage page) {
      if (page.items.isEmpty) {
        return SliverFillRemaining(
          hasScrollBody: false,
          child: StateView(
            icon: Icons.shopping_bag_outlined,
            title: 'Nothing here right now',
            body: filter.withinLimit
                ? 'No eligible phones fit your limit at the moment. New '
                      'products are added every week.'
                : 'No eligible products match. New products are added every '
                      'week.',
            actions: [
              if (!filter.isDefault)
                AppButton.primary(
                  'Show all products',
                  block: true,
                  onPressed: () {
                    _search.clear();
                    _setFilter(const ProductFilter());
                  },
                ),
              AppButton.ghost(
                'Estimate a plan',
                block: true,
                onPressed: () => context.pushOnce(Routes.calculator),
              ),
            ],
          ),
        );
      }
      final more = ref.read(productListProvider(filter).notifier).hasMore;
      return SliverPadding(
        padding: gridPadding,
        // Built lazily: only the rows on screen exist, however many pages
        // have loaded.
        sliver: SliverList.builder(
          itemCount: (page.items.length / columns).ceil() + (more ? 1 : 0),
          itemBuilder: (context, r) {
            final i = r * columns;
            if (i >= page.items.length) {
              return const Padding(
                padding: EdgeInsets.all(Space.s16),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            return Padding(
              padding: EdgeInsets.only(top: r == 0 ? 0 : Space.s12),
              child: row(i, page.items.length, (k) => _card(page.items[k])),
            );
          },
        ),
      );
    }

    return TabRootBack(
      child: Scaffold(
        backgroundColor: c.surface,
        appBar: AppTopBar(
          title: 'Shop with AtomPay',
          leading: null,
          actions: [
            AppIconButton(
              icon: _searching ? Icons.close : Icons.search,
              size: 22,
              label: _searching ? 'Close search' : 'Search products',
              onPressed: () {
                setState(() => _searching = !_searching);
                if (!_searching && _search.text.isNotEmpty) {
                  _search.clear();
                  _onSearch('');
                }
              },
            ),
          ],
        ),
        body: SafeArea(
          top: false,
          bottom: false,
          child: ScrollToTopOnReselect(
            controller: _scroll,
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: CustomScrollView(
                controller: _scroll,
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      Space.gutter,
                      Space.gutter,
                      Space.gutter,
                      0,
                    ),
                    sliver: SliverList.list(children: intro),
                  ),
                  switch (list) {
                    AsyncValue(hasValue: true, :final value?) => content(value),
                    AsyncError(:final error) => SliverFillRemaining(
                      hasScrollBody: false,
                      child: ErrorStateView(
                        error: error,
                        onRetry: () =>
                            ref.invalidate(productListProvider(filter)),
                      ),
                    ),
                    _ => SliverPadding(
                      padding: gridPadding,
                      sliver: SliverToBoxAdapter(
                        child: LoadingShape(
                          label: 'Loading products',
                          child: Column(
                            children: [
                              for (var r = 0; r < 2; r++) ...[
                                if (r > 0) Gap.s12,
                                row(
                                  r * columns,
                                  columns * 2,
                                  (_) => const ProductCardSkeleton(),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  },
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _card(Product p) => ProductCard(
    title: p.title,
    brand: p.brand,
    price: p.price,
    monthly: p.monthly,
    imageUrl: p.imageUrl,
    onTap: () => context.pushOnce(Routes.product(p.id)),
  );
}

// ---- Product plan ---------------------------------------------------------

/// One product and its 3-month plan from `/plan-preview` (canvas "Your
/// plan"). "Buy on Atomshop.pk" opens the listing outside the app.
class ProductScreen extends ConsumerWidget {
  const new({required this.productId, super.key});

  final int productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final product = ref.watch(productProvider(productId));
    return Scaffold(
      backgroundColor: context.colors.surface,
      appBar: const AppTopBar(title: 'Your plan'),
      body: AsyncBody(
        value: product,
        loading: const LoadingShape(
          label: 'Loading this product',
          child: Padding(
            padding: EdgeInsets.all(Space.gutter),
            child: Column(
              children: [
                SkeletonCard(height: 220),
                Gap.s14,
                SkeletonCard(lines: 5),
              ],
            ),
          ),
        ),
        onRetry: () => ref.invalidate(productProvider(productId)),
        notFound: "This product isn't eligible",
        notFoundAction: AppButton.primary(
          'See eligible products',
          block: true,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        data: (p) => _ProductBody(product: p),
      ),
    );
  }
}

class _ProductBody extends ConsumerWidget {
  const new({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.text;
    final c = context.colors;
    final preview = ref.watch(planPreviewProvider(product.price));
    final limit = ref.watch(dashboardProvider).value?.data.limit;
    // In the app once the server takes orders and there is a limit; the
    // server still says no (409) when this product doesn't fit.
    final buyInApp =
        ref.watch(appConfigProvider).features.inAppOrders &&
        (limit?.hasLimit ?? false) &&
        (preview.value?.fitsLimit ?? false);
    final image = product.imageUrl == null
        ? Icon(Icons.image_outlined, size: 56, color: c.glyph)
        : NetImage(
            product.imageUrl!,
            semanticLabel: product.title,
            fallback: Icon(Icons.image_outlined, size: 56, color: c.glyph),
          );
    return FormPage(
      padding: EdgeInsets.zero,
      children: [
        // Full bleed, on surface, with a hairline under it (canvas).
        Container(
          height: 240,
          decoration: BoxDecoration(
            color: c.surface,
            border: Border(bottom: BorderSide(color: c.line)),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              image,
              const Positioned(
                left: Space.s16,
                top: Space.s16,
                child: AppBadge.rose('AtomPay eligible'),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(Space.gutter),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (product.brand != null) ...[
                Text(
                  product.brand!.toUpperCase(),
                  style: t.xs.copyWith(letterSpacing: 0.6),
                ),
                Gap.s4,
              ],
              Semantics(header: true, child: Text(product.title, style: t.h2)),
              Gap.s4,
              Semantics(
                label: 'Cash price ${rsSpoken(product.price)}',
                excludeSemantics: true,
                child: Text.rich(
                  TextSpan(
                    style: t.small,
                    children: [
                      const TextSpan(text: 'Cash price '),
                      TextSpan(
                        text: rs(product.price),
                        style: TextStyle(
                          color: c.ink,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Gap.s14,
              switch (preview) {
                AsyncData(:final value) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    PlanBreakdown(plan: value, title: 'Your AtomPay plan'),
                    if (value.fitsLimit != null && limit != null) ...[
                      Gap.s14,
                      _FitNote(
                        plan: value,
                        available: limit.available,
                        cap: limit.maxInstalment,
                      ),
                    ],
                  ],
                ),
                AsyncError(:final error) => ErrorStateView(
                  error: error,
                  onRetry: () =>
                      ref.invalidate(planPreviewProvider(product.price)),
                ),
                _ => const LoadingShape(
                  label: 'Loading the plan',
                  child: SkeletonCard(lines: 5),
                ),
              },
              Gap.s14,
              if (buyInApp) ...[
                AppButton.primary(
                  'Buy with AtomPay',
                  large: true,
                  block: true,
                  onPressed: () => context.pushOnce(Routes.buy(product.id)),
                ),
                Gap.s14,
                AppButton.ghost(
                  'Ask Atom about this plan',
                  block: true,
                  onPressed: () => context.pushOnce(Routes.atom),
                ),
                Gap.s4,
                Center(
                  child: TextButton.icon(
                    onPressed: () => Links.open(product.url),
                    iconAlignment: IconAlignment.end,
                    icon: const Icon(Icons.north_east, size: 16),
                    label: Semantics(
                      label:
                          'Buy on Atomshop.pk instead, opens outside the app',
                      excludeSemantics: true,
                      child: const Text('Buy on Atomshop.pk instead'),
                    ),
                  ),
                ),
              ] else ...[
                AppButton.dark(
                  'Buy on Atomshop.pk',
                  large: true,
                  block: true,
                  trailingIcon: Icons.north_east,
                  semanticLabel: 'Buy on Atomshop.pk, opens outside the app',
                  onPressed: () => Links.open(product.url),
                ),
                Gap.s14,
                AppButton.ghost(
                  'Ask Atom about this plan',
                  block: true,
                  onPressed: () => context.pushOnce(Routes.atom),
                ),
                Gap.s14,
                Text(
                  'You place the order on Atomshop.pk and choose AtomPay at '
                  'checkout.',
                  style: t.tiny,
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Whether the plan fits, in the server's words (`fits_limit`) with the
/// dashboard's figures.
class _FitNote extends StatelessWidget {
  const new({required this.plan, required this.available, required this.cap});

  final PlanPreview plan;
  final int available;
  final int cap;

  @override
  Widget build(BuildContext context) {
    final monthly = plan.instalments.isEmpty ? 0 : plan.instalments.first;
    if (plan.fitsLimit ?? false) {
      final capText = cap > 0
          ? ', and ${rs(monthly)} a month is under your ${rs(cap)} cap'
          : '';
      return Note(
        tone: NoteTone.green,
        icon: Icons.check,
        text: 'Fits your limit. ${rs(available)} available$capText.',
      );
    }
    return Note(
      tone: NoteTone.amber,
      text:
          "This doesn't fit your limit right now: you have ${rs(available)} "
          'available, and the whole price has to fit because nothing is paid '
          'up front.',
    );
  }
}

// ---- Calculator -------------------------------------------------------------

/// "Estimate a plan": one price in, three months out, from `/plan-preview`
/// (never `/quote`, which prices Atomshop's own financing).
class CalculatorScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends ConsumerState<CalculatorScreen> {
  final _price = TextEditingController();
  Timer? _debounce;
  int? _priceFor;

  @override
  void dispose() {
    _debounce?.cancel();
    _price.dispose();
    super.dispose();
  }

  void _onPrice(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) setState(() => _priceFor = parseRupees(text));
    });
  }

  void _usePrice(int price) {
    _debounce?.cancel();
    _price.text = grouped(price);
    setState(() => _priceFor = price);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.text;
    final c = context.colors;
    final price = _priceFor;
    final preview = price == null
        ? null
        : ref.watch(planPreviewProvider(price));
    final suggestions =
        ref.watch(productListProvider(const ProductFilter())).value?.items ??
        const <Product>[];
    final error = switch (preview) {
      AsyncError(error: final Validation v) => v.first('price') ?? v.message,
      _ => null,
    };
    return Scaffold(
      backgroundColor: c.surface,
      appBar: const AppTopBar(title: 'Estimate a plan'),
      body: FormPage(
        children: [
          Semantics(
            header: true,
            child: Text(
              'See roughly what a monthly payment looks like.',
              style: t.h2,
            ),
          ),
          Gap.s6,
          Text(
            'One price in, three months out. No advance and no markup to '
            'choose.',
            style: t.small,
          ),
          Gap.s14,
          AppTextField(
            label: 'Product price',
            large: true,
            controller: _price,
            prefixText: 'Rs. ',
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(9),
              GroupedDigitsFormatter(),
            ],
            error: error,
            onChanged: _onPrice,
          ),
          if (suggestions.isNotEmpty) ...[
            Gap.s14,
            // Canvas `.chips`: the label is for screen readers only.
            Semantics(
              container: true,
              label: 'Try a real product',
              child: Wrap(
                spacing: Space.s8,
                runSpacing: Space.s8,
                children: [
                  for (final p in suggestions.take(4))
                    Pressable(
                      onTap: () => _usePrice(p.price),
                      semanticLabel: '${p.title}, ${rsSpoken(p.price)}',
                      excludeChildSemantics: true,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: Space.s14,
                          vertical: Space.s8,
                        ),
                        decoration: BoxDecoration(
                          color: c.primarySoft,
                          borderRadius: BorderRadius.circular(Radii.pill),
                          border: Border.all(color: c.primaryLine),
                        ),
                        child: Center(
                          widthFactor: 1,
                          heightFactor: 1,
                          child: Text(
                            '${p.title} · ${rs(p.price)}',
                            style: t.small.copyWith(
                              color: c.primaryDark,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
          switch (preview) {
            null => const SizedBox.shrink(),
            AsyncData(:final value) => Padding(
              padding: const EdgeInsets.only(top: Space.s14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _EstimateCard(plan: value),
                  Gap.s14,
                  FeeDisclaimer(
                    percent: value.processingFeePercent,
                    fee: value.processingFee,
                  ),
                ],
              ),
            ),
            AsyncError(error: Validation()) => const SizedBox.shrink(),
            AsyncError(:final error) => ErrorStateView(
              error: error,
              onRetry: () => ref.invalidate(planPreviewProvider(price!)),
            ),
            _ => const Padding(
              padding: EdgeInsets.only(top: Space.s14),
              child: LoadingShape(
                label: 'Working out the plan',
                child: SkeletonCard(lines: 5),
              ),
            ),
          },
          Gap.s14,
          const Note(
            tone: NoteTone.blue,
            text:
                'This is a close estimate to plan your budget — your exact '
                'plan is confirmed at AtomShop checkout once you pick a real '
                'product.',
          ),
        ],
      ),
    );
  }
}

/// The estimate: the monthly amount large, then each month and the total
/// (canvas Calculator). Every figure is the server's. Primary soft, not the
/// gradient: that belongs to the limit card alone (brief §4).
class _EstimateCard extends StatelessWidget {
  const new({required this.plan});

  final PlanPreview plan;

  @override
  Widget build(BuildContext context) {
    final t = context.text;
    final c = context.colors;
    final months = plan.instalments;
    final plain = plan.advance == 0 && plan.markup == 0;
    final rows = [
      for (var i = 0; i < months.length; i++) ('Month ${i + 1}', months[i]),
      (plain ? 'Total · no advance, 0% markup' : 'Total', plan.total),
    ];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Space.s20),
      decoration: BoxDecoration(
        color: c.primarySoft,
        borderRadius: BorderRadius.circular(Radii.list),
        border: Border.all(color: c.primaryLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'PER MONTH × ${plan.months}',
            style: t.tiny.copyWith(
              color: c.primary,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
          Gap.s14,
          if (months.isNotEmpty)
            Semantics(
              label: '${rsSpoken(months.first)} per month',
              excludeSemantics: true,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  rs(months.first),
                  style: t.display.copyWith(height: 1.05),
                ),
              ),
            ),
          Gap.s14,
          for (var i = 0; i < rows.length; i++)
            MergeSemantics(
              child: Container(
                padding: EdgeInsets.only(
                  top: i == 0 ? Space.s4 : Space.s12,
                  bottom: Space.s12,
                ),
                decoration: i == 0
                    ? null
                    : BoxDecoration(
                        border: Border(top: BorderSide(color: c.primaryLine)),
                      ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        rows[i].$1,
                        style: t.body.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: Space.s12),
                    Semantics(
                      label: rsSpoken(rows[i].$2),
                      excludeSemantics: true,
                      child: Text(rs(rows[i].$2), style: t.h4),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
