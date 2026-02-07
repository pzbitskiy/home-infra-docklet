/**
 * Unit tests for HomeInfra.NetworkUtils.
 *
 * Run with: meson test -C build
 */

namespace HomeInfra.Tests {

    // ---------------------------------------------------------------
    //  ip_to_uint32
    // ---------------------------------------------------------------

    private void test_ip_to_uint32_basic () {
        // 192.168.1.1 = 0xC0A80101 = 3232235777
        assert_cmpuint (NetworkUtils.ip_to_uint32 ("192.168.1.1"),
                        GLib.CompareOperator.EQ, (uint) 0xC0A80101);
    }

    private void test_ip_to_uint32_zeros () {
        // 0.0.0.0 = 0
        assert_cmpuint (NetworkUtils.ip_to_uint32 ("0.0.0.0"),
                        GLib.CompareOperator.EQ, 0);
    }

    private void test_ip_to_uint32_broadcast () {
        // 255.255.255.255 = 0xFFFFFFFF
        assert_cmpuint (NetworkUtils.ip_to_uint32 ("255.255.255.255"),
                        GLib.CompareOperator.EQ, (uint) 0xFFFFFFFF);
    }

    private void test_ip_to_uint32_loopback () {
        // 127.0.0.1 = 0x7F000001
        assert_cmpuint (NetworkUtils.ip_to_uint32 ("127.0.0.1"),
                        GLib.CompareOperator.EQ, 0x7F000001);
    }

    private void test_ip_to_uint32_ten_net () {
        // 10.0.0.1 = 0x0A000001
        assert_cmpuint (NetworkUtils.ip_to_uint32 ("10.0.0.1"),
                        GLib.CompareOperator.EQ, 0x0A000001);
    }

    private void test_ip_to_uint32_class_b () {
        // 172.16.254.1 = 0xAC10FE01
        assert_cmpuint (NetworkUtils.ip_to_uint32 ("172.16.254.1"),
                        GLib.CompareOperator.EQ, (uint) 0xAC10FE01);
    }

    private void test_ip_to_uint32_invalid_too_few_octets () {
        assert_cmpuint (NetworkUtils.ip_to_uint32 ("192.168.1"),
                        GLib.CompareOperator.EQ, 0);
    }

    private void test_ip_to_uint32_invalid_too_many_octets () {
        assert_cmpuint (NetworkUtils.ip_to_uint32 ("192.168.1.1.1"),
                        GLib.CompareOperator.EQ, 0);
    }

    private void test_ip_to_uint32_invalid_empty () {
        assert_cmpuint (NetworkUtils.ip_to_uint32 (""),
                        GLib.CompareOperator.EQ, 0);
    }

    private void test_ip_to_uint32_invalid_garbage () {
        assert_cmpuint (NetworkUtils.ip_to_uint32 ("not.an.ip.address"),
                        GLib.CompareOperator.EQ, 0);
    }

    // ---------------------------------------------------------------
    //  prefix_to_mask
    // ---------------------------------------------------------------

    private void test_prefix_to_mask_32 () {
        // /32 = 255.255.255.255
        assert_cmpuint (NetworkUtils.prefix_to_mask (32),
                        GLib.CompareOperator.EQ, (uint) 0xFFFFFFFF);
    }

    private void test_prefix_to_mask_24 () {
        // /24 = 255.255.255.0
        assert_cmpuint (NetworkUtils.prefix_to_mask (24),
                        GLib.CompareOperator.EQ, (uint) 0xFFFFFF00);
    }

    private void test_prefix_to_mask_16 () {
        // /16 = 255.255.0.0
        assert_cmpuint (NetworkUtils.prefix_to_mask (16),
                        GLib.CompareOperator.EQ, (uint) 0xFFFF0000);
    }

    private void test_prefix_to_mask_8 () {
        // /8 = 255.0.0.0
        assert_cmpuint (NetworkUtils.prefix_to_mask (8),
                        GLib.CompareOperator.EQ, (uint) 0xFF000000);
    }

    private void test_prefix_to_mask_0 () {
        // /0 = 0.0.0.0
        assert_cmpuint (NetworkUtils.prefix_to_mask (0),
                        GLib.CompareOperator.EQ, 0);
    }

    private void test_prefix_to_mask_25 () {
        // /25 = 255.255.255.128
        assert_cmpuint (NetworkUtils.prefix_to_mask (25),
                        GLib.CompareOperator.EQ, (uint) 0xFFFFFF80);
    }

    private void test_prefix_to_mask_1 () {
        // /1 = 128.0.0.0
        assert_cmpuint (NetworkUtils.prefix_to_mask (1),
                        GLib.CompareOperator.EQ, (uint) 0x80000000);
    }

    private void test_prefix_to_mask_20 () {
        // /20 = 255.255.240.0
        assert_cmpuint (NetworkUtils.prefix_to_mask (20),
                        GLib.CompareOperator.EQ, (uint) 0xFFFFF000);
    }

    // ---------------------------------------------------------------
    //  parse_cidr
    // ---------------------------------------------------------------

    private void test_parse_cidr_24 () {
        uint32 addr;
        int prefix;
        assert_true (NetworkUtils.parse_cidr ("192.168.1.0/24", out addr, out prefix));
        assert_cmpuint (addr, GLib.CompareOperator.EQ, (uint) 0xC0A80100);
        assert_cmpint (prefix, GLib.CompareOperator.EQ, 24);
    }

    private void test_parse_cidr_8 () {
        uint32 addr;
        int prefix;
        assert_true (NetworkUtils.parse_cidr ("10.0.0.0/8", out addr, out prefix));
        assert_cmpuint (addr, GLib.CompareOperator.EQ, 0x0A000000);
        assert_cmpint (prefix, GLib.CompareOperator.EQ, 8);
    }

    private void test_parse_cidr_32 () {
        uint32 addr;
        int prefix;
        assert_true (NetworkUtils.parse_cidr ("10.20.30.40/32", out addr, out prefix));
        assert_cmpuint (addr, GLib.CompareOperator.EQ, NetworkUtils.ip_to_uint32 ("10.20.30.40"));
        assert_cmpint (prefix, GLib.CompareOperator.EQ, 32);
    }

    private void test_parse_cidr_16 () {
        uint32 addr;
        int prefix;
        assert_true (NetworkUtils.parse_cidr ("172.16.0.0/16", out addr, out prefix));
        assert_cmpuint (addr, GLib.CompareOperator.EQ, (uint) 0xAC100000);
        assert_cmpint (prefix, GLib.CompareOperator.EQ, 16);
    }

    private void test_parse_cidr_no_slash () {
        uint32 addr;
        int prefix;
        assert_false (NetworkUtils.parse_cidr ("192.168.1.0", out addr, out prefix));
    }

    private void test_parse_cidr_empty () {
        uint32 addr;
        int prefix;
        assert_false (NetworkUtils.parse_cidr ("", out addr, out prefix));
    }

    private void test_parse_cidr_invalid_ip () {
        uint32 addr;
        int prefix;
        assert_false (NetworkUtils.parse_cidr ("not.valid/24", out addr, out prefix));
    }

    private void test_parse_cidr_slash_only () {
        uint32 addr;
        int prefix;
        assert_false (NetworkUtils.parse_cidr ("/24", out addr, out prefix));
    }

    // ---------------------------------------------------------------
    //  Subnet matching logic (manual — same math as is_on_subnet)
    // ---------------------------------------------------------------

    /**
     * Helper: checks whether ip_str falls within cidr using the same
     * arithmetic as is_on_subnet, but without shelling out to `ip`.
     */
    private bool ip_matches_cidr (string ip_str, string cidr) {
        uint32 subnet_addr;
        int prefix_len;
        if (!NetworkUtils.parse_cidr (cidr, out subnet_addr, out prefix_len)) {
            return false;
        }
        uint32 mask = NetworkUtils.prefix_to_mask (prefix_len);
        uint32 ip = NetworkUtils.ip_to_uint32 (ip_str);
        return (ip & mask) == (subnet_addr & mask);
    }

    private void test_match_in_subnet () {
        assert_true (ip_matches_cidr ("192.168.1.42", "192.168.1.0/24"));
    }

    private void test_match_network_address () {
        assert_true (ip_matches_cidr ("192.168.1.0", "192.168.1.0/24"));
    }

    private void test_match_broadcast () {
        assert_true (ip_matches_cidr ("192.168.1.255", "192.168.1.0/24"));
    }

    private void test_no_match_different_subnet () {
        assert_false (ip_matches_cidr ("192.168.2.1", "192.168.1.0/24"));
    }

    private void test_match_wide_prefix () {
        // /8 covers 10.0.0.0 – 10.255.255.255
        assert_true (ip_matches_cidr ("10.99.200.5", "10.0.0.0/8"));
    }

    private void test_no_match_wide_prefix () {
        assert_false (ip_matches_cidr ("11.0.0.1", "10.0.0.0/8"));
    }

    private void test_match_host_route () {
        // /32 matches only that exact IP
        assert_true (ip_matches_cidr ("192.168.1.1", "192.168.1.1/32"));
    }

    private void test_no_match_host_route () {
        assert_false (ip_matches_cidr ("192.168.1.2", "192.168.1.1/32"));
    }

    private void test_match_slash_25_lower () {
        // /25 = .0-.127
        assert_true (ip_matches_cidr ("192.168.1.100", "192.168.1.0/25"));
    }

    private void test_no_match_slash_25_upper () {
        // 192.168.1.200 is in .128-.255 half
        assert_false (ip_matches_cidr ("192.168.1.200", "192.168.1.0/25"));
    }

    private void test_match_slash_20 () {
        // 172.16.0.0/20 covers 172.16.0.0 – 172.16.15.255
        assert_true (ip_matches_cidr ("172.16.10.50", "172.16.0.0/20"));
    }

    private void test_no_match_slash_20 () {
        assert_false (ip_matches_cidr ("172.16.16.1", "172.16.0.0/20"));
    }

    // ---------------------------------------------------------------
    //  is_on_subnet — integration tests using loopback
    // ---------------------------------------------------------------

    private void test_is_on_subnet_loopback () {
        // 127.0.0.1 is always present on lo
        assert_true (NetworkUtils.is_on_subnet ("127.0.0.0/8"));
    }

    private void test_is_on_subnet_absent () {
        // 203.0.113.0/24 is TEST-NET-3, should never be a local address
        assert_false (NetworkUtils.is_on_subnet ("203.0.113.0/24"));
    }

    private void test_is_on_subnet_narrow_loopback () {
        // /32 on the exact loopback address
        assert_true (NetworkUtils.is_on_subnet ("127.0.0.1/32"));
    }

    private void test_is_on_subnet_wrong_loopback () {
        // 127.0.0.2/32 — valid CIDR, but lo only has 127.0.0.1
        assert_false (NetworkUtils.is_on_subnet ("127.0.0.2/32"));
    }

    // ---------------------------------------------------------------
    //  Entry point
    // ---------------------------------------------------------------

    public static int main (string[] args) {
        GLib.Test.init (ref args);

        // ip_to_uint32
        GLib.Test.add_func ("/network-utils/ip-to-uint32/basic", test_ip_to_uint32_basic);
        GLib.Test.add_func ("/network-utils/ip-to-uint32/zeros", test_ip_to_uint32_zeros);
        GLib.Test.add_func ("/network-utils/ip-to-uint32/broadcast", test_ip_to_uint32_broadcast);
        GLib.Test.add_func ("/network-utils/ip-to-uint32/loopback", test_ip_to_uint32_loopback);
        GLib.Test.add_func ("/network-utils/ip-to-uint32/ten-net", test_ip_to_uint32_ten_net);
        GLib.Test.add_func ("/network-utils/ip-to-uint32/class-b", test_ip_to_uint32_class_b);
        GLib.Test.add_func ("/network-utils/ip-to-uint32/invalid-few-octets", test_ip_to_uint32_invalid_too_few_octets);
        GLib.Test.add_func ("/network-utils/ip-to-uint32/invalid-many-octets", test_ip_to_uint32_invalid_too_many_octets);
        GLib.Test.add_func ("/network-utils/ip-to-uint32/invalid-empty", test_ip_to_uint32_invalid_empty);
        GLib.Test.add_func ("/network-utils/ip-to-uint32/invalid-garbage", test_ip_to_uint32_invalid_garbage);

        // prefix_to_mask
        GLib.Test.add_func ("/network-utils/prefix-to-mask/32", test_prefix_to_mask_32);
        GLib.Test.add_func ("/network-utils/prefix-to-mask/24", test_prefix_to_mask_24);
        GLib.Test.add_func ("/network-utils/prefix-to-mask/16", test_prefix_to_mask_16);
        GLib.Test.add_func ("/network-utils/prefix-to-mask/8", test_prefix_to_mask_8);
        GLib.Test.add_func ("/network-utils/prefix-to-mask/0", test_prefix_to_mask_0);
        GLib.Test.add_func ("/network-utils/prefix-to-mask/25", test_prefix_to_mask_25);
        GLib.Test.add_func ("/network-utils/prefix-to-mask/1", test_prefix_to_mask_1);
        GLib.Test.add_func ("/network-utils/prefix-to-mask/20", test_prefix_to_mask_20);

        // parse_cidr
        GLib.Test.add_func ("/network-utils/parse-cidr/24", test_parse_cidr_24);
        GLib.Test.add_func ("/network-utils/parse-cidr/8", test_parse_cidr_8);
        GLib.Test.add_func ("/network-utils/parse-cidr/32", test_parse_cidr_32);
        GLib.Test.add_func ("/network-utils/parse-cidr/16", test_parse_cidr_16);
        GLib.Test.add_func ("/network-utils/parse-cidr/no-slash", test_parse_cidr_no_slash);
        GLib.Test.add_func ("/network-utils/parse-cidr/empty", test_parse_cidr_empty);
        GLib.Test.add_func ("/network-utils/parse-cidr/invalid-ip", test_parse_cidr_invalid_ip);
        GLib.Test.add_func ("/network-utils/parse-cidr/slash-only", test_parse_cidr_slash_only);

        // subnet matching arithmetic
        GLib.Test.add_func ("/network-utils/match/in-subnet", test_match_in_subnet);
        GLib.Test.add_func ("/network-utils/match/network-address", test_match_network_address);
        GLib.Test.add_func ("/network-utils/match/broadcast", test_match_broadcast);
        GLib.Test.add_func ("/network-utils/match/different-subnet", test_no_match_different_subnet);
        GLib.Test.add_func ("/network-utils/match/wide-prefix", test_match_wide_prefix);
        GLib.Test.add_func ("/network-utils/match/no-match-wide", test_no_match_wide_prefix);
        GLib.Test.add_func ("/network-utils/match/host-route", test_match_host_route);
        GLib.Test.add_func ("/network-utils/match/no-match-host-route", test_no_match_host_route);
        GLib.Test.add_func ("/network-utils/match/slash-25-lower", test_match_slash_25_lower);
        GLib.Test.add_func ("/network-utils/match/no-match-slash-25", test_no_match_slash_25_upper);
        GLib.Test.add_func ("/network-utils/match/slash-20", test_match_slash_20);
        GLib.Test.add_func ("/network-utils/match/no-match-slash-20", test_no_match_slash_20);

        // is_on_subnet integration
        GLib.Test.add_func ("/network-utils/is-on-subnet/loopback", test_is_on_subnet_loopback);
        GLib.Test.add_func ("/network-utils/is-on-subnet/absent", test_is_on_subnet_absent);
        GLib.Test.add_func ("/network-utils/is-on-subnet/narrow-loopback", test_is_on_subnet_narrow_loopback);
        GLib.Test.add_func ("/network-utils/is-on-subnet/wrong-loopback", test_is_on_subnet_wrong_loopback);

        return GLib.Test.run ();
    }
}
