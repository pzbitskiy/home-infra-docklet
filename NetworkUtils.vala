namespace HomeInfra {

    /**
     * Utility class for network-related operations such as
     * determining whether the local machine is on a given subnet.
     */
    public class NetworkUtils : Object {

        /**
         * Checks whether the machine currently has an IP address that falls
         * within the specified CIDR subnet (e.g. "192.168.1.0/24").
         *
         * Uses `ip -o -4 addr show` to enumerate local addresses and compares
         * them against the subnet mask.
         */
        public static bool is_on_subnet (string cidr) {
            uint32 subnet_addr;
            int prefix_len;

            if (!parse_cidr (cidr, out subnet_addr, out prefix_len)) {
                warning ("Invalid CIDR notation: %s", cidr);
                return false;
            }

            uint32 mask = prefix_to_mask (prefix_len);

            try {
                string stdout_buf;
                int exit_code;

                Process.spawn_command_line_sync (
                    "ip -o -4 addr show",
                    out stdout_buf, null, out exit_code
                );

                if (exit_code != 0) {
                    warning ("ip addr command failed with exit code %d", exit_code);
                    return false;
                }

                foreach (unowned string line in stdout_buf.split ("\n")) {
                    // Example line:
                    // 2: eth0    inet 192.168.1.42/24 brd 192.168.1.255 scope global eth0
                    string trimmed = line.strip ();
                    if (trimmed.length == 0) {
                        continue;
                    }

                    // Find "inet " token
                    int inet_pos = trimmed.index_of ("inet ");
                    if (inet_pos < 0) {
                        continue;
                    }

                    string after_inet = trimmed.substring (inet_pos + 5).strip ();
                    // Extract the IP/prefix portion
                    int space_pos = after_inet.index_of (" ");
                    string ip_part = (space_pos > 0) ? after_inet.substring (0, space_pos) : after_inet;

                    // Strip the /prefix if present
                    int slash_pos = ip_part.index_of ("/");
                    string ip_str = (slash_pos > 0) ? ip_part.substring (0, slash_pos) : ip_part;

                    uint32 local_addr = ip_to_uint32 (ip_str);
                    if (local_addr == 0) {
                        continue;
                    }

                    if ((local_addr & mask) == (subnet_addr & mask)) {
                        return true;
                    }
                }
            } catch (Error e) {
                warning ("Failed to enumerate local addresses: %s", e.message);
            }

            return false;
        }

        /**
         * Parses a CIDR string like "192.168.1.0/24" into a network address
         * and prefix length.
         */
        public static bool parse_cidr (string cidr, out uint32 addr, out int prefix) {
            addr = 0;
            prefix = 0;

            int slash = cidr.index_of ("/");
            if (slash < 0) {
                return false;
            }

            string ip_str = cidr.substring (0, slash);
            string prefix_str = cidr.substring (slash + 1);

            addr = ip_to_uint32 (ip_str);
            prefix = int.parse (prefix_str);

            return (addr != 0 || ip_str == "0.0.0.0") && prefix >= 0 && prefix <= 32;
        }

        /**
         * Converts a dotted-quad IPv4 string to a 32-bit integer.
         */
        public static uint32 ip_to_uint32 (string ip) {
            var parts = ip.split (".");
            if (parts.length != 4) {
                return 0;
            }

            uint32 result = 0;
            for (int i = 0; i < 4; i++) {
                int octet = int.parse (parts[i]);
                if (octet < 0 || octet > 255) {
                    return 0;
                }
                result = (result << 8) | (uint32) octet;
            }

            return result;
        }

        /**
         * Converts a CIDR prefix length to a 32-bit subnet mask.
         */
        public static uint32 prefix_to_mask (int prefix) {
            if (prefix == 0) {
                return 0;
            }
            return (uint32) (0xFFFFFFFF << (32 - prefix));
        }
    }
}
