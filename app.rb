require 'bundler/setup'
require 'oauth2'
require 'sinatra/base'
require 'sinatra/reloader'
require 'pco_api'
require 'erb'
require 'time'

class ExampleApp < Sinatra::Base
  OAUTH_APP_ID = 'app id goes here'
  OAUTH_SECRET = 'secret goes here'
  SCOPE = 'people'

  enable :sessions
  set :session_secret, 'super secret - BE SURE TO CHANGE THIS'

  configure :development do
    register Sinatra::Reloader
  end

  def client
    OAuth2::Client.new(
      OAUTH_APP_ID,
      OAUTH_SECRET,
      site: 'http://api.pco.dev'
    )
  end

  def token
    return if session[:token].nil?
    token = OAuth2::AccessToken.from_hash(client, session[:token].dup)
    if token.expired? && token.refresh_token
      token = token.refresh!
      session[:token] = token.to_hash
    end
    token
  end

  def api
    PCO::API.new(url: 'http://api.pco.dev', oauth_access_token: token.token)
  end

  get '/' do
    if token
      begin
        people = api.people.v2.people.get
      rescue PCO::API::Errors::Unauthorized
        # token expired or revoked
        session[:token] = nil
        redirect '/'
      else
        erb "<a href='/auth/logout'>log out</a><br><pre>#{JSON.pretty_generate(people)}</pre>"
      end
    else
      erb "<a href='/auth'>authenticate with API</a>"
    end
  end

  get '/auth' do
    url = client.auth_code.authorize_url(
      scope: SCOPE,
      redirect_uri: 'http://localhost:4567/auth/complete'
    )
    redirect url
  end

  get '/auth/complete' do
    token = client.auth_code.get_token(
      params[:code],
      redirect_uri: 'http://localhost:4567/auth/complete'
    )
    session[:token] = token.to_hash
    redirect '/'
  end

  get '/auth/logout' do
    api.oauth.revoke.post(token: token.token)
    redirect '/'
  end

  run! if app_file == $0
end
