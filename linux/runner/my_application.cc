#include "my_application.h"

#include <flutter_linux/flutter_linux.h>
#ifdef GDK_WINDOWING_X11
#include <gdk/gdkx.h>
#endif

#include "flutter/generated_plugin_registrant.h"

struct _MyApplication {
  GtkApplication parent_instance;
  char** dart_entrypoint_arguments;
  FlMethodChannel* channel;  // 'freekmusic/window', set once the view exists
  GPtrArray* pending_files;  // paths received while running, taken by Dart
};

G_DEFINE_TYPE(MyApplication, my_application, GTK_TYPE_APPLICATION)

// Dart asks for the paths received since the last call, or sets the title.
static void channel_cb(FlMethodChannel* channel, FlMethodCall* call,
                       gpointer user_data) {
  MyApplication* self = MY_APPLICATION(user_data);
  const gchar* name = fl_method_call_get_name(call);
  g_autoptr(FlMethodResponse) response = nullptr;
  if (g_strcmp0(name, "takeFiles") == 0) {
    g_autoptr(FlValue) list = fl_value_new_list();
    for (guint i = 0; i < self->pending_files->len; i++) {
      fl_value_append_take(
          list, fl_value_new_string(
                    (const gchar*)g_ptr_array_index(self->pending_files, i)));
    }
    g_ptr_array_set_size(self->pending_files, 0);
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(list));
  } else if (g_strcmp0(name, "setTitle") == 0) {
    FlValue* args = fl_method_call_get_args(call);
    GList* windows = gtk_application_get_windows(GTK_APPLICATION(self));
    if (windows != nullptr && args != nullptr &&
        fl_value_get_type(args) == FL_VALUE_TYPE_STRING) {
      const gchar* title = fl_value_get_string(args);
      GtkWindow* window = GTK_WINDOW(windows->data);
      GtkWidget* bar = gtk_window_get_titlebar(window);
      if (GTK_IS_HEADER_BAR(bar)) {
        gtk_header_bar_set_title(GTK_HEADER_BAR(bar), title);
      }
      gtk_window_set_title(window, title);
    }
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
  } else {
    response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  }
  fl_method_call_respond(call, response, nullptr);
}

// Called when first Flutter frame received.
static void first_frame_cb(MyApplication* self, FlView* view) {
  gtk_widget_show(gtk_widget_get_toplevel(GTK_WIDGET(view)));
}

// Implements GApplication::activate.
static void my_application_activate(GApplication* application) {
  MyApplication* self = MY_APPLICATION(application);
  // Already running (a second launch without files): bring it forward.
  GList* existing = gtk_application_get_windows(GTK_APPLICATION(application));
  if (existing != nullptr) {
    if (gtk_widget_get_visible(GTK_WIDGET(existing->data))) {
      gtk_window_present(GTK_WINDOW(existing->data));
    }
    return;
  }
  GtkWindow* window =
      GTK_WINDOW(gtk_application_window_new(GTK_APPLICATION(application)));

  // Use a header bar when running in GNOME as this is the common style used
  // by applications and is the setup most users will be using (e.g. Ubuntu
  // desktop).
  // If running on X and not using GNOME then just use a traditional title bar
  // in case the window manager does more exotic layout, e.g. tiling.
  // If running on Wayland assume the header bar will work (may need changing
  // if future cases occur).
  gboolean use_header_bar = TRUE;
#ifdef GDK_WINDOWING_X11
  GdkScreen* screen = gtk_window_get_screen(window);
  if (GDK_IS_X11_SCREEN(screen)) {
    const gchar* wm_name = gdk_x11_screen_get_window_manager_name(screen);
    if (g_strcmp0(wm_name, "GNOME Shell") != 0) {
      use_header_bar = FALSE;
    }
  }
#endif
  if (use_header_bar) {
    GtkHeaderBar* header_bar = GTK_HEADER_BAR(gtk_header_bar_new());
    gtk_widget_show(GTK_WIDGET(header_bar));
    gtk_header_bar_set_title(header_bar, "FreeKmusic");
    gtk_header_bar_set_show_close_button(header_bar, TRUE);
    gtk_window_set_titlebar(window, GTK_WIDGET(header_bar));
  } else {
    gtk_window_set_title(window, "FreeKmusic");
  gtk_window_set_icon_name(window, "freekmusic");
  }

  gtk_window_set_default_size(window, 1280, 720);

  g_autoptr(FlDartProject) project = fl_dart_project_new();
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

  // Show the window when Flutter renders.
  // Requires the view to be realized so we can start rendering.
  g_signal_connect_swapped(view, "first-frame", G_CALLBACK(first_frame_cb),
                           self);
  gtk_widget_realize(GTK_WIDGET(view));

  fl_register_plugins(FL_PLUGIN_REGISTRY(view));

  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  self->channel = fl_method_channel_new(
      fl_engine_get_binary_messenger(fl_view_get_engine(view)),
      "freekmusic/window", FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(self->channel, channel_cb, self,
                                            nullptr);

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

  if (g_application_get_is_remote(application)) {
    // Another instance owns the window: hand it the files (or just wake it)
    // and leave.
    int n = g_strv_length(self->dart_entrypoint_arguments);
    if (n > 0) {
      GFile** files = g_new0(GFile*, n);
      for (int i = 0; i < n; i++) {
        files[i] = g_file_new_for_commandline_arg(
            self->dart_entrypoint_arguments[i]);
      }
      g_application_open(application, files, n, "");
      for (int i = 0; i < n; i++) g_object_unref(files[i]);
      g_free(files);
    } else {
      g_application_activate(application);
    }
  } else {
    // The files of this launch reach Dart as the arguments of main.
    g_application_activate(application);
  }
  *exit_status = 0;

  return TRUE;
}

// Implements GApplication::open: files handed over by a second launch.
static void my_application_open(GApplication* application, GFile** files,
                                gint n_files, const gchar* hint) {
  MyApplication* self = MY_APPLICATION(application);
  for (gint i = 0; i < n_files; i++) {
    gchar* path = g_file_get_path(files[i]);
    if (path != nullptr) g_ptr_array_add(self->pending_files, path);
  }
  GList* windows = gtk_application_get_windows(GTK_APPLICATION(application));
  if (windows != nullptr && gtk_widget_get_visible(GTK_WIDGET(windows->data))) {
    gtk_window_present(GTK_WINDOW(windows->data));
  }
  if (self->channel != nullptr) {
    fl_method_channel_invoke_method(self->channel, "opened", nullptr, nullptr,
                                    nullptr, nullptr);
  }
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
  g_clear_pointer(&self->pending_files, g_ptr_array_unref);
  g_clear_object(&self->channel);
  G_OBJECT_CLASS(my_application_parent_class)->dispose(object);
}

static void my_application_class_init(MyApplicationClass* klass) {
  G_APPLICATION_CLASS(klass)->activate = my_application_activate;
  G_APPLICATION_CLASS(klass)->local_command_line =
      my_application_local_command_line;
  G_APPLICATION_CLASS(klass)->open = my_application_open;
  G_APPLICATION_CLASS(klass)->startup = my_application_startup;
  G_APPLICATION_CLASS(klass)->shutdown = my_application_shutdown;
  G_OBJECT_CLASS(klass)->dispose = my_application_dispose;
}

static void my_application_init(MyApplication* self) {
  self->pending_files = g_ptr_array_new_with_free_func(g_free);
}

MyApplication* my_application_new() {
  // Set the program name to the application ID, which helps various systems
  // like GTK and desktop environments map this running application to its
  // corresponding .desktop file. This ensures better integration by allowing
  // the application to be recognized beyond its binary name.
  g_set_prgname(APPLICATION_ID);

  // One window per user (a second launch forwards its files to the first).
  // FREEKMUSIC_NON_UNIQUE=1 opts out: tests and `flutter run` beside the
  // installed app.
  GApplicationFlags flags = G_APPLICATION_HANDLES_OPEN;
  if (g_strcmp0(g_getenv("FREEKMUSIC_NON_UNIQUE"), "1") == 0) {
    flags = (GApplicationFlags)(flags | G_APPLICATION_NON_UNIQUE);
  }
  return MY_APPLICATION(g_object_new(my_application_get_type(),
                                     "application-id", APPLICATION_ID, "flags",
                                     flags, nullptr));
}
