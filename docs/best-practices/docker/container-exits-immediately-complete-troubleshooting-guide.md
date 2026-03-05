# Docker Container Exits Immediately? Complete Troubleshooting Guide

Table of Contents

*   [Understanding Container Lifecycle and Exit Codes](#understanding-container-lifecycle-and-exit-codes)
*   [The Nature of Containers: Process Lifecycle](#the-nature-of-containers-process-lifecycle)
*   [Exit Code Quick Reference: The Story Behind the Numbers](#exit-code-quick-reference-the-story-behind-the-numbers)
*   [Exit Code Patterns](#exit-code-patterns)
*   [4-Step Diagnosis Method for Quick Problem Location](#4-step-diagnosis-method-for-quick-problem-location)
*   [Step 1: Confirm Container Status](#step-1-confirm-container-status)
*   [Step 2: Check Container Logs](#step-2-check-container-logs)
*   [Step 3: Check Container Configuration](#step-3-check-container-configuration)
*   [Step 4: Interactive Startup Verification](#step-4-interactive-startup-verification)
*   [5 Common Failure Scenarios and Solutions](#5-common-failure-scenarios-and-solutions)
*   [Scenario 1: Config File Errors or Missing Paths](#scenario-1-config-file-errors-or-missing-paths)
*   [Scenario 2: Out of Memory (OOM Killed)](#scenario-2-out-of-memory-oom-killed)
*   [Scenario 3: Port Conflicts](#scenario-3-port-conflicts)
*   [Scenario 4: Insufficient Permissions](#scenario-4-insufficient-permissions)
*   [Scenario 5: Dependent Services Not Ready](#scenario-5-dependent-services-not-ready)
*   [Preventive Measures and Best Practices](#preventive-measures-and-best-practices)
*   [Configure Health Checks (HEALTHCHECK)](#configure-health-checks-healthcheck)
*   [Set Restart Policies](#set-restart-policies)
*   [Log Management: Prevent Disk Full](#log-management-prevent-disk-full)
*   [Monitoring and Alerts: Detect Problems Early](#monitoring-and-alerts-detect-problems-early)
*   [Production Environment Configuration Checklist](#production-environment-configuration-checklist)
*   [Conclusion](#conclusion)


This is a guide to diagnosing container startup failures. Whether you’re seeing Exit Code 1, 137, or something else, this method will help you quickly pinpoint the root cause.

## Understanding Container Lifecycle and Exit Codes

Before we start troubleshooting, let’s clarify a fundamental question: why do containers exit?

### The Nature of Containers: Process Lifecycle

A Docker container is essentially an isolated process. When the process is alive, the container runs; when the process dies, the container exits.

Imagine you start a web server container. The main process might be nginx or node. As long as that process runs, `docker ps` shows the container. But if the main process exits for any reason—normal completion, crash, or system kill—the container immediately goes into Exited status.

That’s why sometimes `docker ps` shows nothing, and you need the `-a` flag to see exited containers.

### Exit Code Quick Reference: The Story Behind the Numbers

Each time a container exits, Docker records an exit code. These numbers might seem cryptic, but they’re actually telling you what happened.

**Exit Code 0**: All good, task completed.
For example, if you run a data import script that finishes successfully, it exits with 0. This isn’t a problem—the container just finished its job.

**Exit Code 1**: The program had an issue.
This is the most common error code. Could be a misconfigured file, missing dependency, or code bug. Basically, the application inside the container crashed.

I remember deploying a MySQL container once that kept exiting with code 1. After digging through logs, I found I’d accidentally typed a colon instead of an equals sign in the config file. MySQL saw the syntax error and refused to start.

**Exit Code 137**: Out of memory, or forcibly killed.
This is the code I dread most. 137 usually means one of two things:

1.  The container exceeded its memory limit, and Linux’s OOM Killer terminated the process
2.  Someone (or the system) executed `docker kill` or `kill -9`

How to tell? Check the `OOMKilled` field with `docker inspect`. If it’s `true`, it’s a memory issue; if `false`, it was probably manually terminated.

**Exit Code 127**: Command not found.
Usually means the CMD or ENTRYPOINT in the Dockerfile has a wrong path, or the executable doesn’t exist in the container image.

**Exit Code 139**: Segmentation fault.
This typically shows up in C/C++ programs, meaning the program accessed memory it shouldn’t have. If you’re not running low-level programs, you’ll rarely see this.

### Exit Code Patterns

Exit codes actually follow a pattern:

*   **0**: Normal exit, no issues
*   **1-128**: Application problems (app errors, config errors, etc.)
*   **129-255**: External intervention (killed by signal, terminated by system, etc.)

Understanding these patterns helps you know what type of problem you’re dealing with, giving you direction for troubleshooting.

## 4-Step Diagnosis Method for Quick Problem Location

Now you know what exit codes mean. But knowing meanings isn’t enough—you need to know how to dig out the problem step by step.

I’ve developed a 4-step diagnosis method that covers about 90% of container startup failure scenarios. Follow this process and you’ll find problems aren’t so mysterious after all.

### Step 1: Confirm Container Status

Don’t rush to check logs yet. First, confirm the container exists and has actually died.

```sh
docker ps -a
```

This command lists all containers, including exited ones. Pay attention to these key pieces of information:

**CONTAINER ID**: The container’s unique identifier, needed for subsequent commands. You can copy just the first few characters; Docker will auto-match.

**STATUS column**: This is the key. Running containers show `Up X minutes`, exited containers show `Exited (code) X minutes ago`.

For example:

```sh
CONTAINER ID   IMAGE         STATUS
a1b2c3d4e5f6   mysql:8.0     Exited (1) 2 minutes ago
```

Exit code 1 suggests an application layer problem. If it’s 137, likely a memory issue.

**Note creation and exit times**. If the container exits less than 1 second after creation, it’s probably a startup command or config issue. If it ran for a while before exiting, it might be resource shortage or dependency failure.

### Step 2: Check Container Logs

This is the most critical step. Containers usually leave clues before exiting, and those clues are in the logs.

**Basic viewing**:

```sh
docker logs <container_id>
```

This shows all standard output and standard error from the container. Often you’ll directly see error messages like `Permission denied`, `No such file or directory`, `Connection refused`, etc.

**Real-time tracking** (good for troubleshooting startup process):

```sh
docker logs -f <container_id>
```

If you want to see what happens during container startup, use `-f`. It works like `tail -f`, showing new logs in real-time. Though this is less useful for already-exited containers, it’s great when trying to restart.

**View recent logs only**:

```sh
docker logs --tail 100 <container_id>
```

If container logs are too long, just check the last 100 lines. Often the last few lines reveal the problem.

**Add timestamps**:

```sh
docker logs -t <container_id>
```

The `-t` flag adds timestamps to each log line, helping you determine exactly when the problem occurred.

**Filter error logs**:

```sh
docker logs <container_id> 2>&1 | grep -i error
```

If there are too many logs, just look for lines containing “error”. This quickly pinpoints critical errors.

### Step 3: Check Container Configuration

Sometimes logs don’t reveal much. That’s when you need to dive deeper into the container’s config and state.

**View full configuration**:

```sh
docker inspect <container_id>
```

This outputs a ton of JSON information, including all container config, environment variables, mount points, network settings, etc. It’s a lot of information, but very useful.

**Quickly check specific information**:

Check exit code:

```sh
docker inspect --format '{{.State.ExitCode}}' <container_id>
```

Check if OOM killed:

```sh
docker inspect --format '{{.State.OOMKilled}}' <container_id>
```

If output is `true`, it’s definitely a memory problem.

Check environment variables:

```sh
docker inspect --format '{{.Config.Env}}' <container_id>
```

Sometimes environment variables are misconfigured—database connection strings, API keys, etc.

Check mount paths:

```sh
docker inspect --format '{{.Mounts}}' <container_id>
```

Verify that config files and data directories are mounted correctly.

Check log file path:

```sh
docker inspect --format='{{.LogPath}}' <container_id>
```

If `docker logs` doesn’t work, you can directly find the log file on the host.

### Step 4: Interactive Startup Verification

If you’ve completed the first three steps and still haven’t located the problem, you need to get inside the container yourself.

**Start container interactively**:

If your original startup command was:

```sh
docker run -d my-app
```

Change `-d` to `-it` to run the container in the foreground:

```sh
docker run -it my-app
```

This lets you see all output during container startup in real-time. Many errors will display directly on screen.

**Manually enter container**:

If the container starts and immediately exits, you can use a shell to enter and manually execute commands:

```sh
docker run -it my-app /bin/bash
```

Or:

```sh
docker run -it my-app /bin/sh
```

Once inside, you can:

*   Check if config files exist: `ls /etc/app/config.yaml`
*   Test config file syntax: like MySQL’s `mysqld --verbose --help` validates config
*   Manually run the startup command to see specific errors
*   Check dependency service connectivity: `ping database`, `telnet redis 6379`

This method is especially good for troubleshooting path issues, permission issues, and dependency issues.

I know this seems like a lot of steps. But trust me, in practice, most problems are solved in step 2 when checking logs. Only tricky edge cases require all four steps.

## 5 Common Failure Scenarios and Solutions

Now that we’ve covered troubleshooting methods, let’s look at real-world scenarios. I’ve categorized them into five types that cover most daily issues.

### Scenario 1: Config File Errors or Missing Paths

**Typical symptoms**:

*   Exit Code 1
*   Logs show `No such file or directory`, `config file not found`, `syntax error`, etc.

**Real case**:

Once I deployed a Node.js app and the container wouldn’t start. Logs showed:

```sh
Error: ENOENT: no such file or directory, open '/app/config/prod.json'
```

After checking, I found I’d written the mount path in the `docker run` command as:

```sh
-v /home/user/config:/app/conf  # Notice it's "conf"
```

But the app was reading from `/app/config`. One letter difference, and the app couldn’t find the config file, causing startup failure.

**Troubleshooting method**:

1.  Use `docker inspect --format '{{.Mounts}}'` to check mount paths
2.  Enter the container and `ls` to verify files are actually at that location
3.  If it’s config file syntax error, most apps will specify which line in the logs

**Solutions**:

Wrong mount path:

```sh
# Wrong example
docker run -v /host/path:/wrong/path my-app

# Correct approach
docker run -v /host/path:/app/config my-app
```

Config file syntax error:

*   For YAML files, use online tools or `yamllint` to check syntax
*   For JSON files, use `jq` to validate: `jq . config.json`
*   For MySQL config, execute `mysqld --verbose --help` in the container to check for syntax errors

### Scenario 2: Out of Memory (OOM Killed)

**Typical symptoms**:

*   Exit Code 137
*   `docker inspect --format '{{.State.OOMKilled}}'` returns `true`
*   Logs might show `Cannot allocate memory`, `Out of memory`, etc.

**Real case**:

I had a Java app that ran fine in local dev environment, but kept restarting when deployed to test server. Checking logs:

```sh
OpenJDK 64-Bit Server VM warning: INFO: os::commit_memory failed; error='Cannot allocate memory' (errno=12)
```

Turned out Docker Desktop on the test server only had 512MB memory limit, but this Java app needed 600MB just to start.

**Troubleshooting method**:

```sh
# Confirm OOM
docker inspect --format '{{.State.OOMKilled}}' <container_id>

# Check host memory
free -h

# Check container runtime memory usage
docker stats <container_id>
```

**Solutions**:

Increase container memory limit:

```sh
docker run -m 1g my-app  # Limit max memory to 1GB
docker run -m 512m --memory-swap 1g my-app  # Also set swap
```

If using Docker Desktop, adjust in settings:

*   macOS: Docker Desktop → Preferences → Resources → Memory
*   Windows: Docker Desktop → Settings → Resources → Memory

Optimize the application itself:

*   Java apps can limit JVM heap size: `java -Xmx512m -jar app.jar`
*   Node.js can set: `node --max-old-space-size=512 app.js`
*   Check code for memory leaks

Production environment recommendations:

*   Set reasonable memory limits based on actual app needs
*   Configure `--memory-reservation` for soft limits
*   Monitor memory usage trends, scale up proactively

### Scenario 3: Port Conflicts

**Typical symptoms**:

*   Exit Code 1
*   Logs show `port is already allocated`, `address already in use`, `bind: address already in use`

**Real case**:

Monday morning at the office, I ran `docker-compose up` and the Nginx container wouldn’t start. Error message:

```sh
Error starting userland proxy: listen tcp4 0.0.0.0:80: bind: address already in use
```

Turned out I’d tested a local Nginx before leaving Friday and forgot to shut it down. Port 80 was occupied, so the new container couldn’t start.

**Troubleshooting method**:

Check port usage (Linux/macOS):

```sh
lsof -i :8080
netstat -tuln | grep 8080
```

Check port usage (Windows):

```sh
netstat -ano | findstr 8080
```

Check other containers’ port mappings:

```sh
docker ps --format "table {{.Names}}\t{{.Ports}}"
```

**Solutions**:

**Option 1**: Change mapped port

```sh
# Original command
docker run -p 8080:8080 my-app

# Change to different port
docker run -p 8081:8080 my-app
```

**Option 2**: Stop service using the port

```sh
# Find process ID
lsof -i :8080

# Kill process
kill -9 <PID>
```

**Option 3**: If another container is using it, stop that one first

```sh
docker stop <conflicting_container>
```

**Important note**: If you use `--network=host` mode, the container directly uses the host network, increasing port conflict probability. In this mode, container ports must not conflict with host ports.

### Scenario 4: Insufficient Permissions

**Typical symptoms**:

*   Exit Code 1
*   Logs show `Permission denied`, `Operation not permitted`, `chown: changing ownership failed`

**Real case**:

Deployed a MongoDB container, mounting data directory to host. Container kept failing to start:

```sh
chown: changing ownership of '/data/db': Permission denied
```

Turned out the host directory I mounted belonged to root user, but MongoDB process in the container ran as mongodb user (UID 999), without write permission to that directory.

**Troubleshooting method**:

Check host directory permissions:

```sh
ls -la /host/data/path
```

Check user inside container:

```sh
docker run -it my-app /bin/bash
whoami
id
```

Check SELinux (CentOS/RHEL):

```sh
getenforce  # Check SELinux status
```

**Solutions**:

**Option 1**: Adjust host directory permissions

```sh
# Give all users read/write (not secure, dev environment only)
chmod 777 /host/data/path

# Safer approach: change owner
chown -R 999:999 /host/data/path  # 999 is container user's UID
```

**Option 2**: Use privileged mode (use with caution)

```sh
docker run --privileged=true my-app
```

Note: Privileged mode gives the container almost all host permissions. Security risk. Not recommended for production.

**Option 3**: Specify run user

```sh
docker run --user 1000:1000 my-app  # Use host UID/GID
```

**Option 4**: Handle SELinux issues

```sh
# Method 1: Add Z label (modify host file label)
docker run -v /host/path:/container/path:Z my-app

# Method 2: Add z label (shared label)
docker run -v /host/path:/container/path:z my-app

# Method 3: Temporarily disable SELinux (not recommended for production)
setenforce 0
```

### Scenario 5: Dependent Services Not Ready

**Typical symptoms**:

*   Exit Code 1
*   Logs show database connection failure, Redis connection timeout, etc.
*   `Connection refused`, `ECONNREFUSED`, `could not connect to server`

**Real case**:

Used docker-compose to deploy a microservice stack with an app container depending on MySQL database. Both containers started almost simultaneously, but the app container always failed:

```sh
Error: connect ECONNREFUSED 172.18.0.2:3306
```

The issue: although the MySQL container started, the MySQL service was still initializing and wasn’t ready to accept connections. The app container started too fast, connection failed, then exited.

**Troubleshooting method**:

Check if dependent services are running:

```sh
docker ps  # Check if dependency containers are running
```

Test network connectivity:

```sh
docker exec my-app ping database
docker exec my-app telnet database 3306
docker exec my-app nc -zv database 3306
```

Check Docker network config:

```sh
docker network ls
docker network inspect <network_name>
```

**Solutions**:

**Option 1**: Use docker-compose health checks and depends\_on

```yaml
version: '3.8'
services:
  database:
    image: mysql:8.0
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost"]
      interval: 10s
      timeout: 5s
      retries: 5

  app:
    image: my-app
    depends_on:
      database:
        condition: service_healthy  # Wait for database health check to pass
```

**Option 2**: Add retry logic in application layer

Add connection retry logic in application code:

```js
// Node.js example
async function connectWithRetry(maxRetries = 5) {
  for (let i = 0; i < maxRetries; i++) {
    try {
      await db.connect();
      console.log('Database connected');
      return;
    } catch (err) {
      console.log(`Connection failed, retrying... (${i+1}/${maxRetries})`);
      await new Promise(resolve => setTimeout(resolve, 5000));
    }
  }
  throw new Error('Failed to connect to database');
}
```

**Option 3**: Use startup wait script

Add a wait script before container startup, like `wait-for-it.sh`:

```Dockerfile
# In Dockerfile
COPY wait-for-it.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/wait-for-it.sh

# Use when starting
CMD ["wait-for-it.sh", "database:3306", "--", "node", "app.js"]
```

**Option 4**: Configure restart policy

Let container auto-retry on failure:

```sh
docker run --restart=on-failure:3 my-app  # Max 3 retries on failure
```

In docker-compose:

```yaml
services:
  app:
    restart: on-failure
```

These solutions can be combined—health checks + application retry + restart policy for triple insurance.

## Preventive Measures and Best Practices

Everything above is about fixing problems after they occur. But actually, if you configure certain mechanisms from the start, many problems won’t happen at all, or can auto-recover when they do.

### Configure Health Checks (HEALTHCHECK)

Health checks are Docker’s container self-diagnostic mechanism. By periodically running check commands, Docker can determine if a container is actually working properly, not just that the process is alive.

Configure in Dockerfile:

```Dockerfile
FROM nginx:alpine

# Check every 30 seconds, timeout 3 seconds, mark unhealthy after 3 consecutive failures
HEALTHCHECK --interval=30s --timeout=3s --retries=3 \
  CMD curl -f http://localhost/ || exit 1
```

For web services, check HTTP endpoints:

```Dockerfile
HEALTHCHECK --interval=30s --timeout=5s --start-period=40s \
  CMD curl -f http://localhost:8080/health || exit 1
```

For databases, use dedicated commands:

```Dockerfile
# MySQL
HEALTHCHECK CMD mysqladmin ping -h localhost || exit 1

# PostgreSQL
HEALTHCHECK CMD pg_isready -U postgres || exit 1

# Redis
HEALTHCHECK CMD redis-cli ping || exit 1
```

Health check benefits:

*   **Kubernetes/Swarm orchestrators** automatically restart or reschedule containers based on health status
*   **docker-compose depends\_on** can wait for services to be truly healthy before starting dependent containers
*   **Monitoring systems** can alert based on health status

View health status:

```sh
docker ps  # STATUS column shows health status
docker inspect --format='{{.State.Health.Status}}' <container_id>
```

### Set Restart Policies

Restart policies let containers auto-recover from failures without you manually restarting at 3 AM.

Docker provides four restart policies:

**no** (default): Don’t auto-restart

```sh
docker run --restart=no my-app
```

Suitable for one-time tasks, containers that finish and exit.

**on-failure\[:max-retries\]**: Only restart on abnormal exit

```sh
docker run --restart=on-failure:5 my-app  # Max 5 retries
```

Suitable for services that might fail but you don’t want infinite retries. Note: only restarts when Exit Code is non-zero.

**always**: Always restart

```sh
docker run --restart=always my-app
```

Suitable for long-running services like web servers, API services. Even if manually stopped, it’ll auto-start when Docker Daemon restarts.

**unless-stopped**: Always restart unless manually stopped

```sh
docker run --restart=unless-stopped my-app
```

Similar to always, but if you manually `docker stop`, it won’t auto-start when Docker Daemon restarts. This is my most-used policy—gives me some control.

**Important notes**:

1.  **10-second rule**: Container must run at least 10 seconds after first start for restart policy to work. This prevents infinite restart loops from config errors eating system resources.
2.  **Infinite restart trap**: If container keeps restarting due to config error (like port conflict), logs will explode. Remember to use with log rotation.

For already-running containers, you can dynamically modify policy:

```sh
docker update --restart=unless-stopped <container_id>
```

Configure in docker-compose:

```yaml
services:
  web:
    image: nginx
    restart: unless-stopped  # Recommended for production

  worker:
    image: my-worker
    restart: on-failure  # Might fail, but don't want infinite retries
```

### Log Management: Prevent Disk Full

Docker by default saves all container logs in JSON files. Over time these log files can consume tens of GB of disk space. I’ve experienced production server outages because Docker logs filled up the disk.

Configure log rotation (recommended):
Create or edit `/etc/docker/daemon.json`:

```json
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",    // Max 10MB per log file
    "max-file": "3"       // Keep max 3 log files
  }
}
```

Restart Docker after modification:

```sh
sudo systemctl restart docker
```

This way each container uses max 30MB log space (10MB × 3), old logs auto-delete.

Configure for individual container:

```sh
docker run --log-opt max-size=10m --log-opt max-file=3 my-app
```

In docker-compose:

```yaml
services:
  app:
    image: my-app
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
```

Other log driver options:

*   **syslog**: Send to system log
*   **journald**: Use systemd’s journal
*   **fluentd**: Send to Fluentd for centralized management
*   **none**: Don’t log (not recommended)

Check container log file location and size:

```sh
docker inspect --format='{{.LogPath}}' <container_id>
du -h $(docker inspect --format='{{.LogPath}}' <container_id>)
```

### Monitoring and Alerts: Detect Problems Early

Don’t wait until containers crash to find out. Proactive monitoring prevents many production incidents.

**Basic monitoring: docker stats**

```sh
docker stats  # Real-time display of all containers' resource usage
docker stats <container_id>  # Monitor specific container
```

This command shows real-time data on CPU, memory, network IO, disk IO. If you see memory usage continuously growing, there might be a memory leak—handle it proactively.

**Production environment: Prometheus + Grafana**

More professional approach is using Prometheus to collect metrics, Grafana to visualize:

```yaml
# docker-compose.yml
services:
  prometheus:
    image: prom/prometheus
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
    ports:
      - "9090:9090"

  grafana:
    image: grafana/grafana
    ports:
      - "3000:3000"

  cadvisor:  # Collect container metrics
    image: google/cadvisor
    volumes:
      - /:/rootfs:ro
      - /var/run:/var/run:ro
      - /sys:/sys:ro
      - /var/lib/docker/:/var/lib/docker:ro
    ports:
      - "8080:8080"
```

Configure alert rules for conditions like memory usage over 80%, excessive container restarts, etc., to auto-send notifications.

**Simple and crude: Scheduled script**

If you think Prometheus is too complex, write a simple script:

```sh
#!/bin/bash
# check-containers.sh

# Check for any Exited status containers
EXITED=$(docker ps -a -f "status=exited" --format "{{.Names}}")

if [ -n "$EXITED" ]; then
  echo "Warning: The following containers are exited:"
  echo "$EXITED"
  # Can send email or push notification here
fi
```

Add to crontab to run every 5 minutes:

```sh
*/5 * * * * /path/to/check-containers.sh
```

### Production Environment Configuration Checklist

Finally, here’s a production environment configuration checklist. Follow this and you’ll avoid most big problems:

```yaml
version: '3.8'
services:
  web:
    image: my-web-app:latest

    # Restart policy
    restart: unless-stopped

    # Resource limits
    deploy:
      resources:
        limits:
          cpus: '2'
          memory: 1G
        reservations:
          memory: 512M

    # Health check
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost/health"]
      interval: 30s
      timeout: 5s
      retries: 3
      start_period: 40s

    # Log management
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"

    # Environment variables (use secrets for sensitive info)
    environment:
      - NODE_ENV=production

    # Port mapping
    ports:
      - "8080:8080"

    # Dependencies
    depends_on:
      database:
        condition: service_healthy

  database:
    image: postgres:14
    restart: unless-stopped
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 10s
      timeout: 5s
      retries: 5
    volumes:
      - db-data:/var/lib/postgresql/data
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"

volumes:
  db-data:
```

With this config, crashed containers auto-restart, resource overages get limited, logs won’t fill disk, and monitoring provides early warning. You can sleep soundly.

## Conclusion

After all this, I hope you remember: Docker container startup failures aren’t scary. What’s scary is not having a systematic troubleshooting approach.

Let’s recap the core content:

**Understand exit codes**: See 137, think memory problem. See 1, think config or dependency problem. Exit codes are clues Docker leaves you—don’t ignore them.

**4-step diagnosis**:

1.  Check container status (`docker ps -a`)
2.  Check logs (`docker logs`)
3.  Check configuration (`docker inspect`)
4.  Interactive verification (`docker run -it`)

90%+ of problems are solved in step 2.

**5 common scenarios**: Config errors, memory shortage, port conflicts, permission issues, dependencies not ready. Remember these troubleshooting methods and you’re covered for most cases.

**Prevent proactively**: Configure health checks, set restart policies, manage logs well, monitor properly. These mechanisms make containers more stable and auto-recover when problems occur.

Finally, here’s a quick troubleshooting checklist you can screenshot:

```
Docker Container Startup Failure Troubleshooting Checklist

□ Step 1: docker ps -a check container status and exit code
□ Step 2: docker logs <container_id> check detailed logs
□ Step 3: docker inspect <container_id> check configuration
□ Step 4: docker run -it <image> interactive verification

Quick problem location for common issues:
- Exit Code 1 + "No such file" → Check mount paths and config files
- Exit Code 1 + "port already allocated" → Check port conflicts
- Exit Code 1 + "Permission denied" → Check file permissions and SELinux
- Exit Code 1 + "Connection refused" → Check if dependency services are ready
- Exit Code 137 + OOMKilled=true → Increase memory limit
- Exit Code 127 → Check CMD/ENTRYPOINT path correctness

Preventive measures:
□ Configure HEALTHCHECK
□ Set restart policy (recommend unless-stopped)
□ Configure log rotation (max-size + max-file)
□ Resource limits (-m memory limit)
□ Monitoring alerts (docker stats or Prometheus)
```
