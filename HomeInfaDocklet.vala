/**
 * Home Infrastructure Monitor Docklet
 *
 * Monitors hosts on a home network via ICMP ping or TCP connection checks.
 * Shows green (all up), yellow (partial), or red (all down) status icons.
 */

public static void docklet_init (Plank.DockletManager manager) {
    manager.register_docklet (typeof (HomeInfra.HomeInfraDocklet));
}

namespace HomeInfra {
    /**
     * Resource path for bundled assets
     */
    public const string G_RESOURCE_PATH = "/net/homeinfra/docklet";

    public class HomeInfraDocklet : Object, Plank.Docklet {
        public unowned string get_id () {
            return "home-infra";
        }

        public unowned string get_name () {
            return _("Home Infra");
        }

        public unowned string get_description () {
            return _("Monitors availability of hosts on your home network");
        }

        public unowned string get_icon () {
            return "resource://" + HomeInfra.G_RESOURCE_PATH + "/icons/docklet-icon.svg";
        }

        public bool is_supported () {
            return true;
        }

        public Plank.DockElement make_element (string launcher, GLib.File file) {
            return new HomeInfaDockItem.with_dockitem_file (file);
        }
    }
}
