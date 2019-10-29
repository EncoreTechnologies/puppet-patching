#!/usr/bin/env ruby
require_relative '../../ruby_task_helper/files/task_helper.rb'

# Bolt task for enabling/disabling monitoring alerts in SolarWinds
class MonitoringSolarwindsTask < TaskHelper
  def add_module_lib_paths(install_dir)
    Dir.glob(File.join([install_dir, '*'])).each do |mod|
      $LOAD_PATH << File.join([mod, 'lib'])
    end
  end

  def task(nodes: nil,
           action: nil,
           **kwargs)
    add_module_lib_paths(kwargs[:_installdir])
    require 'puppet_x/encore/patching/orion_client'

    # this key contains all of the remote configuration from the inventory.yaml
    # combined with information for the remote target (SolarWinds server)
    remote_target = kwargs[:_target]

    # suppress alerts on a host
    orion = PuppetX::Patching::OrionClient.new(remote_target[:host],
                                               username: remote_target[:username],
                                               password: remote_target[:password],
                                               port: remote_target.fetch(:port, 17_778))
    missing_nodes = []
    uri_array = nodes.map do |n|
      sw_nodes = orion.get_node(n)

      if sw_nodes.empty?
        missing_nodes << sw_nodes[0]
        next
      elsif sw_nodes.length > 1
        raise ArgumentError, "Found [#{sw_nodes.length}] nodes matching '#{n}': #{sw_nodes.to_json}"
      end

      # extract the URI property for our good nodes
      sw_nodes.map { |sw_n| sw_n['Uri'] }
    end

    # print all of the missing nodes at the same time to make debugging easier
    unless missing_nodes.empty?
      missing_pretty = JSON.pretty_generate(missing_nodes)
      raise ArgumentError, "Unable to find the following nodes in SolarWinds: #{missing_pretty}"
    end

    uri_array.flatten!
    case action
    when 'disable'
      orion.suppress_alerts(uri_array)
    when 'enable'
      orion.resume_alerts(uri_array)
    else
      raise ArgumentError, "Unknown action: #{action}"
    end
  end
end

MonitoringSolarwindsTask.run if $PROGRAM_NAME == __FILE__
