#include "my_application.h"
#include <desktop_multi_window/desktop_multi_window_plugin.h>
#include <flutter/generated_plugin_registrant.h>

int main(int argc, char** argv) {
  desktop_multi_window_plugin_set_window_created_callback([](FlPluginRegistry* registry) {
    fl_register_plugins(registry);
  });
  g_autoptr(MyApplication) app = my_application_new();
  return g_application_run(G_APPLICATION(app), argc, argv);
}
