vcl 4.0;

import std;
import directors;

probe app-probe {
  .request =
    "HEAD / HTTP/1.1"
    "Host: localhost"
    "Connection: close";
  .interval  = 10s;
  .timeout   = 5s;
  .window    = 5;
  .threshold = 3;
}
backend app-node0 {
    .host = "127.0.0.1";
    .port = "80";
    .probe = app-probe;
}
# backend app-node1 {
#     .host = "127.0.0.1";
#     .port = "80";
#     .probe = app-probe;
# }

# Allowed to purge
acl purge {
    "localhost";
    "127.0.0.1";
    "::1";
}

# Allow to bypass Varnish
acl editors {
    "localhost";
    "127.0.0.1";
    "::1";
}

sub vcl_init {
    new app = directors.round_robin();
    app.add_backend(app-node0);
    # app.add_backend(app-node1);
}

sub vcl_recv {
    set req.backend_hint = app.backend();

    # Remove port from host header
    if (req.http.Host) {
        set req.http.Host = regsub(req.http.Host, ":[0-9]+", "");
    }

    if ( req.url ~ "wp-admin"
      || req.url ~ "wp-includes"
      || req.url ~ "ajax"
      || req.url ~ "wp-json"
      || req.url ~ "admin") {
        return(pass);
    }

    if (client.ip ~ editors) {
        set req.http.grace = "none";
    }

    # Remove the proxy header (see https://httpoxy.org/#mitigate-varnish)
    unset req.http.proxy;

    # Normalize the query arguments
    set req.url = std.querysort(req.url);

    # Allow editors to bypass cache with a no-cache header
    if (req.http.Cache-Control ~ "(?i)no-cache" && client.ip ~ editors) {
        return(pass);
    }

    if (req.http.X-Blackfire-Query && client.ip ~ editors) {
        return (pass);
    }

    # Allow purging
    if (req.method == "PURGE") {
        if (!client.ip ~ purge) {
            return (synth(405, "This IP is not allowed to send PURGE requests."));
        }
        return (purge);
    }

    # Only deal with "normal" types
    if (req.method != "GET" &&
        req.method != "HEAD" &&
        req.method != "PUT" &&
        req.method != "POST" &&
        req.method != "TRACE" &&
        req.method != "OPTIONS" &&
        req.method != "PATCH" &&
        req.method != "DELETE") {
        return (pipe);
    }

    # websocket support (https://www.varnish-cache.org/docs/4.0/users-guide/vcl-example-websockets.html)
    if (req.http.Upgrade ~ "(?i)websocket") {
        return (pipe);
    }

    # Only cache GET or HEAD requests.
    if (req.method != "GET" && req.method != "HEAD") {
        return (pass);
    }

    # Remove Google Analytics params
    if (req.url ~ "(\?|&)(utm_source|utm_medium|utm_campaign|utm_content|gclid|cx|ie|cof|siteurl)=") {
        set req.url = regsuball(req.url, "&(utm_source|utm_medium|utm_campaign|utm_content|gclid|cx|ie|cof|siteurl)=([A-z0-9_\-\.%25]+)", "");
        set req.url = regsuball(req.url, "\?(utm_source|utm_medium|utm_campaign|utm_content|gclid|cx|ie|cof|siteurl)=([A-z0-9_\-\.%25]+)", "?");
        set req.url = regsub(req.url, "\?&", "?");
        set req.url = regsub(req.url, "\?$", "");
    }

    # Strip hash, server doesn't need it.
    if (req.url ~ "\#") {
        set req.url = regsub(req.url, "\#.*$", "");
    }

    # Strip a trailing ? if it exists
    if (req.url ~ "\?$") {
        set req.url = regsub(req.url, "\?$", "");
    }

    # Remove the "has_js" cookie
    set req.http.Cookie = regsuball(req.http.Cookie, "has_js=[^;]+(; )?", "");
    # Remove Google Analytics cookies
    set req.http.Cookie = regsuball(req.http.Cookie, "__utm.=[^;]+(; )?", "");
    set req.http.Cookie = regsuball(req.http.Cookie, "_ga=[^;]+(; )?", "");
    set req.http.Cookie = regsuball(req.http.Cookie, "_gat=[^;]+(; )?", "");
    set req.http.Cookie = regsuball(req.http.Cookie, "utmctr=[^;]+(; )?", "");
    set req.http.Cookie = regsuball(req.http.Cookie, "utmcmd.=[^;]+(; )?", "");
    set req.http.Cookie = regsuball(req.http.Cookie, "utmccn.=[^;]+(; )?", "");
    # Remove DoubleClick cookies
    set req.http.Cookie = regsuball(req.http.Cookie, "__gads=[^;]+(; )?", "");
    # Remove "has_js" cookie
    set req.http.Cookie = regsuball(req.http.Cookie, "has_js=[^;]+(; )?", "");
    # Remove Quant Capital cookies
    set req.http.Cookie = regsuball(req.http.Cookie, "__qc.=[^;]+(; )?", "");
    # Remove AddThis cookies
    set req.http.Cookie = regsuball(req.http.Cookie, "__atuv.=[^;]+(; )?", "");
    # Remove a ";" prefix in the cookie if present
    set req.http.Cookie = regsuball(req.http.Cookie, "^;\s*", "");
    # Unset empty cookies
    if (req.http.cookie ~ "^\s*$") {
        unset req.http.cookie;
    }

    # Pass all static files
    if (req.url ~ "^[^?]*\.(7z|avi|bmp|bz2|css|csv|doc|docx|eot|flac|flv|gif|gz|ico|jpeg|jpg|js|less|mka|mkv|mov|mp3|mp4|mpeg|mpg|odt|otf|ogg|ogm|opus|pdf|png|ppt|pptx|rar|rtf|svg|svgz|swf|tar|tbz|tgz|ttf|txt|txz|wav|webm|webp|woff|woff2|xls|xlsx|xml|xz|zip)(\?.*)?$") {
        unset req.http.Cookie;
        return (pass);
    }

    # Send Surrogate-Capability headers to announce ESI support to backend
    set req.http.Surrogate-Capability = "key=ESI/1.0";

    # Don't cache pages behind basic_auth
    if (req.http.Authorization) {
        return (pass);
    }

    return (hash);
}

sub vcl_pipe {

    set bereq.http.Connection = "Close";

    # Websocket support https://www.varnish-cache.org/docs/4.0/users-guide/vcl-example-websockets.html
    if (req.http.upgrade) {
        set bereq.http.upgrade = req.http.upgrade;
    }

    return (pipe);
}

sub vcl_deliver {
    # Add debug header to see if it's a HIT/MISS and the number of hits, only if you're an editor.
    #if (client.ip ~ editors){
        if (obj.hits > 0) {
            set resp.http.X-Cache = "HIT";
        } else {
            set resp.http.X-Cache = "MISS";
        }
        set resp.http.X-Cache-Hits = obj.hits;
        set resp.http.grace = req.http.grace;
    #}

    # Remove some headers:
    unset resp.http.X-Powered-By;
    unset resp.http.Server;
    unset resp.http.X-Varnish;
    unset resp.http.Via;
    unset resp.http.X-Generator;
    set resp.http.X-Powered-By = "SproutStack/Varnish";

    return (deliver);
}

sub vcl_hash {

    hash_data(req.url);

    if (req.http.host) {
        hash_data(req.http.host);
    } else {
        hash_data(server.ip);
    }

    if (req.http.Cookie) {
        hash_data(req.http.Cookie);
    }

    if (req.http.X-Forwarded-Proto) {
        hash_data(req.http.X-Forwarded-Proto);
    }
}

sub vcl_miss {
  return (fetch);
}

sub vcl_purge {
    if (req.method == "PURGE") {
        set req.http.X-Purge = "Yes";
        return (restart);
    }
}

# Can call a redirect in recv with `return (synth(701,"https://domain.ext/path"));`
sub vcl_synth {
    if (resp.status == 701) {
        set resp.http.Location = resp.reason;
        set resp.status = 301;
        return (deliver);
    } elseif (resp.status == 702) {
        set resp.http.Location = resp.reason;
        set resp.status = 302;
        return (deliver);
    }
    return (deliver);
}

sub vcl_backend_response {

    # Pause ESI request and remove Surrogate-Control header
    if (beresp.http.Surrogate-Control ~ "ESI/1.0") {
        unset beresp.http.Surrogate-Control;
        set beresp.do_esi = true;
    }

    if (bereq.url ~ "^[^?]*\.(7z|avi|bz2|flac|flv|gz|mka|mkv|mov|mp3|mp4|mpeg|mpg|ogg|ogm|opus|rar|tar|tgz|tbz|txz|wav|webm|xz|zip)(\?.*)?$") {
        unset beresp.http.set-cookie;
        set beresp.do_stream = true;
    }

    # Remove port from location header for rewrites
    if (beresp.status == 301 || beresp.status == 302) {
        set beresp.http.Location = regsub(beresp.http.Location, ":[0-9]+", "");
    }

    # Don't cache 50x responses
    if (beresp.status == 500 || beresp.status == 502 || beresp.status == 503 || beresp.status == 504) {
        return (abandon);
    }

    # Set 10min cache if unset for static files
    if (beresp.ttl <= 0s || beresp.http.Set-Cookie || beresp.http.Vary == "*") {
        set beresp.ttl = 600s; # Important, you shouldn't rely on this, SET YOUR HEADERS in the backend
        set beresp.uncacheable = true;
        return (deliver);
    }

    # Allow stale content, in case the backend goes down.
    set beresp.grace = 6h;

    return (deliver);
}

sub vcl_hit {

    if (obj.ttl >= 0s) {
        return (deliver);
    }

    # No fresh hits, check for stale.
    if (std.healthy(req.backend_hint)) {
        # Backend healthy. Limit age to 10s
        if (obj.ttl + 10s > 0s) {
            if (client.ip ~ editors) {
                set req.http.grace = "normal(limited)";
            }
            return (deliver);
        }
    } else {
        # Backend sick. Use full grace
        if (obj.ttl + obj.grace > 0s) {
            if (client.ip ~ editors) {
                set req.http.grace = "full";
            }
            return (deliver);
        }
    }
}
