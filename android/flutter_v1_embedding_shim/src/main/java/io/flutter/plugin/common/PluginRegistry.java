// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

package io.flutter.plugin.common;

import android.app.Activity;
import android.content.Context;
import android.content.Intent;
import io.flutter.plugin.platform.PlatformViewRegistry;
import io.flutter.view.FlutterNativeView;
import io.flutter.view.TextureRegistry;
import io.flutter.view.FlutterView;

/**
 * Compatibility shim providing the legacy Flutter Android v1 embedding PluginRegistry
 * and Registrar interfaces. This allows legacy plugins (e.g. audiotagger, file_picker,
 * permission_handler) to compile under Flutter 3.29+ / 3.47+ where the v1 embedding was
 * removed from the engine embedding JAR.
 */
public interface PluginRegistry {

  @Deprecated
  interface Registrar {
    Activity activity();

    Context context();

    Context activeContext();

    BinaryMessenger messenger();

    TextureRegistry textures();

    PlatformViewRegistry platformViewRegistry();

    FlutterView view();

    String lookupKeyForAsset(String asset);

    String lookupKeyForAsset(String asset, String packageName);

    Registrar publish(Object value);

    Registrar addRequestPermissionsResultListener(RequestPermissionsResultListener listener);

    Registrar addActivityResultListener(ActivityResultListener listener);

    Registrar addNewIntentListener(NewIntentListener listener);

    Registrar addUserLeaveHintListener(UserLeaveHintListener listener);

    Registrar addWindowFocusChangedListener(WindowFocusChangedListener listener);

    Registrar addViewDestroyListener(ViewDestroyListener listener);
  }

  interface RequestPermissionsResultListener {
    boolean onRequestPermissionsResult(int requestCode, String[] permissions, int[] grantResults);
  }

  interface ActivityResultListener {
    boolean onActivityResult(int requestCode, int resultCode, Intent data);
  }

  interface NewIntentListener {
    boolean onNewIntent(Intent intent);
  }

  interface UserLeaveHintListener {
    void onUserLeaveHint();
  }

  interface WindowFocusChangedListener {
    void onWindowFocusChanged(boolean hasFocus);
  }

  interface ViewDestroyListener {
    boolean onViewDestroy(FlutterNativeView view);
  }

  interface PluginRegistrantCallback {
    void registerWith(PluginRegistry registry);
  }
}
