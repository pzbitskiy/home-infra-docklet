project(
  'docklet-homeinfra',
  'vala',
  'c',
  version: '0.1.0',
)

# Dependencies
gtk_dep = dependency('gtk+-3.0')
plank_dep = dependency('plank')
gee_dep = dependency('gee-0.8')
gio_dep = dependency('gio-2.0')

# Configure i18n
i18n = import('i18n')
customconf = configuration_data()
customconf.set('GETTEXT_PACKAGE', meson.project_name())

# Compile GResource bundle (SVG icons)
gnome = import('gnome')
resources = gnome.compile_resources(
  'resources',
  'homeinfra.gresource.xml',
  source_dir: '.',
  c_name: 'resources',
)

add_project_arguments(
  [
    '-Wno-discarded-qualifiers',
    '-Wno-incompatible-pointer-types',
    '-Wno-unused',
    '-Wl,--enable-new-dtags',
    '-DGETTEXT_PACKAGE="@0@"'.format(meson.project_name()),
  ],
  language: 'c',
)

# Source files
sources = [
  'HomeInfaDocklet.vala',
  'HomeInfaDockItem.vala',
  'HomeInfaPreferences.vala',
  'ConfigManager.vala',
  'HostChecker.vala',
  'NetworkUtils.vala',
  resources,
]

# Build the shared module that Plank loads
shared_module(
  'docklet-homeinfra',
  sources,
  dependencies: [gtk_dep, plank_dep, gee_dep, gio_dep],
  install: true,
  install_dir: join_paths(get_option('libdir'), 'plank/docklets'),
)

# ---------- Tests ----------
posix_dep = meson.get_compiler('vala').find_library('posix')

test_config_parser = executable(
  'test-config-parser',
  'tests/test_config_parser.vala',
  'ConfigManager.vala',
  dependencies: [gee_dep, gio_dep, posix_dep],
)

test('config-parser', test_config_parser)

test_network_utils = executable(
  'test-network-utils',
  'tests/test_network_utils.vala',
  'NetworkUtils.vala',
  dependencies: [gio_dep],
)

test('network-utils', test_network_utils)
