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

iptables:
* Deny port 32400 externally (Plex still pings over 32400, some clients may use 32400 by mistake despite 443 and 80 being set).
* Note adding `allowLocalhostOnly="1"` to your Preferences.xml, will make Plex only listen on the localhost, achieving the same thing as using a firewall.
* Only allow CloudFlare IPs via iptables using ipset

```
ipset create cf hash:net
for x in $(curl https://www.cloudflare.com/ips-v4); do ipset add cf $x; done
iptables -A INPUT -m set --match-set cf src -p tcp -m multiport --dports http,https -j ACCEPT
