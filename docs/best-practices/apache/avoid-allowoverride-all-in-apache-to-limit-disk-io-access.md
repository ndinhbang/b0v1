# Avoid ‘AllowOverride All’ in Apache to limit disk I/O acce

Apache has an option called `AllowOverride` which allows you to override some Apache settings via a **.htaccess** file you can place in a directory. In it, you can override PHP settings, create URL rewrites, … Pretty much the basics for every website. Most installation guides will tell you to always set `AllowOverride All` in your config, I’ll show you why that’s a very bad idea.

Consider the following simple Virtual Host configuration in Apache.

```
<VirtualHost *:80>
    ServerName mysite.be
    DocumentRoot /var/www/html/mysite.be
    <Directory "/var/www/html/mysite.be">
        AllowOverride All
    </Directory>
</VirtualHost>
```

Thats a simple site called `mysite.be` which gets its content from the directory `/var/www/html/mysite.be` on which the `AllowOverride All` directive is set.
Because you allow overrides in the directory `/var/www/html/mysite.be`, for each lower level file that is being accessed, Apache needs to check if the configuration is not being overwritten. So, if I were to call the URL `mysite.be/content/styles/v3/style.css` for a simple stylesheet, Apache would make the following system calls.

```
open("/var/www/html/mysite.be/content/styles/v3/style.css", {st\_mode=S\_IFREG|0644, st\_size=5, ...}) = 0
open("/var/www/html/mysite.be/.htaccess", O\_RDONLY|O\_CLOEXEC) = -1 ENOENT (No such file or directory)
open("/var/www/html/mysite.be/content/.htaccess", O\_RDONLY|O\_CLOEXEC) = -1 ENOENT (No such file or directory)
open("/var/www/html/mysite.be/content/styles/.htaccess", O\_RDONLY|O\_CLOEXEC) = -1 ENOENT (No such file or directory)
open("/var/www/html/mysite.be/content/styles/v3/.htaccess", O\_RDONLY|O\_CLOEXEC) = -1 ENOENT (No such file or directory)
open("/var/www/html/mysite.be/content/styles/v3/style.css/.htaccess", O\_RDONLY|O\_CLOEXEC) = -1 ENOTDIR (Not a directory)
open("/var/www/html/mysite.be/content/styles/v3/style.css", O\_RDONLY|O\_CLOEXEC) = 10
```

Notice how in each directory between `/var/www/html/mysite.be/` and `/var/www/html/mysite.be/content/styles/v3/style.css/` an extra check is being made to verify if the `.htaccess` file exists there. That happens for every request made to the server, since Apache needs to continuously check if there is a new `.htaccess` file that may overwrite the config.

In comparison, if you don’t enable `AllowOverride None`, there are a lot less system calls needed.

```
open("/var/www/html/mysite.be/content/styles/v3/style.css", {st\_mode=S\_IFREG|0644, st\_size=5, ...}) = 0
open("/var/www/html/mysite.be/content/styles/v3/style.css", O\_RDONLY|O\_CLOEXEC) = 10
```

**Instead of defining your Rewrites and other configurations in .htaccess file, consider placing them directly in your Apache configuration**. On busy servers, this makes quite a difference in disk performance.

References:
- [Apache Documentation on AllowOverride](https://httpd.apache.org/docs/2.4/mod/core.html#allowoverride)
- [Apache Performance Tuning Tips](https://httpd.apache.org/docs/2.4/misc/perf-tuning.html)
- [Tuning Your Apache Server](https://www.linode.com/docs/guides/tuning-your-apache-server/)
