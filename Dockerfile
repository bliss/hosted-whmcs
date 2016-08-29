# Version: 0.0.1
FROM ubuntu:14.04.5

MAINTAINER Igor Savenko "bliss@cloudlinux.com"

RUN DEBIAN_FRONTEND=noninteractive \
    apt-get update && \
    apt-get install -y language-pack-en-base &&\
    export LC_ALL=en_US.UTF-8 && \
    export LANG=en_US.UTF-8


RUN DEBIAN_FRONTEND=noninteractive apt-get update && apt-get install -y software-properties-common
RUN DEBIAN_FRONTEND=noninteractive LC_ALL=en_US.UTF-8 add-apt-repository ppa:ondrej/php -y


RUN DEBIAN_FRONTEND=noninteractive LC_ALL=en_US.UTF-8 \
    apt-get update && apt-get install -y \
    php5.6 php5.6-mbstring php5.6-mcrypt php5.6-mysql php5.6-xml php5.6-fpm php5.6-gd php5.6-curl \
    nginx supervisor wget unzip

RUN wget -O /tmp/ioncube.tgz \
  http://downloads3.ioncube.com/loader_downloads/ioncube_loaders_lin_x86-64_5.1.2.tar.gz \
  && tar -zxf /tmp/ioncube.tgz -C /tmp

RUN sed -i -e "s/;\?cgi.fix_pathinfo\s*=\s*1/cgi.fix_pathinfo = 0/" \
  -e "s/;\?upload_max_filesize\s*=\s*2M/upload_max_filesize = 100M/" \
  -e "s/;\?max_execution_time\s*=\s*30/max_execution_time = 300/" \
  -e "s/;\?post_max_size\s*=\s*8M/post_max_size = 100M/" /etc/php/5.6/fpm/php.ini

RUN sed -i -e "s/;\?daemonize\s*=\s*yes/daemonize = no/" /etc/php/5.6/fpm/php-fpm.conf
RUN sed -i -e "s/;\?catch_workers_output\s*=\s*yes/catch_workers_output = yes/" \
  -e "s/;\?pm.max_children\s*=\s*5/pm.max_children = 9/g" \
  -e "s/;\?pm.start_servers\s*=\s*2/pm.start_servers = 3/g" \
  -e "s/;\?pm.min_spare_servers\s*=\s*1/pm.min_spare_servers = 2/" \
  -e "s/;\?pm.max_spare_servers\s*=\s*3/pm.max_spare_servers = 4/" \
  -e "s/;\?pm.max_requests\s*=\s*500/pm.max_requests = 200/" /etc/php/5.6/fpm/pool.d/www.conf

RUN sed -i -e "s/keepalive_timeout\s*65/keepalive_timeout 5/" \
  -e "/keepalive_timeout/a \\\tclient_max_body_size 100m;" \
  -e "/worker_processes/a daemon off;" /etc/nginx/nginx.conf

RUN rm -rf /etc/nginx/sites-enabled/*
RUN mkdir -p /var/opt/persistent

COPY conf/default /etc/nginx/sites-enabled
COPY conf/supervisord.conf /etc
COPY scripts/loghandler.php /
COPY scripts/start.sh /

COPY src/whmcs*.zip /

RUN chmod 755 /start.sh

VOLUME ["/var/opt/persistent"] 
EXPOSE 80 443

CMD ["/bin/bash", "/start.sh"]
