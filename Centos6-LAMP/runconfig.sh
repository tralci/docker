#!/bin/bash

#################################################################
# Apache 
#################################################################

apache_install() {
    echo "---------------------------"
    echo "Installing Apache...."
    yum -y install httpd mod_rewrite mod_ssl mod_env php php-common php-cli unzip && \
    yum clean all                                                                 && \
    rm -fr /var/cache/* 
    echo "Exiting Apache Installation."
    echo "----------------------------"
}

apache_config() {
    echo "---------------------------"
    echo "Config Apache...."
    cp /etc/httpd/conf/httpd.conf                                                    /etc/httpd/conf/httpd.conf.orig
    sed -ie 's/#ServerName\ www\.exampe\.com\:80/ServerName\ www\.'$APP_NAME'\:80/g' /etc/httpd/conf/httpd.conf
    sed -ie ':a;N;$!ba;s/AllowOverride\ None/AllowOverride\ ALL/2'                   /etc/httpd/conf/httpd.conf
    mv /tmp/wordpress.conf                                                           /etc/httpd/conf.d/$APP_NAME.conf
    echo "# Set Apache Environment Variables that will be passed to Apache via PassEnv (Must have mod_env enabled" >> /etc/sysconfig/httpd
    echo "APP=\"$APP_NAME\""                                                                                       >> /etc/sysconfig/httpd
    echo "SVRALIAS=\"$APACHE_SVRALIAS\""                                                                           >> /etc/sysconfig/httpd
    echo "HOSTNAME=\`hostname\`"                                                                                   >> /etc/sysconfig/httpd
    echo "# Export the variables to PassEnv"                                                                       >> /etc/sysconfig/httpd
    echo "export APP SVRALIAS HOSTNAME"                                                                            >> /etc/sysconfig/httpd
    echo "Exiting Apache Config.    "
    echo "---------------------------"
}

apache_start() {
    echo "---------------------------"
    echo "Starting Apache now...     "
    service httpd start
    echo "Exiting Apache start       "
    echo "---------------------------"
}

apache_stop() {
    echo "---------------------------"
    echo "Stopping Apache now....    "
    service httpd stop
    echo "Exiting Apache Stop        "
    echo "---------------------------"
}

apache_start_on_boot() {
    echo "---------------------------"
    echo "Starting Apache on boot...."
    echo "service httpd  start"  >> ~/.bashrc
    echo "Exiting Apache on boot     "
    echo "---------------------------"
}

#################################################################
# MySQL
#################################################################

mysql_install() {
    echo "---------------------------"
    echo "Staring MySQL Installation.."
    yum -y install php-mysql mysql mysql-server  && \ 
    yum clean all                                && \
    rm -fr /var/cache/*
    echo "Exiting MySQL Installation-"
    echo "---------------------------"
}

mysql_start() {
    echo "---------------------------"
    echo "Starting MySQL now....     "
    service mysqld start
    echo "Exiting MySQL start        "
    echo "---------------------------"
}

mysql_stop() {
    echo "---------------------------"
    echo "Starting MySQL Stop now...."
    service mysqld stop
    echo "Exiting MySQL Stop now     "
    echo "---------------------------"
}

mysql_save_setup() {
    echo "--------------------------------"
    echo "Starting Save Setup now....     "

    echo "Securing root user with password" 
    mysqladmin -u root password "$MYSQL_PASS"

    echo "Creating admin user with password"
    mysql      -u root        -p"$MYSQL_PASS" -e "CREATE USER '$MYSQL_USER'@'$MYSQL_SERVER' IDENTIFIED BY '$MYSQL_PASS' WITH GRANT OPTION;" 
    mysql      -u root        -p"$MYSQL_PASS" -e "CREATE USER '$MYSQL_USER'@'$MYSQL_CLIENT' IDENTIFIED BY '$MYSQL_PASS' WITH GRANT OPTION;" 
    mysql      -u root        -p"$MYSQL_PASS" -e "GRANT ALL PRIVILEGES ON *.* TO '$MYSQL_USER'@'$MYSQL_SERVER' IDENTIFIED BY '$MYSQL_PASS' WITH GRANT OPTION;" 
    mysql      -u root        -p"$MYSQL_PASS" -e "GRANT ALL PRIVILEGES ON *.* TO '$MYSQL_USER'@'$MYSQL_CLIENT' IDENTIFIED BY '$MYSQL_PASS' WITH GRANT OPTION;" 
    mysql      -u root        -p"$MYSQL_PASS" -e "DROP DATABASE test;" 
    mysql      -u root        -p"$MYSQL_PASS" -e "FLUSH PRIVILEGES;" 
    
    echo "Exiting Save Setup              "
    echo "--------------------------------"
}

mysql_create_db() {
    echo "--------------------------------"
    echo "Starting Create DB now.....     "

    mysql -u $MYSQL_USER -p"$MYSQL_PASS" -h $MYSQL_SERVER -e "CREATE DATABASE $MYSQL_DB;"
    mysql -u $MYSQL_USER -p"$MYSQL_PASS" -h $MYSQL_SERVER -e "CREATE USER '$APP_USER'@'$MYSQL_CLIENT' IDENTIFIED BY '$APP_PASS';" 
    mysql -u $MYSQL_USER -p"$MYSQL_PASS" -h $MYSQL_SERVER -e "GRANT ALL PRIVILEGES ON $MYSQL_DB.* TO '$APP_USER'@'$MYSQL_CLIENT' IDENTIFIED BY '$APP_PASS';"
    mysql -u $MYSQL_USER -p"$MYSQL_PASS" -h $MYSQL_SERVER -e "FLUSH PRIVILEGES;"

    echo "Exiting Create DB               "
    echo "--------------------------------"
}

mysql_start_on_boot() {
    echo "--------------------------------"
    echo "Starting MySQL on Boot....      "
    echo "service mysqld start"  >> ~/.bashrc
    echo "Exiting MySQL on Boot           "
    echo "--------------------------------"
}

wait_for_db_container() {
    echo "---------------------------------"
    echo " Waiting for db container...."

    while ! mysqladmin -u $MYSQL_USER -p"$MYSQL_PASS"  ping -h db --silent; 
    do
        echo "Sleeping now...."
        sleep 5 
    done

    echo " Exiting Waiting for db container"
    echo "---------------------------------"
}

#################################################################
# Wordpress
#################################################################

wordpress_install() {
    echo "--------------------------------"
    echo "Starting Wordpress Install now.."
    wget -P /var/www/html/               https://wordpress.org/latest.zip && \
    unzip   /var/www/html/latest.zip -d  /var/www/html/                   && \
    rm -fr  /var/www/html/latest.zip
    cp      /var/www/html/wordpress/wp-config-sample.php /var/www/html/wordpress/wp-config.php
    echo "Exiting Wordpress Install       "
    echo "--------------------------------"
}

wordpress_config() {
    echo "--------------------------------"
    echo "Starting Wordpress Config...    "
    
    # If wordpress directory already there, don't override, leave it
    if [ -d /var/www/html/$APP_NAME && -r /var/www/html/$APP_NAME/wp-config.php ] 
    then
        echo "Directory /var/www/html/$APP_NAME is already there, don't change it"
    else
        echo "Directory /var/www/html/$APP_NAME is not there, create it now......"
        mv /var/www/html/wordpress                            /var/www/html/$APP_NAME
        chown -R apache:apache                                /var/www/html/$APP_NAME
        chmod -R 775                                          /var/www/html/$APP_NAME
        sed -ie 's/database_name_here/'$MYSQL_DB'/g'          /var/www/html/$APP_NAME/wp-config.php && \
        sed -ie 's/username_here/'$APP_USER'/g'               /var/www/html/$APP_NAME/wp-config.php && \
        sed -ie 's/password_here/'$APP_PASS'/g'               /var/www/html/$APP_NAME/wp-config.php && \
        sed -ie 's/localhost/'$MYSQL_SERVER'/g'               /var/www/html/$APP_NAME/wp-config.php && \
        sed -ie "s/put\ your\ unique\ phrase\ here/$WP_KEY/g" /var/www/html/$APP_NAME/wp-config.php
    fi
    echo "Exting Wordpress Config         "
    echo "--------------------------------"
}

#################################################################
# Cleaning up at the end
#################################################################
clean_up() {
    echo "--------------------------------"
    echo "Starting Clean up now...        "
    unset MYSQL_PASS MYSQL_SERVER MYSQL_DB APP_USER APP_PASS
    sed -ie 's/\/tmp\/runconfig.sh/#\/tmp\/runconfig.sh/g' ~/.bashrc
    echo "Exiting Clean up                "
    echo "--------------------------------"
}

################################################
# Handle the different MODES here...
################################################
start_in_mode_standalone() {
  # =================================
  # MODE:      Standalone
  # =================================
  # apache:    install local instance
  # apache:    config  local instance
  # apache:    start   local instance
  # wordpress: install local instance
  # wordpress: config  local instance
  # mysql:     install local instance

  # mysql:     config  local instance
  # mysql:     create  new   database 
  # mysql:     start   local instance
  # =================================
  # Start a local mysql instance, and install a new database on the localhost mysql instance
    echo "--------------------------------"
    echo "MODE: Standalone"
    echo "--------------------------------"

    # apache_install  
    apache_config
    apache_start_on_boot
  
    # mysql_install
    mysql_start_on_boot
    mysql_start
    mysql_save_setup
    mysql_create_db
  
    # wordpress_install
    wordpress_config

    apache_start
    clean_up
}

################################################
start_in_mode_remote() {
  # =================================
  # MODE:      Remote
  # =================================
  # apache:    install local instance
  # apache:    config  local instance
  # apache:    start   local instance
  # wordpress: install local instance
  # wordpress: config  local instance
  # mysql:     config  remote
  # mysql:     create  new   database 
  # =================================
  # Connect to an existing remote database server and install a new database on the remote mysql instance. 
  # MySQL-Server package is removed in this mode. User with grant-option must be pre-configured on the existing database server and supplied at runtime.
  # Remove the mysql-server packages at runtime and will not run mysql at all, but it will leave the mysql package installed for library support.
    echo "--------------------------------"
    echo "MODE: Remote    "
    echo "--------------------------------"

    # apache_install  
    apache_config
    apache_start_on_boot
  
    # mysql_install
    # mysql_start_on_boot
    # mysql_start
    wait_for_db_container 
    mysql_create_db
  
    # wordpress_install
    wordpress_config

    apache_start
    clean_up
}

################################################
start_in_mode_existing() {
  # =================================
  # MODE:      Existing
  # =================================
  # apache:    install local instance
  # apache:    config  local instance
  # apache:    start   local instance
  # wordpress: install local instance
  # wordpress: config  local instance
  # mysql:     config  remote 
  # mysql:     connect remote
  # =================================
  # Connect to an existing remote database on an existing remote mysql instance. MySQL-Server package is removed in this mode.
  # remove the mysql-server packages at runtime and will not run mysql at all, but it will leave the mysql package installed for library support.
    echo "--------------------------------"
    echo "MODE: Existing  "
    echo "--------------------------------"

    # apache_install  
    apache_config
    apache_start_on_boot
  
    # mysql_install
    # mysql_start_on_boot
    # mysql_start
    # mysql_create_db
  
    # wordpress_install
    wordpress_config

    apache_start
    clean_up
}

################################################
start_in_mode_database() {
  # =================================
  # MODE:      Database 
  # =================================
  # mysql:     install local instance
  # mysql:     create  new   database
  # mysql:     start   local instance
  # =================================
    echo "--------------------------------"
    echo "MODE: Database  "
    echo "--------------------------------"

    # apache_install  
    # apache_config
    # apache_start_on_boot
  
    # mysql_install
    mysql_start_on_boot
    mysql_start
    mysql_save_setup
    # mysql_create_db
  
    # wordpress_install
    # wordpress_config

    # apache_start
    clean_up
}

################################################
start_in_mode_datavol() {
  # =================================
  # MODE:      Datavol
  # =================================
  # =================================
  #  This mode will uninstall the mysql, mysql-server, mod_rewrite, mod_ssl, mod_env, php php-common, php-cli, php-mysql and httpd packages.
  #  This mode is intended to be used solely as a data volume, allowing another instance to connect to the installed directory structure of the application for persistent storage.
    echo "--------------------------------"
    echo "MODE: Datavol   "
    echo "--------------------------------"
    
    clean_up
}

################################################
case "$MODE" in
    standalone|Standalone|STANDALONE|"")
        start_in_mode_standalone  ;;
    remote|Remote|REMOTE)
        start_in_mode_remote      ;;
    existing|Existing|EXISTING)
        start_in_mode_existing    ;;
    datavol|Datavol|DATAVOL)
        start_in_mode_datavol     ;;
    database|Database|DATABASE)
        start_in_mode_database    ;;
    *)
        start_in_mode_standalone  ;;
esac
