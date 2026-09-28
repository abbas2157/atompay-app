import 'package:atompay_mobile/core/network/api_exception.dart';
import 'package:atompay_mobile/core/theme/tokens.dart';
import 'package:atompay_mobile/core/widgets/states.dart';
import 'package:atompay_mobile/core/widgets/ui.dart';
import 'package:atompay_mobile/features/profile/data/profile_models.dart';
import 'package:atompay_mobile/features/profile/domain/profile_controllers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The picker's answer. `city == null` means "no city" (it's optional).
class CityChoice {
  const new(this.city);

  final City? city;
}

/// Searchable city list from `GET /cities`. Returns null when dismissed.
Future<CityChoice?> showCityPicker(BuildContext context, {City? selected}) {
  return showModalBottomSheet<CityChoice>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => FractionallySizedBox(
      heightFactor: 0.85,
      child: _CityPicker(selected: selected),
    ),
  );
}

class _CityPicker extends ConsumerStatefulWidget {
  const new({this.selected});

  final City? selected;

  @override
  ConsumerState<_CityPicker> createState() => _CityPickerState();
}

class _CityPickerState extends ConsumerState<_CityPicker> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cities = ref.watch(citiesProvider);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
            child: Text(l10n.cityPickerTitle, style: context.text.title),
          ),
          Padding(
            padding: const EdgeInsets.all(Space.gutter),
            child: TextField(
              autofocus: true,
              decoration: InputDecoration(
                hintText: l10n.citySearchHint,
                prefixIcon: const Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
            ),
          ),
          Expanded(
            child: switch (cities) {
              AsyncData(:final value) => _list(value),
              AsyncError(:final error) => MessageView(
                message: error is ApiException
                    ? apiErrorText(l10n, error)
                    : l10n.genericError,
                actionLabel: l10n.tryAgain,
                onAction: () => ref.invalidate(citiesProvider),
              ),
              _ => const Center(child: CircularProgressIndicator()),
            },
          ),
        ],
      ),
    );
  }

  Widget _list(List<City> all) {
    final l10n = context.l10n;
    final matches = _query.isEmpty
        ? all
        : all.where((c) => c.name.toLowerCase().contains(_query)).toList();
    if (matches.isEmpty) return MessageView(message: l10n.noCityMatches);
    return ListView.builder(
      itemCount: matches.length + 1,
      itemBuilder: (context, i) {
        if (i == 0) {
          return ListTile(
            title: Text(l10n.clearCity),
            onTap: () => Navigator.of(context).pop(const CityChoice(null)),
          );
        }
        final city = matches[i - 1];
        final selected = city.id == widget.selected?.id;
        return ListTile(
          title: Text(city.name),
          selected: selected,
          trailing: selected ? const Icon(Icons.check) : null,
          onTap: () => Navigator.of(context).pop(CityChoice(city)),
        );
      },
    );
  }
}
