require "httpclient"
require "pathname"

module Embulk
  module Input
    module SfdcApi
      class InternalServerError < StandardError; end

      class Api
        DEFAULT_LOGIN_URL = "https://login.salesforce.com".freeze

        attr_reader :client

        def setup(login_url, config)
          token = authentication(login_url, config)
          set_latest_version(token)
          self
        end

        def initialize
          @version_path = ""
          @client = HTTPClient.new
          # @client.debug_dev = STDERR
          @client.default_header = {Accept: 'application/json; charset=UTF-8'}
          @client.ssl_config.ssl_version = "TLSv1.2"
        end

        def get(path, parameters={})
          response = catch_unretryable_error do
            client.get(path, parameters)
          end
          handle_error(response)
          JSON.parse(response.body)
        end

        def get_metadata(sobject_name)
          get(@version_path.join("sobjects/#{sobject_name}/describe").to_s)
        end

        def search(soql)
          get(@version_path.join("query").to_s, {q: soql})
        end

        private

        def catch_unretryable_error(&block)
          # if can't resolve a problem with retry, should raise ConfigError to tell Embulk
          begin
            yield
          rescue SocketError => e # probably login_url is wrong
            raise ConfigError.new "SocketError: #{e.message}"
          end
        end

        def authentication(login_url, _config)
          # NOTE: At SfdcInputPlugin#init, we use Symbol as each key
          #       for task (Hash), but at SfdcInputPlugin#run, task
          #       has them as String...:(
          #       So, I translate keys from String to Symbol
          config = {}
          _config.each { |key, value| config[key.to_sym] = value }

          params = {
            grant_type: 'password',
            client_id: config[:client_id],
            client_secret: config[:client_secret],
            username: config[:username],
            password: config[:password] + config[:security_token]
          }

          oauth_response = catch_unretryable_error do
            @client.post(URI.join(login_url, "services/oauth2/token").to_s, params)
          end
          handle_error(oauth_response)
          oauth = JSON.parse(oauth_response.body)

          client.base_url = oauth["instance_url"]

          oauth["access_token"]
        end

        def set_latest_version(access_token)
          versions_response = @client.get("/services/data")
          # Use latest version always
          @version_path = Pathname.new(JSON.parse(versions_response.body).last["url"])

          client.default_header = client.default_header.merge(Authorization: "Bearer #{access_token}")

          self
        end

        def handle_error(response)
          code = response.status_code

          case code
          when 400..499
            message = "StatusCode: #{code}"

            body = nil
            begin
              body = JSON.parse(response.body)
            rescue
              # Sometimes SFDC returns non-json response
              # https://github.com/treasure-data/embulk-input-sfdc/issues/35
              message << ": #{response.body}"
              raise ConfigError.new message
            end

            message << ": #{body['errorCode']}" if body["errorCode"]
            message << ": #{body['message']}" if body["message"]
            case body["errorCode"]
            when "INVALID_QUERY_LOCATOR", "QUERY_TIMEOUT"
              # will be retried
              raise message
            else
              # won't retry
              raise ConfigError.new message
            end
          when 500..599
            raise SfdcApi::InternalServerError, "Force.com REST API returns 500 (Internal Server Error). Please contact customer support of Force.com."
          end
        end
      end
    end
  end
end
