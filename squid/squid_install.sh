#get needed system libs
sudo yum update -y
sudo yum install -y perl gcc autoconf automake make sudo wget gcc-c++ libxml2-devel libcap-devel libtool libtool-ltdl-devel openssl openssl-devel

#get latest squid package
SQUID_ARCHIVE=http://www.squid-cache.org/Versions/v3/3.5/squid-3.5.27.tar.gz
cd /tmp
wget $SQUID_ARCHIVE
tar xvf squid*.tar.gz
cd $(basename squid*.tar.gz .tar.gz)

#configure and intall squid
sudo ./configure --prefix=/usr --exec-prefix=/usr --libexecdir=/usr/lib64/squid --sysconfdir=/etc/squid --sharedstatedir=/var/lib --localstatedir=/var --libdir=/usr/lib64 --datadir=/usr/share/squid --with-logdir=/var/log/squid --with-pidfile=/var/run/squid.pid --with-default-user=squid --disable-dependency-tracking --enable-linux-netfilter --with-openssl --without-nettle --enable-useragent-log
sudo make
sudo make install

sudo adduser -M squid \
&& sudo chown -R squid:squid /var/log/squid /var/cache/squid \
&& sudo chmod 750 /var/log/squid /var/cache/squid \
&& sudo touch /etc/squid/squid.conf \
&& sudo chown -R root:squid /etc/squid/squid.conf \
&& sudo chmod 640 /etc/squid/squid.conf
&& sudo touch /etc/squid/allowed_sites  \
&& sudo chown -R root:squid /etc/squid/allowed_sites  \
&& sudo chmod 640 /etc/squid/allowed_sites

cat | sudo tee /etc/init.d/squid <<'EOF'
#!/bin/sh
# chkconfig: - 90 25
echo -n 'Squid service'
case "$1" in
start)
/usr/sbin/squid
;;
stop)
/usr/sbin/squid -k shutdown
;;
#restart)
#/usr/sbin/squid -k shutdown
#/usr/sbin/squid
#;;
reload)
/usr/sbin/squid -k reconfigure
;;
*)
echo "Usage: `basename $0` {start|stop|reload|restart}"
;;
esac
EOF

sudo chmod +x /etc/init.d/squid
sudo chkconfig squid on

sudo mkdir /etc/squid/ssl
"cd /etc/squid/ssl",
"openssl genrsa -out squid.key 2048",
"openssl req -new -key squid.key -out squid.csr -subj \"/C=XX/ST=XX/L=squid/O=squid/CN=squid\"",
"openssl x509 -req -days 3650 -in squid.csr -signkey squid.key -out squid.crt",
"cat squid.key squid.crt | tee squid.pem",

cat | sudo tee /etc/squid/squid.conf <<EOF
visible_hostname squid

#Never cache any response
cache deny all

#Handling HTTP requests
http_port 3129 intercept
acl allowed_http_sites dstdomain "/etc/squid/allowed_sites"
#acl allowed_http_sites dstdomain
http_access allow allowed_http_sites

##Handling HTTPS requests
#https_port 3130 cert=/etc/squid/ssl/squid.pem ssl-bump intercept
#acl SSL_port port 443
#http_access allow SSL_port
#acl allowed_https_sites ssl::server_name .amazonaws.com
##acl allowed_https_sites ssl::server_name
#acl step1 at_step SslBump1
#acl step2 at_step SslBump2
#acl step3 at_step SslBump3
#ssl_bump peek step1 all
#ssl_bump peek step2 allowed_https_sites
#ssl_bump splice step3 allowed_https_sites
#ssl_bump terminate step2 all

http_access deny all
EOF

sudo iptables -t nat -A PREROUTING -p tcp --dport 80 -j REDIRECT --to-port 3129
sudo iptables -t nat -A PREROUTING -p tcp --dport 443 -j REDIRECT --to-port 3130
sudo iptables-save > /etc/sysconfig/iptables

sudo service squid start
