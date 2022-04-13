# Plex Nginx Reverse Proxy
 
This configuration will allow you to serve Plex via Nginx behind CloudFlare

 * Originally based on https://github.com/toomuchio/plex-nginx-reverseproxy
 * Build script based on https://github.com/MatthewVance/nginx-build

## Features

```
nginx version: nginx/1.21.7 (04132022-131108-UTC-[debian_nginx-quic_quictls])
built by gcc 11.2.0 (GCC)
built with OpenSSL 3.0.2+quic 15 Mar 2022
TLS SNI support enabled
configure arguments: --build=04132022-131108-UTC-[debian_nginx-quic_quictls] --prefix=/etc/nginx --with-cc-opt='-I/usr/local/include -m64 -march=native -DTCP_FASTOPEN=23 -falign-functions=32 -g -O3 -Wno-error=strict-aliasing -Wno-vla-parameter -fstack-protector-strong -flto=8 -fuse-ld=gold --param=ssp-buffer-size=4 -Wformat -Werror=format-security -Wno-error=pointer-sign -Wimplicit-fallthrough=0 -fcode-hoisting -Wp,-D_FORTIFY_SOURCE=2 -Wno-deprecated-declarations' --with-ld-opt='-Wl,-E -L/usr/local/lib -ljemalloc -Wl,-z,relro -Wl,-rpath,/usr/local/lib -flto=8 -fuse-ld=gold' --with-openssl=../openssl --with-openssl-opt='no-weak-ssl-ciphers no-ssl2 no-ssl3 no-idea no-err no-srp no-psk no-nextprotoneg enable-ktls enable-zlib enable-ec_nistp_64_gcc_128' --with-zlib=../zlib --with-pcre=../pcre-8.45 --sbin-path=/usr/sbin/nginx --modules-path=/usr/lib/nginx/modules --conf-path=/etc/nginx/nginx.conf --error-log-path=/var/log/nginx/error.log --http-log-path=/var/log/nginx/access.log --pid-path=/var/run/nginx.pid --lock-path=/var/run/nginx.lock --http-client-body-temp-path=/var/cache/nginx/client_temp --http-proxy-temp-path=/var/cache/nginx/proxy_temp --http-fastcgi-temp-path=/var/cache/nginx/fastcgi_temp --http-uwsgi-temp-path=/var/cache/nginx/uwsgi_temp --http-scgi-temp-path=/var/cache/nginx/scgi_temp --user=nginx --group=nginx --with-file-aio --with-threads --with-libatomic --with-http_ssl_module --with-http_v2_module --with-http_v3_module --with-http_realip_module --add-module=../ngx_brotli --add-module=../headers-more-nginx-module-0.33 --without-http_charset_module --without-http_ssi_module --without-http_auth_basic_module --without-http_mirror_module --without-http_autoindex_module --without-http_userid_module --without-http_geo_module --without-http_split_clients_module --without-http_referer_module --without-http_fastcgi_module --without-http_uwsgi_module --without-http_scgi_module --without-http_grpc_module --without-http_memcached_module --without-http_limit_conn_module --without-http_limit_req_module --without-http_empty_gif_module --without-http_browser_module --without-http_upstream_hash_module --without-http_upstream_ip_hash_module --without-http_upstream_least_conn_module --without-http_upstream_zone_module --without-mail_imap_module --without-mail_pop3_module --without-mail_smtp_module
```

 * nginx-quic 1.21.7 - https://hg.nginx.org/nginx-quic
 * openssl-3.0.2+quic - quictls: https://github.com/quictls/openssl/tree/openssl-3.0.2+quic
 * Kernel TLS - https://www.nginx.com/blog/improving-nginx-performance-with-kernel-tls
 * QUIC transport protocol and HTTP/3 - https://www.nginx.com/blog/introducing-technology-preview-nginx-support-for-quic-http-3/
 * Add HTTP2 HPACK Encoding Support - https://blog.cloudflare.com/hpack-the-silent-killer-feature-of-http-2/
 * Add Dynamic TLS Record support - https://blog.cloudflare.com/optimizing-tls-over-tcp-to-reduce-latency/
 * Hide Server Signature - https://github.com/torden/ngx_hidden_signature_patch 
 * brotli compression support - https://github.com/google/ngx_brotli
 * More Headers - https://github.com/openresty/headers-more-nginx-module
 * Cloudflare ZLIB - https://github.com/cloudflare/zlib
 * Prevents public access to PMS built-in web interface
 * tmpfs cache (1GB) for Plex images
 
## Requirements
 
Plex:
* Remote Access - Disable
* Network - Custom server access URLs = `https://<your-domain>:443,http://<your-domain>:80`
* Network - Secure connections = Preferred

System: 
* Debian Bullseye x64 (11)
* Custom kernel with Kernel TLS module (CONFIG_TLS=y) - https://www.nginx.com/blog/improving-nginx-performance-with-kernel-tls
* tmpfs for cache - add "tmpfs /var/cache/nginx/ram_cache/ tmpfs defaults,size=1024M 0 0" to fstab

* gcc 11.2.0 

```
Using built-in specs.
COLLECT_GCC=gcc
COLLECT_LTO_WRAPPER=/usr/local/gcc-11.2.0/libexec/gcc/x86_64-linux-gnu/11.2.0/lto-wrapper
Target: x86_64-linux-gnu
Configured with: ../gcc-11.2.0/configure -v --build=x86_64-linux-gnu --host=x86_64-linux-gnu --target=x86_64-linux-gnu --prefix=/usr/local/gcc-11.2.0 --with-system-zlib --enable-checking=release --enable-languages=c,c++,d,fortran,go,objc,obj-c++ --disable-multilib --program-suffix=-11.2
Thread model: posix
Supported LTO compression algorithms: zlib
gcc version 11.2.0 (GCC)
```

Cloudflare:
* SSL: https://support.cloudflare.com/hc/en-us/categories/200276247-SSL-TLS
* Disable ipv6 connectivity

iptables:
* Deny port 32400 externally (Plex still pings over 32400, some clients may use 32400 by mistake despite 443 and 80 being set)
* Note adding `allowLocalhostOnly="1"` to your Preferences.xml, will make Plex only listen on the localhost, achieving the same thing as using a firewall
* Only allow CloudFlare IPs via iptables using ipset

```
ipset create cf hash:net
for x in $(curl https://www.cloudflare.com/ips-v4); do ipset add cf $x; done
iptables -A INPUT -p tcp -m tcp --dport 32400 -j DROP
iptables -A INPUT -m set --match-set cf src -p tcp -m multiport --dports http,https -j ACCEPT
iptables -A INPUT -m set --match-set cf src -p udp -m multiport --dports https -j ACCEPT
```
