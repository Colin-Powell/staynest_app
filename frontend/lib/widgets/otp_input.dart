import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class OtpInput extends StatefulWidget {
  final int length;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onCompleted;
  final bool hasError;
  final bool isLoading;

  const OtpInput({
    super.key,
    this.length = 6,
    this.onChanged,
    this.onCompleted,
    this.hasError = false,
    this.isLoading = false,
  });

  @override
  State<OtpInput> createState() => OtpInputState();
}

class OtpInputState extends State<OtpInput> {
  late List<TextEditingController> _controllers;
  late List<FocusNode> _focusNodes;

  static const _primary = Color(0xFF3D36E8);
  static const _border = Color(0xFFE4E6EF);
  static const _text = Color(0xFF14162C);

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(widget.length, (_) => TextEditingController());
    _focusNodes = List.generate(widget.length, (_) => FocusNode());
  }

  void setCode(String code) {
    if (code.length > widget.length) code = code.substring(0, widget.length);
    for (int i = 0; i < widget.length; i++) {
      if (i < code.length) {
        _controllers[i].text = code[i];
      } else {
        _controllers[i].clear();
      }
    }
    _triggerChanged();
    if (code.length == widget.length) {
      _focusNodes[widget.length - 1].unfocus();
      widget.onCompleted?.call(code);
    }
  }

  void clear() {
    for (var c in _controllers) {
      c.clear();
    }
    _triggerChanged();
    _focusNodes[0].requestFocus();
  }

  void _triggerChanged() {
    final code = _controllers.map((c) => c.text).join();
    widget.onChanged?.call(code);
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    for (final focusNode in _focusNodes) {
      focusNode.dispose();
    }
    super.dispose();
  }

  Widget _buildOtpBox(int index) {
    return SizedBox(
      width: 52,
      height: 64,
      child: KeyboardListener(
        focusNode: FocusNode(skipTraversal: true),
        onKeyEvent: (event) {
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.backspace &&
              _controllers[index].text.isEmpty &&
              index > 0) {
            _focusNodes[index - 1].requestFocus();
            _controllers[index - 1].clear();
            _triggerChanged();
          }
        },
        child: TextField(
          controller: _controllers[index],
          focusNode: _focusNodes[index],
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          maxLength: 6,
          autofillHints: const [AutofillHints.oneTimeCode],
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          enabled: !widget.isLoading,
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            color: _text,
          ),
          decoration: InputDecoration(
            counterText: '',
            filled: true,
            fillColor: Colors.white,
            contentPadding: EdgeInsets.zero,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: widget.hasError ? Colors.red : _border,
                width: 1.5,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: widget.hasError ? Colors.red : _primary,
                width: 2.0,
              ),
            ),
          ),
          onChanged: (value) {
            if (value.length > 1) {
              String pasted = value.replaceAll(RegExp(r'[^0-9]'), '');
              if (pasted.length > widget.length - index) {
                pasted = pasted.substring(0, widget.length - index);
              }
              for (int i = 0; i < pasted.length; i++) {
                if (index + i < widget.length) {
                  _controllers[index + i].text = pasted[i];
                }
              }
              int nextIndex = (index + pasted.length).clamp(0, widget.length - 1);
              if (index + pasted.length >= widget.length) {
                _focusNodes[widget.length - 1].unfocus();
                _triggerChanged();
                widget.onCompleted?.call(_controllers.map((c) => c.text).join());
              } else {
                _focusNodes[nextIndex].requestFocus();
                _triggerChanged();
              }
            } else if (value.isNotEmpty) {
              if (index < widget.length - 1) {
                _focusNodes[index + 1].requestFocus();
              } else {
                _focusNodes[index].unfocus();
                widget.onCompleted?.call(_controllers.map((c) => c.text).join());
              }
              _triggerChanged();
            } else {
              _triggerChanged();
            }
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(widget.length, (index) => _buildOtpBox(index)),
    );
  }
}
