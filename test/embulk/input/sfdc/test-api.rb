require "embulk/input/sfdc/api"

module Embulk
  module Input
    module Sfdc
      class ApiTest < Test::Unit::TestCase
        def setup
          @api = Sfdc::Api.new
        end

        def test_initialize
          assert_true(@api.client.is_a?(HTTPClient))
          assert_equal({Accept: 'application/json; charset=UTF-8'}, @api.client.default_header)
        end

        class SetupTest < self
          def test_setup
            any_instance_of(Sfdc::Api) do |klass|
              mock(klass).authentication(login_url, config) { "access_token" }
              mock(klass).set_latest_version("access_token") { klass }
            end

            @api.setup(login_url, config)

            assert_true(Sfdc::Api.new.setup(login_url, config).instance_of?(Sfdc::Api))
          end

          def test_authentication
            mock(@api.client).post("#{login_url}/services/oauth2/token", params) do |res|
              mock(res).body { authentication_response }
            end
            mock(@api).set_latest_version("access_token") { @api }

            @api.setup(login_url, config)

            assert_equal(instance_url, @api.client.base_url)
          end

          def test_set_latest_version
            stub(@api).authentication(login_url, config) do
              @api.client.base_url = instance_url
              "access_token"
            end

            mock(@api.client).get("/services/data") do |res|
              mock(res).body do
                [
                  {"label"=>"first", "url"=>"/services/data/v1.0", "version"=>"1.0"},
                  {"label"=>"second", "url"=>version_path, "version"=>"2.0"}].to_json
              end
            end

            @api.setup(login_url, config)

            assert_equal(version_path, @api.instance_variable_get(:@version_path))
          end
        end

        def test_get_metadata
          setup_api_stub

          @api.setup(login_url, config)

          metadata = {"metadata" => "is here"}
          mock(@api.client).get(version_path.join("sobjects/custom__c/describe").to_s) do |res|
            mock(res).body do
              metadata.to_json
            end
          end

          assert_equal(metadata, @api.get_metadata("custom__c"))
        end

        def test_search
          setup_api_stub

          @api.setup(login_url, config)

          hit_object = {"Name" => "object1"}
          objects = [hit_object, {"Name" => "object2"}]
          soql = "SELECT name FROM custom__c WHERE Name='object1'"

          mock(@api.client).get(version_path.join("query").to_s, {q: soql}) do |res|
            mock(res).body { hit_object.to_json }
          end

          assert_equal(hit_object, @api.search(soql))
        end

        class GetTest < self
          def setup
            super
          end

          def test_success
            result = {"statusCode" => "OK"}
            path = "success"
            mock(@api.client).get(path, {}) do |res|
              mock(res).body { result.to_json }
            end

            assert_equal(result, @api.get(path))
          end

          def test_success_with_parameters
            result = {"statusCode" => "OK"}
            path = "success"
            parameters = {"parameter" => "is OK"}

            mock(@api.client).get(path, parameters) do |res|
              mock(res).body { result.to_json }
            end

            assert_equal(result, @api.get(path, parameters))
          end

          # TODO: add the test by error after implemented error-handling
        end

        private

        def login_url
          "https://login-sfdc.com"
        end

        def config
          {
            client_id: "client_id",
            client_secret: "client_secret",
            username: "username",
            password: "password",
            security_token: "security_token",
          }
        end

        def params
          {
            grant_type: "password",
            client_id: config[:client_id],
            client_secret: config[:client_secret],
            username: config[:username],
            password: config[:password] + config[:security_token]
          }
        end

        def authentication_response
          {
            "instance_url" => instance_url,
            "access_token" => "access_token"
          }.to_json
        end

        def instance_url
          "https://instance-url.com"
        end

        def version_path
          Pathname.new("/services/data/v2.0")
        end

        def setup_api_stub
          stub(@api).setup(login_url, config) do
            @api.client.base_url = instance_url
            @api.instance_variable_set(:@version_path, version_path)
            @api.client.default_header = {Accept: 'application/json; charset=UTF-8', Authorization: "Bearer access_token"}
            @api
          end
        end
      end
    end
  end
end
