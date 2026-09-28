import 'package:atompay_mobile/core/models/kyc_status.dart';
import 'package:atompay_mobile/core/network/api_exception.dart';
import 'package:atompay_mobile/core/router/routes.dart';
import 'package:atompay_mobile/core/theme/tokens.dart';
import 'package:atompay_mobile/core/utils/dates.dart';
import 'package:atompay_mobile/core/widgets/buttons.dart';
import 'package:atompay_mobile/core/widgets/secure_screen.dart';
import 'package:atompay_mobile/core/widgets/states.dart';
import 'package:atompay_mobile/core/widgets/status.dart';
import 'package:atompay_mobile/core/widgets/ui.dart';
import 'package:atompay_mobile/features/profile/data/profile_models.dart';
import 'package:atompay_mobile/features/profile/data/profile_repository.dart';
import 'package:atompay_mobile/features/profile/domain/profile_controllers.dart';
import 'package:atompay_mobile/features/profile/presentation/profile_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Profile read view (handbook §5.7).
class ProfileScreen extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final profile = ref.watch(profileProvider);

    return SecureScreen(
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.profileTitle),
          actions: [
            IconButton(
              tooltip: l10n.accountTitle,
              icon: const Icon(Icons.settings_outlined),
              onPressed: () => context.push(Routes.account),
            ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: () => ref.refresh(profileProvider.future),
          child: switch (profile) {
            AsyncData(:final value) => _Body(value),
            AsyncError(:final error) => _Scrollable(
              child: MessageView(
                message: error is ApiException
                    ? apiErrorText(l10n, error)
                    : l10n.genericError,
                actionLabel: l10n.tryAgain,
                onAction: () => ref.invalidate(profileProvider),
              ),
            ),
            _ => const _Loading(),
          },
        ),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const new(this.profile);

  final Profile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final p = profile;
    final notStarted = p.status == KycStatus.notStarted;
    final repo = ref.watch(profileRepositoryProvider);
    String orDash(String? v) => v == null || v.isEmpty ? l10n.notProvided : v;

    return ListView(
      padding: const EdgeInsets.all(Space.gutter),
      children: [
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: StatusPill(label: p.status.label(l10n), tone: p.status.tone),
        ),
        if (p.status == KycStatus.rejected) ...[
          const SizedBox(height: Space.x16),
          AppBanner(
            tone: StatusTone.blocked,
            title: l10n.profileRejectedTitle,
            text: l10n.profileRejectedText,
          ),
        ],
        const SizedBox(height: Space.x8),
        InfoRow(label: l10n.fullNameLabel, value: orDash(p.fullName)),
        InfoRow(label: l10n.cnicLabel, value: orDash(p.cnicFormatted)),
        InfoRow(label: l10n.mobileLabel, value: orDash(p.mobileFormatted)),
        InfoRow(
          label: l10n.dobLabel,
          value: switch (Dates.parseDate(p.dateOfBirth)) {
            final d? => Dates.short(d),
            null => l10n.notProvided,
          },
        ),
        InfoRow(label: l10n.addressLabel, value: orDash(p.residentialAddress)),
        InfoRow(label: l10n.cityLabel, value: orDash(p.city?.name)),
        const SizedBox(height: Space.x16),
        Text(l10n.sectionDocuments.toUpperCase(), style: context.text.eyebrow),
        const SizedBox(height: Space.x12),
        _DocumentGrid(
          children: [
            for (final doc in ProfileDocument.values)
              _ReadTile(doc: doc, ref: p.documents.of(doc), repo: repo),
          ],
        ),
        const SizedBox(height: Space.x32),
        PrimaryButton(
          label: notStarted ? l10n.completeProfileCta : l10n.editButton,
          onPressed: () => context.push(Routes.profileEdit),
        ),
      ],
    );
  }
}

class _ReadTile extends StatelessWidget {
  const new({required this.doc, required this.ref, required this.repo});

  final ProfileDocument doc;
  final DocumentRef ref;
  final ProfileRepository repo;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return DocumentTile(
      label: documentLabel(l10n, doc),
      uploaded: ref.uploaded,
      statusLabel: ref.uploaded ? l10n.uploaded : l10n.notUploaded,
      image: ref.uploaded
          ? AuthImage(uri: repo.documentUri(doc), headers: repo.authHeaders)
          : null,
      onTap: ref.uploaded
          ? () => context.push(Routes.profileDocument(doc.apiName))
          : null,
    );
  }
}

/// Two columns on phones, three when there's room.
class _DocumentGrid extends StatelessWidget {
  const new({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final columns = c.maxWidth > 520 ? 3 : 2;
        final width = (c.maxWidth - Space.x16 * (columns - 1)) / columns;
        return Wrap(
          spacing: Space.x16,
          runSpacing: Space.x16,
          children: [
            for (final child in children) SizedBox(width: width, child: child),
          ],
        );
      },
    );
  }
}

/// A private image loaded with the bearer header. `Image.network` keeps it
/// in memory only; nothing is written to disk (handbook rule 12).
class AuthImage extends StatelessWidget {
  const new({
    required this.uri,
    required this.headers,
    super.key,
    this.fit = BoxFit.cover,
  });

  final Uri uri;
  final Map<String, String> headers;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    return Image.network(
      uri.toString(),
      headers: headers,
      fit: fit,
      gaplessPlayback: true,
      loadingBuilder: (context, child, progress) =>
          progress == null ? child : const Skeleton(height: double.infinity),
      errorBuilder: (context, _, _) => Center(
        child: Icon(Icons.broken_image_outlined, color: context.tokens.muted),
      ),
    );
  }
}

class _Scrollable extends StatelessWidget {
  const new({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: SizedBox(height: c.maxHeight, child: child),
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(Space.gutter),
      children: [
        const Skeleton(width: 120, height: 28, radius: Radii.pill),
        const SizedBox(height: Space.x24),
        for (var i = 0; i < 5; i++) ...[
          const Skeleton(width: 80, height: 10),
          const SizedBox(height: Space.x8),
          const Skeleton(height: 18),
          const SizedBox(height: Space.x20),
        ],
      ],
    );
  }
}

/// Full screen, pinch to zoom, auth header, no disk cache, `FLAG_SECURE`.
class DocumentViewerScreen extends ConsumerWidget {
  const new({required this.document, super.key});

  final ProfileDocument document;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(profileRepositoryProvider);
    return SecureScreen(
      child: Scaffold(
        backgroundColor: AppColors.nucleus,
        appBar: AppBar(
          backgroundColor: AppColors.nucleus,
          foregroundColor: AppColors.white,
          title: Text(
            documentLabel(context.l10n, document),
            style: context.text.title.copyWith(color: AppColors.white),
          ),
        ),
        body: InteractiveViewer(
          maxScale: 5,
          child: Center(
            child: Image.network(
              repo.documentUri(document).toString(),
              headers: repo.authHeaders,
              fit: BoxFit.contain,
              loadingBuilder: (context, child, progress) => progress == null
                  ? child
                  : const CircularProgressIndicator(color: AppColors.white),
              errorBuilder: (context, _, _) => Padding(
                padding: const EdgeInsets.all(Space.x32),
                child: Text(
                  context.l10n.documentLoadFailed,
                  textAlign: TextAlign.center,
                  style: context.text.body.copyWith(color: AppColors.white),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
