# PowerDNS Authoritative Server

[![powerdns](https://github.com/RootShell-coder/powerdns/actions/workflows/docker.yml/badge.svg?branch=master)](https://github.com/RootShell-coder/powerdns/actions/workflows/docker.yml)

This is an all-in-one Docker image that includes PHP-FPM, Nginx, PowerAdmin (web interface), and PowerDNS Authoritative Server.

- PowerDNS v 4.9.9
- PowerAdmin v 4.0.4

Note: The image tag corresponds to the PowerAdmin version. Choose the tag based on the desired PowerAdmin version.

## Prerequisites

- Docker installed on your system.
- Docker Compose installed (usually comes with Docker Desktop).
- Basic knowledge of running Docker containers.

Note: The database (MariaDB/MySQL) must be set up separately as it is not included in this image.

## Supported Databases

PowerDNS supports MySQL, MariaDB, PostgreSQL, and SQLite. Configure the backend in the `PDNS_CONF` environment variable (e.g., `launch=gmysql` for MySQL/MariaDB).

## Quick Start

1. Create a `docker-compose.yml` file with the example below.
2. Run `docker-compose up -d` to start the services in the background.
3. Access PowerAdmin at `http://localhost/poweradmin` to complete the setup.

## Docker Compose Example

Here is a basic `docker-compose.yml` to get started:

```yaml
version: '3.8'

services:
  mariadb:
    image: mariadb
    environment:
      MYSQL_ROOT_PASSWORD: root_pass
      MYSQL_DATABASE: pdns_db
      MYSQL_USER: pdns_user
      MYSQL_PASSWORD: pdns_pass

  powerdns:
    image: ghcr.io/rootshell-coder/powerdns:4.0.4
    environment:
      PDNS_CONF: |
        launch=gmysql
        gmysql-host=mariadb
        gmysql-port=3306
        gmysql-dbname=pdns_db
        gmysql-user=pdns_user
        gmysql-password=pdns_pass
        gmysql-dnssec=yes
        allow-axfr-ips=127.0.0.1,::1
        local-address=0.0.0.0
        primary=no
        secondary=no
        cache-ttl=20
        distributor-threads=3
        allow-dnsupdate-from=127.0.0.1,::1
    ports:
      - "53:53/tcp"
      - "53:53/udp"
      - "80:80/tcp"
    depends_on:
      - mariadb
```

## Database Setup

After starting the containers, initialize the PowerDNS database:

1. Copy the schema file from the container:

   ```bash
   docker cp powerdns-powerdns-1:/usr/share/doc/pdns/schema.mysql.sql ./
   ```

2. Import the schema into MariaDB:

   ```bash
   docker exec -it powerdns-mariadb-1 mariadb -u pdns_user -p pdns_db < schema.mysql.sql
   ```

   Enter password: `pdns_pass`

This sets up the necessary tables.

## PowerAdmin Configuration

- Access PowerAdmin at `http://localhost/poweradmin` and follow the installation wizard.
- For custom settings, mount `settings.php` as a volume:

  ```yaml
  volumes:
    - ./settings.php:/var/www/html/poweradmin/config/settings.php:ro
  ```

## Post-Installation

To complete the PowerAdmin installation, remove the install directory as required by the installer:

```bash
docker exec powerdns-powerdns-1 rm -rf /var/www/html/poweradmin/install
```

## Usage

- PowerDNS listens on port 53 for DNS queries.
- PowerAdmin web interface on port 80 at `/poweradmin`.
- Manage DNS zones and records via the web interface.
