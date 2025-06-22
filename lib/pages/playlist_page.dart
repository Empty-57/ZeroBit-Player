import 'package:flutter/material.dart';

class PlayList extends StatelessWidget{
  final Object? args;

  const PlayList({super.key,required this.args});

  @override
  Widget build(BuildContext context) {
    return Text(args.toString());
  }

}