package io.flutter.plugin.common;

import java.nio.ByteBuffer;

public interface BinaryMessenger {
  interface TaskQueue {}

  class TaskQueueOptions {
    private boolean isDaemon = false;

    public boolean getIsDaemon() {
      return isDaemon;
    }

    public TaskQueueOptions setIsDaemon(boolean isDaemon) {
      this.isDaemon = isDaemon;
      return this;
    }
  }

  TaskQueue makeBackgroundTaskQueue();

  TaskQueue makeBackgroundTaskQueue(TaskQueueOptions options);

  interface BinaryMessageHandler {
    void onMessage(ByteBuffer message, BinaryReply reply);
  }

  interface BinaryReply {
    void reply(ByteBuffer reply);
  }

  void send(String channel, ByteBuffer message);

  void send(String channel, ByteBuffer message, BinaryReply callback);

  void setMessageHandler(String channel, BinaryMessageHandler handler);

  void setMessageHandler(String channel, BinaryMessageHandler handler, TaskQueue taskQueue);
}
