package io.flutter.plugin.common;

import java.nio.ByteBuffer;

public interface BinaryMessenger {
  interface BinaryMessageHandler {
    void onMessage(ByteBuffer message, BinaryReply reply);
  }
  interface BinaryReply {
    void reply(ByteBuffer reply);
  }
  void send(String channel, ByteBuffer message);
  void send(String channel, ByteBuffer message, BinaryReply callback);
  void setMessageHandler(String channel, BinaryMessageHandler handler);
}
