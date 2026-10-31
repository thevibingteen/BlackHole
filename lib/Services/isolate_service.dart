import 'dart:isolate';

import 'package:blackhole/Screens/Player/audioplayer.dart';
import 'package:blackhole/Services/youtube_services.dart';
import 'package:get_it/get_it.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:logging/logging.dart';
import 'package:path_provider/path_provider.dart';

SendPort? isolateSendPort;

Future<void> startBackgroundProcessing([AudioPlayerHandler? handler]) async {
  final receivePort = ReceivePort();
  await Isolate.spawn(_backgroundProcess, receivePort.sendPort);

  receivePort.listen((message) async {
    if (isolateSendPort == null) {
      Logger.root.info('setting isolateSendPort');
      isolateSendPort = message as SendPort;
      final appDocumentDirectoryPath =
          (await getApplicationDocumentsDirectory()).path;
      isolateSendPort?.send(appDocumentDirectoryPath);
    } else {
      AudioPlayerHandler? targetHandler = handler;
      if (targetHandler == null && GetIt.I.isRegistered<AudioPlayerHandler>()) {
        targetHandler = GetIt.I<AudioPlayerHandler>();
      }
      if (targetHandler != null) {
        await targetHandler.customAction('refreshLink', {'newData': message});
      }
    }
  });
}

// The function that will run in the background Isolate
Future<void> _backgroundProcess(SendPort sendPort) async {
  final isolateReceivePort = ReceivePort();
  sendPort.send(isolateReceivePort.sendPort);
  bool hiveInit = false;

  await for (final message in isolateReceivePort) {
    if (!hiveInit) {
      Hive.init(message.toString());
      await Hive.openBox('ytlinkcache');
      await Hive.openBox('settings');
      hiveInit = true;
      continue;
    }
    final newData = await YouTubeServices().refreshLink(message.toString());
    sendPort.send(newData);
  }
}

void addIdToBackgroundProcessingIsolate(String id) {
  if (isolateSendPort == null) {
    startBackgroundProcessing();
  }
  isolateSendPort?.send(id);
}
