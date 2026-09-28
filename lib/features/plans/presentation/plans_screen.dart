import 'package:atompay_mobile/core/network/api_exception.dart';
import 'package:atompay_mobile/core/router/routes.dart';
import 'package:atompay_mobile/core/theme/tokens.dart';
import 'package:atompay_mobile/core/widgets/states.dart';
import 'package:atompay_mobile/core/widgets/ui.dart';
import 'package:atompay_mobile/features/launch/domain/launch_controller.dart';
import 'package:atompay_mobile/features/plans/data/plan_models.dart';
import 'package:atompay_mobile/features/plans/domain/plans_controller.dart';
import 'package:atompay_mobile/features/plans/presentation/plan_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Plans tab: Active and History (handbook §5.9).
class PlansScreen extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.plansTitle),
          actions: [
            IconButton(
              tooltip: l10n.calculatorTitle,
              icon: const Icon(Icons.calculate_outlined),
              onPressed: () => context.push(Routes.calculator),
            ),
          ],
          bottom: TabBar(
            labelColor: context.tokens.ink,
            indicatorColor: AppColors.violet,
            tabs: [
              Tab(text: l10n.tabActive),
              Tab(text: l10n.tabHistory),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _PlanList(provider: activePlansProvider, empty: l10n.noPlans),
            _PlanList(
              provider: completedPlansProvider,
              empty: l10n.noCompletedPlans,
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanList extends ConsumerWidget {
  const new({required this.provider, required this.empty});

  final FutureProvider<List<Plan>> provider;
  final String empty;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final plans = ref.watch(provider);
    final shopUrl = ref.watch(appConfigProvider).shopUrl;

    return RefreshIndicator(
      onRefresh: () => ref.refresh(provider.future),
      child: switch (plans) {
        AsyncValue(:final value?) when value.isEmpty => ListView(
          children: [
            MessageView(
              message: empty,
              actionLabel: l10n.shopOnAtomShop,
              onAction: () => openLink(context, Uri.parse(shopUrl)),
            ),
          ],
        ),
        AsyncValue(:final value?) => ListView.separated(
          padding: const EdgeInsets.all(Space.gutter),
          itemCount: value.length,
          separatorBuilder: (_, _) => const SizedBox(height: Space.x16),
          itemBuilder: (context, i) => PlanCard(
            plan: value[i],
            onTap: () => context.push(Routes.plan(value[i].order.id)),
          ),
        ),
        AsyncError(:final error) => ListView(
          children: [
            MessageView(
              message: error is ApiException
                  ? apiErrorText(l10n, error)
                  : l10n.genericError,
              actionLabel: l10n.tryAgain,
              onAction: () => ref.invalidate(provider),
            ),
          ],
        ),
        _ => ListView(
          padding: const EdgeInsets.all(Space.gutter),
          children: const [
            Skeleton(height: 280, radius: Radii.card),
            SizedBox(height: Space.x16),
            Skeleton(height: 280, radius: Radii.card),
          ],
        ),
      },
    );
  }
}
