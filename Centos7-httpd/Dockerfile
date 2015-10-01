FROM centos:latest
MAINTAINER http://www.centos.org
LABEL Vendor="CentOS"
LABEL License=GPLv2
LABEL Version=2.4.6-31

CMD ["/bin/bash"]
RUN yum -y update && yum clean all
RUN yum -y install wget
RUN yum -y install httpd && yum clean all
RUN yum -y install php php-mysql php-gd

VOLUME ["/var/www/html/"]
ADD site.tar /var/www/html/

ENV APACHE_RUN_USER www-data
ENV APACHE_RUN_GROUP www-data
ENV APACHE_LOG_DIR /var/log/apache2

EXPOSE 80

# Simple startup script to avoid some issues observed with container restart 
ADD run-httpd.sh /run-httpd.sh
RUN chmod -v +x /run-httpd.sh
CMD ["/run-httpd.sh"]

