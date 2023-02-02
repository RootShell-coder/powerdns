# powerdns

[![powerdns](https://github.com/RootShell-coder/powerdns/actions/workflows/docker.yml/badge.svg?branch=master)](https://github.com/RootShell-coder/powerdns/actions/workflows/docker.yml)

Powerdns v 4.7.3

PowerAdmin v 3.4.2


## PowerDNS Authoritative Server

The PowerDNS Authoritative Server is the only solution that enables authoritative DNS service from all major databases, including but not limited to MySQL, PostgreSQL, SQLite3, Microsoft SQL Server, LDAP, plain text files, and many other SQL databases via ODBC.

DNS answers can also be fully scripted using a variety of (scripting) languages such as Lua, Java, Perl, Python, Ruby, C and C++. Such scripting can be used for dynamic redirection, (spam) filtering or real time intervention.

In addition, the PowerDNS Authoritative Server is the leading DNSSEC implementation, hosting the majority of all DNSSEC domains worldwide. The Authoritative Server hosts at least 30% of all domain names in Europe, and around 90% of all DNSSEC domains in Europe.

[powerdns documentation](https://www.powerdns.com/documentation.html)




### how to use docker

`docker pull rootshellcoder/powerdns:latest`

docker-compose.yml _for a quick start, this simple yml file is enough_

```yaml
version: '3.9'

networks:
  powerdns:
    name: powerdns
    driver: bridge

services:

  mariadb:
    image: mariadb
    volumes:
      - ./mysqldb:/var/lib/mysql
    networks:
      - powerdns
    environment:
      - MYSQL_ROOT_PASSWORD=root_pass
      - MYSQL_DATABASE=pdns_db
      - MYSQL_USER=pdns_user
      - MYSQL_PASSWORD=pdns_pass

  powerdns:
    image: rootshellcoder/powerdns:latest
    networks:
      - powerdns
    environment:
      - TZ=Europe/Moscow

      - MYSQL_HOST=mariadb
      - MYSQL_DATABASE=pdns_db
      - MYSQL_USER=pdns_user
      - MYSQL_PASSWORD=pdns_pass

      - PDNS_ALLOW_AXFR_IPS=127.0.0.1/32, 172.17.0.1/32
      - PDNS_MASTER=yes
      - PDNS_SLAVE=yes
      - PDNS_CACHE_TTL=20
      - PDNS_DISTRIBUTOR_THREADS=3
      - PDNS_ALLOW_DNSUPDATE_FROM=127.0.0.1/32, 172.17.0.33/23

      - PDNS_WEBSERVER_ENABLE=yes
      - PDNS_WEBSERVER_IP=0.0.0.0
      - PDNS_WEBSERVER_ALLOW_FROM=127.0.0.1/32, 172.17.0.1/32
      - PDNS_WEBSERVER_PASSWORD=adminpass
      - PDNS_WEBSERVER_PORT=8080
      - PDNS_WEBSERVER_API_ENABLE=no
      - PDNS_WEBSERVER_API_KEY=adminapikey

      - POWERADMIN_HOSTMASTER=email.admmin.soa
      - POWERADMIN_IFACE_STYLE=spark
      - POWERADMIN_IFACE_LANG=ru_RU
      - POWERADMIN_NS1=ns1.example.com
      - POWERADMIN_NS2=ns2.example.com
    depends_on:
      - mariadb
    ports:
      - 80:80/TCP
      - 8080:8080/TCP
      - 53:53/TCP
      - 53:53/UDP

```

`docker compose up -d`



новый
