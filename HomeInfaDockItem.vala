using Plank;

namespace HomeInfra {

    /**
     * Overall status derived from host check results.
     */
    public enum InfraStatus {
        /** All monitored hosts are reachable. */
        ALL_OK,
        /** Some hosts are reachable, some are not. */
        PARTIAL,
        /** All monitored hosts are unreachable. */
        ALL_DOWN,
        /** Not on the home network. */
        AWAY,
        /** Initial/unknown state (no checks run yet). */
        UNKNOWN
    }

    /**
     * Main dock item that periodically checks host availability on the
     * home network and updates its icon accordingly.
     */
    public class HomeInfaDockItem : DockletItem {

        private ConfigManager config;
        private CheckerRegistry registry;
        private HomeInfaPreferences prefs;

        private uint check_timer_id = 0;
        private bool check_in_progress = false;
        private GLib.Mutex check_mutex;

        private InfraStatus current_status = InfraStatus.UNKNOWN;
        private Gee.ArrayList<CheckResult>? last_results = null;
        private bool on_home_network = false;

        public HomeInfaDockItem.with_dockitem_file (GLib.File file) {
            GLib.Object (Prefs: new HomeInfaPreferences.with_file (file));
        }

        construct {
            prefs = (HomeInfaPreferences) Prefs;
            config = new ConfigManager ();
            registry = new CheckerRegistry ();

            // Set initial icon
            update_status_icon (InfraStatus.UNKNOWN);

            // Run first check shortly after startup
            GLib.Timeout.add (1000, () => {
                run_check_async.begin ();
                return false;
            });

            // Setup recurring timer based on config interval
            setup_recurring_timer ();
        }

        ~HomeInfaDockItem () {
            if (check_timer_id != 0) {
                GLib.Source.remove (check_timer_id);
                check_timer_id = 0;
            }
        }

        /**
         * Sets up the repeating timer that triggers periodic re-checks.
         */
        private void setup_recurring_timer () {
            if (check_timer_id != 0) {
                GLib.Source.remove (check_timer_id);
            }

            check_timer_id = GLib.Timeout.add_seconds ((uint) config.recheck_interval, () => {
                run_check_async.begin ();
                return true;
            });
        }

        /**
         * Runs the full check cycle asynchronously in a background thread.
         */
        private async void run_check_async () {
            check_mutex.lock ();
            if (check_in_progress) {
                check_mutex.unlock ();
                return;
            }
            check_in_progress = true;
            check_mutex.unlock ();

            // Perform work in a thread to keep the UI responsive
            InfraStatus status = InfraStatus.UNKNOWN;
            Gee.ArrayList<CheckResult>? results = null;
            bool home = false;

            var thread_result = yield run_in_thread<CheckBundle?> (() => {
                bool is_home = NetworkUtils.is_on_subnet (config.home_subnet);

                if (!is_home) {
                    return new CheckBundle (InfraStatus.AWAY, null, is_home);
                }

                if (config.hosts.size == 0) {
                    return new CheckBundle (InfraStatus.UNKNOWN, null, is_home);
                }

                var res = registry.check_all (config.hosts);

                int ok_count = 0;
                foreach (var r in res) {
                    if (r.available) {
                        ok_count++;
                    }
                }

                InfraStatus s;
                if (ok_count == res.size) {
                    s = InfraStatus.ALL_OK;
                } else if (ok_count == 0) {
                    s = InfraStatus.ALL_DOWN;
                } else {
                    s = InfraStatus.PARTIAL;
                }

                return new CheckBundle (s, res, is_home);
            });

            if (thread_result != null) {
                status = thread_result.status;
                results = thread_result.results;
                home = thread_result.on_home;
            }

            // Update state on the main thread (we're already back here)
            current_status = status;
            last_results = results;
            on_home_network = home;

            update_status_icon (status);
            update_tooltip ();

            check_mutex.lock ();
            check_in_progress = false;
            check_mutex.unlock ();
        }

        /**
         * Helper to run a function in a background thread and return the result.
         */
        private async T run_in_thread<T> (owned GLib.ThreadFunc<T> func) {
            T result = null;

            new GLib.Thread<void*> ("home-infra-check", () => {
                result = func ();
                GLib.Idle.add (run_in_thread.callback);
                return null;
            });

            yield;
            return result;
        }

        /**
         * Updates the dock icon based on the current infrastructure status.
         */
        private void update_status_icon (InfraStatus status) {
            string icon_name;

            switch (status) {
                case InfraStatus.ALL_OK:
                    icon_name = "status-ok.svg";
                    break;
                case InfraStatus.PARTIAL:
                    icon_name = "status-warning.svg";
                    break;
                case InfraStatus.ALL_DOWN:
                    icon_name = "status-error.svg";
                    break;
                case InfraStatus.AWAY:
                    icon_name = "status-away.svg";
                    break;
                default:
                    icon_name = "docklet-icon.svg";
                    break;
            }

            Icon = "resource://" + HomeInfra.G_RESOURCE_PATH + "/icons/" + icon_name;
        }

        /**
         * Updates the tooltip text with a summary of the last check.
         */
        private void update_tooltip () {
            if (!on_home_network) {
                Text = _("Not on home network (%s)").printf (config.home_subnet);
                return;
            }

            if (last_results == null || last_results.size == 0) {
                Text = _("No hosts configured");
                return;
            }

            int ok = 0;
            int total = last_results.size;
            var sb = new GLib.StringBuilder ();

            foreach (var r in last_results) {
                if (r.available) {
                    ok++;
                }
            }

            sb.append (_("%d/%d hosts available").printf (ok, total));

            foreach (var r in last_results) {
                string mark = r.available ? "✓" : "✗";
                sb.append ("\n  %s %s (%s)".printf (mark, r.host, r.detail));
            }

            Text = sb.str;
        }

        /**
         * Reloads the config from disk and immediately re-checks.
         */
        private void reload_and_recheck () {
            config.load ();
            setup_recurring_timer ();
            run_check_async.begin ();
        }

        /**
         * Opens the YAML config file in the default text editor.
         */
        private void open_config_in_editor () {
            string config_path = config.get_config_path ();

            try {
                var file = GLib.File.new_for_path (config_path);
                var app_info = file.query_default_handler (null);
                var files = new GLib.List<GLib.File> ();
                files.append (file);
                app_info.launch (files, null);
            } catch (Error e) {
                // Fallback: try xdg-open
                try {
                    Process.spawn_command_line_async ("xdg-open " + config_path);
                } catch (Error e2) {
                    warning ("Failed to open config: %s", e2.message);
                }
            }
        }

        /**
         * Builds the right-click context menu items.
         */
        public override Gee.ArrayList<Gtk.MenuItem> get_menu_items () {
            var items = new Gee.ArrayList<Gtk.MenuItem> ();

            // Status header (non-clickable)
            string header_text;
            switch (current_status) {
                case InfraStatus.ALL_OK:
                    header_text = _("Status: All hosts OK");
                    break;
                case InfraStatus.PARTIAL:
                    header_text = _("Status: Some hosts down");
                    break;
                case InfraStatus.ALL_DOWN:
                    header_text = _("Status: All hosts down");
                    break;
                case InfraStatus.AWAY:
                    header_text = _("Status: Away from home network");
                    break;
                default:
                    header_text = _("Status: Unknown");
                    break;
            }

            var header_item = new Gtk.MenuItem.with_label (header_text);
            header_item.set_sensitive (false);
            items.add (header_item);

            // Show individual host results if available
            if (last_results != null && last_results.size > 0) {
                foreach (var r in last_results) {
                    string mark = r.available ? "  ✓ " : "  ✗ ";
                    string label = mark + r.host;
                    if (r.method.length > 0) {
                        label += " [" + r.method + "]";
                    }
                    var host_item = new Gtk.MenuItem.with_label (label);
                    host_item.set_sensitive (false);
                    items.add (host_item);
                }
            }

            var sep1 = new Gtk.SeparatorMenuItem ();
            items.add (sep1);

            // Re-check
            var recheck_item = new Gtk.MenuItem.with_label (_("Re-check"));
            recheck_item.activate.connect (() => {
                reload_and_recheck ();
            });
            items.add (recheck_item);

            // Open config in text editor
            var config_item = new Gtk.MenuItem.with_label (_("Open config in text editor"));
            config_item.activate.connect (() => {
                open_config_in_editor ();
            });
            items.add (config_item);

            return items;
        }
    }

    /**
     * Internal data bundle to pass results from the background thread.
     */
    private class CheckBundle : Object {
        public InfraStatus status;
        public Gee.ArrayList<CheckResult>? results;
        public bool on_home;

        public CheckBundle (InfraStatus status, Gee.ArrayList<CheckResult>? results, bool on_home) {
            this.status = status;
            this.results = results;
            this.on_home = on_home;
        }
    }
}
