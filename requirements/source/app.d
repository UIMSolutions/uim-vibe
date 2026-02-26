module app;

import std.conv : to;
import std.datetime : Clock, SysTime;
import std.format : format;
import std.string : strip, toLower;

import vibe.vibe;

struct WikiPage {
    string title;
    string slug;
    string content;
    SysTime createdAt;
    SysTime updatedAt;
}

final class WikiStore {
    private WikiPage[] pages;

    WikiPage[] all() {
        return pages.dup;
    }

    WikiPage* find(string slug) {
        foreach (ref page; pages) {
            if (page.slug == slug) {
                return &page;
            }
        }

        return null;
    }

    bool create(string title, string content) {
        auto cleanedTitle = title.strip;
        if (cleanedTitle.empty) {
            return false;
        }

        auto slug = slugify(cleanedTitle);
        if (slug.empty || find(slug) !is null) {
            return false;
        }

        auto now = Clock.currTime();
        pages ~= WikiPage(cleanedTitle, slug, content.strip, now, now);
        return true;
    }

    bool update(string slug, string title, string content) {
        auto page = find(slug);
        if (page is null) {
            return false;
        }

        auto cleanedTitle = title.strip;
        if (cleanedTitle.empty) {
            return false;
        }

        page.title = cleanedTitle;
        page.content = content.strip;
        page.updatedAt = Clock.currTime();
        return true;
    }

    bool remove(string slug) {
        foreach (index, page; pages) {
            if (page.slug == slug) {
                pages = pages[0 .. index] ~ pages[index + 1 .. $];
                return true;
            }
        }

        return false;
    }
}

__gshared WikiStore wikiStore;

void main() {
    wikiStore = new WikiStore;

    auto settings = new HTTPServerSettings;
    settings.port = 8080;
    settings.bindAddresses = ["127.0.0.1"];

    auto router = new URLRouter;

    router.get("/", &listPages);
    router.get("/new", &showCreatePage);
    router.post("/pages", &createPage);
    router.get("/pages/:slug", &showPage);
    router.get("/pages/:slug/edit", &showEditPage);
    router.post("/pages/:slug", &updatePage);
    router.post("/pages/:slug/delete", &deletePage);

    listenHTTP(settings, router);
    runApplication();
}

void listPages(HTTPServerRequest req, HTTPServerResponse res) {
    auto html = renderHome(wikiStore.all());

    res.contentType = "text/html; charset=utf-8";
    res.statusCode = HTTPStatus.ok;
    res.writeBody(html);
}

void showCreatePage(HTTPServerRequest req, HTTPServerResponse res) {
    res.contentType = "text/html; charset=utf-8";
    res.statusCode = HTTPStatus.ok;
    res.writeBody(renderCreateForm());
}

void createPage(HTTPServerRequest req, HTTPServerResponse res) {
    auto form = req.form;
    auto title = form.get("title", "").strip;
    auto content = form.get("content", "").strip;

    if (!wikiStore.create(title, content)) {
        res.contentType = "text/html; charset=utf-8";
        res.statusCode = HTTPStatus.badRequest;
        res.writeBody(renderCreateForm(title, content, "Unable to create page. Title must be unique."));
        return;
    }

    redirectTo(res, "/");
}

void showPage(HTTPServerRequest req, HTTPServerResponse res) {
    auto slug = req.params["slug"].strip;
    auto page = wikiStore.find(slug);
    if (page is null) {
        respondNotFound(res);
        return;
    }

    res.contentType = "text/html; charset=utf-8";
    res.statusCode = HTTPStatus.ok;
    res.writeBody(renderViewPage(*page));
}

void showEditPage(HTTPServerRequest req, HTTPServerResponse res) {
    auto slug = req.params["slug"].strip;
    auto page = wikiStore.find(slug);
    if (page is null) {
        respondNotFound(res);
        return;
    }

    res.contentType = "text/html; charset=utf-8";
    res.statusCode = HTTPStatus.ok;
    res.writeBody(renderEditForm(*page));
}

void updatePage(HTTPServerRequest req, HTTPServerResponse res) {
    auto slug = req.params["slug"].strip;
    auto page = wikiStore.find(slug);
    if (page is null) {
        respondNotFound(res);
        return;
    }

    auto form = req.form;
    auto title = form.get("title", "").strip;
    auto content = form.get("content", "").strip;

    if (!wikiStore.update(slug, title, content)) {
        res.contentType = "text/html; charset=utf-8";
        res.statusCode = HTTPStatus.badRequest;
        res.writeBody(renderEditForm(*page, "Title cannot be empty."));
        return;
    }

    redirectTo(res, format("/pages/%s", slug));
}

void deletePage(HTTPServerRequest req, HTTPServerResponse res) {
    auto slug = req.params["slug"].strip;
    wikiStore.remove(slug);
    redirectTo(res, "/");
}

void redirectTo(HTTPServerResponse res, string path) {
    res.statusCode = HTTPStatus.seeOther;
    res.headers["Location"] = path;
    res.writeBody("Redirecting...");
}

void respondNotFound(HTTPServerResponse res) {
    res.contentType = "text/html; charset=utf-8";
    res.statusCode = HTTPStatus.notFound;
    res.writeBody(renderNotFound());
}

string slugify(string title) {
    string result;
    bool previousWasDash;

    foreach (rawCh; title.toLower()) {
        immutable ch = rawCh;
        if ((ch >= 'a' && ch <= 'z') || (ch >= '0' && ch <= '9')) {
            result ~= ch;
            previousWasDash = false;
            continue;
        }

        if (!previousWasDash && !result.empty) {
            result ~= '-';
            previousWasDash = true;
        }
    }

    if (!result.empty && result[$ - 1] == '-') {
        result = result[0 .. $ - 1];
    }

    return result;
}

string pageLayout(string title, string body) {
    auto template = "<!DOCTYPE html>\n"
        ~ "<html lang=\"en\">\n"
        ~ "<head>\n"
        ~ "  <meta charset=\"utf-8\">\n"
        ~ "  <meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">\n"
        ~ "  <title>%s</title>\n"
        ~ "  <style>\n"
        ~ "    body { font-family: system-ui, sans-serif; max-width: 960px; margin: 2rem auto; padding: 0 1rem; }\n"
        ~ "    h1, h2 { margin-bottom: 0.3rem; }\n"
        ~ "    .muted { color: #555; }\n"
        ~ "    a.button, button { display: inline-block; font: inherit; border: 1px solid #999; background: #f7f7f7; padding: 0.45rem 0.7rem; border-radius: 0.3rem; text-decoration: none; color: inherit; cursor: pointer; }\n"
        ~ "    a.button.primary, button.primary { background: #eceff8; border-color: #8794c4; }\n"
        ~ "    .topbar { display: flex; justify-content: space-between; align-items: center; margin-bottom: 1.1rem; }\n"
        ~ "    ul.pages { list-style: none; padding: 0; margin: 0; }\n"
        ~ "    ul.pages li { border: 1px solid #ddd; border-radius: 0.35rem; padding: 0.8rem; margin-bottom: 0.6rem; }\n"
        ~ "    .meta { font-size: 0.9rem; color: #666; }\n"
        ~ "    form.page-form { display: grid; gap: 0.65rem; }\n"
        ~ "    input[type=text], textarea { font: inherit; width: 100%; padding: 0.55rem; border: 1px solid #cfcfcf; border-radius: 0.3rem; }\n"
        ~ "    textarea { min-height: 16rem; resize: vertical; }\n"
        ~ "    .error { color: #9e2020; margin: 0.2rem 0; }\n"
        ~ "    .actions { display: flex; gap: 0.5rem; align-items: center; }\n"
        ~ "    pre.content { white-space: pre-wrap; border: 1px solid #ddd; border-radius: 0.3rem; padding: 0.9rem; background: #fafafa; }\n"
        ~ "  </style>\n"
        ~ "</head>\n"
        ~ "<body>\n"
        ~ "%s\n"
        ~ "</body>\n"
        ~ "</html>\n";

    return format(template, escapeHtml(title), body);
}

string renderHome(WikiPage[] pages) {
    string items;

    if (pages.empty) {
        items = "<p class=\"muted\">No pages yet. Create your first wiki page.</p>";
    } else {
        items ~= "<ul class=\"pages\">";
        foreach (page; pages) {
            items ~= format(
                "<li>"
                ~ "<h2><a href=\"/pages/%s\">%s</a></h2>"
                ~ "<div class=\"meta\">slug: %s · updated: %s</div>"
                ~ "</li>",
                escapeHtml(page.slug),
                escapeHtml(page.title),
                escapeHtml(page.slug),
                page.updatedAt.toISOExtString()
            );
        }
        items ~= "</ul>";
    }

    auto body = "<div class=\"topbar\">"
        ~ "<div>"
        ~ "<h1>Wiki</h1>"
        ~ "<p class=\"muted\">Simple wiki application with D + vibe.d</p>"
        ~ "</div>"
        ~ "<a class=\"button primary\" href=\"/new\">New Page</a>"
        ~ "</div>"
        ~ items;

    return pageLayout("Wiki", body);
}

string renderCreateForm(string title = "", string content = "", string error = "") {
    string errorHtml;
    if (!error.empty) {
        errorHtml = format("<p class=\"error\">%s</p>", escapeHtml(error));
    }

    auto body = "<div class=\"topbar\">"
        ~ "<h1>Create Page</h1>"
        ~ "<a class=\"button\" href=\"/\">Back to Wiki</a>"
        ~ "</div>"
        ~ errorHtml
        ~ format(
            "<form class=\"page-form\" method=\"post\" action=\"/pages\">"
            ~ "<label>Title</label>"
            ~ "<input type=\"text\" name=\"title\" required value=\"%s\" placeholder=\"Page title\">"
            ~ "<label>Content</label>"
            ~ "<textarea name=\"content\" placeholder=\"Write your wiki content here...\">%s</textarea>"
            ~ "<div class=\"actions\">"
            ~ "<button class=\"primary\" type=\"submit\">Create</button>"
            ~ "<a class=\"button\" href=\"/\">Cancel</a>"
            ~ "</div>"
            ~ "</form>",
            escapeHtml(title),
            escapeHtml(content)
        );

    return pageLayout("Create Page", body);
}

string renderViewPage(WikiPage page) {
    auto body = format(
        "<div class=\"topbar\">"
        ~ "<div><h1>%s</h1><div class=\"meta\">slug: %s · created: %s · updated: %s</div></div>"
        ~ "<div class=\"actions\"><a class=\"button\" href=\"/\">Wiki Home</a><a class=\"button primary\" href=\"/pages/%s/edit\">Edit</a></div>"
        ~ "</div>"
        ~ "<pre class=\"content\">%s</pre>"
        ~ "<form method=\"post\" action=\"/pages/%s/delete\" onsubmit=\"return confirm('Delete this page?');\">"
        ~ "<button type=\"submit\">Delete page</button>"
        ~ "</form>",
        escapeHtml(page.title),
        escapeHtml(page.slug),
        page.createdAt.toISOExtString(),
        page.updatedAt.toISOExtString(),
        escapeHtml(page.slug),
        escapeHtml(page.content),
        escapeHtml(page.slug)
    );

    return pageLayout(page.title, body);
}

string renderEditForm(WikiPage page, string error = "") {
    string errorHtml;
    if (!error.empty) {
        errorHtml = format("<p class=\"error\">%s</p>", escapeHtml(error));
    }

    auto body = format(
        "<div class=\"topbar\">"
        ~ "<h1>Edit Page</h1>"
        ~ "<a class=\"button\" href=\"/pages/%s\">Back to Page</a>"
        ~ "</div>"
        ~ "%s"
        ~ "<form class=\"page-form\" method=\"post\" action=\"/pages/%s\">"
        ~ "<label>Title</label>"
        ~ "<input type=\"text\" name=\"title\" required value=\"%s\">"
        ~ "<label>Content</label>"
        ~ "<textarea name=\"content\">%s</textarea>"
        ~ "<div class=\"actions\">"
        ~ "<button class=\"primary\" type=\"submit\">Save</button>"
        ~ "<a class=\"button\" href=\"/pages/%s\">Cancel</a>"
        ~ "</div>"
        ~ "</form>",
        escapeHtml(page.slug),
        errorHtml,
        escapeHtml(page.slug),
        escapeHtml(page.title),
        escapeHtml(page.content),
        escapeHtml(page.slug)
    );

    return pageLayout(format("Edit %s", page.title), body);
}

string renderNotFound() {
    auto body = "<h1>404 - Page Not Found</h1>"
        ~ "<p class=\"muted\">The wiki page you requested does not exist.</p>"
        ~ "<a class=\"button\" href=\"/\">Back to Wiki</a>";

    return pageLayout("Not Found", body);
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
            default: result ~= ch;
        }
    }
    return result;
}