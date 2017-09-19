# Plex Nginx Reverse Proxy
 
This configuration will allow you to serve Plex via Nginx.
 
## Minimal Requirements
 
Nginx
 
Plex:
* Remote Access - Disable
* Network - Custom server access URLs = `https://<your-domain>:443,http://<your-domain>:80`
* Network - Secure connections = Preferred.
* ![#f03c15](https://placehold.it/15/f03c15/000000?text=+) `Note you can force SSL by setting required and not adding the HTTP URL, however some players which do not support HTTPS (e.g: Roku, Playstations, some SmartTVs) will no longer function.`
 
## Optional Requirements
 
UFW or other firewall:
* Deny port 32400 externally (Plex still pings over 32400, some clients may use 32400 by mistake despite 443 and 80 being set).

