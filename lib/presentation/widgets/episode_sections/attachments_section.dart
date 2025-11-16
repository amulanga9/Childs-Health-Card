import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import '../../../data/database/database.dart';

/// Секция вложений (фото, документы)
class AttachmentsSection extends StatelessWidget {
  final List<Attachment> attachments;
  final Function(int attachmentId)? onAttachmentTap;
  final VoidCallback? onAddAttachment;
  final Function(int attachmentId)? onDeleteAttachment;

  const AttachmentsSection({
    super.key,
    required this.attachments,
    this.onAttachmentTap,
    this.onAddAttachment,
    this.onDeleteAttachment,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  Icons.attach_file,
                  color: theme.colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  'Вложения',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            if (onAddAttachment != null)
              IconButton(
                onPressed: onAddAttachment,
                icon: const Icon(Icons.add_circle_outline),
                tooltip: 'Добавить вложение',
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (attachments.isEmpty)
          _buildEmptyState(theme)
        else
          _buildAttachmentsGrid(theme),
      ],
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.attach_file,
              size: 48,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              'Нет вложений',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (onAddAttachment != null) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onAddAttachment,
                icon: const Icon(Icons.add),
                label: const Text('Добавить файл'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAttachmentsGrid(ThemeData theme) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1,
      ),
      itemCount: attachments.length,
      itemBuilder: (context, index) {
        final attachment = attachments[index];
        return _AttachmentCard(
          attachment: attachment,
          onTap: onAttachmentTap != null
              ? () => onAttachmentTap!(attachment.id)
              : null,
          onDelete: onDeleteAttachment != null
              ? () => onDeleteAttachment!(attachment.id)
              : null,
        );
      },
    );
  }
}

/// Карточка отдельного вложения
class _AttachmentCard extends StatefulWidget {
  final Attachment attachment;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const _AttachmentCard({
    required this.attachment,
    this.onTap,
    this.onDelete,
  });

  @override
  State<_AttachmentCard> createState() => _AttachmentCardState();
}

class _AttachmentCardState extends State<_AttachmentCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _showMenu = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  IconData _getFileIcon(String kind) {
    switch (kind.toLowerCase()) {
      case 'photo':
      case 'image':
      case 'jpeg':
      case 'jpg':
      case 'png':
        return Icons.image;
      case 'pdf':
      case 'document':
        return Icons.picture_as_pdf;
      default:
        return Icons.insert_drive_file;
    }
  }

  Color _getFileColor(String kind) {
    switch (kind.toLowerCase()) {
      case 'photo':
      case 'image':
      case 'jpeg':
      case 'jpg':
      case 'png':
        return Colors.blue;
      case 'pdf':
      case 'document':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  bool _isImageFile(String kind) {
    return ['photo', 'image', 'jpeg', 'jpg', 'png'].contains(kind.toLowerCase());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fileColor = _getFileColor(widget.attachment.kind);
    final isImage = _isImageFile(widget.attachment.kind);

    return GestureDetector(
      onTap: () {
        _controller.forward().then((_) => _controller.reverse());
        widget.onTap?.call();
      },
      onLongPress: () {
        if (widget.onDelete != null) {
          setState(() => _showMenu = true);
        }
      },
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: fileColor.withOpacity(0.3),
                ),
                boxShadow: [
                  BoxShadow(
                    color: theme.shadowColor.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Превью или иконка
                  Expanded(
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(12),
                      ),
                      child: isImage && File(widget.attachment.localPath).existsSync()
                          ? Image.file(
                              File(widget.attachment.localPath),
                              fit: BoxFit.cover,
                              width: double.infinity,
                              errorBuilder: (_, __, ___) => _buildIconPlaceholder(fileColor),
                            )
                          : _buildIconPlaceholder(fileColor),
                    ),
                  ),
                  // Дата
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: fileColor.withOpacity(0.1),
                      borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(12),
                      ),
                    ),
                    child: Text(
                      DateFormat('dd.MM.yy').format(widget.attachment.atDatetime),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: fileColor,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
            // Меню удаления
            if (_showMenu)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        onPressed: () {
                          setState(() => _showMenu = false);
                          widget.onDelete?.call();
                        },
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.white,
                        ),
                      ),
                      IconButton(
                        onPressed: () => setState(() => _showMenu = false),
                        icon: const Icon(
                          Icons.close,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildIconPlaceholder(Color color) {
    return Center(
      child: Icon(
        _getFileIcon(widget.attachment.kind),
        size: 48,
        color: color,
      ),
    );
  }
}
