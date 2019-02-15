# Plex Nginx Reverse Proxy
 
This configuration will allow you to serve Plex via Nginx behind CloudFlare
 
## Minimal Requirements
 
Nginx (https://github.com/the-archive/plex-nginx-reverseproxy-cf/blob/develop/build-nginx.sh)
 
Plex:
* Remote Access - Disable
* Network - Custom server access URLs = `https://<your-domain>:443,http://<your-domain>:80`
* Network - Secure connections = Preferred.
 
## Requirements

Cloudflare:
* Disable ipv6 connectivity

UFW or other firewall:
* Deny port 32400 externally (Plex still pings over 32400, some clients may use 32400 by mistake despite 443 and 80 being set).
* Note adding `allowLocalhostOnly="1"` to your Preferences.xml, will make Plex only listen on the localhost, achieving the same thing as using a firewall.
* Only allow CloudFlare IPs via iptables

```
*filter
:cloudflare - [0:0]
-A INPUT -s 127.0.0.1/32 -p tcp -m tcp --dport 32400 -j ACCEPT
-A INPUT -p tcp -m tcp --dport 32400 -j DROP
-A INPUT -p tcp -m tcp --dport 80 -j cloudflare
-A INPUT -p tcp -m tcp --dport 443 -j cloudflare
-A cloudflare -s 103.21.244.0/22 -j ACCEPT
-A cloudflare -s 103.22.200.0/22 -j ACCEPT
-A cloudflare -s 103.31.4.0/22 -j ACCEPT
-A cloudflare -s 104.16.0.0/12 -j ACCEPT
-A cloudflare -s 108.162.192.0/18 -j ACCEPT
-A cloudflare -s 141.101.64.0/18 -j ACCEPT
-A cloudflare -s 162.158.0.0/15 -j ACCEPT
-A cloudflare -s 172.64.0.0/13 -j ACCEPT
-A cloudflare -s 173.245.48.0/20 -j ACCEPT
-A cloudflare -s 188.114.96.0/20 -j ACCEPT
-A cloudflare -s 190.93.240.0/20 -j ACCEPT
-A cloudflare -s 197.234.240.0/22 -j ACCEPT
-A cloudflare -s 198.41.128.0/17 -j ACCEPT
-A cloudflare -j DROP
