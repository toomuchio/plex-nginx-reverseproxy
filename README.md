# Plex Nginx Reverse Proxy
 
This configuration will allow you to run Plex over port 443(HTTPS) with Nginx.
 
## Minimal Requirements
 
Nginx
 
Plex:
* Remote Access - Manually specify public port = 443
* Network - Custom server access URLs = https://plex.EXAMPLE.COM:443
 
## Optional Requirements
 
UFW or other firewall:
* Deny port 32400 externally (Plex still pings over 32400, some clients may use 32400 dispite 443 being set by mistake).
 
CloudFlare:
* SSL set to at least Full.
* Firewall disabled if an abnormal amount of load is expected.
