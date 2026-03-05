# Docker Compose Service Dependencies: Solving Database Startup Sequence with Healthchecks

Table of Contents

*   [Why depends\_on Isn’t Enough: Started ≠ Ready](#why-depends_on-isnt-enough-started-ready)
*   [The Time Gap Between Container Startup and Service Readiness](#the-time-gap-between-container-startup-and-service-readiness)
*   [Three Conditions of depends\_on](#three-conditions-of-depends_on)
*   [Why Isn’t service\_healthy the Default?](#why-isnt-service_healthy-the-default)
*   [Complete Healthcheck Configuration Guide](#complete-healthcheck-configuration-guide)
*   [Complete Healthcheck Configuration](#complete-healthcheck-configuration)
*   [test: Check Command](#test-check-command)
*   [interval: Check Interval](#interval-check-interval)
*   [timeout: Single Check Timeout](#timeout-single-check-timeout)
*   [retries: Failure Retry Count](#retries-failure-retry-count)
*   [start\_period: Startup Grace Period (Most Easily Overlooked)](#start_period-startup-grace-period-most-easily-overlooked)
*   [Common Errors and Pitfall Guide](#common-errors-and-pitfall-guide)
*   [PostgreSQL Healthcheck Practical Configuration](#postgresql-healthcheck-practical-configuration)
*   [Basic Configuration (Recommended)](#basic-configuration-recommended)
*   [pg\_isready Command Explained](#pg_isready-command-explained)
*   [Advanced Configuration: Add Actual Query](#advanced-configuration-add-actual-query)
*   [Actual Running Effect](#actual-running-effect)
*   [Troubleshooting: Container Always unhealthy](#troubleshooting-container-always-unhealthy)
*   [MySQL Healthcheck Practical Configuration](#mysql-healthcheck-practical-configuration)
*   [Basic Configuration (Recommended)](#basic-configuration-recommended)
*   [mysqladmin ping Command Explained](#mysqladmin-ping-command-explained)
*   [Correct Password Handling](#correct-password-handling)
*   [MySQL 8.0 Special Considerations](#mysql-80-special-considerations)
*   [Common Issues](#common-issues)
*   [Healthchecks for Other Databases and Services](#healthchecks-for-other-databases-and-services)
*   [Redis](#redis)
*   [MongoDB](#mongodb)
*   [RabbitMQ](#rabbitmq)
*   [Generic HTTP Services](#generic-http-services)
*   [Services Without Dedicated Tools](#services-without-dedicated-tools)
*   [wait-for-it Scripts: Still Needed?](#wait-for-it-scripts-still-needed)
*   [Traditional wait-for-it Approach](#traditional-wait-for-it-approach)
*   [Why Not Recommended Anymore?](#why-not-recommended-anymore)
*   [When Still Need wait-for-it?](#when-still-need-wait-for-it)
*   [Other Alternative Tools](#other-alternative-tools)
*   [Troubleshooting Checklist and Best Practices](#troubleshooting-checklist-and-best-practices)
*   [Quick Diagnostic Commands](#quick-diagnostic-commands)
*   [Common Issues Decision Tree](#common-issues-decision-tree)
*   [Production Environment Best Practices](#production-environment-best-practices)
*   [Debugging Tips](#debugging-tips)
*   [Conclusion](#conclusion)

Friday night, 10 PM. I’m staring at error logs scrolling through my terminal, mentally calculating whether I’ll make it home on time.

```
web_1  | Error: connect ECONNREFUSED 127.0.0.1:5432
web_1  | at TCPConnectWrap.afterConnect
db_1   | PostgreSQL init process complete; ready for start up.
web_1  | Exited with code 1
web_1  | Restarting...
```

The application container keeps restarting. The database has started, but it’s always a beat behind. I check docker-compose.yml—depends\_on is configured. Why isn’t it working?

This issue has plagued countless developers. You’ve probably experienced it: run docker-compose up in your local development environment, and the first two attempts always fail. You wait about ten seconds for a few restarts before things run normally. When new teammates ask “is this normal?” you can only awkwardly say “try a few more times.”

The root cause is simple: **Docker’s depends\_on only manages container startup order, not whether services are actually ready**.

In this article, I’ll walk you through:

*   The three condition configurations for depends\_on (90% of people only know the default)
*   Correct healthcheck configurations for PostgreSQL and MySQL (with complete examples)
*   Modern alternatives to wait-for-it scripts
*   A troubleshooting checklist to make your container startups rock solid

## Why depends\_on Isn’t Enough: Started ≠ Ready

There’s a particularly important quote in the Docker official documentation that’s easy to overlook:

> Compose does not wait until a container is “ready”, only until it’s running.

In other words: Compose only waits for the container to run, not whether the service is actually usable.

### The Time Gap Between Container Startup and Service Readiness

Imagine the PostgreSQL container startup process:

1.  **0 seconds**: Docker starts the container, postgres process launches ← depends\_on releases here
2.  **2 seconds**: Initialize data directory
3.  **5 seconds**: Load configuration files
4.  **8 seconds**: Execute init scripts (if any)
5.  **12 seconds**: Finally ready to accept connections

There’s a 12-second gap. If your web application tries to connect to the database at second 1, the result will inevitably be “Connection refused.”

Real cases are more extreme. I once maintained a legacy project where the database initialization script had to import 500MB of test data—that process alone took 40 seconds. With the default depends\_on configuration, the application container had to crash and restart at least 5 times before connecting.

### Three Conditions of depends\_on

Many people don’t know that depends\_on actually supports three conditions:

```yaml
services:
  web:
    depends_on:
      db:
        condition: service_started  # Default, container started is OK
        # condition: service_healthy  # Wait for healthcheck to pass
        # condition: service_completed_successfully  # Wait for container to exit successfully (for init containers)
```

**service\_started** (default): Continue as long as the container is in running state. This is why depends\_on still causes problems.

**service\_healthy**: Must wait for healthcheck to pass and container status to become “healthy” before continuing. This is what we really need.

**service\_completed\_successfully**: Wait for container to exit successfully (exit code 0). Suitable for one-time tasks like data migration.

### Why Isn’t service\_healthy the Default?

You might ask, if service\_healthy is so useful, why isn’t it the default?

Two reasons:

1.  Not all services need healthchecks (like pure stateless workers)
2.  Healthchecks require your configuration—Docker doesn’t know how your service defines “ready”

This brings us to the next topic: how to configure healthchecks.

## Complete Healthcheck Configuration Guide

The healthcheck principle is straightforward: Docker periodically runs a command. If it returns 0, it’s healthy; if it returns 1, it’s unhealthy.

### Complete Healthcheck Configuration

```yaml
services:
  db:
    image: postgres:16
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]  # Check command
      interval: 10s       # Check every 10 seconds
      timeout: 5s         # Single check timeout of 5 seconds
      retries: 3          # Mark as unhealthy after 3 failures
      start_period: 30s   # Failures within 30 seconds after startup don't count toward retries
```

All five parameters are important. Let’s go through them one by one.

### test: Check Command

Two formats:

```yaml
# Method 1: Use shell (recommended)
test: ["CMD-SHELL", "pg_isready -U postgres"]

# Method 2: Execute command directly (without shell)
test: ["CMD", "pg_isready", "-U", "postgres"]
```

CMD-SHELL works in most cases because you can use shell features like pipes and redirects.

**Common pitfall**: Tools in the check command must exist in the image. For example, using curl to check HTTP interfaces when curl isn’t installed in the image means healthcheck will always fail. I’ve hit this snag before—spent half an hour before realizing I needed to add `RUN apk add curl` to the Dockerfile.

### interval: Check Interval

How often to check. Too frequent wastes resources, too slow delays response.

*   **10 seconds** is a good default for most scenarios
*   Critical services like databases can be set to 5 seconds
*   Lightweight services can use 15-30 seconds

### timeout: Single Check Timeout

Timeout for a single check. If the command hangs, Docker will wait this long before giving up.

Too short causes false positives, too long affects fault detection speed. **5-10 seconds** is a safe range.

### retries: Failure Retry Count

How many consecutive failures before marking as unhealthy.

This is a debounce mechanism. Occasional network jitter or brief database overload can cause single check failures—retries make the system more robust.

**3-5 times** is reasonable. retries=1 is too sensitive, retries=10 too sluggish.

### start\_period: Startup Grace Period (Most Easily Overlooked)

This is the most easily overlooked and most error-prone parameter.

Failures within start\_period don’t count toward retries. In other words, it gives the service a “startup buffer.”

Why is it important? Databases need time to start. PostgreSQL initializes data directories, MySQL loads table indexes. Without start\_period, healthchecks start failing at second 2, and the service might be marked unhealthy before retries run out.

**Recommended values**:

*   PostgreSQL/MySQL: **30-60 seconds**
*   Lightweight services (Redis): 15-30 seconds
*   With extensive initialization scripts: Can set to 120 seconds

I usually set 60 seconds—better to wait a bit longer than get false positives.

### Common Errors and Pitfall Guide

**Error 1: Incorrect Environment Variable Reference**

```yaml
# ❌ Wrong: Compose interpolates before startup, container gets host variable value
test: ["CMD", "mysqladmin", "ping", "-p$MYSQL_ROOT_PASSWORD"]

# ✅ Correct: Use $$ escape to let container shell parse
test: ["CMD-SHELL", "mysqladmin ping -p$$MYSQL_ROOT_PASSWORD"]
```

**Error 2: start\_period Too Short**

```yaml
# ❌ Database not initialized yet but counting failures, quickly marked unhealthy
healthcheck:
  test: ["CMD", "pg_isready"]
  interval: 5s
  retries: 3
  start_period: 10s  # Too short!

# ✅ Give enough startup time
healthcheck:
  start_period: 60s  # Much better
```

**Error 3: Check Tool Doesn’t Exist**

This error is particularly insidious because Docker just fails silently.

```yaml
# ❌ If image doesn't have curl, healthcheck always fails
test: ["CMD", "curl", "-f", "http://localhost/health"]

# ✅ Ensure tool exists, or use built-in tools
test: ["CMD", "wget", "--spider", "http://localhost/health"]  # Alpine images have wget
```

With healthcheck configured, let’s see how to configure specific databases.

## PostgreSQL Healthcheck Practical Configuration

PostgreSQL’s official image comes with a gem: **pg\_isready**.

This tool is specifically designed to check if PostgreSQL is ready—much more reliable than writing SQL queries yourself.

### Basic Configuration (Recommended)

```yaml
version: '3.8'

services:
  web:
    image: node:20-alpine
    depends_on:
      db:
        condition: service_healthy  # Key: wait for healthcheck to pass
        restart: true  # Restart app when database restarts
    environment:
      DATABASE_URL: postgresql://postgres:password@db:5432/myapp
    command: npm start

  db:
    image: postgres:16
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: password
      POSTGRES_DB: myapp
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres -d myapp"]
      interval: 10s
      timeout: 5s
      retries: 3
      start_period: 60s
    volumes:
      - postgres_data:/var/lib/postgresql/data

volumes:
  postgres_data:
```

### pg\_isready Command Explained

```sh
pg_isready -U postgres -d myapp
```

*   `-U`: Specify username, must be an actual existing user
*   `-d`: Specify database name (optional but recommended)

Why add `-U`? Without it, pg\_isready tries to connect using the current system user, filling logs with warnings. Doesn’t affect functionality, but it’s annoying.

### Advanced Configuration: Add Actual Query

pg\_isready only checks if the port is reachable, not whether the database can actually execute queries. If you need stricter checking:

```yaml
healthcheck:
  test: ["CMD-SHELL", "pg_isready -U postgres && psql -U postgres -d myapp -c 'SELECT 1'"]
  interval: 10s
  timeout: 10s  # Note timeout needs to increase due to extra query
  retries: 3
  start_period: 60s
```

`SELECT 1` is the simplest query. If it executes successfully, the database is not only started but can process SQL normally.

However, for most scenarios, basic pg\_isready is sufficient.

### Actual Running Effect

After configuration, let’s start it:

```sh
$ docker-compose up

Creating network "myapp_default" ... done
Creating myapp_db_1 ... done
Waiting for myapp_db_1 to be healthy...  ← Notice this line
Creating myapp_web_1 ... done

db_1   | PostgreSQL init process complete; ready for start up.
db_1   | database system is ready to accept connections
web_1  | Server listening on port 3000  ← App starts after database is ready
```

You’ll see a noticeable pause—Docker is waiting for the db container to become healthy. This process might take 30-60 seconds, but it results in zero failed startups.

### Troubleshooting: Container Always unhealthy

If the database container keeps showing unhealthy, check the healthcheck logs:

```sh
# View container health status
$ docker inspect --format='{{json .State.Health}}' myapp_db_1 | jq

{
  "Status": "unhealthy",
  "FailingStreak": 5,
  "Log": [
    {
      "Start": "2024-12-17T03:15:30Z",
      "End": "2024-12-17T03:15:30Z",
      "ExitCode": 1,
      "Output": "pg_isready: could not connect to server: Connection refused"
    }
  ]
}
```

Common causes:

1.  **start\_period too short**: Database still initializing when failure counting starts
2.  **Wrong username or database name**: pg\_isready can’t connect
3.  **PostgreSQL startup failed**: Check container logs `docker logs myapp_db_1`

## MySQL Healthcheck Practical Configuration

MySQL healthcheck uses **mysqladmin ping**, MySQL’s built-in management tool.

### Basic Configuration (Recommended)

```yaml
version: '3.8'

services:
  web:
    image: node:20-alpine
    depends_on:
      db:
        condition: service_healthy
        restart: true
    environment:
      DATABASE_URL: mysql://root:password@db:3306/myapp
    command: npm start

  db:
    image: mysql:8.0
    environment:
      MYSQL_ROOT_PASSWORD: password
      MYSQL_DATABASE: myapp
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost", "-u", "root", "-ppassword"]
      interval: 10s
      timeout: 5s
      retries: 3
      start_period: 60s
    volumes:
      - mysql_data:/var/lib/mysql

volumes:
  mysql_data:
```

### mysqladmin ping Command Explained

```sh
mysqladmin ping -h localhost -u root -ppassword
```

*   `-h`: Host address (use localhost inside container)
*   `-u`: Username
*   `-p`: Password (note no space between `-p` and password)

If MySQL is normal, this command returns:

```sh
mysqld is alive
```

Exit code is 0, healthcheck passes.

### Correct Password Handling

**Method 1: Write Password Directly (Suitable for Development)**

```yaml
healthcheck:
  test: ["CMD", "mysqladmin", "ping", "-h", "localhost", "-u", "root", "-ppassword"]
```

Simple and direct, but password is hardcoded in configuration.

**Method 2: Use Environment Variable (Recommended)**

```yaml
db:
  environment:
    MYSQL_ROOT_PASSWORD: password
  healthcheck:
    test: ["CMD-SHELL", "mysqladmin ping -h localhost -u root -p$$MYSQL_ROOT_PASSWORD"]
    # Note: Use $$ not $
```

There’s a pitfall here: must use `$$` not `$`.

Why? Because Docker Compose parses environment variables before startup. If you use `$MYSQL_ROOT_PASSWORD`, Compose looks for this variable on your host machine, not inside the container. Using `$$` tells Compose “leave it alone, let the container shell parse it.”

**Method 3: Passwordless Check (Simplest, but Controversial)**

```yaml
healthcheck:
  test: ["CMD", "mysqladmin", "ping", "-h", "localhost"]
```

Some MySQL configurations allow local passwordless connections—simplest in this case. However, not recommended for production.

### MySQL 8.0 Special Considerations

MySQL 8.0 defaults to the `caching_sha2_password` authentication plugin, which can prevent some older clients from connecting. If your application reports authentication errors, you can force the old authentication method:

```yaml
db:
  image: mysql:8.0
  command: --default-authentication-plugin=mysql_native_password
  environment:
    MYSQL_ROOT_PASSWORD: password
    MYSQL_DATABASE: myapp
  healthcheck:
    test: ["CMD", "mysqladmin", "ping", "-h", "localhost", "-u", "root", "-ppassword"]
    interval: 10s
    timeout: 5s
    retries: 3
    start_period: 60s
```

### Common Issues

**Issue 1: Access denied for user ‘root’@‘localhost’**

Password is wrong, or environment variable didn’t take effect. Check:

1.  Is MYSQL\_ROOT\_PASSWORD spelled correctly
2.  Does password in healthcheck match
3.  Did you use `$$` escape

**Issue 2: Container Starts Slowly, Stays in starting State**

MySQL needs time to initialize data directory, especially on first startup. Ensure start\_period is set large enough—60 seconds usually works. If you have init scripts importing lots of data, might need 120 seconds or more.

**Issue 3: Healthcheck Passes but App Can’t Connect to Database**

Could be network issue or application configuration problem. Check:

1.  Is application connection string correct (use `db` for hostname, not `localhost`)
2.  Is Docker network configuration normal
3.  Use `docker network inspect` to see if containers are on same network

## Healthchecks for Other Databases and Services

Having mastered PostgreSQL and MySQL, other services follow naturally. Here’s a quick reference.

### Redis

```yaml
redis:
  image: redis:7-alpine
  healthcheck:
    test: ["CMD", "redis-cli", "ping"]
    interval: 10s
    timeout: 3s
    retries: 3
    start_period: 15s
```

`redis-cli ping` returns `PONG`, exit code 0. Redis starts quickly, start\_period can be shorter.

### MongoDB

```yaml
mongo:
  image: mongo:7
  healthcheck:
    test: ["CMD", "mongosh", "--eval", "db.adminCommand('ping')"]
    interval: 10s
    timeout: 5s
    retries: 3
    start_period: 30s
```

Note: MongoDB 6.0+ replaced the old `mongo` command with `mongosh`. For older versions:

```yaml
test: ["CMD", "mongo", "--eval", "db.adminCommand('ping')"]
```

### RabbitMQ

```yaml
rabbitmq:
  image: rabbitmq:3-management-alpine
  healthcheck:
    test: ["CMD", "rabbitmq-diagnostics", "ping"]
    interval: 10s
    timeout: 5s
    retries: 3
    start_period: 40s
```

RabbitMQ starts relatively slowly, recommend start\_period of 40+ seconds.

### Generic HTTP Services

If a service provides HTTP healthcheck endpoints (like `/health` or `/ping`), use wget or curl:

```yaml
api:
  image: myapp:latest
  healthcheck:
    test: ["CMD", "wget", "--spider", "--quiet", "http://localhost:8080/health"]
    # Or use curl (if available in image)
    # test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
    interval: 10s
    timeout: 3s
    retries: 3
    start_period: 20s
```

`--spider` makes wget only check without downloading, `--quiet` suppresses log output.

**Note**: Ensure image has wget or curl. Alpine images have wget by default, Debian/Ubuntu images have curl.

### Services Without Dedicated Tools

If a service lacks healthcheck tools, use netcat (nc) to check ports:

```yaml
service:
  image: some-service:latest
  healthcheck:
    test: ["CMD-SHELL", "nc -z localhost 9000 || exit 1"]
    interval: 10s
    timeout: 3s
    retries: 3
    start_period: 30s
```

`nc -z` only checks if port is open without establishing actual connection. However, this only checks ports, can’t confirm service is truly ready—cruder than previous methods.

## wait-for-it Scripts: Still Needed?

If you search for Docker startup order, you’ll probably see many articles recommending wait-for-it or wait-for scripts.

These scripts work by adding wait logic to the application container’s entrypoint, checking if dependent service TCP ports are reachable.

### Traditional wait-for-it Approach

```yaml
web:
  image: node:20-alpine
  depends_on:
    - db  # Just regular depends_on, doesn't check health status
  volumes:
    - ./wait-for-it.sh:/wait-for-it.sh  # Mount script
  command: ["/wait-for-it.sh", "db:5432", "--", "npm", "start"]
```

wait-for-it.sh loops checking the db:5432 port until connectable before executing `npm start`.

### Why Not Recommended Anymore?

Best practice in 2024: **Use native healthcheck instead of scripts whenever possible**.

Reasons:

1.  **Clearer configuration**: Health check logic is in the database service, dependency relationships are immediately apparent
2.  **No extra files**: No need to maintain scripts or mount volumes
3.  **More powerful**: Healthcheck can check actual service readiness, TCP port checking is too crude
4.  **Better reusability**: Configure healthcheck once, all services depending on it automatically benefit

There’s a popular article in the community literally titled “Forget wait-for-it, use docker-compose healthcheck and depends\_on instead.”

### When Still Need wait-for-it?

Two special cases:

**Case 1: Can’t Modify Image or Compose Configuration**

For example, using third-party images without healthcheck and no permission to add it. Adding wait-for-it on the application side is the only choice.

**Case 2: Need to Wait for Multiple Services**

```sh
./wait-for-it.sh db:5432 redis:6379 rabbitmq:5672 -- npm start
```

While depends\_on can also configure multiple services, wait-for-it is more concise. However, this scenario is rare.

### Other Alternative Tools

Besides wait-for-it, there are several similar tools:

*   **dockerize**: Written in Go, more feature-rich, supports environment variable templates
*   **wait-for**: Simplified version of wait-for-it, pure shell implementation
*   **docker-compose-wait**: Written in Python, supports HTTP checking

But honestly, in 2024, just use healthcheck and don’t bother with these.

## Troubleshooting Checklist and Best Practices

Still not working after configuration? Follow this checklist—solves 90% of problems.

### Quick Diagnostic Commands

```sh
# 1. View all container statuses
$ docker-compose ps

NAME       COMMAND    SERVICE   STATUS              PORTS
myapp_db   postgres   db        healthy             5432/tcp
myapp_web  npm start  web       running             0.0.0.0:3000->3000/tcp

# 2. View healthcheck details
$ docker inspect --format='{{json .State.Health}}' myapp_db_1 | jq

# 3. View container logs
$ docker-compose logs db
$ docker-compose logs web

# 4. Track logs in real-time
$ docker-compose logs -f --tail=100
```

### Common Issues Decision Tree

**Issue: Container Always Shows starting, Never Becomes healthy**

1.  Check if start\_period too short → Try changing to 60s
2.  See if healthcheck command correct → Use `docker inspect` to see actual command
3.  Enter container and manually execute healthcheck command → `docker exec -it myapp_db_1 pg_isready -U postgres`

**Issue: Container Becomes unhealthy Then Recovers healthy, Flip-Flopping**

1.  interval too short, insufficient resources → Change to 10s or 15s
2.  retries too few, occasional failures trigger → Change to 5
3.  Database truly has performance issues → Check database logs

**Issue: Healthcheck Passes but App Still Can’t Connect to Database**

1.  Is application connection string correct → Use service name (like `db`) for hostname, not `localhost`
2.  Is port mapping correct → Inter-container communication uses internal port (5432), not mapped port
3.  Is network configuration correct → Confirm all services on same network

### Production Environment Best Practices

**1\. Recommended Parameter Values (Conservative Configuration)**

```yaml
healthcheck:
  interval: 10s          # Balance response speed and resource consumption
  timeout: 5s            # Give command enough execution time
  retries: 5             # Tolerate occasional failures
  start_period: 60s      # Give database sufficient startup time
```

This set of parameters is stable in most scenarios. If your database has extensive initialization scripts, start\_period can be set to 120s.

**2\. Use Restart Strategy**

```yaml
web:
  depends_on:
    db:
      condition: service_healthy
      restart: true  # Restart app when database restarts
  restart: unless-stopped  # Auto-restart after container exits
```

`restart: true` ensures that when database upgrades or restarts, dependent services also restart and reconnect.

**3\. Resource Limits**

Healthchecks consume resources, though very little. If system resources are tight:

```yaml
healthcheck:
  interval: 30s  # Lengthen check interval
  timeout: 3s    # Shorten timeout
```

Honestly though, healthcheck overhead is usually negligible unless running hundreds of containers.

**4\. Monitor Health Status**

For production, use monitoring tools to track healthcheck status. Docker healthcheck events can be collected by Prometheus, Grafana, and other tools.

```yaml
# docker-compose.yml
services:
  db:
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 10s
      timeout: 5s
      retries: 3
      start_period: 60s
    labels:
      - "prometheus.io/scrape=true"  # Let Prometheus collect health status
```

**5\. Multi-Environment Configuration**

Development and production configurations can differ:

```yaml
# docker-compose.yml (development)
db:
  healthcheck:
    start_period: 30s  # Development environment has less data, starts faster

# docker-compose.prod.yml (production)
db:
  healthcheck:
    start_period: 120s  # Production environment has more data, starts slower
    interval: 5s        # More frequent checks
```

Specify configuration files when using:

```sh
docker-compose -f docker-compose.yml -f docker-compose.prod.yml up
```

### Debugging Tips

**Tip 1: Manually Test Healthcheck Command**

Enter container and manually run healthcheck command to see what’s wrong:

```sh
$ docker exec -it myapp_db_1 sh
/# pg_isready -U postgres -d myapp
/var/run/postgresql:5432 - accepting connections
/# echo $?
0  ← Returning 0 means success
```

**Tip 2: Temporarily Disable Healthcheck**

When debugging, comment out healthcheck and use regular depends\_on to rule out healthcheck itself:

```yaml
web:
  depends_on:
    - db  # Temporarily use simple mode
    # db:
    #   condition: service_healthy
```

After confirming app can connect to database normally, add back healthcheck.

**Tip 3: View Docker Event Logs**

Docker records all container events, including healthcheck status changes:

```sh
$ docker events --filter 'event=health_status'

2024-12-17T03:15:30.123456789Z container health_status: healthy (name=myapp_db_1)
2024-12-17T03:16:45.987654321Z container health_status: unhealthy (name=myapp_db_1)
```

This helps identify when containers became unhealthy, combine with log timestamps to pinpoint issues.

## Conclusion

Back to the article’s opening question: Why doesn’t depends\_on work?

The answer in three words: **Not enough**.

depends\_on by default only manages container startup, not service readiness. Database container running doesn’t mean it can accept connections—this gap is the root cause of our troubles.

The solution is also straightforward:

1.  **Configure healthcheck for database**, use pg\_isready or mysqladmin ping to check actual readiness
2.  **Use service\_healthy condition**, make application wait for healthcheck to pass
3.  **Set reasonable start\_period** (60 seconds minimum), give database enough initialization time

These three steps essentially eliminate container startup failures.

Finally, some quick action suggestions:

*   **Do right now**: Copy PostgreSQL or MySQL configuration from this article to your project, modify environment variables and you’re set
*   **Tonight**: Upgrade all depends\_on in team projects to service\_healthy, once and for all
*   **Next week’s team meeting**: Share with colleagues, standardize team configuration standards



