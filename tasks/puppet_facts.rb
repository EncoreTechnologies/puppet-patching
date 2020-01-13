#!/opt/puppetlabs/puppet/bin/ruby
# frozen_string_literal: true

def puppet_executable
  if Gem.win_platform?
    require 'win32/registry'
    installed_dir =
      begin
        Win32::Registry::HKEY_LOCAL_MACHINE.open('SOFTWARE\Puppet Labs\Puppet') do |reg|
          # rubocop:disable Style/RescueModifier
          # Rescue missing key
          dir = reg['RememberedInstallDir64'] rescue ''
          # Both keys may exist, make sure the dir exists
          break dir if File.exist?(dir)

          # Rescue missing key
          reg['RememberedInstallDir'] rescue ''
          # rubocop:enable Style/RescueModifier
        end
      rescue Win32::Registry::Error
        # Rescue missing registry path
        ''
      end

    puppet =
      if installed_dir.empty?
        ''
      else
        File.join(installed_dir, 'bin', 'puppet')
      end
  else
    puppet = '/opt/puppetlabs/bin/puppet'
  end

  # Fall back to PATH lookup if puppet-agent isn't installed
  File.exist?(puppet) ? puppet : 'puppet'
end

# Delegate to puppet facts
puppet_exe = puppet_executable
if puppet_exe != 'puppet'
  # If using the standard install of Puppet, then clear out any custom GEM_PATH that may
  # be set on the system. Custom GEM_PATHs can cause all sorts of issues when puppet loads
  ENV.delete('GEM_PATH')
end
exec(puppet_exe, 'facts', '--render-as', 'json')
