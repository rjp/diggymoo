diggymoo is a simple twitter-to-email-digest store-and-forward.

Configuration
=============
diggymoo relies on two configuration files.

.diggymoo contains the consumer_key and consumer_secret for OAuth. 

From https://dev.twitter.com/apps/MYAPPID:

    consumer_key: (Consumer key)
    consumer_secret: (Consumer secret)

.diggymoo.json contains the authentication tokens from OAuth. This file is
normally generated by a PIN-based OAuth call but can be generated by hand if
you want to use the assigned tokens from your own app. 

From https://dev.twitter.com/apps/MYAPPID/my_token:

    ---
    :acc: !ruby/object:OAuth::AccessToken
      token: (oauth_token goes here)
      secret: (oauth_token_secret goes here)

The second line must be copied exactly.

Usage
=====
diggy-fetcher.rb performs the actual collection of tweets and inserts them
into Redis for storing.

diggy-mailer.rb retrieves queued tweets from Redis and bundles them into
a HTML email which can be passed directly to `sendmail -t`. The destination
email address is specified as the --email option (defaults to `$USER@browser.org`.