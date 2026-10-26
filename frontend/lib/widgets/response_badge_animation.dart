import 'package:flutter/material.dart';

String responseBadgeAssetForLabel(String performanceLabel) =>
    switch (performanceLabel) {
      'lightning_fast' => 'assets/images/fast.gif',
      'quick_responder' => 'assets/images/quick.gif',
      'getting_faster' => 'assets/images/improving.gif',
      'needs_improvement' => 'assets/images/Slow.gif',
      _ => 'assets/images/active.gif',
    };

String responseBadgeDescription(String performanceLabel) =>
    switch (performanceLabel) {
      'lightning_fast' => 'Lightning fast response badge',
      'quick_responder' => 'Quick responder badge',
      'getting_faster' => 'Improving response activity badge',
      'needs_improvement' => 'Slow response activity badge',
      _ => 'Response activity badge',
    };

class ResponseBadgeAnimation extends StatelessWidget {
  final String performanceLabel;
  final double size;

  const ResponseBadgeAnimation({
    super.key,
    required this.performanceLabel,
    this.size = 40,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: responseBadgeDescription(performanceLabel),
      child: SizedBox.square(
        dimension: size,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.asset(
            responseBadgeAssetForLabel(performanceLabel),
            width: size,
            height: size,
            fit: BoxFit.contain,
            gaplessPlayback: true,
            errorBuilder: (context, error, stackTrace) => const Icon(
              Icons.bolt_rounded,
              color: Color(0xFF10B981),
            ),
          ),
        ),
      ),
    );
  }
}
