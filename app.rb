require 'bundler/setup'
require 'oauth2'
require 'sinatra'
require 'pco_api'
require 'erb'

enable :sessions
set :session_secret, 'super secret'

OAUTH_APP_ID = 'app id goes here'
OAUTH_SECRET = 'secret goes here'
SCOPE = 'people'

client = OAuth2::Client.new(
  OAUTH_APP_ID,
  OAUTH_SECRET,
  site: 'https://api.planningcenteronline.com'
)

def api
  PCO::API.new(oauth_access_token: session[:token])
end

get '/' do
  if session[:token]
    begin
      people = api.people.v2.people.get
    rescue PCO::API::Errors::Unauthorized
      # token expired or revoked
      session[:token] = nil
      redirect '/?token=expired'
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
  session[:token] = token.token
  redirect '/'
end

get '/auth/logout' do
  api.oauth.revoke.post(token: session[:token])
  redirect '/'
end
