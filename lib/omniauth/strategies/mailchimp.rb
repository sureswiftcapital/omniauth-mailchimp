require 'omniauth/strategies/oauth2'
require 'multi_json'

module OmniAuth
  module Strategies
    class Mailchimp < OmniAuth::Strategies::OAuth2

      option :name, "mailchimp"

      option :client_options, {
        :site => "https://login.mailchimp.com",
        :authorize_url => '/oauth2/authorize',
        :token_url => '/oauth2/token',
        :auth_scheme => :request_body
      }

      option :auth_token_params, {
        :expires_at => 100.years.from_now
      }

      def request_phase
        req = Rack::Request.new(@env)
        options.update(req.params)
        super
      end

      uid {
        user_data['user_id']
      }

      info do
        {
          :email => raw_info["email"],
          :username => raw_info["username"],
          :account_name => user_data["accountname"],
          :api_endpoint => user_data["api_endpoint"],
          :dc => user_data["dc"]
        }
      end

      extra do
        {
          :metadata => user_data,
          :raw_info => raw_info
        }
      end

      def raw_info
        @raw_info ||= begin
          data = user_data
          endpoint = data["api_endpoint"]
          apikey = "#{@access_token.token}-#{data['dc']}"
          response = @access_token.get("#{endpoint}/3.0/").parsed
          if response["error"]
            case response["code"]
            when 109
              fail!(:invalid_credentials, response["error"])
            end
          else
            response
          end
        end
      end

      def user_data
        @data ||= MultiJson.decode(@access_token.get("https://login.mailchimp.com/oauth2/metadata").body)
      rescue ::OAuth2::Error => e
        if e.response.status == 302
          @data ||= MultiJson.decode(@access_token.get(e.response.headers['location']))
        else
          raise e
        end
      end
    end
  end
end
