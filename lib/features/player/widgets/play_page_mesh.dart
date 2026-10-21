import 'package:flutter/material.dart';
import 'package:mesh_gradient/mesh_gradient.dart';
import 'package:signals/signals_flutter.dart';
import 'package:zerobit_player/features/player/controller/audio_ctrl.dart';

import '../../../core/utils/memory_manager.dart';

final AnimatedMeshGradientOptions _meshOptions = AnimatedMeshGradientOptions(
  frequency: 5,
  amplitude: 30,
  speed: 0.6,
  grain: 0,
);

final Widget _meshChild = Container();

class PlayPageMesh extends StatelessWidget {
  const PlayPageMesh({super.key});

  @override
  Widget build(BuildContext context) {
    return SignalBuilder(
      builder: (context) => MemoryManager.tickerEnable.value
          ? AnimatedMeshGradient(
              colors: AudioController.instance.coverPalette.value,
              options: _meshOptions,
              child: _meshChild,
            )
          : const SizedBox.shrink(),
    );
  }
}
