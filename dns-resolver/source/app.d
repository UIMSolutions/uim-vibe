module app;

import std.array : split;
import std.conv : to;
import std.datetime : Clock, SysTime;
import std.format : format;
import std.json : JSONValue, parseJSON;
import std.net.curl : get;
import std.process : environment, execute;
import std.string : strip, toLower;

import vibe.vibe;

enum ResolverProvider {
    isp,
    google,
    cloudflare
}

struct ResolutionStep {
    string stage;
    string server;
    string detail;
}

struct ResolutionResult {
    bool success;
    bool fromCache;
    string input;
    string host;
    string ipAddress;
    ResolverProvider provider;
    string providerLabel;
    string errorMessage;
    int ttlSeconds;
    SysTime resolvedAt;
    ResolutionStep[] steps;
}

struct CacheEntry {
    string host;
    string ipAddress;
    ResolverProvider provider;
    int ttlSeconds;
    SysTime createdAt;
    SysTime expiresAt;
}

final class ResolverStore {
    private CacheEntry[string] cache;

    ResolutionResult resolve(string input, ResolverProvider provider) {
        pruneExpired();

        ResolutionResult result;
        result.input = input;
        result.provider = provider;
        result.providerLabel = providerLabel(provider);
        result.ttlSeconds = 300;

        auto host = normalizeTargetToHost(input);
        if (host.empty) {
            result.success = false;
            result.errorMessage = "Please enter a valid URL or hostname.";
            return result;
        }

        result.host = host;

        auto cacheKey = keyFor(host, provider);
        auto cachedPtr = cacheKey in cache;
        if (cachedPtr !is null && cachedPtr.expiresAt > Clock.currTime()) {
            auto cached = *cachedPtr;
            result.success = true;
            result.fromCache = true;
            result.ipAddress = cached.ipAddress;
            result.resolvedAt = cached.createdAt;
            result.ttlSeconds = cast(int) (cached.expiresAt - Clock.currTime()).total!"seconds";
            if (result.ttlSeconds < 0) {
                result.ttlSeconds = 0;
            }
            result.steps ~= ResolutionStep("Stub Resolver", "localhost", "Operating system stub resolver forwards query to recursive resolver.");
            result.steps ~= ResolutionStep("Recursive Resolver", providerServer(provider), "Cache hit in resolver. Returning cached IP without full recursion.");
            return result;
        }

        result.steps ~= ResolutionStep("Stub Resolver", "localhost", "Operating system stub resolver forwards query to recursive resolver.");
        result.steps ~= ResolutionStep("Recursive Resolver", providerServer(provider), "Cache miss. Starting recursive lookup.");
        result.steps ~= ResolutionStep("Root Name Server", rootServer(host), "Resolver asks root where to find the TLD name servers.");
        result.steps ~= ResolutionStep("TLD Name Server", tldServer(host), "Resolver asks TLD server for authoritative name servers.");
        result.steps ~= ResolutionStep("Authoritative Name Server", authoritativeServer(host), "Resolver asks authoritative server for final A record.");

        auto ip = resolveAddress(host, provider, result.errorMessage);
        if (ip.empty) {
            result.success = false;
            if (result.errorMessage.empty) {
                result.errorMessage = "Unable to resolve hostname.";
            }
            return result;
        }

        result.success = true;
        result.ipAddress = ip;
        result.resolvedAt = Clock.currTime();

        CacheEntry entry;
        entry.host = host;
        entry.ipAddress = ip;
        entry.provider = provider;
        entry.ttlSeconds = 300;
        entry.createdAt = result.resolvedAt;
        entry.expiresAt = result.resolvedAt + dur!"seconds"(entry.ttlSeconds);
        cache[cacheKey] = entry;

        return result;
    }

    CacheEntry[] cacheEntries() {
        pruneExpired();
        CacheEntry[] entries;
        foreach (entry; cache.byValue) {
            entries ~= entry;
        }
        return entries;
    }

    void clearCache() {
        cache = null;
    }

    private string keyFor(string host, ResolverProvider provider) {
        return host ~ "|" ~ providerLabel(provider);
    }

    private void pruneExpired() {
        auto now = Clock.currTime();
        string[] expiredKeys;
        foreach (key, entry; cache) {
            if (entry.expiresAt <= now) {
                expiredKeys ~= key;
            }
        }

        foreach (key; expiredKeys) {
            cache.remove(key);
        }
    }
}

__gshared ResolverStore resolverStore;

void main() {
    resolverStore = new ResolverStore;

    auto settings = new HTTPServerSettings;
    settings.port = readEnvPort("PORT", 8080);
    settings.bindAddresses = [readEnvString("BIND_ADDRESS", "127.0.0.1")];

    auto router = new URLRouter;
    router.get("/", &showHome);
    router.post("/resolve", &resolveFromForm);
    router.post("/cache/clear", &clearCache);
    router.get("/healthz", &health);

    listenHTTP(settings, router);
    runApplication();
}

void showHome(HTTPServerRequest req, HTTPServerResponse res) {
    auto target = req.query.get("target", "").strip;
    auto providerRaw = req.query.get("provider", "isp").strip;
    auto provider = parseProvider(providerRaw);

    ResolutionResult* maybeResult;
    ResolutionResult result;

    if (!target.empty) {
        result = resolverStore.resolve(target, provider);
        maybeResult = &result;
    }

    respondHtml(res, HTTPStatus.ok, renderHome(target, provider, maybeResult, resolverStore.cacheEntries()));
}

void resolveFromForm(HTTPServerRequest req, HTTPServerResponse res) {
    auto target = req.form.get("target", "").strip;
    auto providerRaw = req.form.get("provider", "isp").strip;

    auto location = format("/?target=%s&provider=%s", urlEncode(target), urlEncode(providerRaw));
    redirectTo(res, location);
}

void clearCache(HTTPServerRequest req, HTTPServerResponse res) {
    resolverStore.clearCache();
    redirectTo(res, "/");
}

void health(HTTPServerRequest req, HTTPServerResponse res) {
    res.contentType = "application/json; charset=utf-8";
    res.statusCode = HTTPStatus.ok;
    res.writeBody("{\"status\":\"ok\"}");
}

ResolverProvider parseProvider(string raw) {
    switch (raw.toLower()) {
        case "google": return ResolverProvider.google;
        case "cloudflare": return ResolverProvider.cloudflare;
        default: return ResolverProvider.isp;
    }
}

string providerLabel(ResolverProvider provider) {
    final switch (provider) {
        case ResolverProvider.isp: return "ISP Recursive Resolver";
        case ResolverProvider.google: return "Google Public DNS";
        case ResolverProvider.cloudflare: return "Cloudflare DNS";
    }
}

string providerServer(ResolverProvider provider) {
    final switch (provider) {
        case ResolverProvider.isp: return "ISP/System Resolver";
        case ResolverProvider.google: return "8.8.8.8 (DoH: dns.google)";
        case ResolverProvider.cloudflare: return "1.1.1.1 (DoH: cloudflare-dns.com)";
    }
}

string rootServer(string host) {
    return "a.root-servers.net";
}

string tldServer(string host) {
    auto tld = topLevelDomain(host);
    if (tld == "com" || tld == "net" || tld == "org") {
        return "a.gtld-servers.net";
    }
    return format("%s.tld-servers.example", tld);
}

string authoritativeServer(string host) {
    auto labels = host.split(".");
    if (labels.length >= 2) {
        return "ns1." ~ labels[$ - 2] ~ "." ~ labels[$ - 1];
    }
    return "ns1." ~ host;
}

string topLevelDomain(string host) {
    auto labels = host.split(".");
    if (labels.length == 0) {
        return "local";
    }
    return labels[$ - 1].toLower();
}

string resolveAddress(string host, ResolverProvider provider, out string error) {
    if (provider == ResolverProvider.google) {
        auto value = resolveWithGoogleDoH(host, error);
        if (!value.empty) {
            return value;
        }
    }

    if (provider == ResolverProvider.cloudflare) {
        auto value = resolveWithCloudflareDoH(host, error);
        if (!value.empty) {
            return value;
        }
    }

    return resolveWithSystemResolver(host, error);
}

string resolveWithGoogleDoH(string host, out string error) {
    auto endpoint = "https://dns.google/resolve?name=" ~ urlEncode(host) ~ "&type=A";
    return resolveWithDoH(endpoint, false, error);
}

string resolveWithCloudflareDoH(string host, out string error) {
    auto endpoint = "https://cloudflare-dns.com/dns-query?name=" ~ urlEncode(host) ~ "&type=A";
    return resolveWithDoH(endpoint, true, error);
}

string resolveWithDoH(string url, bool addDnsJsonHeader, out string error) {
    try {
        auto payload = cast(string) get(url);
        auto parsed = parseJSON(payload);

        auto answers = parsed["Answer"].array;
        foreach (answer; answers) {
            if (answer["type"].integer == 1) {
                return answer["data"].str;
            }
        }

        error = "No A record in DNS response.";
        return "";
    } catch (Exception ex) {
        error = "DoH lookup failed: " ~ ex.msg;
        return "";
    }
}

string resolveWithSystemResolver(string host, out string error) {
    try {
        auto response = execute(["getent", "ahostsv4", host]);
        if (response.status != 0) {
            error = "System resolver could not resolve host.";
            return "";
        }

        auto lines = response.output.splitLines();
        foreach (line; lines) {
            auto trimmed = line.strip;
            if (trimmed.empty) {
                continue;
            }

            auto pieces = trimmed.split;
            if (pieces.length > 0) {
                return pieces[0];
            }
        }

        error = "System resolver returned no IPv4 records.";
        return "";
    } catch (Exception ex) {
        error = "System resolver failed: " ~ ex.msg;
        return "";
    }
}

string normalizeTargetToHost(string rawInput) {
    auto value = rawInput.strip;
    if (value.empty) {
        return "";
    }

    auto lowered = value.toLower();
    auto start = lowered.indexOf("://");
    if (start >= 0) {
        lowered = lowered[start + 3 .. $];
    }

    auto slash = lowered.indexOf('/');
    if (slash >= 0) {
        lowered = lowered[0 .. slash];
    }

    auto atSign = lowered.lastIndexOf('@');
    if (atSign >= 0 && atSign + 1 < lowered.length) {
        lowered = lowered[atSign + 1 .. $];
    }

    if (!lowered.empty && lowered[$ - 1] == '.') {
        lowered = lowered[0 .. $ - 1];
    }

    auto colon = lowered.indexOf(':');
    if (colon > 0) {
        lowered = lowered[0 .. colon];
    }

    if (lowered.empty) {
        return "";
    }

    foreach (ch; lowered) {
        auto isLetter = ch >= 'a' && ch <= 'z';
        auto isDigit = ch >= '0' && ch <= '9';
        auto allowed = ch == '.' || ch == '-';
        if (!isLetter && !isDigit && !allowed) {
            return "";
        }
    }

    return lowered;
}

string renderHome(string target, ResolverProvider provider, ResolutionResult* result, CacheEntry[] cacheEntries) {
    auto selectedIsp = provider == ResolverProvider.isp ? "selected" : "";
    auto selectedGoogle = provider == ResolverProvider.google ? "selected" : "";
    auto selectedCloudflare = provider == ResolverProvider.cloudflare ? "selected" : "";

    string resultHtml;
    if (result !is null) {
        if (result.success) {
            string stepsHtml = "<ol>";
            foreach (step; result.steps) {
                stepsHtml ~= format(
                    "<li><strong>%s</strong> — <span class=\"muted\">%s</span><br>%s</li>",
                    escapeHtml(step.stage),
                    escapeHtml(step.server),
                    escapeHtml(step.detail)
                );
            }
            stepsHtml ~= "</ol>";

            resultHtml = format(
                "<section class=\"panel success\">"
                ~ "<h2>Resolution Result</h2>"
                ~ "<p><strong>Input:</strong> %s</p>"
                ~ "<p><strong>Host:</strong> %s</p>"
                ~ "<p><strong>IP Address:</strong> %s</p>"
                ~ "<p><strong>Provider:</strong> %s</p>"
                ~ "<p><strong>Source:</strong> %s</p>"
                ~ "<p><strong>TTL:</strong> %s seconds</p>"
                ~ "<h3>Recursive Trace</h3>"
                ~ "%s"
                ~ "</section>",
                escapeHtml(result.input),
                escapeHtml(result.host),
                escapeHtml(result.ipAddress),
                escapeHtml(result.providerLabel),
                result.fromCache ? "Resolver cache hit" : "Live recursive lookup",
                result.ttlSeconds,
                stepsHtml
            );
        } else {
            resultHtml = format(
                "<section class=\"panel error\">"
                ~ "<h2>Resolution Failed</h2>"
                ~ "<p><strong>Input:</strong> %s</p>"
                ~ "<p>%s</p>"
                ~ "</section>",
                escapeHtml(result.input),
                escapeHtml(result.errorMessage)
            );
        }
    }

    string cacheRows;
    if (cacheEntries.empty) {
        cacheRows = "<tr><td colspan=\"5\">Cache is empty.</td></tr>";
    } else {
        foreach (entry; cacheEntries) {
            auto remaining = cast(int) (entry.expiresAt - Clock.currTime()).total!"seconds";
            if (remaining < 0) {
                remaining = 0;
            }

            cacheRows ~= format(
                "<tr><td>%s</td><td>%s</td><td>%s</td><td>%s s</td><td>%s</td></tr>",
                escapeHtml(entry.host),
                escapeHtml(entry.ipAddress),
                escapeHtml(providerLabel(entry.provider)),
                remaining,
                escapeHtml(entry.createdAt.toISOExtString())
            );
        }
    }

    auto body = format(
        "<header class=\"top\">"
        ~ "<h1>DNS Resolver</h1>"
        ~ "<p class=\"muted\">Stub resolver + recursive resolver flow with cache, provider options, and recursive trace.</p>"
        ~ "</header>"
        ~ "<section class=\"panel\">"
        ~ "<h2>Resolve URL or Hostname</h2>"
        ~ "<form method=\"post\" action=\"/resolve\" class=\"form\">"
        ~ "<label>Target URL / Hostname"
        ~ "<input type=\"text\" name=\"target\" required placeholder=\"https://example.com or example.com\" value=\"%s\">"
        ~ "</label>"
        ~ "<label>Recursive Resolver Provider"
        ~ "<select name=\"provider\">"
        ~ "<option value=\"isp\" %s>ISP/System Recursive Resolver</option>"
        ~ "<option value=\"google\" %s>Google Public DNS (8.8.8.8)</option>"
        ~ "<option value=\"cloudflare\" %s>Cloudflare (1.1.1.1)</option>"
        ~ "</select>"
        ~ "</label>"
        ~ "<div class=\"actions\">"
        ~ "<button type=\"submit\" class=\"primary\">Resolve</button>"
        ~ "</div>"
        ~ "</form>"
        ~ "<p class=\"muted\">Stub resolver note: your OS stub sends DNS requests to a recursive resolver, which performs root → TLD → authoritative queries.</p>"
        ~ "</section>"
        ~ "%s"
        ~ "<section class=\"panel\">"
        ~ "<div class=\"row\"><h2>Resolver Cache</h2>"
        ~ "<form method=\"post\" action=\"/cache/clear\"><button type=\"submit\">Clear Cache</button></form>"
        ~ "</div>"
        ~ "<table>"
        ~ "<thead><tr><th>Host</th><th>IP</th><th>Provider</th><th>TTL Remaining</th><th>Created At</th></tr></thead>"
        ~ "<tbody>%s</tbody>"
        ~ "</table>"
        ~ "</section>",
        escapeHtml(target),
        selectedIsp,
        selectedGoogle,
        selectedCloudflare,
        resultHtml,
        cacheRows
    );

    return pageLayout("DNS Resolver", body);
}

string pageLayout(string title, string body) {
    return "<!DOCTYPE html>\n"
        ~ "<html lang=\"en\">\n"
        ~ "<head>\n"
        ~ "  <meta charset=\"utf-8\">\n"
        ~ "  <meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">\n"
        ~ "  <title>" ~ escapeHtml(title) ~ "</title>\n"
        ~ "  <style>\n"
        ~ "    body { font-family: system-ui, sans-serif; max-width: 1100px; margin: 2rem auto; padding: 0 1rem; color: #1e1e1e; }\n"
        ~ "    .top h1 { margin: 0 0 0.3rem; }\n"
        ~ "    .muted { color: #5f6770; }\n"
        ~ "    .panel { border: 1px solid #d7d7d7; border-radius: 0.45rem; padding: 0.9rem; margin-bottom: 1rem; background: #fcfcfc; }\n"
        ~ "    .panel.success { border-color: #98c59b; }\n"
        ~ "    .panel.error { border-color: #d39f9f; }\n"
        ~ "    .form { display: grid; gap: 0.7rem; max-width: 760px; }\n"
        ~ "    label { display: grid; gap: 0.3rem; }\n"
        ~ "    input[type=text], select { font: inherit; padding: 0.5rem; border: 1px solid #c8c8c8; border-radius: 0.3rem; }\n"
        ~ "    button { font: inherit; border: 1px solid #8f8f8f; background: #f2f2f2; border-radius: 0.3rem; padding: 0.45rem 0.7rem; cursor: pointer; }\n"
        ~ "    button.primary { background: #e8eefc; border-color: #98acd9; }\n"
        ~ "    .actions { display: flex; gap: 0.5rem; align-items: center; }\n"
        ~ "    .row { display: flex; justify-content: space-between; align-items: center; gap: 0.8rem; }\n"
        ~ "    table { width: 100%; border-collapse: collapse; margin-top: 0.5rem; }\n"
        ~ "    th, td { border: 1px solid #dddddd; text-align: left; padding: 0.55rem; vertical-align: top; }\n"
        ~ "    th { background: #f3f4f6; }\n"
        ~ "    ol { margin: 0.4rem 0 0 1.2rem; }\n"
        ~ "    li { margin-bottom: 0.55rem; }\n"
        ~ "  </style>\n"
        ~ "</head>\n"
        ~ "<body>" ~ body ~ "</body>\n"
        ~ "</html>\n";
}

void respondHtml(HTTPServerResponse res, HTTPStatus status, string html) {
    res.contentType = "text/html; charset=utf-8";
    res.statusCode = status;
    res.writeBody(html);
}

void redirectTo(HTTPServerResponse res, string path) {
    res.statusCode = HTTPStatus.seeOther;
    res.headers["Location"] = path;
    res.writeBody("Redirecting...");
}

string escapeHtml(string value) {
    string result;
    result.reserve(value.length);

    foreach (ch; value) {
        switch (ch) {
            case '&': result ~= "&amp;"; break;
            case '<': result ~= "&lt;"; break;
            case '>': result ~= "&gt;"; break;
            case '"': result ~= "&quot;"; break;
            case '\'': result ~= "&#39;"; break;
            default: result ~= ch; break;
        }
    }

    return result;
}

string urlEncode(string value) {
    string encoded;
    foreach (ch; value) {
        auto isAlpha = (ch >= 'a' && ch <= 'z') || (ch >= 'A' && ch <= 'Z');
        auto isDigit = ch >= '0' && ch <= '9';
        auto safe = ch == '-' || ch == '_' || ch == '.' || ch == '~';
        if (isAlpha || isDigit || safe) {
            encoded ~= ch;
        } else {
            encoded ~= "%" ~ format("%02X", cast(ubyte) ch);
        }
    }
    return encoded;
}

ushort readEnvPort(string key, ushort fallback) {
    auto value = environment.get(key, "").strip;
    if (value.empty) {
        return fallback;
    }

    try {
        auto parsed = value.to!int;
        if (parsed <= 0 || parsed > 65535) {
            return fallback;
        }

        return cast(ushort) parsed;
    } catch (Exception) {
        return fallback;
    }
}

string readEnvString(string key, string fallback) {
    auto value = environment.get(key, "").strip;
    return value.empty ? fallback : value;
}
