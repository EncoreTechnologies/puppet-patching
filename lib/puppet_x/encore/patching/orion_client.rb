require 'puppet_x'
require 'puppet_x/encore/patching/http_helper'

module PuppetX::Patching
  # Abstraction of the SolarWinds Orion API
  class OrionClient < HTTPHelper
    def initialize(server,
                   port: 17_778,
                   username: nil,
                   password: nil,
                   ssl: true,
                   ssl_verify: OpenSSL::SSL::VERIFY_NONE,
                   redirect_limit: 10,
                   headers: {
                     'Content-Type' => 'application/json',
                   })
      super(username: username,
            password: password,
            ssl: ssl,
            ssl_verify: ssl_verify,
            redirect_limit: redirect_limit,
            headers: headers)
      @server = server
      @port = port
      @scheme = ssl ? 'https' : 'http'
    end

    def make_url(endpoint)
      "#{@scheme}://#{@server}:#{@port}/SolarWinds/InformationService/v3/Json/#{endpoint}"
    end

    def query(query, params)
      body = {
        'query' => query,
        'parameters' => params,
      }
      resp = post(make_url('Query'), body: body.to_json)
      data = JSON.parse(resp.body)
      if data['results']
        data['results']
      else
        []
      end
    end

    def invoke(entity, verb, body: nil)
      resp = post(make_url("Invoke/#{entity}/#{verb}"), body: body)
      JSON.parse(resp.body)
    end

    def get_node(hostname_or_ip, name_property: 'DNS')
      field = ip?(hostname_or_ip) ? 'IPAddress' : name_property
      field_list = ['NodeID', 'Uri', 'IPAddress', name_property].uniq
      q = "SELECT #{field_list.join(',')} FROM Orion.Nodes WHERE #{field}=@query_on"
      params = {
        'query_on' => hostname_or_ip,
      }
      query(q, params)
    end

    def suppress_alerts(uri_array)
      body = [uri_array].to_json
      invoke('Orion.AlertSuppression', 'SuppressAlerts', body: body)
    end

    def resume_alerts(uri_array)
      body = [uri_array].to_json
      invoke('Orion.AlertSuppression', 'ResumeAlerts', body: body)
    end
  end
end
