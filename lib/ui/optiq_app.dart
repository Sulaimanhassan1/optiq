import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:image_picker/image_picker.dart';

import '../application/library_controller.dart';

class Optiq extends StatelessWidget {
  const Optiq({super.key, required this.controller});

  final LibraryController controller;

  ThemeData _theme(Brightness brightness) => ThemeData(
    brightness: brightness,
    colorSchemeSeed: const Color(0xff087e74),
    visualDensity: VisualDensity.standard,
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(),
    ),
  );

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Optiq',
    debugShowCheckedModeBanner: false,
    theme: _theme(Brightness.light),
    darkTheme: _theme(Brightness.dark),
    home: LibraryScreen(controller: controller),
  );
}

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key, required this.controller});
  final LibraryController controller;

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  LibraryController get library => widget.controller;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await library.load();
      if (mounted && library.ready && library.error == null) {
        await library.scan(null, _review);
      }
    });
  }

  Future<ScanChoice?> _review(ScanDraft draft) {
    if (!mounted) return Future.value(null);
    return Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => _ReviewScreen(draft: draft)));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Optiq')),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: ListenableBuilder(
            listenable: library,
            builder: (context, _) {
              final scheme = Theme.of(context).colorScheme;
              final canScan = library.ready && !library.busy;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    Text(
                      'Your documents',
                      style: Theme.of(context).textTheme.headlineLarge,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Stored on this device',
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 18),
                    if (library.activity case final activity?) ...[
                      LinearProgressIndicator(semanticsLabel: activity),
                      const SizedBox(height: 8),
                      Semantics(liveRegion: true, child: Text(activity)),
                    ],
                    if (library.error case final error?)
                      Card(
                        color: scheme.errorContainer,
                        child: ListTile(
                          textColor: scheme.onErrorContainer,
                          title: Semantics(
                            liveRegion: true,
                            child: Text(error),
                          ),
                          trailing: TextButton(
                            onPressed: library.load,
                            child: const Text('Retry library'),
                          ),
                        ),
                      ),
                    Expanded(
                      child: library.entries.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.description_outlined,
                                      color: scheme.primary,
                                      size: 42,
                                    ),
                                    const SizedBox(height: 14),
                                    Text(
                                      library.ready
                                          ? 'No documents yet'
                                          : 'Document library',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleLarge,
                                    ),
                                    if (library.ready)
                                      const Text(
                                        'Scan a page or import a photo to get started.',
                                        textAlign: TextAlign.center,
                                      ),
                                  ],
                                ),
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              itemCount: library.entries.length,
                              separatorBuilder: (_, _) =>
                                  const Divider(height: 1),
                              itemBuilder: (_, index) {
                                final entry = library.entries[index];
                                return ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                  leading: const Icon(
                                    Icons.picture_as_pdf_outlined,
                                  ),
                                  title: Text(entry.filename),
                                  trailing: Builder(
                                    builder: (anchor) => IconButton(
                                      tooltip: 'Share PDF',
                                      icon: const Icon(Icons.ios_share),
                                      onPressed: canScan
                                          ? () {
                                              final render =
                                                  anchor.findRenderObject()!
                                                      as RenderBox;
                                              library.share(
                                                entry,
                                                render.localToGlobal(
                                                      Offset.zero,
                                                    ) &
                                                    render.size,
                                              );
                                            }
                                          : null,
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          FilledButton.icon(
                            onPressed: canScan
                                ? () =>
                                      library.scan(ImageSource.camera, _review)
                                : null,
                            icon: const Icon(Icons.document_scanner_outlined),
                            label: const Text('New scan'),
                          ),
                          OutlinedButton.icon(
                            onPressed: canScan
                                ? () =>
                                      library.scan(ImageSource.gallery, _review)
                                : null,
                            icon: const Icon(Icons.image_outlined),
                            label: const Text('Import image'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    ),
  );
}

class _ReviewScreen extends StatefulWidget {
  const _ReviewScreen({required this.draft});
  final ScanDraft draft;

  @override
  State<_ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<_ReviewScreen> {
  late final _name = TextEditingController(text: widget.draft.suggestion);
  bool _grayscale = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final image = Image.file(
      File(widget.draft.photo.path),
      height: 280,
      fit: BoxFit.contain,
      cacheWidth: 1100,
      semanticLabel: 'Imported document preview',
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Review scan')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                if (_grayscale)
                  ColorFiltered(
                    colorFilter: const ColorFilter.matrix([
                      .2126,
                      .7152,
                      .0722,
                      0,
                      0,
                      .2126,
                      .7152,
                      .0722,
                      0,
                      0,
                      .2126,
                      .7152,
                      .0722,
                      0,
                      0,
                      0,
                      0,
                      0,
                      1,
                      0,
                    ]),
                    child: image,
                  )
                else
                  image,
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Grayscale'),
                  value: _grayscale,
                  onChanged: (value) => setState(() => _grayscale = value),
                ),
                TextField(
                  controller: _name,
                  decoration: const InputDecoration(
                    labelText: 'Suggested filename',
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => Navigator.pop(context, (
                    name: _name.text,
                    grayscale: _grayscale,
                  )),
                  child: const Text('Save PDF'),
                ),
                const SizedBox(height: 24),
                Text(
                  'Recognized text',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (widget.draft.text.trim().isEmpty)
                  const Text('No text detected.')
                else
                  SelectableText(widget.draft.text),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
