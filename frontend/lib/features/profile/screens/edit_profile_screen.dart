// KAMOS — Edit profile screen. Display name, bio, avatar. Username is NOT
// editable here — set at registration, held for 30 days after deletion.
// Email and password live in Settings.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/theme.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/async_widget.dart';
import '../../../shared/widgets/kamos_avatar.dart';
import '../providers/profile_providers.dart';
import '../repository/profile_repository.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _name = TextEditingController();
  final _bio = TextEditingController();
  bool _isSaving = false;
  bool _hydrated = false;

  @override
  void dispose() {
    _name.dispose();
    _bio.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final l = AppLocalizations.of(context);
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(l.profileAvatarPickGallery),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(l.profileAvatarPickCamera),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    try {
      // The upload pipeline for avatars is not wired yet (no server endpoint
      // beyond `PATCH /me {avatar_url}`); picking the file is the slice we
      // own. Server-side persistence stays as-is.
      await ImagePicker().pickImage(source: source);
    } catch (_) {
      // Image picker not available (sim/test) — silently no-op.
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = context.tokens;
    final async = ref.watch(meProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
        title: Text(l.profileEdit),
        actions: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: FilledButton(
              onPressed: _isSaving
                  ? null
                  : () async {
                      setState(() => _isSaving = true);
                      try {
                        await ref
                            .read(profileRepositoryProvider)
                            .updateMe(displayName: _name.text, bio: _bio.text);
                        ref.invalidate(meProvider);
                        if (context.mounted) context.pop();
                      } finally {
                        if (mounted) setState(() => _isSaving = false);
                      }
                    },
              style: FilledButton.styleFrom(
                backgroundColor: t.ai,
                shape: const StadiumBorder(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(l.actionSave),
            ),
          ),
        ],
      ),
      body: AsyncWidget(
        value: async,
        center: true,
        data: (me) {
          if (!_hydrated) {
            _name.text = me.user.displayName;
            _bio.text = me.user.bio ?? '';
            _hydrated = true;
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Center(
                  child: InkResponse(
                    onTap: _pickAvatar,
                    radius: 56,
                    child: KamosAvatar(
                      initial: me.user.displayUsername,
                      size: 84,
                      imageUrl: me.user.avatarUrl,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                _Label(l.profileDisplayName),
                TextField(
                  controller: _name,
                  maxLength: 50,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 10),
                _Label(l.authUsernameLabel),
                TextField(
                  controller: TextEditingController(
                    text: me.user.displayUsername,
                  ),
                  enabled: false,
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    l.profileUsernameLocked,
                    style: TextStyle(fontSize: 12, color: t.fg3),
                  ),
                ),
                const SizedBox(height: 10),
                _Label(l.profileBioLabel),
                TextField(
                  controller: _bio,
                  maxLength: 200,
                  maxLines: 3,
                  onChanged: (_) => setState(() {}),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          text.toUpperCase(),
          style: TextStyle(
            fontFamily: 'NotoSansJP',
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.3,
            color: t.fg3,
          ),
        ),
      ),
    );
  }
}
