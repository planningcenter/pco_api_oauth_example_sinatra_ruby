# PCO API OAuth Example - Sinatra + Ruby

This is an example Sinatra app for demonstrating how one might build an app to authenticate any PCO user
and then subsequently use that authentication to query the API using [pco_api](https://github.com/planningcenter/pco_api_ruby).

You can learn more about Planning Center's API [here](https://developer.planning.center/docs).

## Setup

1. Create an app at [api.planningcenteronline.com](https://api.planningcenteronline.com/oauth/applications).

   Set the callback URL to be `http://localhost:4567/auth/complete`.

2. Install the required gems:

   ```bash
   bundle install
   ```

3. Set your Application ID and Secret in the environment and run the app:

   ```bash
   export OAUTH_APP_ID=abcdef0123456789abcdef0123456789abcdef012345789abcdef0123456789a
   export OAUTH_SECRET=0123456789abcdef0123456789abcdef012345789abcdef0123456789abcdef0
   export SESSION_SECRET=some-secret-phrase-for-session-cookie-encryption
   ruby app.rb
   ```

4. Visit [localhost:4567](http://localhost:4567).

## Copyright & License

Copyright Ministry Centered Technologies. Licensed MIT.
