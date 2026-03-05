# Complete Guide to Docker Nginx: Configuration File Mounting, HTTPS Setup, and Reverse Proxy

Table of Contents

*   [Introduction](#introduction)
*   [Docker Nginx Configuration Basics and File Mounting](#docker-nginx-configuration-basics-and-file-mounting)
*   [Why Mount Configuration Files?](#why-mount-configuration-files)
*   [Key Nginx Container Directory Structure](#key-nginx-container-directory-structure)
*   [The Right Mounting Approach: Step by Step](#the-right-mounting-approach-step-by-step)
*   [Four Traps You Might Fall Into](#four-traps-you-might-fall-into)
*   [Single File Mount vs Directory Mount: Which to Choose?](#single-file-mount-vs-directory-mount-which-to-choose)
*   [HTTPS Configuration and Let’s Encrypt Auto-Renewal](#https-configuration-and-lets-encrypt-auto-renewal)
*   [Self-Signed Certificates: Quick Dev Environment Validation](#self-signed-certificates-quick-dev-environment-validation)
*   [Let’s Encrypt: Free Production Certificates](#lets-encrypt-free-production-certificates)
*   [Steps for Initial Certificate Request](#steps-for-initial-certificate-request)
*   [Verifying Auto-Renewal](#verifying-auto-renewal)
*   [Security Enhancements for HTTPS Configuration](#security-enhancements-for-https-configuration)
*   [Reverse Proxy and Docker Inter-Container Communication](#reverse-proxy-and-docker-inter-container-communication)
*   [Container Networking Explained](#container-networking-explained)
*   [Creating Custom Network and Running Containers](#creating-custom-network-and-running-containers)
*   [Nginx Reverse Proxy Configuration in Action](#nginx-reverse-proxy-configuration-in-action)
*   [Simplifying Multi-Container Management with docker-compose](#simplifying-multi-container-management-with-docker-compose)
*   [Troubleshooting Common Proxy Issues](#troubleshooting-common-proxy-issues)
*   [Load Balancing Multiple Backend Services](#load-balancing-multiple-backend-services)
*   [Production Best Practices and Performance Optimization](#production-best-practices-and-performance-optimization)
*   [Configuration File Management: Don’t Go to Production Naked](#configuration-file-management-dont-go-to-production-naked)
*   [Log Management: Don’t Wait Until Disk is Full](#log-management-dont-wait-until-disk-is-full)
*   [Graceful Reload: Don’t Let Users Notice](#graceful-reload-dont-let-users-notice)
*   [Security Hardening Checklist](#security-hardening-checklist)
*   [Performance Tuning: Squeeze Out Nginx Performance](#performance-tuning-squeeze-out-nginx-performance)
*   [Monitoring and Health Checks](#monitoring-and-health-checks)
*   [Conclusion](#conclusion)

## Introduction

What you’ll learn:

*   Why config changes don’t take effect and 5 correct mounting approaches
*   Complete path from self-signed certificates to Let’s Encrypt configuration
*   Network configuration tricks for reverse proxying other Docker containers
*   Production environment security hardening and performance optimization

## Docker Nginx Configuration Basics and File Mounting

### Why Mount Configuration Files?

You might ask: why not just bake the Nginx config into the image? You could, but that’s painful…

Every config change means rebuilding the image, pushing to a registry, pulling it back down, and restarting the container—the whole process takes 10+ minutes. Not to mention config version control and multi-environment deployment needs. Imagine: 2 AM, production issue, you want to quickly rollback a config change, but you have to wait for an image build? Nightmare fuel.

Mounting config files solves this pain point: modify files on the host, changes take effect in the container immediately. Testing, rollback, team collaboration—all much easier.

### Key Nginx Container Directory Structure

First, understand where Nginx keeps its stuff in the container:

```
/etc/nginx/
├── nginx.conf              # Main config file, the boss
├── conf.d/                 # Site config directory
│   └── default.conf        # Default site config
/usr/share/nginx/html       # Static files root directory
/var/log/nginx/             # Logs directory
    ├── access.log
    └── error.log
```

Key point: nginx.conf contains this line: `include /etc/nginx/conf.d/*.conf;`. This means the main config automatically loads all .conf files in conf.d. If you only mount nginx.conf and forget conf.d—congratulations, you’ve found your first trap.

### The Right Mounting Approach: Step by Step

Don’t rush to start the container. Do some prep work first—it’ll save you headaches later.

**Step 1: Copy default config from container as template**

Why? Official default configs are tested and reliable. Better to modify them than write from scratch.

```sh
# Start a temporary container
docker run --name nginx-temp -d nginx

# Copy out the default config
docker cp nginx-temp:/etc/nginx/nginx.conf ./nginx/nginx.conf
docker cp nginx-temp:/etc/nginx/conf.d ./nginx/conf.d

# Clean up
docker stop nginx-temp && docker rm nginx-temp
```

**Step 2: Create standard directory structure on host**

My habit is keeping all Docker stuff under `/opt`, but adjust to your preference:

```sh
mkdir -p /opt/nginx/{conf,conf.d,html,logs,ssl}
```

This directory structure covers config, static files, logs, and SSL certificates. All in one go.

**Step 3: Start container and mount all directories**

Here comes the main event. Pay attention to the path mappings after each `-v` parameter:

```sh
docker run -d --name my-nginx \
  -p 80:80 -p 443:443 \
  -v /opt/nginx/conf/nginx.conf:/etc/nginx/nginx.conf:ro \
  -v /opt/nginx/conf.d:/etc/nginx/conf.d \
  -v /opt/nginx/html:/usr/share/nginx/html \
  -v /opt/nginx/logs:/var/log/nginx \
  -v /opt/nginx/ssl:/etc/nginx/ssl \
  nginx
```

Key points:

*   `-p 80:80 -p 443:443`: Expose both HTTP and HTTPS ports (needed for HTTPS later)
*   `nginx.conf` has `:ro` (read-only mount) to prevent container processes from accidentally modifying config
*   `conf.d` mounts the entire directory, not a single file (very important, I’ll explain why below)

### Four Traps You Might Fall Into

**Trap 1: Container doesn’t sync after editing config with vim**

This was my first trap. Modified nginx.conf on the host, restarted container, no effect.

Reason: vim changes the file’s inode value when editing. Docker mounting works through inodes, so when the inode changes, the container still sees the old file.

Two solutions:

*   Solution A: Use nano editor (doesn’t change inode)
*   Solution B: Mount the entire directory instead of a single file

I now use Solution B. With directory mounting, inode changes don’t matter, plus you can flexibly add/remove config files.

**Trap 2: Incorrect include path configuration**

Check your nginx.conf inside the container:

```sh
docker exec -it my-nginx bash
cat /etc/nginx/nginx.conf | grep include
```

Make sure this line exists:

```sh
include /etc/nginx/conf.d/*.conf;
```

If you changed it to `/opt/nginx/conf.d/*.conf` (host path), that’s wrong. The container only recognizes container paths.

**Trap 3: Forgetting to mount the conf.d directory**

Mounting nginx.conf alone isn’t enough. If you add new site configs in the host’s conf.d, the container won’t see them.

Verification:

```sh
docker exec my-nginx ls /etc/nginx/conf.d
```

You should see all files from your host’s `/opt/nginx/conf.d`.

**Trap 4: File permissions preventing Nginx from reading config**

This is common on Linux. Config file permissions too strict, Nginx process (usually runs as nginx user) can’t read them.

Fix:

```sh
chmod 644 /opt/nginx/conf/nginx.conf
chmod 644 /opt/nginx/conf.d/*.conf
```

After modifying config, make it a habit to test syntax:

```sh
docker exec my-nginx nginx -t
```

Seeing `syntax is ok` means you’re good.

### Single File Mount vs Directory Mount: Which to Choose?

This gets asked a lot. My recommendation:

**Main config nginx.conf**: Can do single file mount + read-only (:ro), since it rarely changes frequently

**conf.d directory**: Must mount the directory for flexible management of multiple site configs

**html, logs**: Directory mount, no question

Remember this principle: need to flexibly manage multiple files? Mount the directory. Core config file you want version-controlled? Single file mount with read-only protection.

## HTTPS Configuration and Let’s Encrypt Auto-Renewal

### Self-Signed Certificates: Quick Dev Environment Validation

Production definitely needs proper certificates, but for dev/test, self-signed certificates work fine. A few commands:

```sh
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /opt/nginx/ssl/nginx.key \
  -out /opt/nginx/ssl/nginx.crt \
  -subj "/C=CN/ST=Beijing/L=Beijing/O=Dev/CN=localhost"
```

This generates two files:

*   `nginx.key`: Private key, keep it secret
*   `nginx.crt`: Certificate file

Then create an `ssl.conf` in `/opt/nginx/conf.d/`:

```nginx
server {
    listen 443 ssl;
    server_name localhost;

    ssl_certificate /etc/nginx/ssl/nginx.crt;
    ssl_certificate_key /etc/nginx/ssl/nginx.key;

    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;

    location / {
        root /usr/share/nginx/html;
        index index.html;
    }
}
```

Key points:

*   `ssl_certificate` path is the container path (`/etc/nginx/ssl`), not the host’s `/opt/nginx/ssl`
*   `ssl_protocols` only enables TLS 1.2 and 1.3, older protocol versions have security vulnerabilities
*   Don’t forget `-p 443:443` when starting the container, or HTTPS port won’t be exposed

Hot reload config:

```sh
docker exec my-nginx nginx -s reload
```

Visit `https://localhost`, browser will warn about untrusted certificate—don’t panic, that’s normal for self-signed certs. Click “continue anyway.”

### Let’s Encrypt: Free Production Certificates

Let’s Encrypt is amazing. Free, automated, globally trusted. The only “drawback” is certificates expire in 90 days, but with proper auto-renewal setup, it’s no problem.

I recommend the `docker-compose` + `certbot` container approach—much more reliable than manual fiddling.

Here’s the complete `docker-compose.yml`:

```yaml
version: '3'

services:
  nginx:
    image: nginx:latest
    container_name: my-nginx
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx/conf.d:/etc/nginx/conf.d
      - ./nginx/html:/usr/share/nginx/html
      - ./certbot/conf:/etc/letsencrypt
      - ./certbot/www:/var/www/certbot
    command: "/bin/sh -c 'while :; do sleep 6h & wait $${!}; nginx -s reload; done & nginx -g \"daemon off;\"'"
    networks:
      - web

  certbot:
    image: certbot/certbot
    container_name: certbot
    volumes:
      - ./certbot/conf:/etc/letsencrypt
      - ./certbot/www:/var/www/certbot
    entrypoint: "/bin/sh -c 'trap exit TERM; while :; do certbot renew; sleep 12h & wait $${!}; done;'"
    networks:
      - web

networks:
  web:
    driver: bridge
```

Key points:

**1\. Shared mounts for certificates and verification files**

*   `./certbot/conf` mounted to both containers—certbot generates certs, nginx reads them
*   `./certbot/www` used for Let’s Encrypt HTTP verification (webroot method)

**2\. Nginx auto-reloads every 6 hours**

This complex-looking command just starts a background loop that reloads config every 6 hours, so renewed certificates take effect immediately.

**3\. Certbot checks for renewal every 12 hours**

Let’s Encrypt recommends daily checks, 12 hours is even safer.

### Steps for Initial Certificate Request

First create a temporary config `temp.conf` in `/opt/nginx/conf.d/` for HTTP verification:

```nginx
server {
    listen 80;
    server_name your-domain.com;  # Change to your domain

    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }

    location / {
        return 301 https://$host$request_uri;
    }
}
```

Start services:

```sh
docker-compose up -d
```

Request certificate (replace your-domain.com and [your@email.com](mailto:your@email.com) with yours):

```sh
docker-compose run --rm certbot certonly --webroot \
  -w /var/www/certbot \
  -d your-domain.com \
  --email your@email.com \
  --agree-tos \
  --no-eff-email
```

If all goes well, you’ll see “Congratulations!” Certificate files will be in `./certbot/conf/live/your-domain.com/`.

Now create the production HTTPS config. Modify `temp.conf` to:

```nginx
server {
    listen 80;
    server_name your-domain.com;

    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }

    location / {
        return 301 https://$host$request_uri;
    }
}

server {
    listen 443 ssl http2;
    server_name your-domain.com;

    ssl_certificate /etc/letsencrypt/live/your-domain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/your-domain.com/privkey.pem;

    # SSL optimization
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256';
    ssl_prefer_server_ciphers on;

    # HSTS (force HTTPS)
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;

    location / {
        root /usr/share/nginx/html;
        index index.html;
    }
}
```

Reload config:

```sh
docker-compose exec nginx nginx -s reload
```

### Verifying Auto-Renewal

Let’s Encrypt certificates are valid for 90 days, but certbot auto-renews when 30 days remain. Test it manually:

```sh
docker-compose run --rm certbot renew --dry-run
```

Seeing “The dry run was successful” means you’re good.

Check cron logs to see if renewal task runs normally:

```sh
docker-compose logs certbot
```

### Security Enhancements for HTTPS Configuration

If you want a more secure SSL config, add these:

```nginx
# OCSP Stapling (online certificate status check)
ssl_stapling on;
ssl_stapling_verify on;
ssl_trusted_certificate /etc/letsencrypt/live/your-domain.com/chain.pem;
resolver 8.8.8.8 8.8.4.4 valid=300s;
resolver_timeout 5s;

# Prevent iframe embedding (clickjacking protection)
add_header X-Frame-Options DENY;

# XSS protection
add_header X-Content-Type-Options nosniff;
add_header X-XSS-Protection "1; mode=block";
```

After configuring, test your SSL config rating at [SSL Labs](https://www.ssllabs.com/ssltest/). Getting an A+ isn’t hard.

## Reverse Proxy and Docker Inter-Container Communication

### Container Networking Explained

When it comes to using Nginx to proxy other Docker containers, networking configuration is the biggest headache. You might have tried using container IPs directly, only to find they change after each restart—config needs updating again.

Docker has several network modes, these two are most common:

*   **bridge**: Default mode, containers communicate through a virtual bridge
*   **host**: Container uses host’s network stack directly, better performance but worse isolation

For Nginx reverse proxy scenarios, I strongly recommend **custom bridge networks**. Why?

1.  Containers can communicate using service names, no need to worry about IP changes
2.  Network isolation, project containers form their own network environment
3.  Automatic DNS resolution, Docker’s built-in service discovery

### Creating Custom Network and Running Containers

First create a custom network:

```sh
docker network create my-app-network
```

Start your backend service (assume it’s a Node.js API):

```sh
docker run -d \
  --name backend-api \
  --network my-app-network \
  -e NODE_ENV=production \
  my-backend:latest
```

Start Nginx, connect to the same network:

```sh
docker run -d \
  --name my-nginx \
  --network my-app-network \
  -p 80:80 -p 443:443 \
  -v /opt/nginx/conf.d:/etc/nginx/conf.d \
  nginx
```

Key point: Both containers on the same network, Nginx config can directly use `backend-api` as the hostname to access the backend service.

### Nginx Reverse Proxy Configuration in Action

Create `api-proxy.conf` in `/opt/nginx/conf.d/`:

```nginx
upstream backend {
    server backend-api:3000;  # container-name:port
    keepalive 32;
}

server {
    listen 80;
    server_name api.example.com;

    # API proxy
    location /api/ {
        proxy_pass http://backend/;

        # Pass real client info
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # WebSocket support (if needed)
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";

        # Timeout settings
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }

    # Static files served by Nginx
    location / {
        root /usr/share/nginx/html;
        index index.html;
        try_files $uri $uri/ /index.html;
    }
}
```

Easy-to-miss details:

**1\. Path handling in upstream and proxy\_pass**

Notice `proxy_pass http://backend/;` has a trailing slash. This means request `/api/users` gets forwarded as `http://backend/users` (strips /api prefix).

Without the slash `proxy_pass http://backend;`, it forwards as `http://backend/api/users` (keeps full path).

**2\. Importance of X-Forwarded-For header**

If backend service needs real client IP, it relies on this header. Otherwise backend only sees Nginx container IP.

**3\. Keepalive connection pool**

`keepalive 32` in upstream reuses TCP connections, reducing handshake overhead. Very useful for high concurrency scenarios.

### Simplifying Multi-Container Management with docker-compose

Manually creating networks and starting containers one by one is tedious. Use docker-compose for one-command deployment:

```yaml
version: '3.8'

services:
  backend:
    image: my-backend:latest
    container_name: backend-api
    environment:
      - NODE_ENV=production
      - DATABASE_URL=postgres://db:5432/mydb
    networks:
      - app-network
    depends_on:
      - db

  nginx:
    image: nginx:latest
    container_name: my-nginx
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx/conf.d:/etc/nginx/conf.d
      - ./nginx/html:/usr/share/nginx/html
      - ./nginx/logs:/var/log/nginx
    networks:
      - app-network
    depends_on:
      - backend

  db:
    image: postgres:14
    container_name: postgres-db
    environment:
      - POSTGRES_PASSWORD=secret
      - POSTGRES_DB=mydb
    volumes:
      - db-data:/var/lib/postgresql/data
    networks:
      - app-network

networks:
  app-network:
    driver: bridge

volumes:
  db-data:
```

One command starts the entire service stack:

```sh
docker-compose up -d
```

Docker automatically:

*   Creates the `app-network` network
*   Starts containers in `depends_on` order
*   Sets up inter-container DNS resolution

Your Nginx config can directly use `backend` and `db` as hostnames to access corresponding services. Sweet.

### Troubleshooting Common Proxy Issues

**Issue 1: 502 Bad Gateway**

Most common error, usually caused by:

*   Backend service not started or crashed
*   Nginx and backend not on same network
*   Backend listening on wrong port

Troubleshooting steps:

```sh
# Check if backend service is running
docker ps | grep backend

# Check network connection
docker network inspect my-app-network

# Enter Nginx container to test connectivity
docker exec -it my-nginx sh
ping backend-api
curl http://backend-api:3000/health
```

If ping doesn’t work, network config issue. If curl times out, backend service listening issue.

**Issue 2: Request Timeout**

Default proxy timeout is 60 seconds. If your API takes longer (large file uploads, complex calculations), increase timeout:

```nginx
location /api/long-running/ {
    proxy_pass http://backend/;
    proxy_connect_timeout 300s;
    proxy_send_timeout 300s;
    proxy_read_timeout 300s;
}
```

**Issue 3: POST Request Body Lost**

Sometimes POST requests become GET at backend, or request body is empty. Check this config:

```nginx
location /api/ {
    proxy_pass http://backend/;
    proxy_request_buffering off;  # Disable request buffering
    client_max_body_size 100M;     # Allow large file uploads
}
```

### Load Balancing Multiple Backend Services

If you have multiple backend instances, Nginx can do load balancing:

```nginx
upstream backend_cluster {
    least_conn;  # Least connections algorithm

    server backend-1:3000 weight=3;  # Weight 3
    server backend-2:3000 weight=1;  # Weight 1
    server backend-3:3000 backup;     # Backup server

    keepalive 32;
}

server {
    listen 80;

    location /api/ {
        proxy_pass http://backend_cluster/;
        # ... other proxy settings
    }
}
```

Load balancing algorithms:

*   `round-robin` (default): Round robin
*   `least_conn`: Least connections first
*   `ip_hash`: Same client IP always goes to same server

If a backend crashes, Nginx automatically routes traffic to other healthy nodes.

## Production Best Practices and Performance Optimization

### Configuration File Management: Don’t Go to Production Naked

Throwing config files directly on the server? That’s for dev environments. Production needs more finesse.

**Git-Based Configuration Management**

My approach is a separate repo for all Nginx configs, with different environments in separate directories. Benefits are obvious:

*   Version history at a glance, rollback is just `git checkout`
*   Easy team collaboration, PR review config changes
*   CI/CD integration, automated deployment

**Configuration Templating**

Different environment configs are mostly similar, templates + variable substitution saves tons of work. Use `envsubst` during deployment to replace variables.

### Log Management: Don’t Wait Until Disk is Full

Nginx writes logs fast. High-traffic sites easily generate several GB per day. If not managed, one day the disk fills up and the container dies.

**Log Rotation Configuration**

Configure logrotate on the host to rotate logs daily, keep 14 days, auto-compress old logs. Key is making Nginx reopen log files after rotation (`nginx -s reopen`), otherwise it keeps writing to the old file.

**Centralized Logging Solution**

If you have multiple servers, consider sending logs to a centralized platform (ELK, Loki, cloud services). Using Docker logging drivers or Promtail is simple.

### Graceful Reload: Don’t Let Users Notice

After modifying config, never do `docker restart`. Restart drops all connections, all in-flight requests get lost.

Right way:

```sh
# Test config syntax first
docker exec my-nginx nginx -t

# If syntax is OK, then reload
docker exec my-nginx nginx -s reload
```

`reload` is graceful: new worker processes start with new config, old workers finish existing requests then exit, seamless transition, users notice nothing.

### Security Hardening Checklist

Before going to production, check these security points:

**1\. Hide Nginx Version Number**

By default, error pages expose Nginx version. Hackers can use this for targeted attacks on known vulnerabilities. Add `server_tokens off;` in http block to hide version.

**2\. Rate Limiting for DDoS Protection**

Simple but effective protection:

```nginx
http {
    # Limit request rate per IP
    limit_req_zone $binary_remote_addr zone=api_limit:10m rate=10r/s;

    # Limit concurrent connections
    limit_conn_zone $binary_remote_addr zone=conn_limit:10m;
}

server {
    location /api/ {
        limit_req zone=api_limit burst=20 nodelay;
        limit_conn conn_limit 10;
        proxy_pass http://backend/;
    }
}
```

**3\. Read-Only Config File Mounting**

Add `:ro` to main config to prevent container processes from accidentally modifying it.

**4\. Principle of Least Privilege**

Ensure nginx.conf has `user nginx;`, don’t change to root—huge security risk.

### Performance Tuning: Squeeze Out Nginx Performance

**Worker Process Optimization**

```nginx
worker_processes auto;  # Auto-match CPU cores
worker_cpu_affinity auto;  # Bind CPU affinity
```

`auto` is a lazy person’s blessing, Nginx auto-detects CPU cores.

**Connection Optimization**

```nginx
events {
    worker_connections 2048;  # Max connections per worker
    use epoll;                # epoll has best performance on Linux
}
```

Theoretical max concurrency: `worker_processes * worker_connections`. But also consider file handle limits (`ulimit -n`).

**Gzip Compression**

Text content can be reduced 60-80% after compression:

```nginx
http {
    gzip on;
    gzip_vary on;
    gzip_proxied any;
    gzip_comp_level 6;  # Level 1-9, 6 balances performance and compression
    gzip_types
        text/plain
        text/css
        text/xml
        application/json
        application/javascript
        application/xml+rss
        application/atom+xml
        image/svg+xml;
    gzip_min_length 1000;  # Don't compress files under 1KB, wastes CPU
}
```

**Static Asset Caching**

```nginx
location ~* \.(jpg|jpeg|png|gif|ico|css|js|woff2)$ {
    expires 30d;  # Browser cache 30 days
    add_header Cache-Control "public, immutable";
}
```

**HTTP/2 Support**

HTTP/2 significantly improves performance, enabling is simple:

```nginx
server {
    listen 443 ssl http2;  # Just add http2
    # ... other config
}
```

Prerequisite: you need HTTPS, HTTP/2 requires TLS.

### Monitoring and Health Checks

Don’t forget monitoring. Recommend Prometheus + Grafana with nginx-prometheus-exporter to export metrics. Enable stub\_status in Nginx config, restrict to Docker internal network only, then Prometheus scrapes metrics and Grafana displays monitoring dashboards.

## Conclusion

To sum it all up, four key things:

**Config File Mounting**: Directory mounting beats single file, add read-only protection to main config, don’t forget conf.d and ssl directories. Avoid vim’s inode trap.

**HTTPS Configuration**: Use self-signed for dev quick validation, Let’s Encrypt + Certbot automation for production. docker-compose makes renewal brain-dead simple.

**Reverse Proxy**: Custom bridge network is king, using container names for communication is worry-free. Add keepalive to upstream config for both performance and reliability.

**Production Practices**: Git-manage config versions, don’t forget log rotation, graceful reload not restart, don’t skip security strategies.

Docker Nginx looks simple but has tons of details. Master these, and you can build a stable, reliable web service architecture from dev to production.
