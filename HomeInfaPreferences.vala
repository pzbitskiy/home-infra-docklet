using Plank;

namespace HomeInfra {

    /**
     * Plank DockItemPreferences stub for the Home Infra docklet.
     *
     * Actual configuration is handled via the YAML config file
     * (~/.config/plank/home-infa-docklet.yaml) rather than through
     * Plank's built-in preference system, because the config includes
     * a dynamic list of monitored hosts which doesn't map well to
     * Plank's flat key-value properties.
     */
    public class HomeInfaPreferences : DockItemPreferences {

        public HomeInfaPreferences.with_file (GLib.File file) {
            base.with_file (file);
        }

        protected override void reset_properties () {
            // No Plank-level properties to reset; config is in YAML.
        }
    }
}
