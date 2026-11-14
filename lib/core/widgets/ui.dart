import 'package:atompay_mobile/core/format/money.dart';
import 'package:atompay_mobile/core/theme/tokens.dart';
import 'package:atompay_mobile/core/widgets/buttons.dart';
import 'package:atompay_mobile/core/widgets/pressable.dart';
import 'package:flutter/material.dart';

/// The app bar every pushed screen uses: back (or close), a title and one
/// optional action. Tab roots pass `leading: null`.
class AppTopBar extends StatelessWidget implements PreferredSizeWidget {
  const new({
    this.title,
    this.leading = TopBarLeading.back,
    this.onLeading,
    this.actions = const [],
    this.white,
    this.bottomBorder,
    super.key,
  });

  final String? title;
  final TopBarLeading? leading;

  /// Defaults to `Navigator.maybePop`, so dirty-form and busy guards run.
  final VoidCallback? onLeading;
  final List<Widget> actions;

  /// Null follows canvas `.topw`: a titled bar is white with a hairline
  /// under it; a bare bar (back only) has neither.
  final bool? white;
  final bool? bottomBorder;
  bool get _isWhite => white ?? title != null;
  bool get _hasBorder => bottomBorder ?? title != null;

  @override
  Size get preferredSize => const Size.fromHeight(Sizes.appBar);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final lead = leading;
    // Bar text grows to 150% at most, as platform navigation bars do; the
    // title ellipsizes and screen readers always get it in full.
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.5,
      child: _bar(context, c, lead),
    );
  }

  Widget _bar(BuildContext context, AppColors c, TopBarLeading? lead) {
    return Material(
      color: _isWhite ? c.white : c.surface,
      child: SafeArea(
        bottom: false,
        child: Container(
          height: Sizes.appBar,
          decoration: _hasBorder
              ? BoxDecoration(
                  border: Border(bottom: BorderSide(color: c.line)),
                )
              : null,
          padding: const EdgeInsets.symmetric(horizontal: Space.s8),
          child: Row(
            children: [
              if (lead != null)
                AppIconButton(
                  icon: lead == TopBarLeading.back
                      ? Icons.chevron_left
                      : Icons.close,
                  size: lead == TopBarLeading.back ? 28 : 22,
                  label: lead == TopBarLeading.back ? 'Back' : 'Close',
                  onPressed:
                      onLeading ?? () => Navigator.of(context).maybePop(),
                )
              else
                const SizedBox(width: Space.s8),
              if (lead != null) const SizedBox(width: Space.s6),
              Expanded(
                child: title == null
                    ? const SizedBox()
                    : Semantics(
                        header: true,
                        child: Text(
                          title!,
                          style: context.text.h4,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
              ),
              if (actions.isNotEmpty) const SizedBox(width: Space.s6),
              ...actions,
            ],
          ),
        ),
      ),
    );
  }
}

enum TopBarLeading { back, close }

/// Small upper-case label above a heading. [atomPay] uses rose.
class Eyebrow extends StatelessWidget {
  const new(this.text, {this.atomPay = false, super.key});

  final String text;
  final bool atomPay;

  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: context.text.eyebrow.copyWith(
      color: atomPay ? context.colors.rose : null,
    ),
  );
}

/// Eyebrow, heading and lead paragraph: the top of most form screens.
class PageIntro extends StatelessWidget {
  const new({
    required this.title,
    this.eyebrow,
    this.lead,
    this.leadSpans,
    this.atomPay = true,
    super.key,
  });

  final String? eyebrow;
  final String title;
  final String? lead;

  /// Rich lead text (bold destinations, links).
  final List<InlineSpan>? leadSpans;
  final bool atomPay;

  @override
  Widget build(BuildContext context) {
    final t = context.text;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (eyebrow != null) ...[
          Eyebrow(eyebrow!, atomPay: atomPay),
          const SizedBox(height: Space.s8),
        ],
        Semantics(header: true, child: Text(title, style: t.h1)),
        if (lead != null || leadSpans != null) ...[
          const SizedBox(height: Space.s8),
          if (leadSpans != null)
            Text.rich(TextSpan(style: t.lead, children: leadSpans))
          else
            Text(lead!, style: t.lead),
        ],
      ],
    );
  }
}

/// White, 24 radius, hairline border.
class AppCard extends StatelessWidget {
  const new({
    required this.child,
    this.padding = const EdgeInsets.all(Space.s20),
    this.color,
    this.borderColor,
    this.onTap,
    this.semanticLabel,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Color? borderColor;
  final VoidCallback? onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final box = Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? c.white,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: borderColor ?? c.line),
      ),
      child: child,
    );
    if (onTap == null) return box;
    return Pressable(
      onTap: onTap,
      semanticLabel: semanticLabel,
      borderRadius: BorderRadius.circular(Radii.card),
      pressedColor: c.primarySoft.withValues(alpha: 0.5),
      child: box,
    );
  }
}

enum BadgeTone { green, amber, rose, blue, grey }

/// Status pill. Soft background, strong text, upper case.
class AppBadge extends StatelessWidget {
  const new(this.label, {required this.tone, this.icon, super.key});

  /// Paid · Verified · Approved.
  const new green(this.label, {this.icon, super.key}) : tone = BadgeTone.green;

  /// Due · Under review.
  const new amber(this.label, {this.icon, super.key}) : tone = BadgeTone.amber;

  /// Late · AtomPay eligible.
  const new rose(this.label, {this.icon, super.key}) : tone = BadgeTone.rose;
  const new blue(this.label, {this.icon, super.key}) : tone = BadgeTone.blue;
  const new grey(this.label, {this.icon, super.key}) : tone = BadgeTone.grey;

  final String label;
  final BadgeTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (bg, fg) = switch (tone) {
      BadgeTone.green => (c.greenSoft, c.green),
      BadgeTone.amber => (c.amberSoft, c.amberInk),
      BadgeTone.rose => (c.roseSoft, c.rose),
      BadgeTone.blue => (c.primarySoft, c.primary),
      BadgeTone.grey => (c.greySoft, c.body),
    };
    return Semantics(
      label: label,
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: Space.s10,
          vertical: Space.s4,
        ),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(Radii.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: fg),
              const SizedBox(width: Space.s4),
            ],
            Flexible(
              child: Text(
                label.toUpperCase(),
                style: context.text.xs.copyWith(
                  color: fg,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum NoteTone { green, rose, blue, wash, amber }

/// An inline message with an icon.
class Note extends StatelessWidget {
  const new({
    required this.tone,
    this.text,
    this.spans,
    this.icon,
    this.action,
    super.key,
  }) : assert(text != null || spans != null, 'text or spans');

  final NoteTone tone;
  final String? text;
  final List<InlineSpan>? spans;
  final IconData? icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (bg, fg, border) = switch (tone) {
      NoteTone.green => (c.greenSoft, c.green, null),
      NoteTone.rose => (c.roseSoft, c.rose, null),
      NoteTone.blue => (c.primarySoft, c.primaryDark, null),
      NoteTone.wash => (c.apayWash, c.body, c.apayLine),
      NoteTone.amber => (c.amberSoft, c.amberInk, null),
    };
    final defaultIcon = switch (tone) {
      NoteTone.green => Icons.check,
      NoteTone.rose => Icons.error_outline,
      NoteTone.amber => Icons.schedule,
      NoteTone.blue || NoteTone.wash => Icons.info_outline,
    };
    final style = context.text.base.copyWith(color: fg);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: Space.s16,
        vertical: Space.s14,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(Radii.note),
        border: border == null ? null : Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: Space.s2),
            child: Icon(
              icon ?? defaultIcon,
              size: 18,
              color: tone == NoteTone.wash ? c.rose : fg,
            ),
          ),
          const SizedBox(width: Space.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (spans != null)
                  Text.rich(TextSpan(style: style, children: spans))
                else
                  Text(text!, style: style),
                if (action != null) ...[
                  const SizedBox(height: Space.s8),
                  action!,
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum TileTone { blue, green, amber, rose, grey, wash }

/// The 40 dp rounded icon square at the start of a row.
class IconTile extends StatelessWidget {
  const new(
    this.icon, {
    this.tone = TileTone.blue,
    this.size = Sizes.iconTile,
    super.key,
  });

  final IconData icon;
  final TileTone tone;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (bg, fg) = switch (tone) {
      TileTone.blue => (c.primarySoft, c.primary),
      TileTone.green => (c.greenSoft, c.green),
      TileTone.amber => (c.amberSoft, c.amberInk),
      TileTone.rose => (c.roseSoft, c.rose),
      TileTone.grey => (c.greySoft, c.body),
      TileTone.wash => (c.apayWash, c.rose),
    };
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: Icon(icon, size: size * 0.45, color: fg),
    );
  }
}

/// Every settings-style row: icon tile, title, a one-line summary, an
/// optional badge or value, then a chevron, or ↗ when it leaves the app.
class ListRow extends StatelessWidget {
  const new({
    required this.title,
    this.icon,
    this.tileTone = TileTone.blue,
    this.leading,
    this.summary,
    this.badge,
    this.trailing,
    this.onTap,
    this.external = false,
    this.showChevron = true,
    this.titleColor,
    this.semanticLabel,
    this.alignTop = false,
    super.key,
  });

  final String title;

  /// Canvas `.li.u-top`: tile and badge pinned to the top of a long row.
  final bool alignTop;
  final IconData? icon;
  final TileTone tileTone;

  /// Replaces the icon tile (an avatar, a logo).
  final Widget? leading;
  final String? summary;
  final Widget? badge;

  /// Replaces the chevron (a switch, an amount).
  final Widget? trailing;
  final VoidCallback? onTap;

  /// Opens outside the app: ↗ instead of the chevron.
  final bool external;
  final bool showChevron;
  final Color? titleColor;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    // At very large text a badge or a control beside the title has no room:
    // it moves under the title instead (brief §13, 200% without clipping).
    final stacked = MediaQuery.textScalerOf(context).scale(10) >= 16;
    final side = <Widget>[
      ?badge,
      if (trailing != null)
        // Its own node: a button or switch here is a separate control, not
        // part of the row's label.
        Semantics(container: true, child: trailing),
    ];
    final row = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Space.s16,
        vertical: Space.s12,
      ),
      child: Row(
        crossAxisAlignment: alignTop
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: [
          if (leading != null)
            leading!
          else if (icon != null)
            IconTile(icon!, tone: tileTone),
          if (leading != null || icon != null) const SizedBox(width: Space.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: t.body.copyWith(
                    fontWeight: FontWeight.w700,
                    color: titleColor,
                    height: 1.25,
                  ),
                ),
                if (summary != null) ...[
                  const SizedBox(height: 1),
                  Text(
                    summary!,
                    style: t.small.copyWith(
                      fontWeight: FontWeight.w500,
                      height: 1.3,
                    ),
                  ),
                ],
                if (stacked && side.isNotEmpty) ...[
                  const SizedBox(height: Space.s8),
                  Wrap(
                    spacing: Space.s8,
                    runSpacing: Space.s8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: side,
                  ),
                ],
              ],
            ),
          ),
          if (!stacked)
            for (final w in side) ...[const SizedBox(width: Space.s8), w],
          if (trailing != null)
            const SizedBox.shrink()
          else if (onTap != null && showChevron) ...[
            const SizedBox(width: Space.s8),
            Icon(
              external ? Icons.north_east : Icons.chevron_right,
              size: external ? 16 : 20,
              color: c.glyph,
            ),
          ],
        ],
      ),
    );
    final body = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 60),
      child: row,
    );
    if (onTap == null) {
      return Semantics(container: true, label: semanticLabel, child: body);
    }
    return Pressable(
      onTap: onTap,
      scaleOnPress: false,
      borderRadius: BorderRadius.zero,
      pressedColor: c.primarySoft,
      semanticLabel:
          semanticLabel ??
          [title, ?summary, if (external) 'opens outside the app'].join(', '),
      excludeChildSemantics: semanticLabel != null || trailing == null,
      child: body,
    );
  }
}

/// A white rounded group of rows with hairlines between them.
class ListGroup extends StatelessWidget {
  const new({required this.children, this.title, super.key});

  final List<Widget> children;

  /// An upper-case label above the group ("SECURITY").
  final String? title;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final group = ClipRRect(
      borderRadius: BorderRadius.circular(Radii.list),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: c.white,
          border: Border.all(color: c.line),
          borderRadius: BorderRadius.circular(Radii.list),
        ),
        child: Column(
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) Divider(height: 1, color: c.line),
              children[i],
            ],
          ],
        ),
      ),
    );
    if (title == null) return group;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [SectionLabel(title!), group],
    );
  }
}

/// `SECURITY`: the muted upper-case label over a group.
class SectionLabel extends StatelessWidget {
  const new(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: Space.s8),
    child: Semantics(
      header: true,
      child: Text(
        text.toUpperCase(),
        style: context.text.tiny.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
        ),
      ),
    ),
  );
}

/// "Your plans  ·  See all": a section heading with an optional link.
class SectionHeader extends StatelessWidget {
  const new(this.title, {this.action, this.onAction, super.key});

  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Semantics(
          header: true,
          child: Text(title, style: context.text.h4),
        ),
      ),
      if (action != null)
        TextLink(
          action!,
          onPressed: onAction,
          style: context.text.base.copyWith(
            color: context.colors.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
    ],
  );
}

/// One row of a key/value list.
class KeyValue {
  const new(
    this.label,
    this.value, {
    this.spoken,
    this.valueColor,
    this.placeholder = false,
    this.pending,
  });

  final String label;
  final String value;

  /// A placeholder the business still has to supply, under the value
  /// ("[confirm it is charged]"). Shown in rose.
  final String? pending;

  /// What a screen reader says for [value] ("Rupees 15,666").
  final String? spoken;
  final Color? valueColor;

  /// A fact the business hasn't supplied: shown in rose.
  final bool placeholder;
}

/// Label left (muted, upper case), value right.
class KeyValueList extends StatelessWidget {
  const new(this.rows, {super.key});

  final List<KeyValue> rows;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    return Column(
      children: [
        for (var i = 0; i < rows.length; i++)
          MergeSemantics(
            child: Container(
              padding: EdgeInsets.only(top: i == 0 ? 0 : 11, bottom: 11),
              decoration: BoxDecoration(
                border: i == 0 ? null : Border(top: BorderSide(color: c.line)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  // Canvas `.kv`: the label keeps its width and the value
                  // takes the rest, right-aligned. A label never takes
                  // more than 60% (long ones wrap, also at 200% text).
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.sizeOf(context).width * 0.6,
                    ),
                    child: Text(
                      rows[i].label.toUpperCase(),
                      style: t.tiny.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                  const SizedBox(width: Space.s16),
                  Expanded(
                    child: Semantics(
                      label: rows[i].spoken,
                      excludeSemantics: rows[i].spoken != null,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            rows[i].value,
                            textAlign: TextAlign.right,
                            style: t.base.copyWith(
                              fontWeight: FontWeight.w700,
                              color: rows[i].placeholder
                                  ? c.rose
                                  : (rows[i].valueColor ?? c.ink),
                            ),
                          ),
                          if (rows[i].pending != null)
                            Text(
                              rows[i].pending!,
                              textAlign: TextAlign.right,
                              style: t.small.copyWith(
                                color: c.rose,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

enum TrackState { done, now, upcoming, stop }

class TrackStep {
  const new({required this.title, required this.state, this.hint});

  final String title;
  final String? hint;
  final TrackState state;
}

/// The vertical process stepper.
class Track extends StatelessWidget {
  const new(this.steps, {super.key});

  final List<TrackStep> steps;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    return Column(
      children: [
        for (var i = 0; i < steps.length; i++)
          MergeSemantics(
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: 24,
                    child: Column(
                      children: [
                        _dot(c, steps[i].state),
                        if (i < steps.length - 1)
                          Expanded(
                            child: Container(
                              width: 2,
                              margin: const EdgeInsets.symmetric(
                                vertical: Space.s2,
                              ),
                              color: steps[i].state == TrackState.done
                                  ? c.green
                                  : c.line,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: Space.s14),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        bottom: i < steps.length - 1 ? Space.s18 : 0,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            steps[i].title,
                            semanticsLabel:
                                '${steps[i].title}, ${_spoken(steps[i].state)}',
                            style: t.base.copyWith(
                              fontWeight: FontWeight.w700,
                              height: 1.25,
                              color: switch (steps[i].state) {
                                TrackState.done => c.ink,
                                TrackState.now => c.primary,
                                TrackState.stop => c.rose,
                                TrackState.upcoming => c.muted,
                              },
                            ),
                          ),
                          if (steps[i].hint != null)
                            Padding(
                              padding: const EdgeInsets.only(top: Space.s2),
                              child: Text(
                                steps[i].state == TrackState.done
                                    ? '✓ ${steps[i].hint!}'
                                    : steps[i].hint!,
                                style: t.tiny.copyWith(
                                  height: 1.3,
                                  color: steps[i].state == TrackState.done
                                      ? c.green
                                      : c.muted,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  static String _spoken(TrackState s) => switch (s) {
    TrackState.done => 'done',
    TrackState.now => 'in progress',
    TrackState.upcoming => 'not started',
    TrackState.stop => 'needs attention',
  };

  Widget _dot(AppColors c, TrackState s) => Container(
    width: 24,
    height: 24,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: switch (s) {
        TrackState.done => c.green,
        TrackState.stop => c.roseSoft,
        _ => c.white,
      },
      border: Border.all(
        width: s == TrackState.now ? 7 : 2,
        color: switch (s) {
          TrackState.done => c.green,
          TrackState.now => c.primary,
          TrackState.stop => c.rose,
          TrackState.upcoming => c.line3,
        },
      ),
    ),
    child: s == TrackState.done
        ? Icon(Icons.check, size: 14, color: c.white)
        : null,
  );
}

/// The amber-to-coral limit card. Solid ink text only.
class LimitCard extends StatelessWidget {
  const new({
    required this.available,
    required this.approved,
    required this.used,
    this.usedPercent,
    this.monthlyCap,
    this.label = 'Available to spend',
    this.compact = false,
    super.key,
  });

  final int available;
  final int approved;
  final int used;

  /// "Up to Rs. 20,000 a month", shown in place of "In use" while nothing
  /// is in use.
  final int? monthlyCap;

  /// From the server. Never derived here.
  final int? usedPercent;
  final String label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final ink = TextStyle(color: c.ink);
    final showCap = used == 0 && monthlyCap != null;
    final spokenSecond = showCap
        ? 'up to ${rsSpoken(monthlyCap!)} a month'
        : 'in use ${rsSpoken(used)}';
    return Semantics(
      container: true,
      label:
          '$label ${rsSpoken(available)}. Limit ${rsSpoken(approved)}, '
          '$spokenSecond.',
      excludeSemantics: true,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(compact ? Space.s14 : Space.s20),
        decoration: BoxDecoration(
          gradient: c.apayGradient,
          borderRadius: BorderRadius.circular(Radii.list),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label.toUpperCase(),
              style: t.tiny
                  .merge(ink)
                  .copyWith(fontWeight: FontWeight.w800, letterSpacing: 1.2),
            ),
            SizedBox(height: compact ? Space.s6 : Space.s14),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                rs(available),
                style: (compact ? t.h1b : t.display).merge(ink),
              ),
            ),
            if (!compact) ...[
              if (usedPercent != null) ...[
                const SizedBox(height: Space.s14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(Radii.pill),
                  child: LinearProgressIndicator(
                    value: (usedPercent!.clamp(0, 100)) / 100,
                    minHeight: 8,
                    color: c.ink,
                    backgroundColor: c.ink.withValues(alpha: 0.18),
                  ),
                ),
              ],
              const SizedBox(height: Space.s12),
              // Full width, so the second item sits at the right edge.
              SizedBox(
                width: double.infinity,
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  spacing: Space.s14,
                  runSpacing: Space.s6,
                  children: [
                    Text(
                      'Limit ${rs(approved)}',
                      style: t.small
                          .merge(ink)
                          .copyWith(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      showCap
                          ? 'Up to ${rs(monthlyCap!)} a month'
                          : 'In use ${rs(used)}',
                      style: t.small
                          .merge(ink)
                          .copyWith(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

enum MonthState { paid, next, upcoming }

/// The three-month bar: paid, next, upcoming.
class Mini3 extends StatelessWidget {
  const new(this.months, {super.key})
    : assert(months.length == 3, 'always three months');

  final List<MonthState> months;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final paid = months.where((m) => m == MonthState.paid).length;
    return Semantics(
      label: '$paid of 3 months paid',
      excludeSemantics: true,
      child: Row(
        children: [
          for (var i = 0; i < 3; i++) ...[
            if (i > 0) const SizedBox(width: Space.s6),
            Expanded(
              child: Container(
                height: 8,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(Radii.pill),
                  color: switch (months[i]) {
                    MonthState.paid => c.green,
                    MonthState.next => c.amber,
                    MonthState.upcoming => c.line,
                  },
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The checkbox row where the whole row is the target.
class ConsentRow extends StatelessWidget {
  const new({
    required this.value,
    required this.onChanged,
    required this.child,
    super.key,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return MergeSemantics(
      child: Pressable(
        onTap: onChanged == null ? null : () => onChanged!(!value),
        isButton: false,
        scaleOnPress: false,
        borderRadius: BorderRadius.circular(Radii.note),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: Space.s16,
            vertical: Space.s14,
          ),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(Radii.note),
            border: Border.all(color: c.line),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox.square(
                dimension: 22,
                child: Checkbox(
                  value: value,
                  onChanged: onChanged == null
                      ? null
                      : (v) => onChanged!(v ?? false),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              const SizedBox(width: Space.s12),
              Expanded(
                child: DefaultTextStyle.merge(
                  style: context.text.base,
                  child: child,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A fact the business hasn't supplied yet. Never filled with a guess.
class TbdText extends StatelessWidget {
  const new(this.text, {this.style, super.key});

  /// e.g. `[LICENSED ENTITY NAME]`.
  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: (style ?? context.text.base).copyWith(
      color: context.colors.rose,
      fontWeight: FontWeight.w700,
    ),
  );
}

/// The span form of [TbdText] for use inside rich text.
TextSpan placeholderSpan(BuildContext context, String text) => TextSpan(
  text: text,
  style: TextStyle(color: context.colors.rose, fontWeight: FontWeight.w700),
);

/// A business fact from the server ([known]) as plain text, or its rose
/// placeholder ([tbd]) while the server doesn't send it.
TextSpan factSpan(BuildContext context, String? known, String tbd) =>
    known == null ? placeholderSpan(context, tbd) : TextSpan(text: known);

/// A bulleted list with an icon per item.
class TickList extends StatelessWidget {
  const new(
    this.items, {
    this.icon = Icons.check,
    this.icons,
    this.color,
    super.key,
  });

  final List<InlineSpan> items;
  final IconData icon;

  /// One icon per item (canvas lists with a camera, a bell, …), in place
  /// of [icon].
  final List<IconData>? icons;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    // Canvas `.ticks`: 12 between items, nothing after the last.
    return Column(
      children: [
        for (var i = 0; i < items.length; i++)
          Padding(
            padding: EdgeInsets.only(
              bottom: i < items.length - 1 ? Space.s12 : 0,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: Space.s2),
                  child: Icon(
                    icons?[i] ?? icon,
                    size: 20,
                    color: color ?? c.green,
                  ),
                ),
                const SizedBox(width: Space.s12),
                Expanded(
                  child: Text.rich(
                    TextSpan(style: context.text.base, children: [items[i]]),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// A money figure in a narrow tile ("Rs. 47,000"): kept on one line by
/// shrinking a little on 360 dp phones. At large text sizes it wraps
/// instead, so it never gets smaller than the user asked for.
class FigureText extends StatelessWidget {
  const new(
    this.text, {
    required this.style,
    this.alignment = Alignment.centerLeft,
    this.textAlign = TextAlign.start,
    super.key,
  });

  final String text;
  final TextStyle style;
  final AlignmentGeometry alignment;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    final label = Text(text, style: style, textAlign: textAlign);
    if (MediaQuery.textScalerOf(context).scale(10) > 13) return label;
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: alignment,
      child: Text(text, style: style, maxLines: 1, softWrap: false),
    );
  }
}
