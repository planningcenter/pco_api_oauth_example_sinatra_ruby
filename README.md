# PCO API OAuth Example

This is an example Sinatra app for demonstrating how one might build an app to authenticate any PCO user
and then subsequently use that authentication to query the API using [pco_api](https://github.com/planningcenter/pco_api_ruby).

NOTE: This app talks to our v2 API, documented at [planningcenter.github.io/api-docs](https://planningcenter.github.io/api-docs).

## Setup

1. Create an app at [api.planningcenteronline.com](https://api.planningcenteronline.com/oauth/applications).

   Set the callback URL to be `http://localhost:4567/auth/complete`.

2. Edit `app.rb` and include your app id and secret.

3. Install the required gems and start the app:

   ```
   bundle install
   OAUTH_APP_ID=myclientid OAUTH_SECRET=mysecret ruby app.rb
   ```

4. Visit [localhost:4567](http://localhost:4567).

## Copyright & License

Copyright 2015, Ministry Centered Technologies. Licensed MIT.
