FROM ubuntu:16.04
MAINTAINER Roman Kredentser <shareed2k@gmail.com>

ENV DEBIAN_FRONTEND noninteractive

# Update Package List
RUN apt-get update && \
	apt-get upgrade -y

# Force Local
RUN echo "LC_ALL=en_US.UTF-8" >> /etc/default/locale && \
	locale-gen en_US.UTF-8 && \
	export LANG=en_US.UTF-8

# Basic packages
RUN apt-get install -y sudo sqlite3 libsqlite3-dev openssh-server pwgen software-properties-common nano curl ruby-dev openssl \
	build-essential dos2unix gcc git git-flow libmcrypt4 libpcre3-dev apt-utils \
	make python2.7-dev python-pip re2c supervisor unattended-upgrades whois vim zip unzip && \
	
	# Install ssh server
	mkdir -p /var/run/sshd && \
	sed -i "s/UsePrivilegeSeparation.*/UsePrivilegeSeparation no/g" /etc/ssh/sshd_config && \
	sed -i "s/UsePAM.*/UsePAM no/g" /etc/ssh/sshd_config && \
	sed -i "s/PermitRootLogin.*/PermitRootLogin yes/g" /etc/ssh/sshd_config

# PPA
RUN	apt-add-repository ppa:ondrej/php -y && \
	## add repository for yarn
	apt-key adv --keyserver pgp.mit.edu --recv D101F7899D41F3C3 && \
	echo "deb http://dl.yarnpkg.com/debian/ stable main" | sudo tee /etc/apt/sources.list.d/yarn.list && \
	curl --silent --location https://deb.nodesource.com/setup_6.x | bash -

#install compass
RUN gem install --no-rdoc --no-ri compass

# Create homestead user
RUN adduser homestead && \
	usermod -p $(echo secret | openssl passwd -1 -stdin) homestead && \
	# Add homestead to the sudo group and www-data
	usermod -aG sudo homestead && \
	usermod -aG www-data homestead && \
	# Timezone
	ln -sf /usr/share/zoneinfo/UTC /etc/localtime

RUN apt-get update && apt-get install -y --allow-unauthenticated nodejs yarn \
	# PHP
	php-cli php-dev php-pear \
	php-mysql php-pgsql php-sqlite3 \
	php-apcu php-json php-curl php-gd \
	php-gmp php-imap php-mcrypt php-xdebug \
	php-memcached php-redis php-mbstring php-zip nginx php-fpm && \
	# Enable mcrypt
	phpenmod mcrypt && \

	# Install Composer
	curl -sS https://getcomposer.org/installer | php && \
	mv composer.phar /usr/local/bin/composer && \
	# Add Composer Global Bin To Path
	printf "\nPATH=\"/home/homestead/.composer/vendor/bin:\$PATH\"\n" | tee -a /home/homestead/.profile

# create ssl certificate for nginx 443 port
RUN mkdir /etc/nginx/ssl && \
	touch /etc/nginx/ssl/nginx.key && \
	touch /etc/nginx/ssl/nginx.crt && \
	openssl req -x509 -newkey rsa:2048 \
	  -subj "/C=XX/ST=XXXX/L=XXXX/O=XXXX/CN=localhost" \
	  -keyout "/etc/nginx/ssl/nginx.key" \
	  -out "/etc/nginx/ssl/nginx.crt" \
	  -days 3650 -nodes

# Set Some PHP CLI Settings
RUN sed -i "s/error_reporting = .*/error_reporting = E_ALL/" /etc/php/7.0/cli/php.ini && \
	sed -i "s/display_errors = .*/display_errors = On/" /etc/php/7.0/cli/php.ini && \
	sed -i "s/memory_limit = .*/memory_limit = 512M/" /etc/php/7.0/cli/php.ini && \
	sed -i "s/;date.timezone.*/date.timezone = UTC/" /etc/php/7.0/cli/php.ini && \
	sed -i "s/.*daemonize.*/daemonize = no/" /etc/php/7.0/fpm/php-fpm.conf && \
	sed -i "s/error_reporting = .*/error_reporting = E_ALL/" /etc/php/7.0/fpm/php.ini && \
	sed -i "s/display_errors = .*/display_errors = On/" /etc/php/7.0/fpm/php.ini && \
	sed -i "s/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/" /etc/php/7.0/fpm/php.ini && \
	sed -i "s/memory_limit = .*/memory_limit = 512M/" /etc/php/7.0/fpm/php.ini && \
	sed -i "s/;date.timezone.*/date.timezone = UTC/" /etc/php/7.0/fpm/php.ini && \
	# Enable Remote xdebug
	echo "xdebug.idekey = PHPSTORM" >> /etc/php/7.0/fpm/conf.d/20-xdebug.ini && \
	echo "xdebug.default_enable = 0" >> /etc/php/7.0/fpm/conf.d/20-xdebug.ini && \
	echo "xdebug.remote_enable = 1" >> /etc/php/7.0/fpm/conf.d/20-xdebug.ini && \
	echo "xdebug.remote_autostart = 0" >> /etc/php/7.0/fpm/conf.d/20-xdebug.ini && \
	echo "xdebug.remote_connect_back = 0" >> /etc/php/7.0/fpm/conf.d/20-xdebug.ini && \
	echo "xdebug.profiler_enable = 0" >> /etc/php/7.0/fpm/conf.d/20-xdebug.ini && \
	echo "xdebug.remote_host = 10.254.254.254" >> /etc/php/7.0/fpm/conf.d/20-xdebug.ini && \
	# Set The Nginx & PHP-FPM User
	#sed -i '1 idaemon off;' /etc/nginx/nginx.conf
	sed -i "s/user www-data;/user homestead;/" /etc/nginx/nginx.conf && \
	sed -i "s/# server_names_hash_bucket_size.*/server_names_hash_bucket_size 64;/" /etc/nginx/nginx.conf && \
	mkdir -p /run/php && \
	touch /run/php/php7.0-fpm.sock && \
	sed -i "s/user = www-data/user = homestead/" /etc/php/7.0/fpm/pool.d/www.conf && \
	sed -i "s/group = www-data/group = homestead/" /etc/php/7.0/fpm/pool.d/www.conf && \
	sed -i "s/;listen\.owner.*/listen.owner = homestead/" /etc/php/7.0/fpm/pool.d/www.conf && \
	sed -i "s/;listen\.group.*/listen.group = homestead/" /etc/php/7.0/fpm/pool.d/www.conf && \
	sed -i "s/;listen\.mode.*/listen.mode = 0666/" /etc/php/7.0/fpm/pool.d/www.conf

# Install Node
RUN npm install -g grunt-cli gulp bower

# Install packages
ADD provision.sh /provision.sh

ADD serve.sh /serve.sh

ADD supervisor.conf /etc/supervisor/conf.d/supervisor.conf

RUN chmod +x /*.sh

RUN ./provision.sh

EXPOSE 80 22 8443 8080 35729 9876
CMD ["/usr/bin/supervisord"]