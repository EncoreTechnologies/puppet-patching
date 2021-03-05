#!/usr/bin/env ruby
require_relative '../../ruby_task_helper/files/task_helper.rb'
require_relative '../lib/puppet_x/encore/patching/http_helper.rb'
require 'time'
require 'json'

# Bolt task for enabling/disabling monitoring alerts in SolarWinds
class MonitoringPrometheusTask < TaskHelper
  def initialize
    super()
    @http_helper = PuppetX::Patching::HTTPHelper.new(ssl: false, ssl_verify: false)
  end

  def get_end_timestamp(duration, units)
    case units
    when 'minutes'
      offset = 60
    when 'hours'
      offset = 3600
    when 'days'
      offset = 86_400
    when 'weeks'
      offset = 604_800
    end

    (Time.now.utc + duration * offset).iso8601
  end

  # Create a silence for every target that starts now and ends after the given duration
  def create_silences(targets, duration, units, prometheus_server)
    silence_ids = []
    targets.each do |target|
      payload = {
        matchers: [{ name: 'alias', value: target, isRegex: false }],
        startsAt: Time.now.utc.iso8601,
        endsAt: get_end_timestamp(duration, units),
        comment: "Silencing alerts on #{target} for patching",
        createdBy: 'patching',
      }
      headers = { 'Content-Type' => 'application/json' }
      res = @http_helper.post("http://#{prometheus_server}:9093/api/v2/silences",
                              body: payload.to_json,
                              headers: headers)

      silence_ids.push((JSON.parse res.body)['silenceID'])
    end

    silence_ids
  end

  # Remove all silences for targets that were created by 'patching'
  def remove_silences(targets, prometheus_server)
    res = @http_helper.get("http://#{prometheus_server}:9093/api/v2/silences")
    silences = res.body

    (JSON.parse silences).each do |silence|
      # Verify that the current silence is for one of the given targets
      # All silences created by this task will have exactly one matcher
      next if silence['matchers'][0]['name'] != 'alias' || !targets.include?(silence['matchers'][0]['value'])
      # Remove only silences that are active and were created by 'patching'
      if silence['status']['state'] == 'active' && silence['createdBy'] == 'patching'
        @http_helper.delete("http://#{prometheus_server}:9093/api/v2/silence/#{silence['id']}")
      end
    end
  end

  # This will either enable or disable monitoring
  def task(targets: nil,
           action: nil,
           prometheus_server: nil,
           silence_duration: nil,
           silence_units: nil,
           **_kwargs)
    # targets can be either an array or a string with a single target
    # Check if a single target was given and convert it to an array if it was
    if targets.is_a? String
      targets = [targets]
    end

    if action == 'disable'
      create_silences(targets, silence_duration, silence_units, prometheus_server)
    elsif action == 'enable'
      remove_silences(targets, prometheus_server)
    end
  end
end

MonitoringPrometheusTask.run if $PROGRAM_NAME == __FILE__
