# Plex Nginx Reverse Proxy
 
This configuration will allow you to serve Plex via Nginx.
 
## Minimal Requirements
 
Nginx
 
Plex:
* Remote Access - Disable
* Network - Custom server access URLs = `https://<your-domain>:443`
* Network - Secure connections = Preferred (For player support (LG Smart TV ect..), can be required if needed).
 
## Optional Requirements
 
UFW or other firewall:
* Deny port 32400 externally (Plex still pings over 32400, some clients may use 32400 by mistake despite 443 being set).
 
CloudFlare:
* SSL set to at least Full.
* Firewall disabled if an abnormal amount of load is expected.
