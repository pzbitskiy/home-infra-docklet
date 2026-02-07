/**
 * Unit tests for the HomeInfra YAML configuration parser.
 *
 * Run with: meson test -C build
 */

namespace HomeInfra.Tests {

    /**
     * Helper: writes content to a temporary file and returns a ConfigManager
     * loaded from that file.
     */
    private ConfigManager config_from_yaml (string yaml) {
        string path;
        try {
            int fd = GLib.FileUtils.open_tmp ("home-infra-test-XXXXXX.yaml", out path);
            Posix.close (fd);
            GLib.FileUtils.set_contents (path, yaml);
        } catch (Error e) {
            GLib.Test.message ("Failed to write temp file: %s", e.message);
            assert_not_reached ();
        }

        var cfg = new ConfigManager.with_path (path);
        GLib.FileUtils.unlink (path);
        return cfg;
    }

    // ---------------------------------------------------------------
    //  Default / sample config
    // ---------------------------------------------------------------

    private void test_default_config () {
        var yaml = """home_subnet: "192.168.1.0/24"
recheck_interval: 60
hosts:
  - host: "192.168.1.1"
    method: "icmp"
  - host: "192.168.1.2"
    method: "icmp"
""";
        var cfg = config_from_yaml (yaml);

        assert_cmpstr (cfg.home_subnet, GLib.CompareOperator.EQ, "192.168.1.0/24");
        assert_cmpint (cfg.recheck_interval, GLib.CompareOperator.EQ, 60);
        assert_cmpint (cfg.hosts.size, GLib.CompareOperator.EQ, 2);

        assert_cmpstr (cfg.hosts[0].host, GLib.CompareOperator.EQ, "192.168.1.1");
        assert_cmpstr (cfg.hosts[0].method, GLib.CompareOperator.EQ, "icmp");
        assert_cmpint (cfg.hosts[0].port, GLib.CompareOperator.EQ, 0);

        assert_cmpstr (cfg.hosts[1].host, GLib.CompareOperator.EQ, "192.168.1.2");
        assert_cmpstr (cfg.hosts[1].method, GLib.CompareOperator.EQ, "icmp");
    }

    // ---------------------------------------------------------------
    //  Quoting styles
    // ---------------------------------------------------------------

    private void test_single_quoted_values () {
        var yaml = """home_subnet: '10.0.0.0/8'
recheck_interval: 30
hosts:
  - host: '10.0.0.1'
    method: 'icmp'
""";
        var cfg = config_from_yaml (yaml);

        assert_cmpstr (cfg.home_subnet, GLib.CompareOperator.EQ, "10.0.0.0/8");
        assert_cmpstr (cfg.hosts[0].host, GLib.CompareOperator.EQ, "10.0.0.1");
    }

    private void test_unquoted_values () {
        var yaml = """home_subnet: 172.16.0.0/12
recheck_interval: 45
hosts:
  - host: 172.16.0.1
    method: icmp
""";
        var cfg = config_from_yaml (yaml);

        assert_cmpstr (cfg.home_subnet, GLib.CompareOperator.EQ, "172.16.0.0/12");
        assert_cmpint (cfg.recheck_interval, GLib.CompareOperator.EQ, 45);
        assert_cmpstr (cfg.hosts[0].host, GLib.CompareOperator.EQ, "172.16.0.1");
        assert_cmpstr (cfg.hosts[0].method, GLib.CompareOperator.EQ, "icmp");
    }

    // ---------------------------------------------------------------
    //  TCP method with port
    // ---------------------------------------------------------------

    private void test_tcp_method_port_parsing () {
        var yaml = """home_subnet: "192.168.1.0/24"
recheck_interval: 60
hosts:
  - host: "192.168.1.10"
    method: "tcp:22"
  - host: "192.168.1.20"
    method: "tcp:80"
  - host: "192.168.1.30"
    method: "tcp:443"
""";
        var cfg = config_from_yaml (yaml);

        assert_cmpint (cfg.hosts.size, GLib.CompareOperator.EQ, 3);

        assert_cmpstr (cfg.hosts[0].method, GLib.CompareOperator.EQ, "tcp");
        assert_cmpint (cfg.hosts[0].port, GLib.CompareOperator.EQ, 22);

        assert_cmpstr (cfg.hosts[1].method, GLib.CompareOperator.EQ, "tcp");
        assert_cmpint (cfg.hosts[1].port, GLib.CompareOperator.EQ, 80);

        assert_cmpstr (cfg.hosts[2].method, GLib.CompareOperator.EQ, "tcp");
        assert_cmpint (cfg.hosts[2].port, GLib.CompareOperator.EQ, 443);
    }

    // ---------------------------------------------------------------
    //  Mixed methods
    // ---------------------------------------------------------------

    private void test_mixed_icmp_and_tcp () {
        var yaml = """home_subnet: "10.0.0.0/8"
recheck_interval: 120
hosts:
  - host: "10.0.0.1"
    method: "icmp"
  - host: "10.0.0.5"
    method: "tcp:22"
  - host: "10.0.0.10"
    method: "icmp"
  - host: "10.0.0.20"
    method: "tcp:8080"
""";
        var cfg = config_from_yaml (yaml);

        assert_cmpint (cfg.hosts.size, GLib.CompareOperator.EQ, 4);

        assert_cmpstr (cfg.hosts[0].method, GLib.CompareOperator.EQ, "icmp");
        assert_cmpint (cfg.hosts[0].port, GLib.CompareOperator.EQ, 0);

        assert_cmpstr (cfg.hosts[1].method, GLib.CompareOperator.EQ, "tcp");
        assert_cmpint (cfg.hosts[1].port, GLib.CompareOperator.EQ, 22);

        assert_cmpstr (cfg.hosts[2].method, GLib.CompareOperator.EQ, "icmp");

        assert_cmpstr (cfg.hosts[3].host, GLib.CompareOperator.EQ, "10.0.0.20");
        assert_cmpstr (cfg.hosts[3].method, GLib.CompareOperator.EQ, "tcp");
        assert_cmpint (cfg.hosts[3].port, GLib.CompareOperator.EQ, 8080);
    }

    // ---------------------------------------------------------------
    //  Comments and blank lines
    // ---------------------------------------------------------------

    private void test_comments_and_blanks () {
        var yaml = """# Full-line comment
home_subnet: "192.168.50.0/24"

# Another comment
recheck_interval: 90

# Hosts section
hosts:
  # The router
  - host: "192.168.50.1"
    method: "icmp"

  # NAS box
  - host: "192.168.50.100"
    method: "tcp:445"
""";
        var cfg = config_from_yaml (yaml);

        assert_cmpstr (cfg.home_subnet, GLib.CompareOperator.EQ, "192.168.50.0/24");
        assert_cmpint (cfg.recheck_interval, GLib.CompareOperator.EQ, 90);
        assert_cmpint (cfg.hosts.size, GLib.CompareOperator.EQ, 2);

        assert_cmpstr (cfg.hosts[0].host, GLib.CompareOperator.EQ, "192.168.50.1");
        assert_cmpstr (cfg.hosts[1].host, GLib.CompareOperator.EQ, "192.168.50.100");
        assert_cmpint (cfg.hosts[1].port, GLib.CompareOperator.EQ, 445);
    }

    // ---------------------------------------------------------------
    //  Minimum recheck interval clamped to 5
    // ---------------------------------------------------------------

    private void test_minimum_recheck_interval () {
        var yaml = """home_subnet: "192.168.1.0/24"
recheck_interval: 1
hosts:
  - host: "192.168.1.1"
    method: "icmp"
""";
        var cfg = config_from_yaml (yaml);

        assert_cmpint (cfg.recheck_interval, GLib.CompareOperator.GE, 5);
    }

    private void test_zero_recheck_interval () {
        var yaml = """home_subnet: "192.168.1.0/24"
recheck_interval: 0
hosts:
  - host: "192.168.1.1"
    method: "icmp"
""";
        var cfg = config_from_yaml (yaml);

        assert_cmpint (cfg.recheck_interval, GLib.CompareOperator.EQ, 5);
    }

    // ---------------------------------------------------------------
    //  Empty hosts list
    // ---------------------------------------------------------------

    private void test_empty_hosts () {
        var yaml = """home_subnet: "192.168.1.0/24"
recheck_interval: 60
hosts:
""";
        var cfg = config_from_yaml (yaml);

        assert_cmpint (cfg.hosts.size, GLib.CompareOperator.EQ, 0);
    }

    // ---------------------------------------------------------------
    //  No hosts key at all
    // ---------------------------------------------------------------

    private void test_no_hosts_key () {
        var yaml = """home_subnet: "192.168.1.0/24"
recheck_interval: 30
""";
        var cfg = config_from_yaml (yaml);

        assert_cmpstr (cfg.home_subnet, GLib.CompareOperator.EQ, "192.168.1.0/24");
        assert_cmpint (cfg.recheck_interval, GLib.CompareOperator.EQ, 30);
        assert_cmpint (cfg.hosts.size, GLib.CompareOperator.EQ, 0);
    }

    // ---------------------------------------------------------------
    //  Single host
    // ---------------------------------------------------------------

    private void test_single_host () {
        var yaml = """home_subnet: "192.168.1.0/24"
recheck_interval: 60
hosts:
  - host: "192.168.1.1"
    method: "icmp"
""";
        var cfg = config_from_yaml (yaml);

        assert_cmpint (cfg.hosts.size, GLib.CompareOperator.EQ, 1);
        assert_cmpstr (cfg.hosts[0].host, GLib.CompareOperator.EQ, "192.168.1.1");
    }

    // ---------------------------------------------------------------
    //  Method defaults to icmp when omitted
    // ---------------------------------------------------------------

    private void test_method_defaults_to_icmp () {
        var yaml = """home_subnet: "192.168.1.0/24"
recheck_interval: 60
hosts:
  - host: "192.168.1.1"
  - host: "192.168.1.2"
""";
        var cfg = config_from_yaml (yaml);

        assert_cmpint (cfg.hosts.size, GLib.CompareOperator.EQ, 2);
        assert_cmpstr (cfg.hosts[0].method, GLib.CompareOperator.EQ, "icmp");
        assert_cmpstr (cfg.hosts[1].method, GLib.CompareOperator.EQ, "icmp");
    }

    // ---------------------------------------------------------------
    //  Reload clears previous state
    // ---------------------------------------------------------------

    private void test_reload_replaces_state () {
        var yaml1 = """home_subnet: "192.168.1.0/24"
recheck_interval: 60
hosts:
  - host: "192.168.1.1"
    method: "icmp"
  - host: "192.168.1.2"
    method: "icmp"
  - host: "192.168.1.3"
    method: "icmp"
""";
        var yaml2 = """home_subnet: "10.0.0.0/8"
recheck_interval: 15
hosts:
  - host: "10.0.0.1"
    method: "tcp:80"
""";
        string path;
        try {
            int fd = GLib.FileUtils.open_tmp ("home-infra-test-XXXXXX.yaml", out path);
            Posix.close (fd);
            GLib.FileUtils.set_contents (path, yaml1);
        } catch (Error e) {
            assert_not_reached ();
        }

        var cfg = new ConfigManager.with_path (path);
        assert_cmpint (cfg.hosts.size, GLib.CompareOperator.EQ, 3);
        assert_cmpstr (cfg.home_subnet, GLib.CompareOperator.EQ, "192.168.1.0/24");

        // Overwrite config and reload
        try {
            GLib.FileUtils.set_contents (path, yaml2);
        } catch (Error e) {
            assert_not_reached ();
        }

        cfg.load ();

        assert_cmpstr (cfg.home_subnet, GLib.CompareOperator.EQ, "10.0.0.0/8");
        assert_cmpint (cfg.recheck_interval, GLib.CompareOperator.EQ, 15);
        assert_cmpint (cfg.hosts.size, GLib.CompareOperator.EQ, 1);
        assert_cmpstr (cfg.hosts[0].host, GLib.CompareOperator.EQ, "10.0.0.1");
        assert_cmpstr (cfg.hosts[0].method, GLib.CompareOperator.EQ, "tcp");
        assert_cmpint (cfg.hosts[0].port, GLib.CompareOperator.EQ, 80);

        GLib.FileUtils.unlink (path);
    }

    // ---------------------------------------------------------------
    //  Many hosts
    // ---------------------------------------------------------------

    private void test_many_hosts () {
        var sb = new GLib.StringBuilder ();
        sb.append ("home_subnet: \"192.168.1.0/24\"\n");
        sb.append ("recheck_interval: 60\n");
        sb.append ("hosts:\n");
        for (int i = 1; i <= 50; i++) {
            sb.append ("  - host: \"192.168.1.%d\"\n".printf (i));
            sb.append ("    method: \"icmp\"\n");
        }

        var cfg = config_from_yaml (sb.str);

        assert_cmpint (cfg.hosts.size, GLib.CompareOperator.EQ, 50);
        assert_cmpstr (cfg.hosts[0].host, GLib.CompareOperator.EQ, "192.168.1.1");
        assert_cmpstr (cfg.hosts[49].host, GLib.CompareOperator.EQ, "192.168.1.50");
    }

    // ---------------------------------------------------------------
    //  Nonexistent file produces empty/default state
    // ---------------------------------------------------------------

    private void test_nonexistent_file () {
        var cfg = new ConfigManager.with_path ("/tmp/home-infra-nonexistent-abc123.yaml");

        // Should fall back to defaults
        assert_cmpstr (cfg.home_subnet, GLib.CompareOperator.EQ, "192.168.1.0/24");
        assert_cmpint (cfg.recheck_interval, GLib.CompareOperator.EQ, 60);
        assert_cmpint (cfg.hosts.size, GLib.CompareOperator.EQ, 0);
    }

    // ---------------------------------------------------------------
    //  Entry point
    // ---------------------------------------------------------------

    public static int main (string[] args) {
        GLib.Test.init (ref args);

        GLib.Test.add_func ("/config-parser/default-config", test_default_config);
        GLib.Test.add_func ("/config-parser/single-quoted-values", test_single_quoted_values);
        GLib.Test.add_func ("/config-parser/unquoted-values", test_unquoted_values);
        GLib.Test.add_func ("/config-parser/tcp-method-port", test_tcp_method_port_parsing);
        GLib.Test.add_func ("/config-parser/mixed-icmp-tcp", test_mixed_icmp_and_tcp);
        GLib.Test.add_func ("/config-parser/comments-and-blanks", test_comments_and_blanks);
        GLib.Test.add_func ("/config-parser/min-recheck-interval", test_minimum_recheck_interval);
        GLib.Test.add_func ("/config-parser/zero-recheck-interval", test_zero_recheck_interval);
        GLib.Test.add_func ("/config-parser/empty-hosts", test_empty_hosts);
        GLib.Test.add_func ("/config-parser/no-hosts-key", test_no_hosts_key);
        GLib.Test.add_func ("/config-parser/single-host", test_single_host);
        GLib.Test.add_func ("/config-parser/method-defaults-to-icmp", test_method_defaults_to_icmp);
        GLib.Test.add_func ("/config-parser/reload-replaces-state", test_reload_replaces_state);
        GLib.Test.add_func ("/config-parser/many-hosts", test_many_hosts);
        GLib.Test.add_func ("/config-parser/nonexistent-file", test_nonexistent_file);

        return GLib.Test.run ();
    }
}
