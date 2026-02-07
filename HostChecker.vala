namespace HomeInfra {

    /**
     * Result of a single host check.
     */
    public class CheckResult : Object {
        public string host { get; set; }
        public string method { get; set; }
        public bool available { get; set; }
        public string detail { get; set; default = ""; }

        public CheckResult (string host, string method, bool available, string detail = "") {
            this.host = host;
            this.method = method;
            this.available = available;
            this.detail = detail;
        }
    }

    /**
     * Abstract base class for host availability checkers.
     * Extend this to add new check methods (HTTP, DNS, etc.).
     */
    public abstract class BaseChecker : Object {
        /**
         * The method identifier this checker handles (e.g. "icmp", "tcp").
         */
        public abstract string method_id { get; }

        /**
         * Performs a synchronous availability check for the given host.
         * This runs in a thread to avoid blocking the UI.
         */
        public abstract CheckResult check (MonitoredHost entry);
    }

    /**
     * ICMP ping checker. Shells out to the system `ping` command.
     */
    public class IcmpChecker : BaseChecker {
        public override string method_id { get { return "icmp"; } }

        public override CheckResult check (MonitoredHost entry) {
            try {
                string[] cmd = {
                    "ping", "-c", "1", "-W", "3", entry.host
                };
                int exit_code;
                Process.spawn_sync (
                    null, cmd, null,
                    SpawnFlags.SEARCH_PATH | SpawnFlags.STDOUT_TO_DEV_NULL | SpawnFlags.STDERR_TO_DEV_NULL,
                    null, null, null, out exit_code
                );
                bool ok = (exit_code == 0);
                return new CheckResult (
                    entry.host, "icmp", ok,
                    ok ? "ping ok" : "ping failed (exit %d)".printf (exit_code)
                );
            } catch (Error e) {
                return new CheckResult (entry.host, "icmp", false, "error: " + e.message);
            }
        }
    }

    /**
     * TCP port checker. Attempts to connect to host:port with a short timeout.
     */
    public class TcpChecker : BaseChecker {
        public override string method_id { get { return "tcp"; } }

        public override CheckResult check (MonitoredHost entry) {
            if (entry.port == 0) {
                return new CheckResult (entry.host, "tcp", false, "no port specified");
            }

            try {
                var resolver = GLib.Resolver.get_default ();
                var addresses = resolver.lookup_by_name (entry.host, null);

                if (addresses.length () == 0) {
                    return new CheckResult (entry.host, "tcp", false, "DNS resolution failed");
                }

                var address = addresses.nth_data (0);
                var sock_addr = new GLib.InetSocketAddress (address, entry.port);
                var client = new GLib.SocketClient ();
                client.set_timeout (5);

                var conn = client.connect (sock_addr, null);
                conn.close (null);

                return new CheckResult (
                    entry.host, "tcp:%u".printf (entry.port), true,
                    "tcp connect ok"
                );
            } catch (Error e) {
                return new CheckResult (
                    entry.host, "tcp:%u".printf (entry.port), false,
                    "tcp failed: " + e.message
                );
            }
        }
    }

    /**
     * Registry that maps method identifiers to checker instances.
     * New checkers can be registered at runtime.
     */
    public class CheckerRegistry : Object {
        private Gee.HashMap<string, BaseChecker> checkers;

        public CheckerRegistry () {
            checkers = new Gee.HashMap<string, BaseChecker> ();

            // Register built-in checkers
            register_checker (new IcmpChecker ());
            register_checker (new TcpChecker ());
        }

        /**
         * Registers a new checker for its method_id.
         */
        public void register_checker (BaseChecker checker) {
            checkers.set (checker.method_id, checker);
        }

        /**
         * Looks up the appropriate checker for a MonitoredHost and runs the check.
         */
        public CheckResult check_host (MonitoredHost entry) {
            var checker = checkers.get (entry.method);
            if (checker == null) {
                return new CheckResult (
                    entry.host, entry.method, false,
                    "unknown method: " + entry.method
                );
            }
            return checker.check (entry);
        }

        /**
         * Checks all hosts in parallel using a thread pool and returns results.
         */
        public Gee.ArrayList<CheckResult> check_all (Gee.ArrayList<MonitoredHost> hosts) {
            var results = new Gee.ArrayList<CheckResult> ();
            var mutex = GLib.Mutex ();

            // Check hosts sequentially for simplicity and reliability
            // (ping already has its own timeout, and thread pool adds complexity)
            foreach (var host in hosts) {
                var result = check_host (host);
                mutex.lock ();
                results.add (result);
                mutex.unlock ();
            }

            return results;
        }
    }
}
