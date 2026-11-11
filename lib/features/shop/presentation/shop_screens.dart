import 'dart:async';

import 'package:atompay_mobile/core/format/input_formatters.dart';
import 'package:atompay_mobile/core/format/money.dart';
import 'package:atompay_mobile/core/network/api_exception.dart';
import 'package:atompay_mobile/core/router/app_shell.dart';
import 'package:atompay_mobile/core/router/navigation.dart';
import 'package:atompay_mobile/core/router/routes.dart';
import 'package:atompay_mobile/core/theme/tokens.dart';
import 'package:atompay_mobile/core/utils/links.dart';
import 'package:atompay_mobile/core/widgets/buttons.dart';
import 'package:atompay_mobile/core/widgets/fields.dart';
import 'package:atompay_mobile/core/widgets/form_parts.dart';
import 'package:atompay_mobile/core/widgets/pressable.dart';
import 'package:atompay_mobile/core/widgets/product_card.dart';
import 'package:atompay_mobile/core/widgets/states.dart';
import 'package:atompay_mobile/core/widgets/ui.dart';
import 'package:atompay_mobile/features/home/application/home_controller.dart';
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
    final t = context.text;

    Widget chip(String label, {required bool selected, VoidCallback? onTap}) =>
        Padding(
          padding: const EdgeInsets.only(right: Space.s8),
          child: Pressable(
            onTap: onTap,
            selected: selected,
            semanticLabel: label,
            excludeChildSemantics: true,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: Space.s16,
                vertical: Space.s10,
              ),
              decoration: BoxDecoration(
                color: selected ? context.colors.ink : context.colors.white,
                borderRadius: BorderRadius.circular(Radii.pill),
                border: Border.all(
                  color: selected ? context.colors.ink : context.colors.line2,
                ),
              ),
              child: Text(
                label,
                style: t.small.copyWith(
                  color: selected ? context.colors.white : context.colors.ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        );

    final header = Padding(
      padding: const EdgeInsets.fromLTRB(
        Space.gutter,
        Space.s8,
        Space.s8,
        Space.s8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Eyebrow('Shop with AtomPay', atomPay: true),
                    Semantics(
                      header: true,
                      child: Text('Eligible products', style: t.h2),
                    ),
                  ],
                ),
              ),
              AppIconButton(
                icon: _searching ? Icons.close : Icons.search,
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
          Gap.s4,
          Text('Look for the badge on the listing.', style: t.base),
          Text(
            'AtomPay is offered on selected listed products only, never on '
            'custom orders or offers.',
            style: t.small,
          ),
          if (_searching) ...[
            Gap.s12,
            Padding(
              padding: const EdgeInsets.only(right: Space.s8),
              child: AppTextField(
                label: 'Search',
                controller: _search,
                placeholder: 'Brand or product',
                textInputAction: TextInputAction.search,
                onChanged: _onSearch,
              ),
            ),
          ],
        ],
      ),
    );

    final chips = SizedBox(
      height: Sizes.target,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
        children: [
          chip(
            'All',
            selected: filter.category == null,
            onTap: () => _setFilter(
              ProductFilter(
                query: filter.query,
                withinLimit: filter.withinLimit,
              ),
            ),
          ),
          for (final cat in categories)
            chip(
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
          if (hasLimit)
            chip(
              'Fits my limit',
              selected: filter.withinLimit,
              onTap: () => _setFilter(
                ProductFilter(
                  category: filter.category,
                  query: filter.query,
                  withinLimit: !filter.withinLimit,
                ),
              ),
            ),
        ],
      ),
    );

    Widget content(ProductPage page) {
      if (page.items.isEmpty) {
        return SliverFillRemaining(
          hasScrollBody: false,
          child: StateView(
            icon: Icons.inventory_2_outlined,
            title: 'Nothing here right now',
            body: filter.withinLimit
                ? 'No eligible products fit your limit at the moment. New '
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
        padding: const EdgeInsets.fromLTRB(
          Space.gutter,
          Space.s8,
          Space.gutter,
          Space.s32,
        ),
        sliver: SliverList.list(
          children: [
            for (var i = 0; i < page.items.length; i += columns) ...[
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var j = 0; j < columns; j++) ...[
                      if (j > 0) const SizedBox(width: Space.s12),
                      Expanded(
                        child: i + j < page.items.length
                            ? _card(page.items[i + j])
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ],
                ),
              ),
              Gap.s12,
            ],
            if (more)
              const Padding(
                padding: EdgeInsets.all(Space.s16),
                child: Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      );
    }

    return TabRootBack(
      child: Scaffold(
        backgroundColor: context.colors.surface,
        body: SafeArea(
          bottom: false,
          child: ScrollToTopOnReselect(
            controller: _scroll,
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: CustomScrollView(
                controller: _scroll,
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(child: header),
                  SliverToBoxAdapter(child: chips),
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
                    _ => SliverToBoxAdapter(
                      child: _ShopSkeleton(columns: columns),
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

class _ShopSkeleton extends StatelessWidget {
  const new({required this.columns});

  final int columns;

  @override
  Widget build(BuildContext context) => LoadingShape(
    label: 'Loading products',
    child: Padding(
      padding: const EdgeInsets.all(Space.gutter),
      child: Column(
        children: [
          for (var r = 0; r < 2; r++) ...[
            Row(
              children: [
                for (var j = 0; j < columns; j++) ...[
                  if (j > 0) const SizedBox(width: Space.s12),
                  const Expanded(child: SkeletonCard(height: 250)),
                ],
              ],
            ),
            Gap.s12,
          ],
        ],
      ),
    ),
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
      appBar: const AppTopBar(title: 'Your plan', bottomBorder: true),
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
    return FormPage(
      footer: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppButton.dark(
            'Buy on Atomshop.pk',
            large: true,
            block: true,
            trailingIcon: Icons.north_east,
            semanticLabel: 'Buy on Atomshop.pk, opens outside the app',
            onPressed: () => Links.open(product.url),
          ),
          Gap.s8,
          AppButton.ghost(
            'Ask Atom about this plan',
            block: true,
            onPressed: () => context.pushOnce(Routes.atom),
          ),
        ],
      ),
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(Radii.productCard),
          child: SizedBox(
            height: 220,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ColoredBox(
                  color: c.white,
                  child: product.imageUrl == null
                      ? Icon(Icons.image_outlined, size: 56, color: c.glyph)
                      : Image.network(
                          product.imageUrl!,
                          fit: BoxFit.contain,
                          semanticLabel: product.title,
                          errorBuilder: (_, _, _) => Icon(
                            Icons.image_outlined,
                            size: 56,
                            color: c.glyph,
                          ),
                        ),
                ),
                const Positioned(
                  left: Space.s12,
                  top: Space.s12,
                  child: AppBadge.rose('AtomPay eligible'),
                ),
              ],
            ),
          ),
        ),
        Gap.s16,
        if (product.brand != null)
          Text(
            product.brand!.toUpperCase(),
            style: t.xs.copyWith(letterSpacing: 0.6),
          ),
        Semantics(header: true, child: Text(product.title, style: t.h2)),
        Gap.s4,
        Semantics(
          label: 'Cash price ${rsSpoken(product.price)}',
          excludeSemantics: true,
          child: Text('Cash price ${rs(product.price)}', style: t.base),
        ),
        if (product.description != null) ...[
          Gap.s8,
          Text(product.description!, style: t.small),
        ],
        Gap.s16,
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
            onRetry: () => ref.invalidate(planPreviewProvider(product.price)),
          ),
          _ => const LoadingShape(
            label: 'Loading the plan',
            child: SkeletonCard(lines: 5),
          ),
        },
        Gap.s14,
        Text(
          'You place the order on Atomshop.pk and choose AtomPay at checkout.',
          style: t.small,
          textAlign: TextAlign.center,
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
      appBar: const AppTopBar(title: 'Estimate a plan', bottomBorder: true),
      body: FormPage(
        children: [
          Text('See roughly what a monthly payment looks like.', style: t.h3),
          Gap.s4,
          Text(
            'One price in, three months out. No advance and no markup to '
            'choose.',
            style: t.lead,
          ),
          Gap.s20,
          AppTextField(
            label: 'Product price',
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
            Gap.s12,
            Text('Try a real product', style: t.small),
            Gap.s6,
            Wrap(
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
                        vertical: Space.s10,
                      ),
                      decoration: BoxDecoration(
                        color: c.white,
                        borderRadius: BorderRadius.circular(Radii.pill),
                        border: Border.all(color: c.line2),
                      ),
                      child: Text(
                        '${p.title} · ${rs(p.price)}',
                        style: t.small.copyWith(
                          color: c.ink,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
          Gap.s20,
          switch (preview) {
            null => const SizedBox.shrink(),
            AsyncData(:final value) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppCard(
                  color: c.primarySoft,
                  borderColor: c.primaryLine,
                  semanticLabel:
                      '${rsSpoken(value.instalments.first)} per month for '
                      '${value.months} months',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'PER MONTH × ${value.months}',
                        style: t.tiny.copyWith(
                          color: c.primary,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                      Text(rs(value.instalments.first), style: t.h1),
                    ],
                  ),
                ),
                Gap.s12,
                PlanBreakdown(plan: value),
                Gap.s12,
                const Note(
                  tone: NoteTone.blue,
                  text:
                      'This is a close estimate to plan your budget. Your '
                      'exact plan is confirmed at AtomShop checkout once you '
                      'pick a real product.',
                ),
              ],
            ),
            AsyncError(error: Validation()) => const SizedBox.shrink(),
            AsyncError(:final error) => ErrorStateView(
              error: error,
              onRetry: () => ref.invalidate(planPreviewProvider(price!)),
            ),
            _ => const LoadingShape(
              label: 'Working out the plan',
              child: SkeletonCard(lines: 5),
            ),
          },
        ],
      ),
    );
  }
}
