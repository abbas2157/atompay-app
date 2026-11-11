import 'package:atompay_mobile/core/theme/tokens.dart';
import 'package:atompay_mobile/core/widgets/buttons.dart';
import 'package:atompay_mobile/core/widgets/pressable.dart';
import 'package:flutter/material.dart';

/// One choice in a [PickerSheet].
@immutable
class PickerOption<T> {
  const new(this.value, this.title, {this.subtitle});

  final T value;
  final String title;

  /// A second line, also searched ("OXY 3218L Android · delivered 9 Nov").
  final String? subtitle;
}

/// Search matches anywhere in the label, ignores case and extra spaces, and
/// keeps the list's order.
List<PickerOption<T>> filterOptions<T>(
  List<PickerOption<T>> options,
  String query,
) {
  final q = normaliseQuery(query);
  if (q.isEmpty) return options;
  return [
    for (final o in options)
      if ('${o.title} ${o.subtitle ?? ''}'.toLowerCase().contains(q)) o,
  ];
}

String normaliseQuery(String query) =>
    query.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

/// Looks like an input; opens a [PickerSheet]. Disabled with [disabledText]
/// ("Choose a city first") until its parent value is set.
class PickerField<T> extends StatelessWidget {
  const new({
    required this.label,
    required this.sheetTitle,
    required this.noun,
    required this.options,
    required this.value,
    required this.onChanged,
    this.placeholder = 'Choose',
    this.searchPlaceholder = 'Type to search',
    this.disabledText,
    this.error,
    this.loading = false,
    this.total,
    this.focusNode,
    super.key,
  });

  final String label;
  final String sheetTitle;

  /// Plural for the count line: "cities", "areas in Lahore".
  final String noun;
  final List<PickerOption<T>> options;
  final T? value;
  final ValueChanged<T>? onChanged;
  final String placeholder;
  final String searchPlaceholder;

  /// Non-null disables the field and shows this instead.
  final String? disabledText;
  final String? error;
  final bool loading;
  final int? total;
  final FocusNode? focusNode;

  PickerOption<T>? get _selected {
    for (final o in options) {
      if (o.value == value) return o;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final disabled = disabledText != null || onChanged == null;
    final selected = _selected;
    final hasError = error != null;
    final shown = disabledText ?? selected?.title ?? placeholder;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ExcludeSemantics(child: Text(label, style: t.label)),
        const SizedBox(height: Space.s6),
        Pressable(
          focusNode: focusNode,
          onTap: disabled || loading
              ? null
              : () async {
                  final picked = await showPickerSheet<T>(
                    context: context,
                    title: sheetTitle,
                    noun: noun,
                    options: options,
                    current: value,
                    total: total,
                    searchPlaceholder: searchPlaceholder,
                  );
                  if (picked != null) onChanged?.call(picked);
                },
          scaleOnPress: false,
          borderRadius: BorderRadius.circular(Radii.input),
          semanticLabel:
              '$label, ${selected?.title ?? (disabledText ?? 'not chosen')}',
          excludeChildSemantics: true,
          child: Container(
            constraints: const BoxConstraints(minHeight: Sizes.target),
            padding: const EdgeInsets.symmetric(horizontal: Space.s14),
            decoration: BoxDecoration(
              color: hasError ? c.dangerWash : (disabled ? c.surface : c.field),
              borderRadius: BorderRadius.circular(Radii.input),
              border: Border.all(color: hasError ? c.danger : c.line2),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    shown,
                    style: t.body.copyWith(
                      color: selected == null || disabled ? c.muted : c.ink,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (loading)
                  SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: c.muted,
                    ),
                  )
                else
                  Icon(
                    Icons.keyboard_arrow_down,
                    color: disabled ? c.glyph : c.ink,
                  ),
              ],
            ),
          ),
        ),
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(top: Space.s6),
            child: Semantics(
              liveRegion: true,
              child: Text(error!, style: t.small.copyWith(color: c.rose)),
            ),
          ),
      ],
    );
  }
}

/// Opens the searchable sheet. Returns the chosen value, or null when it is
/// closed, dismissed with back or swiped down (the value stays as it was).
Future<T?> showPickerSheet<T>({
  required BuildContext context,
  required String title,
  required String noun,
  required List<PickerOption<T>> options,
  T? current,
  int? total,
  String searchPlaceholder = 'Type to search',
}) => showModalBottomSheet<T>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: false,
  builder: (_) => PickerSheet<T>(
    title: title,
    noun: noun,
    options: options,
    current: current,
    total: total,
    searchPlaceholder: searchPlaceholder,
  ),
);

class PickerSheet<T> extends StatefulWidget {
  const new({
    required this.title,
    required this.noun,
    required this.options,
    this.current,
    this.total,
    this.searchPlaceholder = 'Type to search',
    super.key,
  });

  final String title;
  final String noun;
  final List<PickerOption<T>> options;
  final T? current;
  final int? total;
  final String searchPlaceholder;

  @override
  State<PickerSheet<T>> createState() => _PickerSheetState<T>();
}

class _PickerSheetState<T> extends State<PickerSheet<T>> {
  final _query = TextEditingController();
  late T? _picked = widget.current;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  String? get _pickedTitle {
    for (final o in widget.options) {
      if (o.value == _picked) return o.title;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final shown = filterOptions(widget.options, _query.text);
    final total = widget.total ?? widget.options.length;
    final hasQuery = normaliseQuery(_query.text).isNotEmpty;
    final count = hasQuery
        ? '${shown.length} of $total ${widget.noun}'
        : '$total ${widget.noun}';
    final pickedTitle = _pickedTitle;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: FractionallySizedBox(
        heightFactor: 0.9,
        child: Column(
          children: [
            Container(
              width: 40,
              height: 5,
              margin: const EdgeInsets.only(top: Space.s10, bottom: Space.s4),
              decoration: BoxDecoration(
                color: c.line2,
                borderRadius: BorderRadius.circular(Radii.pill),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Space.s20,
                Space.s8,
                Space.s8,
                Space.s8,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Semantics(
                          header: true,
                          child: Text(widget.title, style: t.h4),
                        ),
                        Semantics(
                          liveRegion: true,
                          child: Text(count, style: t.tiny),
                        ),
                      ],
                    ),
                  ),
                  AppIconButton(
                    icon: Icons.close,
                    label: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.s16),
              child: TextField(
                controller: _query,
                autofocus: true,
                textInputAction: TextInputAction.search,
                style: t.body,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: widget.searchPlaceholder,
                  prefixIcon: Icon(Icons.search, color: c.muted),
                  suffixIcon: hasQuery || _query.text.isNotEmpty
                      ? AppIconButton(
                          icon: Icons.cancel,
                          label: 'Clear search',
                          size: 20,
                          color: c.muted,
                          onPressed: () => setState(_query.clear),
                        )
                      : null,
                  semanticCounterText: '',
                ).applyDefaults(Theme.of(context).inputDecorationTheme),
              ),
            ),
            const SizedBox(height: Space.s8),
            Expanded(
              child: shown.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(Space.s24),
                      child: Column(
                        children: [
                          Text(
                            'Nothing matches "${_query.text.trim()}". '
                            'Try fewer letters.',
                            style: t.small,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: Space.s12),
                          AppButton.ghost(
                            'Clear search',
                            onPressed: () => setState(_query.clear),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      itemCount: shown.length,
                      separatorBuilder: (_, _) =>
                          Divider(height: 1, color: c.greySoft),
                      itemBuilder: (context, i) {
                        final o = shown[i];
                        final sel = o.value == _picked;
                        return Pressable(
                          onTap: () => setState(() => _picked = o.value),
                          selected: sel,
                          scaleOnPress: false,
                          borderRadius: BorderRadius.zero,
                          pressedColor: c.primarySoft,
                          semanticLabel: [
                            o.title,
                            ?o.subtitle,
                            if (sel) 'selected',
                          ].join(', '),
                          excludeChildSemantics: true,
                          child: Container(
                            constraints: const BoxConstraints(minHeight: 52),
                            padding: const EdgeInsets.symmetric(
                              horizontal: Space.s20,
                              vertical: Space.s8,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        o.title,
                                        style: t.body.copyWith(
                                          fontWeight: sel
                                              ? FontWeight.w800
                                              : FontWeight.w600,
                                          color: sel ? c.primary : c.ink,
                                        ),
                                      ),
                                      if (o.subtitle != null)
                                        Text(o.subtitle!, style: t.tiny),
                                    ],
                                  ),
                                ),
                                if (sel)
                                  Icon(Icons.check, color: c.primary, size: 20),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(
                Space.s16,
                Space.s12,
                Space.s16,
                Space.s16,
              ),
              decoration: BoxDecoration(
                color: c.white,
                border: Border(top: BorderSide(color: c.line)),
              ),
              child: SafeArea(
                top: false,
                child: AppButton.primary(
                  pickedTitle == null ? 'Choose one' : 'Use $pickedTitle',
                  large: true,
                  block: true,
                  onPressed: pickedTitle == null
                      ? null
                      : () => Navigator.of(context).pop(_picked),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
