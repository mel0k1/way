list(APPEND FLUTTER_PLUGIN_LIST
  dynamic_color
  file_selector_linux
  flutter_secure_storage_linux
  path_provider_linux
  shared_preferences_linux
  system_tray
)

list(APPEND FLUTTER_FFI_PLUGIN_LIST
)

set(FLUTTER_PLUGIN_BUNDLED_LIBRARIES "")

foreach(plugin ${FLUTTER_PLUGIN_LIST})
  add_subdirectory(flutter/ephemeral/.plugin_symlinks/${plugin} plugins/${plugin})
  target_link_libraries(${BINARY_NAME} PRIVATE ${plugin}_plugin)
  list(APPEND FLUTTER_PLUGIN_BUNDLED_LIBRARIES $<TARGET_FILE:${plugin}_plugin>)
endforeach(plugin)

foreach(ffi_plugin ${FLUTTER_FFI_PLUGIN_LIST})
  add_subdirectory(flutter/ephemeral/.plugin_symlinks/${ffi_plugin} plugins/${ffi_plugin})
  list(APPEND FLUTTER_PLUGIN_BUNDLED_LIBRARIES $<TARGET_FILE:${ffi_plugin}_ffi>)
endforeach(ffi_plugin)
