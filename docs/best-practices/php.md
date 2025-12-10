## Optimize PHP-FPM (Detailed & Specific Commands)

![php-fpm](.images/php-fpm.png)

### I. OPCache

#### 1. Enable OPCache
Run the following commands to check and enable OPCache in your PHP configuration:

```bash
php -i | grep opcache
```

Locate the `opcache.enable` directive in your `php.ini` file and set it to `1`:

```ini
# https://www.php.net/manual/en/opcache.configuration.php
opcache.enable=1
; opcache.enable_cli=1
```

#### 2. Configure OPCache
The default OPcache configuration is not suited for Symfony/Laravel applications, so it's recommended to change these settings as follows:
```ini
; https://symfony.com/doc/current/performance.html#performance-configure-opcache
; maximum memory that OPcache can use to store compiled PHP files (in megabytes)
opcache.memory_consumption=256
; The amount of memory for interned strings in Mbytes.
opcache.interned_strings_buffer=64
; maximum number of files that can be stored in the cache
opcache.max_accelerated_files=20000
```

Count all PHP files in the current directory and its subdirectories to set `opcache.max_accelerated_files` appropriately:
```bash
cd /path/to/your/project
find . -type f -name "*.php" | wc -l
```

#### 3. Disable Timestamp Validation (Optional)
In production servers, PHP files should never change, unless a new application version is deployed. However, by default OPcache checks if cached files have changed their contents since they were cached. This check introduces some overhead that can be avoided as follows:
```ini
opcache.validate_timestamps=0
```
After each deployment, you must empty and regenerate the cache of OPcache. Otherwise you won't see the updates made in the application. Given that in PHP, ***the CLI and the web processes don't share the same OPcache***, you cannot clear the web server OPcache by executing some command in your terminal. These are some of the possible solutions:

- Restart the web server (e.g., `systemctl reload php-fpm` or `systemctl reload nginx`);
- Call the `apc_clear_cache()` or `opcache_reset()` functions via the web server (i.e. by having these in a script that you execute over the web);
- Use the [cachetool](https://github.com/gordalina/cachetool) utility to control APC and OPcache from the CLI.

#### 4. Additional OPCache Commands
Here are some additional commands to manage and monitor OPCache:
```bash
# Clear the OPcache
php -r 'opcache_reset();'
# Get OPcache status and statistics
php -r 'print_r(opcache_get_status());'
# Get OPcache configuration
php -r 'print_r(opcache_get_configuration());'
```

### II. Configure the PHP `realpath` Cache
When a relative path is transformed into its real and absolute path, PHP caches the result to improve performance. Applications that open many PHP files should use at least these values:
```ini
; maximum memory allocated to store the results of realpath lookups
realpath_cache_size=4096K
; save the results for 10 minutes (600 seconds)
realpath_cache_ttl=600
```
Note: PHP disables the `realpath` cache when the `open_basedir` config option is enabled.

To check if the open_basedir option is enabled, run:
```bash
php -i | grep open_basedir
```

### References
- https://www.php.net/manual/en/opcache.configuration.php
- https://symfony.com/doc/current/performance.html#performance-configure-opcache
- https://hatam.notion.site/www-conf-21a7827e85968065bfc4cfd8ee46f11a
- https://github.com/hipages/php-fpm_exporter
