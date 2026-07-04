import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:scanmate/core/constants/app_constants.dart';
import 'package:scanmate/core/theme/app_colors.dart';
import 'package:scanmate/features/settings/presentation/screens/privacy_policy_screen.dart';
import 'package:scanmate/core/models/local_document_model.dart';
import 'package:scanmate/core/models/document_model.dart';
import 'package:scanmate/core/services/local_document_service.dart';
import 'package:scanmate/core/services/settings_service.dart';
import 'package:scanmate/core/services/auth_service.dart';
import 'package:scanmate/core/services/document_service.dart';
import 'package:scanmate/core/services/drive_service.dart';
import 'package:scanmate/core/services/pdf_service.dart';
import 'package:scanmate/features/scanner/presentation/providers/scan_provider.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  int _currentTab = 0;
  bool _autoCapture = true;
  bool _cloudBackup = true;

  // Library view filters
  bool _foldersView = false; // showing the folders section
  String? _openFolder; // when set, showing docs inside this folder
  bool _starredOnly = false; // showing only starred documents

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      if (mounted) {
        ref.read(scanProvider.notifier).clearScanSession();
      }
      // Load persisted settings into the toggle states.
      final settings = await ref.read(settingsProvider.future);
      if (mounted) {
        setState(() {
          _cloudBackup = settings.cloudBackup;
          _autoCapture = settings.autoCapture;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mediaQuery = MediaQuery.of(context);
    final isWideScreen = mediaQuery.size.width >= 600;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(theme),
      body: _buildTabContent(isWideScreen),
      floatingActionButton: _currentTab == 0
          ? FloatingActionButton(
              onPressed: () => context.push('/scanner'),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: const CircleBorder(),
              child: const Icon(Icons.camera_alt_outlined, size: 28),
            )
          : null,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.border, width: 1.5)),
        ),
        child: BottomAppBar(
          color: AppColors.background,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          height: 72,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildBottomNavItem(index: 0, icon: Icons.description_outlined, activeIcon: Icons.description_rounded, label: 'Documents'),
              _buildBottomNavItem(index: 1, icon: Icons.center_focus_weak_rounded, activeIcon: Icons.center_focus_strong_rounded, label: 'Scan'),
              _buildBottomNavItem(index: 2, icon: Icons.cloud_outlined, activeIcon: Icons.cloud_rounded, label: 'Cloud'),
              _buildBottomNavItem(index: 3, icon: Icons.settings_outlined, activeIcon: Icons.settings_rounded, label: 'Settings'),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(ThemeData theme) {
    if (_currentTab == 3) {
      return AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.text),
          onPressed: () => setState(() => _currentTab = 0),
        ),
        title: const Center(
          child: Text('Settings',
            style: TextStyle(color: AppColors.text, fontWeight: FontWeight.bold, fontSize: 18)),
        ),
      );
    }

    return AppBar(
      automaticallyImplyLeading: false,
      title: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.secondary,
            child: const Text('AY', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
          ),
          const SizedBox(width: 12),
          Text('ScanMate', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700, color: AppColors.text)),
        ],
      ),
      actions: [
        IconButton(icon: const Icon(Icons.search_rounded, color: AppColors.text), onPressed: () {}),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildTabContent(bool isWideScreen) {
    switch (_currentTab) {
      case 0:
        return _buildLibraryTab(isWideScreen);
      case 1:
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.center_focus_weak_rounded, size: 64, color: AppColors.hint),
              const SizedBox(height: 16),
              const Text('Scan Page stub'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.push('/scanner'),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                child: const Text('Launch Scanner'),
              ),
            ],
          ),
        );
      case 2:
        return _buildCloudTab();
      case 3:
        return _buildSettingsTab();
      default:
        return _buildLibraryTab(isWideScreen);
    }
  }

  // ── Cloud tab: documents synced to Firestore + Google Drive ────────────────
  Widget _buildCloudTab() {
    final user = ref.watch(authStateProvider);

    if (user == null) {
      return _emptyState(
        'Sign in to see your cloud documents.',
        icon: Icons.cloud_off_outlined,
      );
    }

    final cloudAsync = ref.watch(documentListProvider);

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(documentListProvider),
      child: cloudAsync.when(
        data: (docs) {
          if (docs.isEmpty) {
            return ListView(
              children: [
                const SizedBox(height: 80),
                _emptyState(
                  'No cloud documents yet.\nScan with Cloud backup ON to sync.',
                  icon: Icons.cloud_queue_outlined,
                ),
              ],
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: docs.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) => _buildCloudDocTile(docs[index]),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _emptyState('Could not load cloud documents:\n$e',
            icon: Icons.error_outline_rounded),
      ),
    );
  }

  Widget _buildCloudDocTile(DocumentModel doc) {
    final hasFile = doc.fileUrl != null && doc.fileUrl!.isNotEmpty;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 1.5),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.picture_as_pdf_rounded,
              color: AppColors.primary),
        ),
        title: Text(doc.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontWeight: FontWeight.bold, color: AppColors.text)),
        subtitle: Text(
          '${doc.date} · ${doc.pageCount} ${doc.pageCount == 1 ? 'page' : 'pages'}'
          '${hasFile ? '' : ' · metadata only'}',
          style: const TextStyle(color: AppColors.hint, fontSize: 12),
        ),
        trailing: Icon(
          hasFile ? Icons.cloud_download_outlined : Icons.cloud_done_outlined,
          color: hasFile ? AppColors.primary : AppColors.hint,
        ),
        onTap: hasFile ? () => _openCloudDoc(doc) : null,
      ),
    );
  }

  Future<void> _openCloudDoc(DocumentModel doc) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(const SnackBar(
      content: Text('Downloading from Google Drive…'),
      duration: Duration(seconds: 30),
    ));
    try {
      final dir = await getTemporaryDirectory();
      final target = File('${dir.path}/${doc.id}.pdf');
      final ok =
          await ref.read(driveServiceProvider).downloadFile(doc.fileUrl!, target);
      messenger.hideCurrentSnackBar();
      if (ok) {
        await OpenFilex.open(target.path);
      } else {
        messenger.showSnackBar(const SnackBar(
          content: Text('Could not download. Check Google Drive access.'),
          backgroundColor: AppColors.error,
        ));
      }
    } catch (e) {
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(SnackBar(
        content: Text('Open failed: $e'),
        backgroundColor: AppColors.error,
      ));
    }
  }

  Widget _buildLibraryTab(bool isWideScreen) {
    final docsAsync = ref.watch(localDocumentProvider);
    final user = ref.watch(authStateProvider);
    final userName = user?.displayName ?? 'User';

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Good morning, $userName',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.text, letterSpacing: -0.5)),
          const SizedBox(height: 4),
          docsAsync.when(
            data: (docs) => Text(
              docs.isEmpty ? 'No documents yet' : '${docs.length} document${docs.length == 1 ? '' : 's'}',
              style: const TextStyle(color: AppColors.hint, fontSize: 14),
            ),
            loading: () => const Text('Loading...', style: TextStyle(color: AppColors.hint, fontSize: 14)),
            error: (_, _) => const Text('0 documents', style: TextStyle(color: AppColors.hint, fontSize: 14)),
          ),
          const SizedBox(height: 24),
          _buildQuickActionsBar(),
          const SizedBox(height: 32),
          if (_foldersView && _openFolder == null)
            _buildFoldersSection(isWideScreen)
          else
            _buildDocumentsSection(isWideScreen, docsAsync),
        ],
      ),
    );
  }

  // ── Documents section (Recent / Starred / inside-a-folder) ─────────────────
  Widget _buildDocumentsSection(
      bool isWideScreen, AsyncValue<List<LocalDocumentModel>> docsAsync) {
    final String sectionTitle = _openFolder != null
        ? _openFolder!
        : (_starredOnly ? 'Starred' : 'Recent');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (_openFolder != null)
              GestureDetector(
                onTap: () => setState(() => _openFolder = null),
                child: const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: Icon(Icons.arrow_back_rounded,
                      size: 20, color: AppColors.text),
                ),
              ),
            Expanded(
              child: Text(sectionTitle,
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.text)),
            ),
            if (_starredOnly || _openFolder != null)
              TextButton(
                onPressed: () => setState(() {
                  _starredOnly = false;
                  _openFolder = null;
                  _foldersView = false;
                }),
                style: TextButton.styleFrom(
                    foregroundColor: AppColors.secondary,
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                child: const Text('Show all'),
              ),
          ],
        ),
        const SizedBox(height: 16),
        docsAsync.when(
          data: (allDocs) {
            var docs = allDocs;
            if (_openFolder != null) {
              docs = docs.where((d) => d.folder == _openFolder).toList();
            }
            if (_starredOnly) {
              docs = docs.where((d) => d.isStarred).toList();
            }

            if (docs.isEmpty) {
              return _emptyState(
                _openFolder != null
                    ? 'This folder is empty.\nMove documents here to organize them.'
                    : _starredOnly
                        ? 'No starred documents yet.\nTap the star on a document.'
                        : 'No documents yet.\nScan your first document!',
              );
            }
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: docs.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: isWideScreen ? 3 : 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.75,
              ),
              itemBuilder: (context, index) => _buildDocumentCard(docs[index]),
            );
          },
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: CircularProgressIndicator(),
            ),
          ),
          error: (e, _) => Center(
              child: Text('Error: $e',
                  style: const TextStyle(color: AppColors.error))),
        ),
      ],
    );
  }

  // ── Folders section ────────────────────────────────────────────────────────
  Widget _buildFoldersSection(bool isWideScreen) {
    final foldersAsync = ref.watch(folderProvider);
    final docs = ref.watch(localDocumentProvider).value ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Folders',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.text)),
            TextButton.icon(
              onPressed: _promptNewFolder,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('New'),
              style: TextButton.styleFrom(foregroundColor: AppColors.primary),
            ),
          ],
        ),
        const SizedBox(height: 16),
        foldersAsync.when(
          data: (folders) {
            if (folders.isEmpty) {
              return _emptyState(
                'No folders yet.\nTap "New" to create one.',
                icon: Icons.folder_outlined,
              );
            }
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: folders.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: isWideScreen ? 3 : 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.4,
              ),
              itemBuilder: (context, index) {
                final name = folders[index];
                final count = docs.where((d) => d.folder == name).length;
                return _buildFolderTile(name, count);
              },
            );
          },
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: CircularProgressIndicator(),
            ),
          ),
          error: (e, _) => Center(
              child: Text('Error: $e',
                  style: const TextStyle(color: AppColors.error))),
        ),
      ],
    );
  }

  Widget _buildFolderTile(String name, int count) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => setState(() {
        _openFolder = name;
        _foldersView = false;
      }),
      onLongPress: () => _confirmDeleteFolder(name),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: AppColors.border.withValues(alpha: 0.8), width: 1.2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Icon(Icons.folder_rounded, color: AppColors.primary, size: 36),
            const Spacer(),
            Text(name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.text)),
            const SizedBox(height: 2),
            Text('$count ${count == 1 ? 'item' : 'items'}',
                style: const TextStyle(fontSize: 11, color: AppColors.hint)),
          ],
        ),
      ),
    );
  }

  Widget _emptyState(String message, {IconData icon = Icons.description_outlined}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Column(
          children: [
            Icon(icon, size: 64, color: AppColors.hint),
            const SizedBox(height: 16),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.hint, fontSize: 14)),
          ],
        ),
      ),
    );
  }

  Future<void> _promptNewFolder() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Folder'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Folder name'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) {
      await ref.read(folderProvider.notifier).addFolder(name);
    }
  }

  void _confirmDeleteFolder(String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Folder'),
        content: Text(
            'Delete folder "$name"? Documents inside will be moved out, not deleted.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(folderProvider.notifier).removeFolder(name);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  /// Bottom sheet with actions for a document (star / move / delete).
  void _showDocActions(LocalDocumentModel doc) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2))),
            ListTile(
              leading: Icon(
                  doc.isStarred ? Icons.star_rounded : Icons.star_border_rounded,
                  color: AppColors.primary),
              title: Text(doc.isStarred ? 'Unstar' : 'Star'),
              onTap: () {
                Navigator.pop(ctx);
                ref.read(localDocumentProvider.notifier).toggleStar(doc.id);
              },
            ),
            ListTile(
              leading: const Icon(Icons.drive_file_move_outlined,
                  color: AppColors.text),
              title: Text(doc.folder == null
                  ? 'Move to folder'
                  : 'Move (in "${doc.folder}")'),
              onTap: () {
                Navigator.pop(ctx);
                _showMoveToFolder(doc);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded,
                  color: AppColors.error),
              title: const Text('Delete',
                  style: TextStyle(color: AppColors.error)),
              onTap: () {
                Navigator.pop(ctx);
                _confirmDelete(doc);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showMoveToFolder(LocalDocumentModel doc) {
    final folders = ref.read(folderProvider).value ?? [];
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Move to folder',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppColors.text)),
            ),
            if (doc.folder != null)
              ListTile(
                leading: const Icon(Icons.folder_off_outlined,
                    color: AppColors.text),
                title: const Text('Remove from folder'),
                onTap: () {
                  Navigator.pop(ctx);
                  ref
                      .read(localDocumentProvider.notifier)
                      .moveToFolder(doc.id, null);
                },
              ),
            ...folders.map((f) => ListTile(
                  leading: Icon(Icons.folder_rounded,
                      color: doc.folder == f
                          ? AppColors.primary
                          : AppColors.hint),
                  title: Text(f),
                  trailing: doc.folder == f
                      ? const Icon(Icons.check_rounded,
                          color: AppColors.primary)
                      : null,
                  onTap: () {
                    Navigator.pop(ctx);
                    ref
                        .read(localDocumentProvider.notifier)
                        .moveToFolder(doc.id, f);
                  },
                )),
            ListTile(
              leading: const Icon(Icons.create_new_folder_outlined,
                  color: AppColors.primary),
              title: const Text('New folder…',
                  style: TextStyle(color: AppColors.primary)),
              onTap: () async {
                Navigator.pop(ctx);
                final controller = TextEditingController();
                final name = await showDialog<String>(
                  context: context,
                  builder: (dctx) => AlertDialog(
                    title: const Text('New Folder'),
                    content: TextField(
                        controller: controller,
                        autofocus: true,
                        decoration:
                            const InputDecoration(hintText: 'Folder name')),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(dctx),
                          child: const Text('Cancel')),
                      ElevatedButton(
                        onPressed: () =>
                            Navigator.pop(dctx, controller.text.trim()),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary),
                        child: const Text('Create & Move'),
                      ),
                    ],
                  ),
                );
                if (name != null && name.isNotEmpty) {
                  await ref.read(folderProvider.notifier).addFolder(name);
                  await ref
                      .read(localDocumentProvider.notifier)
                      .moveToFolder(doc.id, name);
                }
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionsBar() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          ElevatedButton.icon(
            onPressed: () => context.push('/scanner'),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Scan'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            ),
          ),
          const SizedBox(width: 12),
          _buildOutlinedQuickButton(icon: Icons.credit_card_rounded, label: 'Card', onPressed: () => context.push('/business-card-scanner')),
          const SizedBox(width: 12),
          _buildOutlinedQuickButton(icon: Icons.drive_folder_upload_outlined, label: 'Import', onPressed: _handleImport),
          const SizedBox(width: 12),
          _buildOutlinedQuickButton(
            icon: Icons.create_new_folder_outlined,
            label: 'Folder',
            isActive: _foldersView,
            onPressed: () => setState(() {
              _foldersView = !_foldersView;
              _openFolder = null;
              _starredOnly = false;
            }),
          ),
          const SizedBox(width: 12),
          _buildOutlinedQuickButton(
            icon: _starredOnly ? Icons.star_rounded : Icons.star_border_rounded,
            label: 'Starred',
            isActive: _starredOnly,
            onPressed: () => setState(() {
              _starredOnly = !_starredOnly;
              _foldersView = false;
              _openFolder = null;
            }),
          ),
        ],
      ),
    );
  }

  /// Best-effort cloud backup of a locally-saved doc, gated on the setting.
  Future<void> _backupDocToCloud(LocalDocumentModel doc, File pdfFile) async {
    try {
      final settings = ref.read(settingsProvider).value;
      if (!(settings?.cloudBackup ?? true)) return;
      final user = ref.read(authStateProvider);
      if (user == null) return;

      // Upload the PDF to the user's own Google Drive (free); metadata to
      // Firestore either way.
      final driveId =
          await ref.read(driveServiceProvider).uploadPdf(pdfFile, '${doc.id}.pdf');
      final cloudDoc = DocumentModel(
        id: doc.id,
        title: doc.title,
        date: doc.date,
        pageCount: doc.pageCount,
        type: doc.type,
        thumbnailType: 'pdf',
        fileUrl: driveId,
        isStarred: doc.isStarred,
      );
      await ref.read(documentServiceProvider).addDocument(cloudDoc);
    } catch (e) {
      debugPrint('Import cloud backup skipped/failed: $e');
    }
  }

  /// Import images from gallery → generate PDF → save to local docs
  Future<void> _handleImport() async {
    final picker = ImagePicker();
    final List<XFile> picked = await picker.pickMultiImage();
    if (picked.isEmpty || !mounted) return;

    // Show loading snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Importing document...'),
        duration: Duration(seconds: 60),
      ),
    );

    try {
      final images = picked.map((x) => File(x.path)).toList();
      final pdfService = ref.read(pdfServiceProvider);
      final pdfFile = await pdfService.generatePdf(images);

      final now = DateTime.now();
      final dateStr =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      final doc = LocalDocumentModel(
        id: now.millisecondsSinceEpoch.toString(),
        title: 'Import_$dateStr',
        date: dateStr,
        pageCount: images.length,
        type: 'PDF',
        pdfPath: pdfFile.path,
        thumbnailPath: images.first.path,
        imagePaths: images.map((f) => f.path).toList(),
      );

      await ref.read(localDocumentProvider.notifier).addDocument(doc);
      await _backupDocToCloud(doc, pdfFile);

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${images.length} page(s) imported successfully'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Import failed: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Widget _buildOutlinedQuickButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    bool isActive = false,
  }) {
    final fg = isActive ? AppColors.primary : AppColors.text;
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18, color: fg),
      label: Text(label, style: TextStyle(color: fg)),
      style: OutlinedButton.styleFrom(
        backgroundColor:
            isActive ? AppColors.primary.withValues(alpha: 0.08) : null,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        side: BorderSide(
            color: isActive ? AppColors.primary : AppColors.border,
            width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
    );
  }

  Widget _buildDocumentCard(LocalDocumentModel doc) {
    final thumbFile = File(doc.thumbnailPath);
    final thumbExists = thumbFile.existsSync();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.border.withValues(alpha: 0.8), width: 1.2),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          final notifier = ref.read(scanProvider.notifier);
          notifier.clearScanSession();
          for (final path in doc.imagePaths) {
            notifier.addCapturedImage(File(path));
          }
          notifier.setDocumentDetails(doc.id, '${doc.title}.pdf');
          context.push('/preview');
        },
        onLongPress: () => _showDocActions(doc),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Thumbnail
              Expanded(
                child: Stack(
                  children: [
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.border.withValues(alpha: 0.4), width: 1.0),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: thumbExists
                            ? Image.file(
                                thumbFile,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity,
                              )
                            : const Center(
                                child: Icon(Icons.insert_drive_file_outlined,
                                    color: AppColors.hint, size: 40),
                              ),
                      ),
                    ),
                    // Type badge
                    Positioned(
                      top: 6, right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(doc.type,
                            style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: Colors.white)),
                      ),
                    ),
                    // Star badge
                    if (doc.isStarred)
                      const Positioned(
                        top: 6, left: 6,
                        child: Icon(Icons.star_rounded, color: Color(0xFFFDA856), size: 16),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(doc.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.text)),
              const SizedBox(height: 2),
              Text(
                '${doc.date} · ${doc.pageCount} ${doc.pageCount == 1 ? 'page' : 'pages'}',
                style: const TextStyle(fontSize: 11, color: AppColors.hint),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Long-press to delete confirmation
  void _confirmDelete(LocalDocumentModel doc) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Document'),
        content: Text('Delete "${doc.title}"? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref
                  .read(localDocumentProvider.notifier)
                  .deleteDocument(doc.id);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Document deleted'),
                    backgroundColor: AppColors.error,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }




  static const Map<String, String> _filterLabels = {
    'original': 'Original',
    'magicColor': 'Magic Color',
    'blackAndWhite': 'Black & White',
    'gray': 'Grayscale',
    'retro': 'Retro',
  };

  Widget _buildSettingsTab() {
    final user = ref.watch(authStateProvider);
    final settings = ref.watch(settingsProvider).value ?? const AppSettings();
    final userName = user?.displayName ?? 'Guest';
    final userEmail = user?.email ?? 'Not signed in';

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border, width: 1.5)),
            padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: const Color(0xFF2E5CB8),
                  child: Text(userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 24)),
                ),
                const SizedBox(height: 12),
                Text(userName, style: const TextStyle(color: Color(0xFF2A2A2A), fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 4),
                Text(userEmail, style: const TextStyle(color: AppColors.hint, fontSize: 12)),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: user == null ? null : _editProfile,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary, width: 1.5),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  child: const Text('Edit Profile', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildSectionHeader('SCAN PREFERENCES'),
          Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border, width: 1.5)),
            child: Column(
              children: [
                _buildSettingsItem(icon: Icons.image_outlined, title: 'Default filter',
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [Text(_filterLabels[settings.defaultFilter] ?? 'Magic Color',
                        style: const TextStyle(color: AppColors.hint, fontSize: 13)),
                      const SizedBox(width: 4), const Icon(Icons.keyboard_arrow_right_rounded, color: AppColors.hint)],
                  ), onTap: () => _pickDefaultFilter(settings.defaultFilter)),
                const Divider(height: 1, color: AppColors.border),
                _buildSettingsItem(icon: Icons.camera_alt_outlined, title: 'Auto-capture',
                  trailing: Switch(
                    value: _autoCapture,
                    onChanged: (val) async {
                      setState(() => _autoCapture = val);
                      await ref.read(settingsProvider.notifier).setAutoCapture(val);
                    },
                    activeThumbColor: Colors.white, activeTrackColor: AppColors.primary)),
                const Divider(height: 1, color: AppColors.border),
                _buildSettingsItem(icon: Icons.photo_size_select_actual_outlined, title: 'Image quality',
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [Text(settings.imageQuality, style: const TextStyle(color: AppColors.hint, fontSize: 13)),
                      const SizedBox(width: 4), const Icon(Icons.keyboard_arrow_right_rounded, color: AppColors.hint)],
                  ), onTap: () => _pickImageQuality(settings.imageQuality)),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildSectionHeader('STORAGE & SYNC'),
          Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border, width: 1.5)),
            child: Column(
              children: [
                _buildSettingsItem(icon: Icons.cloud_queue_outlined, title: 'Cloud backup',
                  trailing: Switch(
                    value: _cloudBackup,
                    onChanged: (val) async {
                      setState(() => _cloudBackup = val);
                      await ref.read(settingsProvider.notifier).setCloudBackup(val);
                      if (!mounted) return;
                      final signedIn = ref.read(authStateProvider) != null;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(val
                              ? (signedIn
                                  ? 'Cloud backup ON — new scans will sync'
                                  : 'Cloud backup ON — sign in to sync')
                              : 'Cloud backup OFF — saving locally only'),
                          backgroundColor: AppColors.success,
                        ),
                      );
                    },
                    activeThumbColor: Colors.white, activeTrackColor: AppColors.primary)),
                const Divider(height: 1, color: AppColors.border),
                _buildSettingsItem(icon: Icons.storage_outlined, title: 'Storage used',
                  trailing: FutureBuilder<String>(
                    future: _computeStorageUsed(),
                    builder: (context, snap) => Text(
                      snap.data ?? '…',
                      style: const TextStyle(
                          color: AppColors.text,
                          fontWeight: FontWeight.bold,
                          fontSize: 12),
                    ),
                  )),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildSectionHeader('ABOUT'),
          Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border, width: 1.5)),
            child: Column(
              children: [
                _buildSettingsItem(title: 'Version',
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [Text(AppConstants.appVersion, style: const TextStyle(color: AppColors.hint, fontSize: 13)),
                      const SizedBox(width: 4), const Icon(Icons.keyboard_arrow_right_rounded, color: AppColors.hint)],
                  ), onTap: _showAbout),
                const Divider(height: 1, color: AppColors.border),
                _buildSettingsItem(title: 'Privacy policy',
                  trailing: const Icon(Icons.keyboard_arrow_right_rounded, color: AppColors.hint),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
                  )),
                const Divider(height: 1, color: AppColors.border),
                _buildSettingsItem(title: 'Rate app',
                  trailing: const Icon(Icons.keyboard_arrow_right_rounded, color: AppColors.hint),
                  onTap: () => _openUrl('https://play.google.com/store/apps/details?id=com.scanmate.scanmate')),
                const Divider(height: 1, color: AppColors.border),
                _buildSettingsItem(title: 'Help & feedback',
                  trailing: const Icon(Icons.keyboard_arrow_right_rounded, color: AppColors.hint),
                  onTap: () => _openUrl(
                    'mailto:ayushmaan.ggn@gmail.com?subject=ScanMate%20Help%20%26%20Feedback')),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Container(
            margin: const EdgeInsets.only(bottom: 24.0),
            child: ElevatedButton(
              onPressed: () async {
                final authService = ref.read(authServiceProvider);
                final router = GoRouter.of(context);
                await authService.signOut();
                ref.read(scanProvider.notifier).clearScanSession();
                router.go('/login');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFFD32F2F),
                side: const BorderSide(color: AppColors.border, width: 1.5),
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('Sign out', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ),
          ),
        ],
      ),
    );
  }

  // ── Settings actions ───────────────────────────────────────────────────────

  Future<void> _editProfile() async {
    final user = ref.read(authStateProvider);
    final controller = TextEditingController(text: user?.displayName ?? '');
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Profile'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Display name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (newName == null || newName.isEmpty || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final error = await ref.read(authServiceProvider).updateDisplayName(newName);
    messenger.showSnackBar(SnackBar(
      content: Text(error ?? 'Profile updated'),
      backgroundColor: error == null ? AppColors.success : AppColors.error,
    ));
  }

  Future<void> _pickDefaultFilter(String current) async {
    final choice = await _pickFromList(
      title: 'Default filter',
      options: _filterLabels.entries
          .map((e) => (value: e.key, label: e.value))
          .toList(),
      current: current,
    );
    if (choice != null) {
      await ref.read(settingsProvider.notifier).setDefaultFilter(choice);
    }
  }

  Future<void> _pickImageQuality(String current) async {
    final choice = await _pickFromList(
      title: 'Image quality',
      options: const [
        (value: 'High', label: 'High (best quality)'),
        (value: 'Medium', label: 'Medium (balanced)'),
        (value: 'Low', label: 'Low (smallest size)'),
      ],
      current: current,
    );
    if (choice != null) {
      await ref.read(settingsProvider.notifier).setImageQuality(choice);
    }
  }

  Future<String?> _pickFromList({
    required String title,
    required List<({String value, String label})> options,
    required String current,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppColors.text)),
            ),
            ...options.map((o) => ListTile(
                  title: Text(o.label),
                  trailing: o.value == current
                      ? const Icon(Icons.check_rounded, color: AppColors.primary)
                      : null,
                  onTap: () => Navigator.pop(ctx, o.value),
                )),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<String> _computeStorageUsed() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      int bytes = 0;
      await for (final entity in dir.list(recursive: true, followLinks: false)) {
        if (entity is File) {
          bytes += await entity.length();
        }
      }
      if (bytes < 1024 * 1024) {
        return '${(bytes / 1024).toStringAsFixed(0)} KB';
      }
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } catch (e) {
      return '—';
    }
  }

  void _showAbout() {
    showAboutDialog(
      context: context,
      applicationName: AppConstants.appName,
      applicationVersion: 'Version ${AppConstants.appVersion}',
      applicationIcon: const Icon(Icons.document_scanner_rounded,
          color: AppColors.primary, size: 40),
      children: const [
        SizedBox(height: 12),
        Text('Scan documents and business cards, run OCR, and back up to '
            'your own Google Drive.'),
      ],
    );
  }

  Future<void> _openUrl(String url) async {
    final messenger = ScaffoldMessenger.of(context);
    final uri = Uri.parse(url);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) {
      messenger.showSnackBar(const SnackBar(
        content: Text('Could not open link'),
        backgroundColor: AppColors.error,
      ));
    }
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8.0, bottom: 8.0),
      child: Text(title,
        style: const TextStyle(color: AppColors.hint, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.8)),
    );
  }

  Widget _buildSettingsItem({IconData? icon, required String title, required Widget trailing, VoidCallback? onTap}) {
    final itemContent = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Row(
        children: [
          if (icon != null) ...[Icon(icon, color: const Color(0xFF3F62F6), size: 22), const SizedBox(width: 12)],
          Expanded(child: Text(title, style: const TextStyle(color: Color(0xFF2A2A2A), fontWeight: FontWeight.bold, fontSize: 14))),
          trailing,
        ],
      ),
    );
    if (onTap != null) return InkWell(onTap: onTap, child: itemContent);
    return itemContent;
  }

  Widget _buildBottomNavItem({required int index, required IconData icon, required IconData activeIcon, required String label}) {
    final isActive = _currentTab == index;
    return GestureDetector(
      onTap: () => setState(() => _currentTab = index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFFEEF2FE) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(isActive ? activeIcon : icon,
              color: isActive ? const Color(0xFF3F62F6) : AppColors.text, size: 24),
            if (isActive) ...[
              const SizedBox(width: 8),
              Text(label, style: const TextStyle(color: Color(0xFF3F62F6), fontWeight: FontWeight.bold, fontSize: 12)),
            ],
          ],
        ),
      ),
    );
  }
}
