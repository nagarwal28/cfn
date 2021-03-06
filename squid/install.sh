#!/bin/bash
 yum update -y  
 yum install -y perl gcc autoconf automake make sudo wget gcc-c++ libxml2-devel libcap-devel libtool libtool-ltdl-devel openssl openssl-devel
 SQUID_ARCHIVE=http://www.squid-cache.org/Versions/v3/3.5/squid-3.5.27.tar.gz
 cd /tmp
 wget $SQUID_ARCHIVE
 tar xvf squid*.tar.gz
 cd $(basename squid*.tar.gz .tar.gz)
 ./configure --prefix=/usr --exec-prefix=/usr --libexecdir=/usr/lib64/squid --sysconfdir=/etc/squid --sharedstatedir=/var/lib --localstatedir=/var --libdir=/usr/lib64 --datadir=/usr/share/squid --with-logdir=/var/log/squid --with-pidfile=/var/run/squid.pid --with-default-user=squid --disable-dependency-tracking --enable-linux-netfilter --with-openssl --without-nettle --enable-useragent-log
 make
 make install
 adduser -M squid
 chown -R squid:squid /var/log/squid /var/cache/squid
 chmod 750 /var/log/squid /var/cache/squid
 touch /etc/squid/squid.conf
 chown -R root:squid /etc/squid/squid.conf
 chmod 640 /etc/squid/squid.conf
 touch /etc/squid/allowed_sites
 chown -R root:squid /etc/squid/allowed_sites
 chmod 640 /etc/squid/allowed_sites
 cat | tee /etc/init.d/squid <<'EOF'
 #!/bin/sh
 # chkconfig: - 90 25
 echo -n 'Squid service'
 case \ $1\  in
 start)
 /usr/sbin/squid
 ;;
 stop)
 /usr/sbin/squid -k shutdown
 ;;
 reload)
 /usr/sbin/squid -k reconfigure
 ;;
 *)
 echo \ Usage: `basename $0` {start|stop|reload}\
 ;;
 esac
 EOF
 chmod +x /etc/init.d/squid
 chkconfig squid on
 mkdir /etc/squid/ssl
 cd /etc/squid/ssl
 cat | tee /etc/squid/squid.conf <<EOF
 visible_hostname squid
 #Never cache any response
 cache deny all
 #Handling HTTP requests
 http_port 3129 intercept
 acl allowed_http_sites dstdomain '/etc/squid/allowed_sites'
 #acl allowed_http_sites dstdomain [you can add other domains to permit]
 http_access allow allowed_http_sites
 #Handling HTTPS requests
 #https_port 3130 cert=/etc/squid/ssl/squid.pem ssl-bump intercept
 #acl SSL_port port 443
 #http_access allow SSL_port
 #acl allowed_https_sites ssl::server_name .amazonaws.com
 #acl allowed_https_sites ssl::server_name [you can add other domains to permit]
 #acl step1 at_step SslBump1
 #acl step2 at_step SslBump2
 #acl step3 at_step SslBump3
 #ssl_bump peek step1 all
 #ssl_bump peek step2 allowed_https_sites
 #ssl_bump splice step3 allowed_https_sites
 #ssl_bump terminate step2 all
 http_access deny all
 EOF
 iptables -t nat -A PREROUTING -p tcp --dport 80 -j REDIRECT --to-port 3129
 iptables -t nat -A PREROUTING -p tcp --dport 443 -j REDIRECT --to-port 3130
 iptables-save > /etc/sysconfig/iptables
 service squid start
