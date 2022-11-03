# frozen_string_literal: true

require 'bundler/setup'
require 'cgi'
require 'erb'
require 'jwt'
require 'oauth2'
require 'pco_api'
require 'sequel'
require 'sinatra/base'
require 'sinatra/reloader'
require 'time'

class ExampleApp < Sinatra::Base
  OAUTH_APP_ID = ENV.fetch('OAUTH_APP_ID').freeze
  OAUTH_SECRET = ENV.fetch('OAUTH_SECRET').freeze
  HMAC_SECRET = OAUTH_SECRET[0...100]
  SCOPE = ENV.fetch('SCOPE', 'people').freeze
  DOMAIN = ENV.fetch('DOMAIN', 'http://localhost:4567').freeze
  API_URL = 'http://api.pco.test'

  DB = Sequel.sqlite('data.sqlite3')

  unless DB.table_exists?(:tokens)
    DB.create_table :tokens do
      primary_key :id
      Integer :organization_id, unique: true, null: false
      String :token, null: false
    end
  end

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

  def build_token(hash, refresh: false)
    token = OAuth2::AccessToken.from_hash(client, hash.dup)
    if refresh || (token.expires? && (token.expires_at < Time.now.to_i + TOKEN_EXPIRATION_PADDING) && token.refresh_token)
      # looks like our token will expire soon and we have a refresh token,
      # so let's get a new access token
      token = token.refresh!
      id = update_token_in_db(token)
      session[:token_id] = id
    end
    token
  rescue OAuth2::Error
    # our token info is bad, let's start over
    session[:token_id] = nil
  end

  def session_token(refresh: false)
    return unless (id = session[:token_id])

    row = DB[:tokens].where(id: id).first!
    build_token(JSON.parse(row[:token]), refresh: refresh)
  end

  def organization_token(organization_id, refresh: false)
    row = DB[:tokens].where(organization_id: organization_id).first!
    build_token(JSON.parse(row[:token]), refresh: refresh)
  end

  def api(token: session_token)
    PCO::API.new(oauth_access_token: token.token, url: API_URL)
  end

  ALLOWED_ORIGINS = %w[
    http://api.pco.test
    https://api-staging.planningcenteronline.com
    https://api.planningcenteronline.com
  ].freeze

  def origin
    request.env['HTTP_ORIGIN']
  end

  def add_cors_headers
    return unless ALLOWED_ORIGINS.include?(origin)

    headers(
      'Access-Control-Allow-Origin' => origin,
      'Access-Control-Allow-Methods' => 'POST'
    )
  end

  def update_token_in_db(token)
    organization_id = api(token: token).people.v2.me.get.dig('meta', 'parent', 'id')
    begin
      DB[:tokens].insert(organization_id: organization_id, token: token.to_hash.to_json)
    rescue Sequel::UniqueConstraintViolation
      DB[:tokens].where(organization_id: organization_id).update(token: token.to_hash.to_json)
      DB[:tokens].where(organization_id: organization_id).first[:id]
    end
  end

  def decode_identity(identity_jwt)
    JWT.decode(identity_jwt, HMAC_SECRET, true, { algorithm: 'HS256' }).first['data']
  end

  options '/add_background_check' do
    add_cors_headers
    head :ok
  end

  post '/add_background_check' do
    add_cors_headers

    # get data from POST body
    data = JSON.parse(request.body.read)
    person_id = data['personId']

    # verify and decode identity JWT
    identity = decode_identity(data['identity'])

    # find the OAuth token for this org in the db
    organization_id = identity.dig('org', 'id')
    token = organization_token(organization_id)

    # add the background check with the API
    api(token: token).people.v2.people[person_id].background_checks.post(
      data: {
        attributes: {
          status: 'report_clear'
        }
      }
    )

    content_type 'application/json'
    { status: :added }.to_json
  end

  options '/delete_background_check' do
    add_cors_headers
    head :ok
  end

  post '/delete_background_check' do
    add_cors_headers

    # get data from POST body
    data = JSON.parse(request.body.read)
    person_id = data['personId']

    # verify and decode identity JWT
    identity = decode_identity(data['identity'])

    # find the OAuth token for this org in the db
    organization_id = identity.dig('org', 'id')
    token = organization_token(organization_id)

    # remove the background check with the API
    checks = api(token: token).people.v2.people[person_id].background_checks.get
    checks['data'].each do |check|
      api(token: token).people.v2.people[person_id].background_checks[check.fetch('id')].delete
    end

    content_type 'application/json'
    { status: :deleted }.to_json
  end

  get '/' do
    if (token = session_token)
      @me = api.people.v2.me.get
      @token = token.to_hash
      erb :index
    else
      erb :login
    end
  rescue PCO::API::Errors::Unauthorized
    # bad token, start over
    session[:token_id] = nil
    redirect '/'
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
    id = update_token_in_db(token)
    session[:token_id] = id
    redirect '/'
  end

  get '/auth/logout' do
    # make an api call to PCO to revoke the access token
    api.oauth.revoke.post(token: session_token.token)
    session.clear
    redirect '/'
  end

  get '/auth/refresh' do
    session_token(refresh: true)
    redirect '/'
  end

  run! if app_file == $PROGRAM_NAME
end
