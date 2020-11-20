#!/bin/bash
###################################
#             Autor               #
#          Gustavo Nunez          #
# Install ElasticSearch on CentOs #
###################################

clear

echo "Running ..."
rpm --import https://packages.elasticsearch.org/GPG-KEY-elasticsearch
content = "
[elasticsearch]
name=Elasticsearch repository for 7.x packages
baseurl=https://artifacts.elastic.co/packages/7.x/yum
gpgcheck=1
gpgkey=https://artifacts.elastic.co/GPG-KEY-elasticsearch
enabled=0
autorefresh=1
type=rpm-md"
echo "[OK]"

echo $content >> /etc/yum.repos.d/elasticsearch.repo

    yum clean packages

    yum clean all

    yum clean all
    
echo "Installing elasticsearch ..."
yum -y install --enablerepo=elasticsearch elasticsearch
yum -y install elasticsearch

echo "[OK]"

yum install java-1.8.0-openjdk.x86_64

wget https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-7.9.2-x86_64.rpm

rpm -ivh elasticsearch-7.9.2-x86_64.rpm

systemctl enable elasticsearch.service

systemctl start elasticsearch.service

vim /etc/elasticsearch/elasticsearch.yml

Ajustar

cluster.name: my-application
network.host: localhost
http.port: 9200

vim /etc/elasticsearch/jvm.options

Alterar

-Djava.io.tmpdir=/var/log/elasticsearch

systemctl start elasticsearch.service


echo "Opening Ports On Firewall ..."

# open port 9200 (for http) and 9300 (for tcp)
sudo iptables -L -n
iptables -A INPUT -p tcp -m tcp --dport 9200 -j ACCEPT
iptables -A INPUT -p tcp -m tcp --dport 9300 -j ACCEPT
service iptables save

echo "[OK]"

# restart server
service elasticsearch restart


#https://github.com/elastic/elasticsearch/issues/57018
