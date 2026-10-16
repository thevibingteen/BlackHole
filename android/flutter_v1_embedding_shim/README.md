# Flutter v1 Embedding Compatibility Shim

## Purpose
Flutter 3.29+ / 3.47+ permanently removed the deprecated Android v1 embedding interfaces from the engine embedding JAR (`io.flutter:flutter_embedding_*`), including `io.flutter.plugin.common.PluginRegistry.Registrar`.

Legacy plugins such as `audiotagger`, `file_picker`, and `permission_handler` retain dormant backward-compatible `registerWith(PluginRegistry.Registrar registrar)` declarations alongside their modern v2 `FlutterPlugin` implementations. In Flutter 3.29+, javac fails to compile these plugins with:
```
error: cannot find symbol ... class Registrar ... location: interface PluginRegistry
```

## How It Works
This module is a local Android library providing interface declarations for the removed v1 `PluginRegistry` and `Registrar`.

- It is linked to plugin subprojects strictly via `compileOnly project(':flutter_v1_embedding_shim')`.
- It satisfies `javac` during compile time so legacy plugins compile without modifications.
- Because it is `compileOnly`, it is **never** packaged into the release APK runtime bundle.
- At runtime on Android, Flutter v2 embedding (`FlutterPlugin`) is used exclusively.
