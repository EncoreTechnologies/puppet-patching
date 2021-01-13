require 'net/https'
require 'ipaddr'
require 'puppet_x'

module PuppetX::Patching
  # Helper class for HTTP calls
  class HTTPHelper
    def initialize(username: nil,
                   password: nil,
                   ssl: true,
                   ssl_verify: OpenSSL::SSL::VERIFY_NONE,
                   redirect_limit: 10,
                   headers: {})
      @username = username
      @password = password
      @ssl = ssl
      @ssl_verify = ssl_verify
      @redirect_limit = redirect_limit
      @headers = headers
    end

    def execute(method, url, body: nil, headers: {}, redirect_limit: @redirect_limit)
      raise ArgumentError, 'HTTP redirect too deep' if redirect_limit.zero?

      # setup our HTTP class
      uri = URI.parse(url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = @ssl
      http.verify_mode = @ssl_verify

      # create our request
      req = net_http_request_class(method).new(uri)
      req.basic_auth(@username, @password) if @username && @password

      # copy headers into the request
      headers.each { |k, v| req[k] = v }
      # set the body in the request
      req.body = body if body

      # execute
      resp = http.request(req)

      # check response for success, redirect or error
      case resp
      when Net::HTTPSuccess then
        resp
      when Net::HTTPRedirection then
        execute(method, resp['location'],
                body: body, headers: headers,
                redirect_limit: redirect_limit - 1)
      else
        message = 'code=' + resp.code
        message += ' message=' + resp.message
        message += ' body=' + resp.body
        raise resp.error_type.new(message, resp)
      end
    end

    def net_http_request_class(method)
      Net::HTTP.const_get(method.capitalize, false)
    end

    def ip?(str)
      IPAddr.new(str)
      true
    rescue
      false
    end

    def get(url, body: nil, headers: @headers)
      execute('get', url, body: body, headers: headers, redirect_limit: @redirect_limit)
    end

    def post(url, body: nil, headers: @headers)
      execute('post', url, body: body, headers: headers, redirect_limit: @redirect_limit)
    end

    def delete(url, body: nil, headers: @headers)
      execute('delete', url, body: body, headers: headers, redirect_limit: @redirect_limit)
    end
  end
end
