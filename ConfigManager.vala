namespace HomeInfra {

    /**
     * Represents a single monitored host entry from configuration.
     */
    public class MonitoredHost : Object {
        public string host { get; set; default = ""; }
        public string method { get; set; default = "icmp"; }
        public uint16 port { get; set; default = 0; }

        public MonitoredHost (string host, string method, uint16 port = 0) {
            this.host = host;
            this.method = method;
            this.port = port;
        }
    }

    /**
     * Manages loading, saving, and creating default YAML configuration
     * stored at ~/.config/plank/home-infa-docklet.yaml
     */
    public class ConfigManager : Object {
        private const string CONFIG_DIR = "plank";
        private const string CONFIG_FILE = "home-infa-docklet.yaml";

        public string home_subnet { get; set; default = "192.168.1.0/24"; }
        public int recheck_interval { get; set; default = 60; }
        public Gee.ArrayList<MonitoredHost> hosts { get; set; }

        private string config_path;

        public ConfigManager () {
            hosts = new Gee.ArrayList<MonitoredHost> ();
            config_path = GLib.Path.build_filename (
                GLib.Environment.get_user_config_dir (),
                CONFIG_DIR,
                CONFIG_FILE
            );

            if (!GLib.FileUtils.test (config_path, GLib.FileTest.EXISTS)) {
                create_default_config ();
            }

            load ();
        }

        /**
         * Creates a ConfigManager that reads from the given path.
         * Does not auto-create a default config. Intended for testing.
         */
        public ConfigManager.with_path (string path) {
            hosts = new Gee.ArrayList<MonitoredHost> ();
            config_path = path;

            if (GLib.FileUtils.test (config_path, GLib.FileTest.EXISTS)) {
                load ();
            }
        }

        /**
         * Returns the full path to the configuration file.
         */
        public string get_config_path () {
            return config_path;
        }

        /**
         * Creates the default sample configuration file.
         */
        private void create_default_config () {
            var dir_path = GLib.Path.get_dirname (config_path);
            DirUtils.create_with_parents (dir_path, 0755);

            var contents = """# Home Infrastructure Monitor Docklet Configuration
#
# home_subnet: your local network CIDR. The docklet only runs checks
#              when the machine has an IP address within this subnet.
# recheck_interval: seconds between automatic re-checks.
# hosts: list of hosts to monitor.
#   - host: IP address or hostname
#     method: "icmp" (ping) or "tcp:<port>" (TCP connection check)

home_subnet: "192.168.1.0/24"
recheck_interval: 60
hosts:
  - host: "192.168.1.1"
    method: "icmp"
  - host: "192.168.1.2"
    method: "icmp"
""";
            try {
                GLib.FileUtils.set_contents (config_path, contents);
            } catch (Error e) {
                warning ("Failed to create default config: %s", e.message);
            }
        }

        /**
         * Loads configuration from the YAML file.
         * Parses a simple subset of YAML sufficient for this config structure.
         */
        public void load () {
            hosts.clear ();

            string contents;
            try {
                GLib.FileUtils.get_contents (config_path, out contents);
            } catch (Error e) {
                warning ("Failed to read config: %s", e.message);
                return;
            }

            bool in_hosts = false;
            string? pending_host = null;
            string? pending_method = null;

            foreach (unowned string raw_line in contents.split ("\n")) {
                string line = raw_line.strip ();

                // Skip comments and empty lines
                if (line.length == 0 || line.has_prefix ("#")) {
                    continue;
                }

                // Top-level key: value
                if (!line.has_prefix ("-") && !line.has_prefix ("host:") && !line.has_prefix ("method:")) {
                    if (line.has_prefix ("home_subnet:")) {
                        home_subnet = parse_yaml_string_value (line, "home_subnet:");
                        in_hosts = false;
                    } else if (line.has_prefix ("recheck_interval:")) {
                        var val = parse_yaml_string_value (line, "recheck_interval:");
                        recheck_interval = int.parse (val);
                        if (recheck_interval < 5) {
                            recheck_interval = 5;
                        }
                        in_hosts = false;
                    } else if (line.has_prefix ("hosts:")) {
                        in_hosts = true;
                    }
                    continue;
                }

                if (!in_hosts) {
                    continue;
                }

                // List item start "- host: ..."
                if (line.has_prefix ("- host:") || line.has_prefix ("-host:")) {
                    // Flush previous entry
                    flush_pending_host (ref pending_host, ref pending_method);
                    pending_host = parse_yaml_string_value (line.substring (line.index_of ("host:")), "host:");
                    pending_method = "icmp";
                } else if (line.has_prefix ("- method:") || line.has_prefix ("-method:")) {
                    pending_method = parse_yaml_string_value (line.substring (line.index_of ("method:")), "method:");
                } else if (line.has_prefix ("host:")) {
                    // Flush previous entry
                    flush_pending_host (ref pending_host, ref pending_method);
                    pending_host = parse_yaml_string_value (line, "host:");
                    pending_method = "icmp";
                } else if (line.has_prefix ("method:")) {
                    pending_method = parse_yaml_string_value (line, "method:");
                }
            }

            // Flush last entry
            flush_pending_host (ref pending_host, ref pending_method);

            message ("Config loaded: subnet=%s, interval=%d, hosts=%d",
                     home_subnet, recheck_interval, hosts.size);
        }

        /**
         * Adds a pending host/method pair to the hosts list and resets the refs.
         */
        private void flush_pending_host (ref string? host, ref string? method) {
            if (host != null && host.length > 0) {
                string m = (method != null && method.length > 0) ? method : "icmp";
                uint16 port = 0;

                if (m.has_prefix ("tcp:")) {
                    port = (uint16) int.parse (m.substring (4));
                    m = "tcp";
                }

                hosts.add (new MonitoredHost (host, m, port));
            }

            host = null;
            method = null;
        }

        /**
         * Parses a simple YAML "key: value" extracting the value part.
         * Handles optional quoting with single or double quotes.
         */
        private string parse_yaml_string_value (string line, string key) {
            var after = line.substring (key.length).strip ();
            // Remove surrounding quotes if present
            if ((after.has_prefix ("\"") && after.has_suffix ("\"")) ||
                (after.has_prefix ("'") && after.has_suffix ("'"))) {
                after = after.substring (1, after.length - 2);
            }
            return after;
        }
    }
}
