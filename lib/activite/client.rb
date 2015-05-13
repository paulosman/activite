require 'activite/error'
require 'activite/http/request'
require 'activite/activity'
require 'activite/measurement_group'
require 'activite/notification'
require 'activite/sleep_series'
require 'activite/sleep_summary'
require 'activite/response'

module Activite
  class Client
    include Activite::HTTP::OAuthClient

    attr_writer :user_agent
    
    # Initializes a new Client object used to communicate with the Withings API.
    #
    # An authenticated Client can be created with an access token and access token
    # secret if the user has previously authorized access to their Withings account
    # and you've stored their access credentials. An unauthenticated Client can be
    # created that will allow you to initiate the OAuth authorization flow, directing
    # the user to Withings to authorize access to their account.
    #
    # @param options [Hash]
    # @option options [String] :consumer_key The consumer key (required)
    # @option options [String] :consumer_secret The consumer secret (required)
    # @option options [String] :token The access token (if you've stored it)
    # @option options [String] :secret The access token secret (if you've stored it)
    #
    # @example User has not yet authorized access to their Withings account
    #   client = Activite::Client.new({ consumer_key: your_key, consumer_secret: your_secret })
    #
    # @example User has authorized access to their Withings account
    #   client = Activite::Client.new({
    #     consumer_key: your_key,
    #     consumer_secret: your_secret,
    #     token: your_access_token,
    #     secret: your_access_token_secret
    #   })
    #
    # @example You can also pass parameters as a block
    #   client = Activite::Client.new do |config|
    #     config.consumer_key = your_key
    #     config.consumer_secret = your_secret
    #     config.token = token
    #     config.secret = secret
    #   end
    #
    # @return [Activite::Client]
    def initialize(options = {})
      options.each do |key, value|
        instance_variable_set("@#{key}", value)
      end

      yield(self) if block_given?

      unless @token.nil? || @secret.nil?
        @access_token = existing_access_token(@token, @secret)
      end
    end

    # Return the User-Agent string
    #
    # @return [String]
    def user_agent
      @user_agent ||= "WithingsRubyGem/#{Activite::VERSION}"
    end

    # Get a list of activity measures for the specified user
    #
    # @param user_id [Integer]
    # @param options [Hash]
    #
    # @return [Array<Activite::Activity>]
    def activities(user_id, options = {})
      perform_request(:get, '/v2/measure', Activite::Activity, 'activities', {
        action: 'getactivity',
        userid: user_id
      }.merge(options))
    end

    # Get a list of body measurements taken by Withings devices
    #
    # @param user_id [Integer]
    # @param options [Hash]
    #
    # @return [Array<Activite::MeasurementGroup>]
    def body_measurements(user_id, options = {})
      perform_request(:get, '/measure', Activite::MeasurementGroup, 'measuregrps', {
        action: 'getmeas',
        userid: user_id
      }.merge(options))
    end

    # Get details about a user's sleep
    #
    # @param user_id [Integer]
    # @param options [Hash]
    #
    # @return [Array<Activite::Sleep>]
    def sleep_series(user_id, options = {})
      perform_request(:get, '/v2/sleep', Activite::SleepSeries, 'series', {
        action: 'get',
        userid: user_id
      }.merge(options))
    end

    # Get a summary of a user's night. Includes the total time they slept,
    # how long it took them to fall asleep, how long it took them to fall
    # asleep, etc.
    #
    # NOTE: user_id isn't actually used in this API call (so I assume it is
    # derived from the OAuth credentials) but I was uncomfortable introducing
    # this inconsitency into this gem.
    #
    # @param user_id [Intger]
    # @param options [Hash]
    #
    # @return [Array<Activite::SleepSummary>]
    def sleep_summary(user_id, options = {})
      perform_request(:get, '/v2/sleep', Activite::SleepSummary, 'series', {
        action: 'getsummary'
      }.merge(options))
    end

    # Register a webhook / notification with the Withings API. This allows
    # you to be notified when new data is available for a user.
    #
    # @param user_id [Integer]
    # @param options [Hash]
    #
    # @return [Activite::Response]
    def create_notification(user_id, options = {})
      perform_request(:post, '/notify', Activite::Response, nil, {
        action: 'subscribe'
      }.merge(options))
    end

    # Get information about a specific webhook / notification.
    #
    # @param user_id [Integer]
    # @param options [Hash]
    #
    # @return [Activite::Notification]
    def get_notification(user_id, options = {})
      perform_request(:get, '/notify', Activite::Notification, nil, {
        action: 'get'
      }.merge(options))
    end

    # Return a list of registered webhooks / notifications.
    #
    # @param user_id [Integer]
    # @param options [Hash]
    #
    # @return [Array<Activite::Notification>]
    def list_notifications(user_id, options = {})
      perform_request(:get, '/notify', Activite::Notification, 'profiles', {
        action: 'list'
      }.merge(options))
    end

    # Revoke previously subscribed webhook / notification.
    #
    # @param user_id [Integer]
    # @param options [Hash]
    #
    # @return [Activite::Response]
    def revoke_notification(user_id, options = {})
      perform_request(:get, '/notify', Activite::Response, nil, {
        action: 'revoke'
      }.merge(options))
    end

    private

    # Helper function that handles all API requests
    #
    # @param http_method [Symbol]
    # @param path [String]
    # @param klass [Class]
    # @param key [String]
    # @param options [Hash]
    #
    # @return [Array<Object>]
    def perform_request(http_method, path, klass, key, options = {})
      if @consumer_key.nil? || @consumer_secret.nil?
        raise Activite::Error::ClientConfigurationError, "Missing consumer_key or consumer_secret"
      end
      options = Activite::Utils.normalize_date_params(options)
      request = Activite::HTTP::Request.new(@access_token, { 'User-Agent' => user_agent })
      response = request.send(http_method, path, options)
      if key.nil?
        klass.new(response)
      elsif response.has_key? key
        response[key].collect do |element|
          klass.new(element)
        end
      else
        [klass.new(response)]
      end
    end
  end
end