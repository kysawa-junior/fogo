#include "my_application.h"

#include <flutter_linux/flutter_linux.h>

#include "desktop_multi_window/desktop_multi_window_plugin.h"
#include "flutter/generated_plugin_registrant.h"

struct _MyApplication {
  GtkApplication parent_instance;
  char** dart_entrypoint_arguments;
};

G_DEFINE_TYPE(MyApplication, my_application, GTK_TYPE_APPLICATION)

// Implements GApplication::activate.
static void my_application_activate(GApplication* application) {
  MyApplication* self = MY_APPLICATION(application);
  GtkWindow* window =
      GTK_WINDOW(gtk_application_window_new(GTK_APPLICATION(application)));

  // Sem header bar GTK: a titlebar é a do próprio app (window_manager,
  // TitleBarStyle.hidden). O GtkHeaderBar do template mantinha o frame
  // CSD — cantos arredondados e sombra ao redor da janela — mesmo após
  // o window_manager ocultá-lo. Sem titlebar, o window_manager chama
  // gtk_window_set_decorated(false) e a janela fica sem o sombreado.
  gtk_window_set_title(window, "F.O.G.O.");
  gtk_window_set_decorated(window, FALSE);

  // Tamanho FINAL no nascimento, limitado à workarea (GTK unidades
  // lógicas): a superfície EGL nasce uma única vez com o tamanho
  // definitivo. Resize pós-criação wedgea o pipeline Impeller/Wayland —
  // evidência (stderr do embedder):
  //   "Timed out waiting for OpenGL frame of size 1440x900 (have 1x1)"
  //   Gdk-CRITICAL: gdk_wayland_window_configure: assertion 'width > 0'
  // (janela nascia 1×1, crescia no reveal — buffer nunca acoplava).
  // Workarea-clamped: 900 de altura em monitor 1080@125% = 864 lógicos —
  // o clamp do compositor é outro resize proibido.
  GdkMonitor* monitor =
      gdk_display_get_primary_monitor(gdk_display_get_default());
  GdkRectangle workarea = {0, 0, 1440, 864};
  if (monitor) {
    gdk_monitor_get_workarea(monitor, &workarea);
  }
  gtk_window_set_default_size(window, MIN(1440, workarea.width),
                              MIN(900, workarea.height));

  g_autoptr(FlDartProject) project = fl_dart_project_new();
  // F.O.G.O. 3D Engine (Flutter Scene) exige Flutter GPU habilitado.
  fl_dart_project_set_enable_flutter_gpu(project, TRUE);
  fl_dart_project_set_dart_entrypoint_arguments(
      project, self->dart_entrypoint_arguments);

  FlView* view = fl_view_new(project);
  GdkRGBA background_color;
  // Background defaults to black, override it here if necessary, e.g. #00000000
  // for transparent.
  gdk_rgba_parse(&background_color, "#000000");
  fl_view_set_background_color(view, &background_color);
  gtk_widget_show(GTK_WIDGET(view));
  gtk_container_add(GTK_CONTAINER(window), GTK_WIDGET(view));

  // Plugins ANTES do realize: o engine nasce no realize e o main() do
  // Dart já precisa de window_manager/desktop_multi_window registrados.
  fl_register_plugins(FL_PLUGIN_REGISTRY(view));

  // Janelas criadas pelo desktop_multi_window (a Splash 800x500) nascem
  // SEM plugins do app: este callback registra window_manager (e o
  // resto) em cada engine novo — sem ele a Splash não consegue se
  // dimensionar/decorar.
  desktop_multi_window_plugin_set_window_created_callback(
      [](FlPluginRegistry* registry) {
        fl_register_plugins(registry);

        // Splash 800x500 SEM borda: o plugin cria toda janela nova com
        // 1280x720 e (no GNOME) com header bar. O GTK aplica o default
        // size no primeiro mapeamento (need_default_size), por isso o
        // resize via window_manager é sobrescrito — o tamanho precisa
        // ser corrigido AQUI, antes do mapeamento.
        g_autoptr(FlPluginRegistrar) registrar =
            fl_plugin_registry_get_registrar_for_plugin(registry,
                                                        "WindowManagerPlugin");
        if (registrar == nullptr) return;
        FlView* splash_view = fl_plugin_registrar_get_view(registrar);
        if (splash_view == nullptr) return;
        GtkWidget* toplevel = gtk_widget_get_toplevel(GTK_WIDGET(splash_view));
        if (!GTK_IS_WINDOW(toplevel)) return;
        GtkWindow* splash_window = GTK_WINDOW(toplevel);
        // Header bar do plugin: ESCONDIDO, não removido —
        // gtk_window_set_titlebar() em janela já realizada unrealiza a
        // janela (GTK3) e derruba o GdkWindow: o window_manager depois
        // chama gdk_window_set_geometry_hints(NULL) → segfault.
        GtkWidget* titlebar = gtk_window_get_titlebar(splash_window);
        if (titlebar != nullptr) gtk_widget_set_visible(titlebar, FALSE);
        gtk_window_set_decorated(splash_window, FALSE);
        gtk_window_set_default_size(splash_window, 800, 500);
      });

  // JANELA DEFINITIVA NASCE OCULTA (startup multi-window): a Splash
  // 800x500 é exibida primeiro e esta janela só é mapeada pelo Dart
  // (windowManager.show) quando o mapa já está carregado. O tamanho
  // final é definido ANTES do realize — a superfície nasce no tamanho
  // definitivo (resize pós-criação wedgea o pipeline Impeller).
  // O realize explícito da view é o que inicia o engine (fl_engine_start
  // no realize do renderer) — realize da janela sozinho não basta.
  gtk_widget_realize(GTK_WIDGET(window));
  gtk_widget_realize(GTK_WIDGET(view));

  gtk_widget_grab_focus(GTK_WIDGET(view));
}

// Implements GApplication::local_command_line.
static gboolean my_application_local_command_line(GApplication* application,
                                                  gchar*** arguments,
                                                  int* exit_status) {
  MyApplication* self = MY_APPLICATION(application);
  // Strip out the first argument as it is the binary name.
  self->dart_entrypoint_arguments = g_strdupv(*arguments + 1);

  g_autoptr(GError) error = nullptr;
  if (!g_application_register(application, nullptr, &error)) {
    g_warning("Failed to register: %s", error->message);
    *exit_status = 1;
    return TRUE;
  }

  g_application_activate(application);
  *exit_status = 0;

  return TRUE;
}

// Implements GApplication::startup.
static void my_application_startup(GApplication* application) {
  // MyApplication* self = MY_APPLICATION(object);

  // Perform any actions required at application startup.

  G_APPLICATION_CLASS(my_application_parent_class)->startup(application);
}

// Implements GApplication::shutdown.
static void my_application_shutdown(GApplication* application) {
  // MyApplication* self = MY_APPLICATION(object);

  // Perform any actions required at application shutdown.

  G_APPLICATION_CLASS(my_application_parent_class)->shutdown(application);
}

// Implements GObject::dispose.
static void my_application_dispose(GObject* object) {
  MyApplication* self = MY_APPLICATION(object);
  g_clear_pointer(&self->dart_entrypoint_arguments, g_strfreev);
  G_OBJECT_CLASS(my_application_parent_class)->dispose(object);
}

static void my_application_class_init(MyApplicationClass* klass) {
  G_APPLICATION_CLASS(klass)->activate = my_application_activate;
  G_APPLICATION_CLASS(klass)->local_command_line =
      my_application_local_command_line;
  G_APPLICATION_CLASS(klass)->startup = my_application_startup;
  G_APPLICATION_CLASS(klass)->shutdown = my_application_shutdown;
  G_OBJECT_CLASS(klass)->dispose = my_application_dispose;
}

static void my_application_init(MyApplication* self) {}

MyApplication* my_application_new() {
  // Set the program name to the application ID, which helps various
  // systems like GTK and desktop environments map this running
  // application to its corresponding .desktop file. This ensures better
  // integration by allowing the application to be recognized beyond its
  // binary name.
  g_set_prgname(APPLICATION_ID);

  return MY_APPLICATION(g_object_new(my_application_get_type(),
                                     "application-id", APPLICATION_ID, "flags",
                                     G_APPLICATION_NON_UNIQUE, nullptr));
}
