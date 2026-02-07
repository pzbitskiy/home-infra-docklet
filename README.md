# Home Infra Docklet

A home infrastructure monitor docklet for [Plank Reloaded](https://github.com/zquestz/plank-reloaded).

Monitors availability of hosts on your home network and displays a color-coded status icon on the dock:

- **Green** (checkmark) -- all monitored hosts are reachable
- **Yellow** (exclamation) -- some hosts are down
- **Red** (X) -- all hosts are unreachable

The docklet only runs checks when the machine is connected to the configured home subnet.

## Features

- Automatic home network detection via CIDR subnet matching
- Periodic host availability checks with configurable interval
- ICMP (ping) and TCP port connection checks
- Extendable checker architecture -- easy to add new check methods
- Right-click menu with per-host status, re-check, and config editor access
- YAML configuration with auto-generated sample on first run

## Dependencies

- vala
- gtk+-3.0
- gee-0.8
- gio-2.0
- plank-reloaded

## Installation

```bash
# Clone the repository
git clone <repo-url>
cd home-infa-docklet

# Build and install
meson setup --prefix=/usr build
meson compile -C build
sudo meson install -C build
```

## Running Tests

```bash
meson setup build
meson compile -C build
meson test -C build
```

For verbose output showing individual test cases:

```bash
meson test -C build -v
```

The test suite includes:

- **config-parser** (15 tests) -- YAML config parsing: quoting styles, TCP port extraction, comments, interval clamping, reload behavior, edge cases.
- **network-utils** (42 tests) -- IP-to-integer conversion, CIDR prefix masks, subnet matching arithmetic, and `is_on_subnet` integration tests using loopback.

## Setup

After installation, open the Plank Reloaded settings, navigate to "Docklets", and drag and drop Home Infra onto your dock.

On the first run, a sample configuration file is created at `~/.config/plank/home-infa-docklet.yaml`.

## Configuration

Edit `~/.config/plank/home-infa-docklet.yaml`:

```yaml
home_subnet: "192.168.1.0/24"
recheck_interval: 60
hosts:
  - host: "192.168.1.1"
    method: "icmp"
  - host: "192.168.1.2"
    method: "icmp"
```

| Key | Description |
|---|---|
| `home_subnet` | CIDR notation of your home network. Checks only run when a local interface has an IP within this subnet. |
| `recheck_interval` | Seconds between automatic re-checks (minimum 5). |
| `hosts` | List of hosts to monitor. Each entry has a `host` and a `method`. |

### Supported check methods

| Method | Format | Example | Description |
|---|---|---|---|
| ICMP ping | `"icmp"` | `method: "icmp"` | Sends a single ping with a 3-second timeout |
| TCP port | `"tcp:<port>"` | `method: "tcp:22"` | Attempts a TCP connection to the given port with a 5-second timeout |

### Example with mixed methods

```yaml
home_subnet: "10.0.0.0/8"
recheck_interval: 120
hosts:
  - host: "10.0.0.1"
    method: "icmp"
  - host: "10.0.0.5"
    method: "tcp:22"
  - host: "10.0.0.10"
    method: "tcp:80"
```

## Usage

- **Hover**: Shows a tooltip with the check summary and per-host status.
- **Right-click**: Context menu with:
  - Status overview and per-host results
  - **Re-check** -- reloads the config and immediately re-checks all hosts
  - **Open config in text editor** -- opens the YAML config in your default editor

## Extending

To add a new check method, subclass `BaseChecker` in `HostChecker.vala`:

```vala
public class HttpChecker : BaseChecker {
    public override string method_id { get { return "http"; } }

    public override CheckResult check (MonitoredHost entry) {
        // your implementation here
    }
}
```

Then register it in the `CheckerRegistry` constructor:

```vala
register_checker (new HttpChecker ());
```

## License

MIT
