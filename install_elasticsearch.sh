#!/bin/bash
###################################
#             Autor               #
#          Gustavo Nunez          #
# Install ElasticSearch on CentOs #
###################################

clear

echo "Running ..."
rpm --import https://packages.elasticsearch.org/GPG-KEY-elasticsearch
#content = "
#[elasticsearch-1.4]
#name=Elasticsearch repository for 6.x packages
#baseurl=https://artifacts.elastic.co/packages/6.x/yum
#gpgcheck=1
#gpgkey=https://artifacts.elastic.co/GPG-KEY-elasticsearch
#enabled=1
#autorefresh=1
#type=rpm-md"
echo "[OK]"

#echo $content >> /etc/yum.repos.d/elasticsearch.repo

echo "Installing elasticsearch ..."
yum -y install elasticsearch

echo "[OK]"

echo "Opening Ports On Firewall ..."

# open port 9200 (for http) and 9300 (for tcp)
sudo iptables -L -n
iptables -A INPUT -p tcp -m tcp --dport 9200 -j ACCEPT
iptables -A INPUT -p tcp -m tcp --dport 9300 -j ACCEPT
service iptables save

echo "[OK]"

chkconfig elasticsearch on

# set min max memory variables
export ES_MIN_MEM=5G
export ES_MAX_MEM=5G

# restart server
service elasticsearch restart
