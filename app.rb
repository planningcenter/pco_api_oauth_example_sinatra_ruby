# frozen_string_literal: true

require 'bundler/setup'
require 'cgi'
require 'erb'
require 'oauth2'
require 'pco_api'
require 'sinatra/base'
require 'sinatra/reloader'
require 'time'

class ExampleApp < Sinatra::Base
  OAUTH_APP_ID = ENV.fetch('OAUTH_APP_ID').freeze
  OAUTH_SECRET = ENV.fetch('OAUTH_SECRET').freeze
  SCOPE = ENV.fetch('SCOPE', 'people services').freeze
  DOMAIN = ENV.fetch('DOMAIN', 'http://localhost:4567').freeze
  API_URL = ENV.fetch('API_URL', 'https://api.planningcenteronline.com').freeze

  TOKEN_EXPIRATION_PADDING = 300 # go ahead and refresh a token if it's within this many seconds of expiring

  enable :sessions
  set :session_secret, ENV.fetch('SESSION_SECRET')

  configure :development do
    register Sinatra::Reloader
  end

  helpers do
    def h(html)
      CGI.escapeHTML html
    end
  end

  def client
    OAuth2::Client.new(OAUTH_APP_ID, OAUTH_SECRET, site: API_URL)
  end

  def token
    return if session[:token].nil?
    token = OAuth2::AccessToken.from_hash(client, session[:token].dup)
    if token.expires? && (token.expires_at < Time.now.to_i + TOKEN_EXPIRATION_PADDING) && token.refresh_token
      # looks like our token will expire soon and we have a refresh token,
      # so let's get a new access token
      token = token.refresh!
      session[:token] = token.to_hash
    end
    token
  rescue OAuth2::Error
    # our token info is bad, let's start over
    session[:token] = nil
  end

  def api
    PCO::API.new(oauth_access_token: token.token, url: API_URL)
  end

  get '/' do
    if token
      redirect '/people'
    else
      erb :login
    end
  end

  get '/people' do
    if token
      @logged_in = true
      begin
        response = api.people.v2.people.get
      rescue PCO::API::Errors::Unauthorized
        # token probably revoked
        session[:token] = nil
        redirect '/'
      else
        @people = response['data']
        @formatted_response = JSON.pretty_generate(response)
        erb :people
      end
    else
      redirect '/'
    end
  end

  get '/auth' do
    # redirect the user to PCO where they can authorize our app
    url = client.auth_code.authorize_url(
      scope: SCOPE,
      redirect_uri: "#{DOMAIN}/auth/complete"
    )
    redirect url
  end

  get '/auth/complete' do
    # user was redirected back after they authorized our app
    token = client.auth_code.get_token(
      params[:code],
      redirect_uri: "#{DOMAIN}/auth/complete"
    )
    # store the auth token and refresh token info in our session
    session[:token] = token.to_hash
    redirect '/'
  end

  get '/auth/logout' do
    # make an api call to PCO to revoke the access token
    api.oauth.revoke.post(
      token: token.token,
      client_id: OAUTH_APP_ID,
      client_secret: OAUTH_SECRET
    )
    session.clear
    redirect '/'
  end

  run! if app_file == $PROGRAM_NAME
end
