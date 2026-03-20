// lib/ui/screens/ar_whiteboard/ar_whiteboard_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants.dart';
import '../../../models/note.dart';
import '../../../providers/notes_provider.dart';
import '../../../providers/purchase_provider.dart';

class ArWhiteboardScreen extends ConsumerStatefulWidget {
  const ArWhiteboardScreen({super.key});

  @override
  ConsumerState<ArWhiteboardScreen> createState() => _ArWhiteboardScreenState();
}

class _ArWhiteboardScreenState extends ConsumerState<ArWhiteboardScreen> {
  String? _capturedImage; // base64
  bool _isProcessing = false;
  String _recognizedText = '';
  _CaptureStep _step = _CaptureStep.prompt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final purchase = ref.watch(purchaseProvider);

    if (!purchase.canUseAR) return _PaywallView();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: const Text('AR Whiteboard Capture'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Chip(
              label: const Text('🔮 AR', style: TextStyle(color: Colors.white, fontSize: 11)),
              backgroundColor: AppColors.primary.withOpacity(0.3),
              side: BorderSide(color: AppColors.primary.withOpacity(0.5)),
            ),
          ),
        ],
      ),
      body: AnimatedSwitcher(
        duration: AppConstants.animationMedium,
        child: switch (_step) {
          _CaptureStep.prompt   => _PromptView(onCapture: _capture, onGallery: _fromGallery),
          _CaptureStep.preview  => _PreviewView(
              image: _capturedImage!,
              isProcessing: _isProcessing,
              recognizedText: _recognizedText,
              onRetake: _retake,
              onAccept: _createNote,
              onEditText: (t) => setState(() => _recognizedText = t),
            ),
          _CaptureStep.done    => _DoneView(onNewCapture: _retake, onGoNotes: () => context.go('/')),
        },
      ),
    );
  }

  Future<void> _capture() async {
    HapticFeedback.mediumImpact();
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 90,
      preferredCameraDevice: CameraDevice.rear,
    );
    if (file == null) return;

    final bytes = await file.readAsBytes();
    setState(() {
      _capturedImage = base64Encode(bytes);
      _step = _CaptureStep.preview;
      _isProcessing = true;
    });

    // Simulate whiteboard text extraction (replace with real OCR in production)
    await Future.delayed(const Duration(milliseconds: 1800));
    setState(() {
      _recognizedText = '# Whiteboard Capture\n\n'
          'Text extracted from whiteboard.\n\n'
          '**Action Items:**\n'
          '- [ ] Item 1\n'
          '- [ ] Item 2\n\n'
          '*Edit this text to add your notes.*';
      _isProcessing = false;
    });
  }

  Future<void> _fromGallery() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 90);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() {
      _capturedImage = base64Encode(bytes);
      _step = _CaptureStep.preview;
      _isProcessing = true;
    });
    await Future.delayed(const Duration(milliseconds: 1500));
    setState(() {
      _recognizedText = '# Gallery Image\n\nEdit this to add your notes.';
      _isProcessing = false;
    });
  }

  Future<void> _createNote() async {
    if (_capturedImage == null) return;
    final note = Note(
      title: 'Whiteboard ${DateTime.now().toString().substring(0, 16)}',
      content: _recognizedText,
      isMarkdown: true,
      imageBase64: [_capturedImage!],
      tags: ['whiteboard', 'ar-capture'],
    );
    await ref.read(notesProvider.notifier).addNote(note);
    HapticFeedback.heavyImpact();
    setState(() => _step = _CaptureStep.done);
  }

  void _retake() {
    setState(() {
      _capturedImage = null;
      _recognizedText = '';
      _step = _CaptureStep.prompt;
      _isProcessing = false;
    });
  }
}

enum _CaptureStep { prompt, preview, done }

// ─── Prompt view ──────────────────────────────────────────────────────────────

class _PromptView extends StatelessWidget {
  final VoidCallback onCapture, onGallery;
  const _PromptView({required this.onCapture, required this.onGallery});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Animated scan frame
                _ScanFrame(),
                const SizedBox(height: 32),
                const Text(
                  'Point camera at a whiteboard\nor handwritten notes',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w500),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'AI extracts text and creates\nan editable markdown note',
                  style: TextStyle(color: Colors.white54, fontSize: 13, height: 1.5),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
          child: Column(
            children: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onCapture,
                  icon: const Icon(Icons.camera_alt_rounded),
                  label: const Text('Capture Whiteboard'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onGallery,
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('From Gallery'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white30),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ScanFrame extends StatefulWidget {
  @override
  State<_ScanFrame> createState() => _ScanFrameState();
}

class _ScanFrameState extends State<_ScanFrame> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Container(
        width: 220,
        height: 160,
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.neon.withOpacity(0.4 + _ctrl.value * 0.5), width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Stack(
          children: [
            // Corner markers
            ..._corners().map((c) => Positioned(
              left: c.dx < 0.5 ? 0 : null,
              right: c.dx > 0.5 ? 0 : null,
              top: c.dy < 0.5 ? 0 : null,
              bottom: c.dy > 0.5 ? 0 : null,
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  border: Border(
                    left: c.dx < 0.5 ? BorderSide(color: AppColors.neon, width: 3) : BorderSide.none,
                    right: c.dx > 0.5 ? BorderSide(color: AppColors.neon, width: 3) : BorderSide.none,
                    top: c.dy < 0.5 ? BorderSide(color: AppColors.neon, width: 3) : BorderSide.none,
                    bottom: c.dy > 0.5 ? BorderSide(color: AppColors.neon, width: 3) : BorderSide.none,
                  ),
                ),
              ),
            )),
            // Scanning line
            Positioned(
              top: _ctrl.value * 140,
              left: 0,
              right: 0,
              child: Container(
                height: 2,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    Colors.transparent,
                    AppColors.neon.withOpacity(0.8),
                    Colors.transparent,
                  ]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Offset> _corners() => [
    const Offset(0, 0), const Offset(1, 0),
    const Offset(0, 1), const Offset(1, 1),
  ];
}

// ─── Preview view ─────────────────────────────────────────────────────────────

class _PreviewView extends StatefulWidget {
  final String image, recognizedText;
  final bool isProcessing;
  final VoidCallback onRetake, onAccept;
  final void Function(String) onEditText;

  const _PreviewView({
    required this.image,
    required this.recognizedText,
    required this.isProcessing,
    required this.onRetake,
    required this.onAccept,
    required this.onEditText,
  });

  @override
  State<_PreviewView> createState() => _PreviewViewState();
}

class _PreviewViewState extends State<_PreviewView> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.recognizedText);
    _ctrl.addListener(() => widget.onEditText(_ctrl.text));
  }

  @override
  void didUpdateWidget(_PreviewView old) {
    super.didUpdateWidget(old);
    if (old.recognizedText != widget.recognizedText) {
      _ctrl.text = widget.recognizedText;
    }
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        // Image preview
        Container(
          height: 200,
          width: double.infinity,
          child: Image.memory(
            base64Decode(widget.image),
            fit: BoxFit.cover,
          ),
        ),

        // Extracted text or spinner
        Expanded(
          child: widget.isProcessing
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(color: AppColors.primary),
                      const SizedBox(height: 16),
                      Text('Extracting text...', style: theme.textTheme.bodyMedium),
                    ],
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.text_fields, size: 16, color: AppColors.primary),
                          const SizedBox(width: 6),
                          Text('Extracted Text',
                              style: theme.textTheme.labelMedium?.copyWith(color: AppColors.primary, fontWeight: FontWeight.w600)),
                          const Spacer(),
                          Text('Tap to edit', style: theme.textTheme.labelSmall),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: TextField(
                          controller: _ctrl,
                          maxLines: null,
                          expands: true,
                          style: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.all(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
        ),

        // Action buttons
        if (!widget.isProcessing)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: widget.onRetake,
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Retake'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: widget.onAccept,
                    icon: const Icon(Icons.save_alt, size: 16),
                    label: const Text('Save as Note'),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ─── Done view ────────────────────────────────────────────────────────────────

class _DoneView extends StatelessWidget {
  final VoidCallback onNewCapture, onGoNotes;
  const _DoneView({required this.onNewCapture, required this.onGoNotes});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('✅', style: TextStyle(fontSize: 64))
                .animate().scale(duration: 600.ms, curve: Curves.elasticOut),
            const SizedBox(height: 20),
            Text(
              'Whiteboard saved!',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700, color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            const Text('Your note is ready to share.',
                style: TextStyle(color: Colors.white60)),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onNewCapture,
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white30)),
                    child: const Text('New Capture'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onGoNotes,
                    child: const Text('View Notes'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Paywall ──────────────────────────────────────────────────────────────────

class _PaywallView extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.transparent, foregroundColor: Colors.white, title: const Text('AR Whiteboard')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🔮', style: TextStyle(fontSize: 60)),
              const SizedBox(height: 16),
              const Text('AR Whiteboard Capture',
                  style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              const Text(
                'Capture whiteboards, sticky notes, and sketches.\nAI converts them to editable markdown.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54, height: 1.5),
              ),
              const SizedBox(height: 28),
              ElevatedButton(
                onPressed: () => context.push('/monetization'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                ),
                child: const Text('Unlock — \$10 Lifetime'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
