# Redirect URLs with the Apache Web Server

Redirecting a URL allows you to return an HTTP status code that directs the client to a different URL, making it useful for cases in which you’ve moved a piece of content. Redirect is part of Apache’s [mod\_alias](https://httpd.apache.org/docs/current/mod/mod_alias.html) module.

## The Redirect Directive[](#the-redirect-directive)

`Redirect` settings can be located in your main Apache configuration file, but we recommend you keep them in your virtual host files or directory blocks. You can also use
`Redirect` statements in `.htaccess`
 files. Here’s an example of how to use `.htaccess`:

```
Redirect /username http://team.example.com/~username/
```

If no argument is given, `Redirect`
 sends a temporary (`302`) status code, and the client is informed that the resource available at `/username` has temporarily moved to `http://team.example.com/~username/`.

No matter where they are located, `Redirect` statements must specify the full file path of the redirected resource, following the domain name. These statements must also include the full URL of the resource’s new location.

You can also provide an argument to return a specific HTTP status:

```
Redirect /username http://team.example.com/~username/
Redirect permanent /username http://team.example.com/~username/
Redirect temp /username http://team.example.com/~username/
Redirect seeother /username http://team.example.com/~username/
Redirect gone /username
```

-   `permanent` tells the client the resource has moved permanently. This returns a 301 HTTP status code.
-   `temp` is the default behavior, and tells the client the resource has moved temporarily. This returns a 302 HTTP status code.
-   `seeother` tells the user the requested resource has been replaced by another one. This returns a 303 HTTP status code.
-   `gone` tells the user that the resource they are looking for has been removed permanently. When using this argument, you don’t need to specify a final URL. This returns a 410 HTTP status code.

You can also use the HTTP status codes as arguments. Here’s an example using the status code options:

```
Redirect 301 /username http://team.example.com/~username/
Redirect 302 /username http://team.example.com/~username/
Redirect 303 /username http://team.example.com/~username/
Redirect 410 /username
```

Permanent and temporary redirects can also be done with `RedirectPermanent` and `RedirectTemp`, respectively:

```
RedirectPermanent /username/bio.html http://team.example.com/~username/bio/
RedirectTemp /username/bio.html http://team.example.com/~username/bio/
```

Redirects can be made with [regex patterns](https://en.wikipedia.org/wiki/Regular_expression) as well, using `RedirectMatch`:

```
RedirectMatch (.*)\.jpg$ http://static.example.com$1.jpg
```

This matches any request for a file with a `.jpg` extension and replaces it with a location on a given domain. The parentheses allow you to get a specific part of the request, and insert it into the new location’s URL as a variable (specified by `$1`, `$2`, etc.). For example:

-   A request for`http://www.example.com/avatar.jpg` will be redirected to `http://static.example.com/avatar.jpg`
-   A request for`http://www.example.com/images/avatar.jpg` will be redirected to `http://static.example.com/images/avatar.jpg`.

## Beyond URL Redirection[](#beyond-url-redirection)

In addition to redirecting users, Apache also allows you to [rewrite URLs](https://www.linode.com/docs/guides/rewrite-urls-with-modrewrite-and-apache/) with
`mod_rewrite`. While the features are similar, the main difference is that rewriting a URL involves the server returning a different request than the one provided by the client, whereas **a redirect simply returns a status code, and the “correct” result is then requested by the client**.

On a more practical level, rewriting a request does not change the contents of the browser’s address bar, and can be useful in hiding URLs with sensitive or vulnerable data.

Although redirection allows you to easily change the locations of specific resources, you may find that rewriting better fits your needs in certain situations. For more information, refer to [Apache’s mod\_rewrite documentation](https://httpd.apache.org/docs/current/mod/mod_rewrite.html).

