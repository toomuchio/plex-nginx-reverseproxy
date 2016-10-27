# plex-nginx-reverseproxy

This is useful for running Plex over port 443(HTTPS), it's important to go to your Plex server settings and change the following settings.

Remote Access - Manually specify public port = 443

Network - Custom server access URLs = https://plex.EXAMPLE.COM:443

Doing this also allows you to run CloudFlare in front of your Plex server which can improve peering.
