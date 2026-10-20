import 'package:flutter/material.dart';
import 'app_localizations.dart';

/// The desktop close path consults the current editor as well as route back.
abstract final class EditSession {
  static Future<bool> Function()? beforeClose;
}

class UnsavedChanges extends StatefulWidget {
  const UnsavedChanges({
    super.key,
    required this.dirty,
    this.canLeave,
    required this.child,
  });
  final bool Function() dirty;
  final bool Function()? canLeave;
  final Widget child;
  @override
  State<UnsavedChanges> createState() => _UnsavedChangesState();
}

class _UnsavedChangesState extends State<UnsavedChanges> {
  Future<bool> Function()? _previous;
  bool _leaving = false, _asking = false;
  @override
  void initState() {
    super.initState();
    _previous = EditSession.beforeClose;
    EditSession.beforeClose = _confirm;
  }

  Future<bool> _confirm() async {
    if (widget.canLeave?.call() == false) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: AppText('正在验证，请等待完成后离开。')));
      return false;
    }
    if (!widget.dirty() || _leaving) return true;
    if (_asking) return false;
    _asking = true;
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const AppText('放弃未保存的修改？'),
        content: const AppText('继续编辑可保留输入；放弃后将无法恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const AppText('继续编辑'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const AppText('放弃修改'),
          ),
        ],
      ),
    );
    _asking = false;
    return discard == true;
  }

  @override
  void dispose() {
    EditSession.beforeClose = _previous;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _leaving || (!widget.dirty() && widget.canLeave?.call() != false),
    onPopInvokedWithResult: (didPop, result) async {
      if (didPop) return;
      if (await _confirm() && mounted) {
        setState(() => _leaving = true);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) Navigator.of(context).pop(result);
        });
      }
    },
    child: widget.child,
  );
}
