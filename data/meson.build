# Desktop
desktop_conf = configuration_data()
desktop_conf.set('exec', application_id)
desktop_conf.set('icon', application_id)
desktop_file = i18n.merge_file(
  input: configure_file(
    input: files('io.github.dev_aatif.planote.desktop.in.in'),
    output: 'io.github.dev_aatif.planote.desktop.in',
    configuration: desktop_conf,
  ),
  output: '@0@.desktop'.format(application_id),
  type: 'desktop',
  po_dir: join_paths(meson.project_source_root(), 'po'),
  install: true,
  install_dir: get_option('datadir') / 'applications',
)

desktop_utils = find_program('desktop-file-validate', required: false)
if desktop_utils.found()
  test('Validate desktop file', desktop_utils, args: [desktop_file])
endif


# AppStream 
appdata_conf = configuration_data()
appdata_conf.set('appid', application_id)
appstream_file = i18n.merge_file(
  input: configure_file(
    input: files('io.github.dev_aatif.planote.appdata.xml.in.in'),
    output: 'io.github.dev_aatif.planote.appdata.xml.in',
    configuration: appdata_conf
  ),
  output: '@0@.appdata.xml'.format(application_id),
  po_dir: join_paths(meson.project_source_root(), 'po'),
  install: true,
  install_dir: get_option('datadir') / 'appdata',
)

# GSettings schema - configure with correct app ID
schema_conf = configuration_data()
schema_conf.set('APP_ID', application_id)
schema_conf.set('APP_PATH', application_path)

schema_file = configure_file(
  input: 'io.github.dev_aatif.planote.gschema.xml.in',
  output: '@0@.gschema.xml'.format(application_id),
  configuration: schema_conf,
  install: true,
  install_dir: get_option('datadir') / 'glib-2.0/schemas',
)

compile_schemas = find_program('glib-compile-schemas', required: false)
if compile_schemas.found()
  test('Validate schema file', compile_schemas,
    args: ['--strict', '--dry-run', meson.current_build_dir()]
  )
endif

subdir('icons')