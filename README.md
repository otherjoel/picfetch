# `picfetch`: Cross-publish statuses/pics from Mastodon

This is a Racket script that will poll a Mastodon account, find the latest status with a specified
hashtag that also has an image attachment, and save the image and metadata locally. I use this for
the [Latest Weather page](https://joeldueck.com/mnwx.html) on my website. I can post a pic to
Mastodon from my phone and it shows up on that page within a minute.

I recommend looking through `fetch.rkt`: the code is short and sweet.

You are free to use modify this code however you want, as long as you [give credit](LICENSE.md).

## Setup

Clone the repository.

Install dependencies: `raco pkg install http-easy threading`.

Rename `options.example.ini` to `options.ini` and fill in your own options.

You will need [your Mastodon account ID](https://prouser123.me/mastodon-userid-lookup/) and an API
access token.

To get an API access token, go to your Mastodon instance and go to *Preferences* → *Development* and
click **New Application**. Give the app a name like “Pic Fetcher” and select only the `Read` scope.
Mastodon will set you up with three gnarly-lookin values, the one you want is “Your access token”.

## Cross-compiling and deploying to a Linux server

You could install Racket on the web server and use it to run this program. What I do instead is
cross-compile to a Linux executable and package this in a distribution folder containing all the
dependencies. This way I never have to manage a Racket installation on any machine but my own
laptop.

On my M1 Mac, I cross-compile as follows. The first two commands are only needed once.

    raco cross pkg install http-easy-lib threading-lib
    raco cross --target x86_64-linux pkg install http-easy-lib threading-lib
    raco cross --target x86_64-linux exe fetch.rkt
    raco cross --target x86_64-linux dist picfetch-dist fetch

At this point I have a `picfetch-dist` folder which I can upload to my web server. After uploading,
I dig around inside that folder for the `options.ini` file and ensure it uses the correct output
paths (inside my public web folder).

## Creating a system service on the web server

Do `sudo vim /etc/systemd/system/picfetch.service` and save the file with this content (editing the
`ExecStart` path and `User` to match your environment):

    [Unit]
    Description=Monitor Mastodon for new mnwx pics
    DefaultDependencies=no
    After=network.target
    StartLimitIntervalSec=0

    [Service]
    ExecStart=/home/me/picfetch-dist/bin/fetch
    User=me
    Type=simple
    Restart=always
    RestartSec=1

    [Install]
    WantedBy=multi-user.target

Now you can do `sudo systemctl start picfetch` and `sudo systemctl enable picfetch` to start the
program in the background.

You can monitor the background service with, e.g., `journalctl -u picfetch.service`.
