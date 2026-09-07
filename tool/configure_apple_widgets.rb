#!/usr/bin/env ruby

require 'xcodeproj'

ROOT = File.expand_path('..', __dir__)
TEAM_ID = 'A6Y73X2ZLS'

def file_reference(group, name)
  group.files.find { |file| file.path == name } || group.new_file(name)
end

def embed_extension(host, extension, platform:)
  host.add_dependency(extension) unless host.dependencies.any? do |dependency|
    dependency.target == extension
  end

  phase = host.copy_files_build_phases.find do |candidate|
    candidate.name == 'Embed App Extensions'
  end
  phase ||= host.new_copy_files_build_phase('Embed App Extensions')
  phase.dst_subfolder_spec = '13'
  unless phase.files_references.include?(extension.product_reference)
    phase.add_file_reference(extension.product_reference)
  end

  thin_binary_index = host.build_phases.index do |build_phase|
    build_phase.respond_to?(:name) && build_phase.name == 'Thin Binary'
  end
  if thin_binary_index
    thin_binary_phase = host.build_phases[thin_binary_index]
    thin_binary_phase.input_paths = [] if platform == :ios
    host.build_phases.delete(phase)
    host.build_phases.insert(thin_binary_index, phase)
  end
end

def configure_project(
  project_path:,
  target_name:,
  platform:,
  deployment_target:,
  bundle_identifier:,
  entitlements:
)
  project = Xcodeproj::Project.open(project_path)
  host = project.targets.find { |target| target.name == 'Runner' }
  raise "Runner target missing in #{project_path}" unless host

  widget_group = project.main_group.groups.find { |group| group.name == 'DailyWidgets' }
  widget_group ||= project.main_group.new_group('DailyWidgets', '../apple_widgets')
  swift_file = file_reference(widget_group, 'DailyWidgets.swift')
  alarm_metadata_file = platform == :ios \
    ? file_reference(widget_group, 'DailyAlarmMetadata.swift') \
    : nil
  file_reference(widget_group, 'Info.plist')
  file_reference(widget_group, File.basename(entitlements))

  widget = project.targets.find { |target| target.name == target_name }
  widget ||= project.new_target(
    :app_extension,
    target_name,
    platform,
    deployment_target
  )

  target_attributes = project.root_object.attributes['TargetAttributes'] ||= {}
  capability_name = platform == :ios \
    ? 'com.apple.ApplicationGroups.iOS' \
    : 'com.apple.ApplicationGroups.mac'
  [host, widget].each do |target|
    attributes = target_attributes[target.uuid] ||= {}
    attributes['DevelopmentTeam'] = TEAM_ID
    attributes['ProvisioningStyle'] = 'Automatic'
    capabilities = attributes['SystemCapabilities'] ||= {}
    capabilities[capability_name] = { 'enabled' => 1 }
  end
  unless widget.source_build_phase.files_references.include?(swift_file)
    widget.source_build_phase.add_file_reference(swift_file)
  end
  if alarm_metadata_file
    unless widget.source_build_phase.files_references.include?(alarm_metadata_file)
      widget.source_build_phase.add_file_reference(alarm_metadata_file)
    end
    unless host.source_build_phase.files_references.include?(alarm_metadata_file)
      host.source_build_phase.add_file_reference(alarm_metadata_file)
    end
  end

  widget.build_configurations.each do |configuration|
    settings = configuration.build_settings
    settings['APPLICATION_EXTENSION_API_ONLY'] = 'YES'
    settings['CODE_SIGN_ENTITLEMENTS'] = "../apple_widgets/#{File.basename(entitlements)}"
    settings['CODE_SIGN_STYLE'] = 'Automatic'
    settings['CURRENT_PROJECT_VERSION'] = '3.4.0'
    settings['DEVELOPMENT_TEAM'] = TEAM_ID
    settings['GENERATE_INFOPLIST_FILE'] = 'NO'
    settings['INFOPLIST_FILE'] = '../apple_widgets/Info.plist'
    settings['LD_RUNPATH_SEARCH_PATHS'] = [
      '$(inherited)',
      '@executable_path/Frameworks',
      '@executable_path/../../Frameworks'
    ]
    settings['MARKETING_VERSION'] = '3.4.0'
    settings['PRODUCT_BUNDLE_IDENTIFIER'] = bundle_identifier
    settings['PRODUCT_NAME'] = '$(TARGET_NAME)'
    settings['PROVISIONING_PROFILE_SPECIFIER'] = ''
    settings['SKIP_INSTALL'] = 'YES'
    settings['SWIFT_VERSION'] = '5.0'
    if platform == :ios
      settings['IPHONEOS_DEPLOYMENT_TARGET'] = deployment_target
      settings['TARGETED_DEVICE_FAMILY'] = '1,2'
    else
      settings['MACOSX_DEPLOYMENT_TARGET'] = deployment_target
      if configuration.name != 'Release'
        settings['CODE_SIGN_IDENTITY'] = 'Apple Development'
      else
        settings.delete('CODE_SIGN_IDENTITY')
      end
    end
  end

  embed_extension(host, widget, platform: platform)
  project.save
end

configure_project(
  project_path: File.join(ROOT, 'ios/Runner.xcodeproj'),
  target_name: 'DailyWidgets',
  platform: :ios,
  deployment_target: '17.0',
  bundle_identifier: 'com.littlebit0.daily.widgets',
  entitlements: 'DailyWidgets.entitlements'
)

configure_project(
  project_path: File.join(ROOT, 'macos/Runner.xcodeproj'),
  target_name: 'DailyMacWidgets',
  platform: :osx,
  deployment_target: '14.0',
  bundle_identifier: 'com.littlebit0.daily.widgets',
  entitlements: 'DailyMacWidgets.entitlements'
)
