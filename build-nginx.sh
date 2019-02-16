#!/usr/bin/env bash
# Run as root or with sudo
if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root or with sudo."
  exit 1
fi

# Make script exit if a simple command fails and
# Make script print commands being executed
set -e -x

# Set names of latest versions of each package
version_pcre=pcre-8.42
version_zlib=zlib-1.2.11
version_openssl=openssl-1.1.1a
version_libressl=libressl-2.8.3
version_nginx=nginx-1.15.8
version_headers=0.33

# Set checksums of latest versions
sha256_pcre=69acbc2fbdefb955d42a4c606dfde800c2885711d2979e356c0636efde9ec3b5
sha256_zlib=c3e5e9fdd5004dcb542feda5ee4f0ff0744628baf8ed2dd5d66f8ca1197cb1a1
sha256_openssl=fc20130f8b7cbd2fb918b2f14e2f429e109c31ddd0fb38fc5d71d9ffed3f9f41
sha256_nginx=a8bdafbca87eb99813ae4fcac1ad0875bf725ce19eb265d28268c309b2b40787
sha256_headers=a3dcbab117a9c103bc1ea5200fc00a7b7d2af97ff7fd525f16f8ac2632e30fbf

# Set URLs to the source directories
source_pcre=https://ftp.pcre.org/pub/pcre/
source_zlib=https://zlib.net/
source_openssl=https://www.openssl.org/source/
source_libressl=https://ftp.openbsd.org/pub/OpenBSD/LibreSSL/
source_nginx=https://nginx.org/download/
source_brotli=https://github.com/eustas/ngx_brotli
source_headers=https://github.com/openresty/headers-more-nginx-module/archive/v
source_dyntls=https://raw.githubusercontent.com/kn007/patch/master/nginx.patch
source_chacha=https://raw.githubusercontent.com/kn007/patch/master/nginx_auto_using_PRIORITIZE_CHACHA.patch

# Set where OpenSSL and NGINX will be built
bpath=$(pwd)/build

# Clean out any files from previous runs of this script
rm -rf \
  "$bpath" \
  /etc/nginx-default
mkdir "$bpath"

# Ensure the required software to compile NGINX is installed
apt-get update && apt-get -y install \
  binutils \
  build-essential \
  git \
  curl \
  wget

# Download the source files and verify their checksums
curl -L "${source_pcre}${version_pcre}.tar.gz" -o "${bpath}/pcre.tar.gz" && \
  echo "${sha256_pcre} ${bpath}/pcre.tar.gz" | sha256sum -c -
curl -L "${source_zlib}${version_zlib}.tar.gz" -o "${bpath}/zlib.tar.gz" && \
  echo "${sha256_zlib} ${bpath}/zlib.tar.gz" | sha256sum -c -
curl -L "${source_openssl}${version_openssl}.tar.gz" -o "${bpath}/openssl.tar.gz" && \
  echo "${sha256_openssl} ${bpath}/openssl.tar.gz" | sha256sum -c -
curl -L "${source_nginx}${version_nginx}.tar.gz" -o "${bpath}/nginx.tar.gz" && \
  echo "${sha256_nginx} ${bpath}/nginx.tar.gz" | sha256sum -c -
curl -L "${source_headers}${version_headers}.tar.gz" -o "${bpath}/headers.tar.gz" && \
  echo "${sha256_headers} ${bpath}/headers.tar.gz" | sha256sum -c -
cd "$bpath"
git clone $source_brotli
cd "$bpath/ngx_brotli"
git submodule update --init

# Expand the source files
cd "$bpath"
for archive in ./*.tar.gz; do
  tar xzf "$archive"
done

# Clean up source files
rm -rf \
  "$GNUPGHOME" \
  "$bpath"/*.tar.*

# Create NGINX cache directories if they do not already exist
if [ ! -d "/var/cache/nginx/" ]; then
  mkdir -p \
    /var/cache/nginx/client_temp \
    /var/cache/nginx/proxy_temp \
    /var/cache/nginx/fastcgi_temp \
    /var/cache/nginx/uwsgi_temp \
    /var/cache/nginx/scgi_temp
fi

# We add sites-* folders as some use them. /etc/nginx/conf.d/ is the vhost folder by defaultnginx
if [[ ! -d /etc/nginx/sites-available ]]; then
	mkdir -p /etc/nginx/sites-available
	curl https://raw.githubusercontent.com/the-archive/plex-nginx-reverseproxy-cf/master/sites-available/plex.domain.tld -o /etc/nginx/sites-available/plex.domain.tld
fi
if [[ ! -d /etc/nginx/sites-enabled ]]; then
	mkdir -p /etc/nginx/sites-enabled
fi

if [[ ! -e /etc/nginx/nginx.conf ]]; then
	mkdir -p /etc/nginx
	cd /etc/nginx || exit 1
	wget https://raw.githubusercontent.com/the-archive/plex-nginx-reverseproxy-cf/master/nginx.conf
fi

# Add NGINX group and user if they do not already exist
id -g nginx &>/dev/null || addgroup --system nginx
id -u nginx &>/dev/null || adduser --disabled-password --system --home /var/cache/nginx --shell /sbin/nologin --group nginx

# Test to see if our version of gcc supports __SIZEOF_INT128__
if gcc -dM -E - </dev/null | grep -q __SIZEOF_INT128__
then
  ecflag="enable-ec_nistp_64_gcc_128"
else
  ecflag=""
fi

# Build NGINX, with various modules included/excluded
cd "$bpath/$version_nginx"
wget $source_dyntls
wget $source_chacha
patch -p1 < nginx.patch
patch -p1 < nginx_auto_using_PRIORITIZE_CHACHA.patch
./configure \
  --prefix=/etc/nginx \
  --with-cc-opt="-O3 -fPIE -fstack-protector-strong -Wformat -Werror=format-security" \
  --with-ld-opt="-Wl,-Bsymbolic-functions -Wl,-z,relro" \
  --with-pcre="$bpath/$version_pcre" \
  --with-zlib="$bpath/$version_zlib" \
  --with-openssl-opt="no-weak-ssl-ciphers no-ssl3 no-shared $ecflag -DOPENSSL_NO_HEARTBEATS -fstack-protector-strong" \
  --with-openssl="$bpath/$version_openssl" \
  --sbin-path=/usr/sbin/nginx \
  --modules-path=/usr/lib/nginx/modules \
  --conf-path=/etc/nginx/nginx.conf \
  --error-log-path=/var/log/nginx/error.log \
  --http-log-path=/var/log/nginx/access.log \
  --pid-path=/var/run/nginx.pid \
  --lock-path=/var/run/nginx.lock \
  --http-client-body-temp-path=/var/cache/nginx/client_temp \
  --http-proxy-temp-path=/var/cache/nginx/proxy_temp \
  --http-fastcgi-temp-path=/var/cache/nginx/fastcgi_temp \
  --http-uwsgi-temp-path=/var/cache/nginx/uwsgi_temp \
  --http-scgi-temp-path=/var/cache/nginx/scgi_temp \
  --user=nginx \
  --group=nginx \
  --with-file-aio \
  --with-threads \
  --with-http_ssl_module \
  --with-http_v2_module \
  --with-http_realip_module \
  --add-module=$bpath/ngx_brotli \
  --add-module=$bpath/headers-more-nginx-module-$version_headers \
  --without-http_charset_module \
  --without-http_ssi_module \
  --without-http_userid_module \
  --without-http_access_module \
  --without-http_auth_basic_module \
  --without-http_autoindex_module \
  --without-http_geo_module \
  --without-http_map_module \
  --without-http_split_clients_module \
  --without-http_referer_module \
  --without-http_fastcgi_module \
  --without-http_uwsgi_module \
  --without-http_scgi_module \
  --without-http_memcached_module \
  --without-http_limit_conn_module \
  --without-http_limit_req_module \
  --without-http_empty_gif_module \
  --without-http_browser_module \
  --without-http_upstream_ip_hash_module \
  --without-http_upstream_least_conn_module \
  --without-mail_imap_module \
  --without-mail_pop3_module \
  --without-mail_smtp_module
make
make install
make clean
strip -s /usr/sbin/nginx*

# Create NGINX systemd service file if it does not already exist
if [ ! -e "/lib/systemd/system/nginx.service" ]; then
  # Control will enter here if the NGINX service doesn't exist.
  file="/lib/systemd/system/nginx.service"

  /bin/cat >$file <<'EOF'
[Unit]
Description=A high performance web server and a reverse proxy server
After=network.target nss-lookup.target

[Service]
Type=forking
PIDFile=/run/nginx.pid
ExecStartPre=/usr/sbin/nginx -t -q -g 'daemon on; master_process on;'
ExecStart=/usr/sbin/nginx -g 'daemon on; master_process on;'
ExecStartPost=/bin/sleep 0.1
ExecReload=/usr/sbin/nginx -g 'daemon on; master_process on;' -s reload
ExecStop=-/sbin/start-stop-daemon --quiet --stop --retry QUIT/5 --pidfile /run/nginx.pid
TimeoutStopSec=5
KillMode=mixed

[Install]
WantedBy=multi-user.target
EOF
fi

echo "All done.";
