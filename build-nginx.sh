#!/usr/bin/env bash
# Run as root or with sudo

if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root or with sudo."
  exit 1
fi

set -e

## Set names of latest versions of each package
VERSION_LIBATOMIC=7.6.12
VERSION_MORE_HEADERS=0.33
VERSION_NGINX=1.21.7
VERSION_PCRE=pcre-8.45
VERSION_SECURITY_HEADERS=0.0.11

## Set URLs to the source directories
SOURCE_BROTLI=https://github.com/google/ngx_brotli
SOURCE_JEMALLOC=https://github.com/jemalloc/jemalloc
SOURCE_LIBATOMIC=https://github.com/ivmai/libatomic_ops/archive/v
SOURCE_MORE_HEADERS=https://github.com/openresty/headers-more-nginx-module/archive/v
SOURCE_NGINX=https://hg.nginx.org/nginx-quic
SOURCE_OPENSSL=https://github.com/quictls/openssl
SOURCE_PCRE=https://ftp.exim.org/pub/pcre/
SOURCE_SECURITY_HEADERS=https://github.com/GetPageSpeed/ngx_security_headers/archive/
SOURCE_ZLIB=https://github.com/cloudflare/zlib

## Set where OpenSSL and NGINX will be built
SPATH=$(pwd)
BPATH=$SPATH/build
TIME=$(date +%m%d%Y-%H%M%S-%Z)

## Clean screen before launching
clear

## Clean out any files from previous runs of this script
rm -rf \
  "$BPATH"
mkdir "$BPATH"
rm -rf \
  "$SPATH/packages"
mkdir "$SPATH/packages"

## Move tmp within build directory
mkdir "$BPATH/tmp"
export TMPDIR="$BPATH/tmp"

## Ensure the required software to compile NGINX is installed
apt-get update && apt-get -y install \
  binutils \
  build-essential \
  checkinstall \
  cmake \
  autoconf \
  automake \
  libtool \
  mercurial \
  git \
  curl \
  wget
  
clear

## Download the source files
curl -L "${SOURCE_LIBATOMIC}${VERSION_LIBATOMIC}.tar.gz" -o "${BPATH}/libatomic.tar.gz"
curl -L "${SOURCE_MORE_HEADERS}${VERSION_MORE_HEADERS}.tar.gz" -o "${BPATH}/more-headers.tar.gz"
curl -L "${SOURCE_PCRE}${VERSION_PCRE}.tar.gz" -o "${BPATH}/pcre.tar.gz"
curl -L "${SOURCE_SECURITY_HEADERS}${VERSION_SECURITY_HEADERS}.tar.gz" -o "${BPATH}/security-headers.tar.gz"


cd "$BPATH"
git clone $SOURCE_JEMALLOC
git clone $SOURCE_ZLIB --branch gcc.amd64
git clone --depth=1 --recurse-submodules $SOURCE_BROTLI
git clone --recursive $SOURCE_OPENSSL
hg clone -b quic $SOURCE_NGINX

## Expand the source files
cd "$BPATH"
for ARCHIVE in ./*.tar.gz; do
  tar xzf "$ARCHIVE"
done

## Clean up source files
rm -rf \
  "$BPATH"/*.tar.*

## Create NGINX cache directories if they do not already exist
if [ ! -d "/var/cache/nginx/" ]; then
  mkdir -p \
    /var/cache/nginx/client_temp \
    /var/cache/nginx/fastcgi_temp \
    /var/cache/nginx/proxy_temp \
    /var/cache/nginx/ram_cache \
    /var/cache/nginx/scgi_temp \
    /var/cache/nginx/uwsgi_temp
fi

## We add sites-* folders as some use them. /etc/nginx/conf.d/ is the vhost folder by defaultnginx
if [[ ! -d /etc/nginx/sites-available ]]; then
	mkdir -p /etc/nginx/sites-available
	cp "$SPATH/conf/plex.domain.tld" "/etc/nginx/sites-available/plex.domain.tld"
fi
if [[ ! -d /etc/nginx/sites-enabled ]]; then
	mkdir -p /etc/nginx/sites-enabled
fi

if [[ ! -e /etc/nginx/nginx.conf ]]; then
	mkdir -p /etc/nginx
	cd /etc/nginx || exit 1
	cp "$SPATH/conf/nginx.conf" "/etc/nginx/nginx.conf"
fi

## Add NGINX group and user if they do not already exist
id -g nginx &>/dev/null || addgroup --system nginx
id -u nginx &>/dev/null || adduser --disabled-password --system --home /var/cache/nginx --shell /sbin/nologin --group nginx

## make libatomic
cd "$BPATH/libatomic_ops-$VERSION_LIBATOMIC"
autoreconf -i
./configure
make -j "$(nproc)"
make install

## make zlib
cd "$BPATH/zlib"
./configure
make -j "$(nproc)"

## make jemalloc
cd "$BPATH/jemalloc"
./autogen.sh
make -j "$(nproc)"
checkinstall --install=no --pkgversion=$(cat "$BPATH/jemalloc/VERSION") -y
cp "$BPATH/jemalloc"/*.deb "$SPATH/packages"
make install

ldconfig

## Build NGINX, with various modules included/excluded; requires GCC 11.2
clear
cd "$BPATH/ngx_brotli"
readlink -f config

## Add HTTP2 HPACK Encoding Support & Dynamic TLS Record Support - https://github.com/kn007/patch/blob/master/nginx.patch
cd "$BPATH/nginx-quic"
patch -p1  < "$SPATH/patches/nginx.patch"

./auto/configure \
  --build="$TIME-[debian_nginx-quic_quictls]" \
  --prefix=/etc/nginx \
  --with-cc-opt='-I/usr/local/include -m64 -march=native -DTCP_FASTOPEN=23 -falign-functions=32 -g -O3 -Wno-error=strict-aliasing -Wno-vla-parameter -fstack-protector-strong -flto=8 -fuse-ld=gold --param=ssp-buffer-size=4 -Wformat -Werror=format-security -Wno-error=pointer-sign -Wimplicit-fallthrough=0 -fcode-hoisting -Wp,-D_FORTIFY_SOURCE=2 -Wno-deprecated-declarations' \
  --with-ld-opt='-Wl,-E -L/usr/local/lib -ljemalloc -Wl,-z,relro -Wl,-rpath,/usr/local/lib -flto=8 -fuse-ld=gold' \
  --with-openssl="../openssl" \
  --with-openssl-opt='no-weak-ssl-ciphers no-ssl2 no-ssl3 no-idea no-err no-srp no-psk no-nextprotoneg enable-ktls enable-zlib enable-ec_nistp_64_gcc_128' \
  --with-pcre="../pcre-8.45" \
  --with-zlib="../zlib" \
  --conf-path=/etc/nginx/nginx.conf \
  --error-log-path=/var/log/nginx/error.log \
  --http-log-path=/var/log/nginx/access.log \
  --lock-path=/var/run/nginx.lock \
  --modules-path=/usr/lib/nginx/modules \
  --pid-path=/var/run/nginx.pid \
  --sbin-path=/usr/sbin/nginx \
  --http-client-body-temp-path=/var/cache/nginx/client_temp \
  --http-fastcgi-temp-path=/var/cache/nginx/fastcgi_temp \
  --http-proxy-temp-path=/var/cache/nginx/proxy_temp \
  --http-scgi-temp-path=/var/cache/nginx/scgi_temp \
  --http-uwsgi-temp-path=/var/cache/nginx/uwsgi_temp \
  --user=nginx \
  --group=nginx \
  --with-file-aio \
  --with-libatomic \
  --with-threads \
  --with-http_realip_module \
  --with-http_ssl_module \
  --with-http_v2_hpack_enc \
  --with-http_v2_module \
  --with-http_v3_module \
  --add-module="../headers-more-nginx-module-$VERSION_MORE_HEADERS" \
  --add-module="../ngx_brotli" \
  --add-module="../ngx_security_headers-$VERSION_SECURITY_HEADERS" \
  --without-http_auth_basic_module \
  --without-http_autoindex_module \
  --without-http_browser_module \
  --without-http_charset_module \
  --without-http_empty_gif_module \
  --without-http_fastcgi_module \
  --without-http_geo_module \
  --without-http_grpc_module \
  --without-http_limit_conn_module \
  --without-http_limit_req_module \
  --without-http_memcached_module \
  --without-http_mirror_module \
  --without-http_referer_module \
  --without-http_scgi_module \
  --without-http_split_clients_module \
  --without-http_ssi_module \
  --without-http_upstream_hash_module \
  --without-http_upstream_ip_hash_module \
  --without-http_upstream_least_conn_module \
  --without-http_upstream_zone_module \
  --without-http_userid_module \
  --without-http_uwsgi_module \
  --without-mail_imap_module \
  --without-mail_pop3_module \
  --without-mail_smtp_module

make -j "$(nproc)"
make install
checkinstall --install=no --pkgname="nginx-quic" --pkgversion="$VERSION_NGINX" -y
cp "$BPATH/nginx-quic"/*.deb "$SPATH/packages"
make clean
strip -s /usr/sbin/nginx*

## Create NGINX systemd service file if it does not already exist
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

clear 

echo "SUCCESS"

nginx -V

## Clean out any files from this script
rm -rf \
  "$BPATH"