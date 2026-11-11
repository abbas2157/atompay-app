import 'package:atompay_mobile/core/network/api_exception.dart';
import 'package:atompay_mobile/core/theme/tokens.dart';
import 'package:atompay_mobile/core/widgets/brand.dart';
import 'package:atompay_mobile/core/widgets/buttons.dart';
import 'package:atompay_mobile/core/widgets/dialogs.dart';
import 'package:atompay_mobile/core/widgets/fields.dart';
import 'package:atompay_mobile/core/widgets/form_parts.dart';
import 'package:atompay_mobile/core/widgets/picker.dart';
import 'package:atompay_mobile/core/widgets/states.dart';
import 'package:atompay_mobile/core/widgets/ui.dart';
import 'package:flutter/material.dart';

/// Every shared widget in every state (brief §14, Phase 0). Only routed in
/// dev and staging builds; opened by long-pressing the Welcome logo.
class GalleryScreen extends StatefulWidget {
  const new({super.key});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  static const _cities = [
    PickerOption(1, 'Lahore'),
    PickerOption(2, 'Karachi'),
    PickerOption(3, 'Islamabad'),
    PickerOption(4, 'Rawalpindi'),
    PickerOption(5, 'Faisalabad'),
  ];

  int? _city = 1;
  int? _area;
  bool _consent = false;

  void _noop() {}

  @override
  Widget build(BuildContext context) {
    final t = context.text;
    return Scaffold(
      backgroundColor: context.colors.surface,
      appBar: const AppTopBar(title: 'Widget gallery'),
      body: ListView(
        padding: const EdgeInsets.all(Space.gutter),
        children: [
          const _Section('Brand'),
          const Wrap(
            spacing: Space.s16,
            runSpacing: Space.s16,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              AtomPayMark(),
              AtomAvatar(),
              AtomAvatar(ring: true),
              AtomPayLogo(height: 48),
            ],
          ),

          const _Section('Type scale'),
          Text('Display 38', style: t.display),
          Text('Heading 30', style: t.h1),
          Text('Heading 24', style: t.h1b),
          Text('Heading 22', style: t.h2),
          Text('Heading 20', style: t.h3),
          Text('Heading 17', style: t.h4),
          Text('Body 15', style: t.body),
          Text('Base 14', style: t.base),
          Text('Small 13', style: t.small),
          Text('Tiny 12', style: t.tiny),
          Text('XS 11', style: t.xs),

          const _Section('Buttons'),
          AppButton.primary('Primary', onPressed: _noop, block: true),
          Gap.s8,
          AppButton.dark('Dark', onPressed: _noop, block: true),
          Gap.s8,
          AppButton.ghost('Ghost', onPressed: _noop, block: true),
          Gap.s8,
          AppButton.amber('Amber', onPressed: _noop, block: true),
          Gap.s8,
          AppButton.danger('Danger', onPressed: _noop, block: true),
          Gap.s8,
          const AppButton.primary('Disabled', onPressed: null, block: true),
          Gap.s8,
          AppButton.primary(
            'Busy',
            onPressed: _noop,
            busy: true,
            large: true,
            block: true,
          ),
          Gap.s8,
          Wrap(
            spacing: Space.s8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              AppIconButton(
                icon: Icons.settings_outlined,
                label: 'Settings',
                onPressed: _noop,
              ),
              TextLink('Text link', onPressed: _noop),
              TextLink('External link', onPressed: _noop, external: true),
            ],
          ),

          const _Section('Badges'),
          const Wrap(
            spacing: Space.s8,
            runSpacing: Space.s8,
            children: [
              AppBadge.green('Paid'),
              AppBadge.amber('Due'),
              AppBadge.rose('Late'),
              AppBadge.amber('Under review'),
              AppBadge.blue('Blue'),
              AppBadge.grey('Grey'),
            ],
          ),

          const _Section('Notes'),
          const Note(tone: NoteTone.green, text: 'Green note.'),
          Gap.s8,
          const Note(tone: NoteTone.rose, text: 'Rose note.'),
          Gap.s8,
          const Note(tone: NoteTone.blue, text: 'Blue note.'),
          Gap.s8,
          const Note(tone: NoteTone.wash, text: 'Wash note.'),
          Gap.s8,
          const Note(tone: NoteTone.amber, text: 'Amber note.'),

          const _Section('Card, list rows, key-value'),
          const AppCard(child: Text('A card')),
          Gap.s12,
          ListGroup(
            title: 'List group',
            children: [
              ListRow(
                title: 'Personal details',
                summary: 'Name, CNIC, address',
                icon: Icons.person_outline,
                onTap: _noop,
              ),
              ListRow(
                title: 'With a badge',
                icon: Icons.verified_user_outlined,
                tileTone: TileTone.green,
                badge: const AppBadge.green('Verified'),
                onTap: _noop,
              ),
              ListRow(
                title: 'External link',
                icon: Icons.policy_outlined,
                tileTone: TileTone.grey,
                external: true,
                onTap: _noop,
              ),
            ],
          ),
          Gap.s12,
          const AppCard(
            child: KeyValueList([
              KeyValue('Order', 'AS-01279'),
              KeyValue('Monthly', 'Rs. 15,666', spoken: 'Rupees 15,666'),
              KeyValue('Lender', '[LICENSED ENTITY NAME]', placeholder: true),
            ]),
          ),

          const _Section('Limit card and Mini3'),
          const LimitCard(available: 32000, approved: 60000, used: 28000),
          Gap.s12,
          const LimitCard(
            available: 32000,
            approved: 60000,
            used: 28000,
            compact: true,
          ),
          Gap.s12,
          AppCard(
            child: Mini3(const [
              MonthState.paid,
              MonthState.next,
              MonthState.upcoming,
            ]),
          ),

          const _Section('Track'),
          const AppCard(
            child: Track([
              TrackStep(title: 'Profile', state: TrackState.done),
              TrackStep(
                title: 'Verification',
                state: TrackState.now,
                hint: 'Usually within 1 working day',
              ),
              TrackStep(title: 'Limit', state: TrackState.upcoming),
              TrackStep(title: 'Rejected', state: TrackState.stop),
            ]),
          ),

          const _Section('Fields'),
          const AppTextField(label: 'Full name', hint: 'As on your CNIC'),
          Gap.s12,
          const AppTextField(
            label: 'With an error',
            error: 'Enter your full name.',
          ),
          Gap.s12,
          const AppTextField(label: 'Disabled', enabled: false),
          Gap.s12,
          const PasswordField(label: 'Password'),
          Gap.s12,
          OtpField(onChanged: (_) {}, autofocus: false),

          const _Section('Pickers'),
          PickerField<int>(
            label: 'City',
            sheetTitle: 'Choose your city',
            noun: 'cities',
            options: _cities,
            value: _city,
            onChanged: (v) => setState(() {
              _city = v;
              _area = null;
            }),
          ),
          Gap.s12,
          PickerField<int>(
            label: 'Area',
            sheetTitle: 'Choose your area',
            noun: 'areas',
            options: const [],
            value: _area,
            onChanged: (v) => setState(() => _area = v),
            disabledText: _city == null ? 'Choose a city first' : null,
            loading: _city != null,
          ),
          Gap.s12,
          ConsentRow(
            value: _consent,
            onChanged: (v) => setState(() => _consent = v),
            child: const Text('I have read the privacy policy.'),
          ),

          const _Section('Dialogs and toasts'),
          AppButton.ghost(
            'Discard dialog',
            block: true,
            onPressed: () => confirmDiscard(context),
          ),
          Gap.s8,
          AppButton.ghost(
            'Toast',
            block: true,
            onPressed: () => showToast('Password changed'),
          ),
          Gap.s8,
          AppButton.ghost(
            'Error toast',
            block: true,
            onPressed: () => showToast("Couldn't refresh", error: true),
          ),

          const _Section('Loading'),
          const LoadingShape(
            label: 'Loading the gallery',
            child: Column(children: [SkeletonCard(), Gap.s12, SkeletonRow()]),
          ),

          const _Section('States'),
          const OfflineBanner(what: 'your orders'),
          Gap.s12,
          const _Framed(
            StateView(
              icon: Icons.inbox_outlined,
              title: "You're all caught up",
              body: 'New messages will show here.',
            ),
          ),
          for (final e in const <ApiException>[
            Offline(),
            Server(reference: 'REF-1234'),
            Timeout(),
            NotFound(),
          ])
            _Framed(
              ErrorStateView(
                error: e,
                onRetry: _noop,
                notFound: "We can't find this order",
              ),
            ),
          const _Section('Retry countdown'),
          const RetryCountdown(retryAfter: Duration(seconds: 42)),
          Gap.s24,
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const new(this.title);

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: Space.s32, bottom: Space.s12),
    child: SectionLabel(title),
  );
}

/// Gives a full-height state view a bounded box in the scrolling list.
class _Framed extends StatelessWidget {
  const new(this.child);

  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: Space.s12),
    child: AppCard(
      padding: EdgeInsets.zero,
      child: SizedBox(height: 360, child: child),
    ),
  );
}
