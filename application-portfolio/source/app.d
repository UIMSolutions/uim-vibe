module app;

import std.datetime : Clock, SysTime;
import std.format : format;
import std.string : strip, toLower;
import std.conv : to;

import vibe.vibe;

enum RationalizationDecision {
    invest,
    tolerate,
    migrate,
    retire
}

struct PortfolioApplication {
    string id;
    string name;
    string owner;
    string vendor;
    bool isInHouse;
    string licenseModel;
    double annualCost;
    int monthlyActiveUsers;
    string businessCapability;
    string technology;
    string lifecycleStatus;
    bool vendorSupportEnding;

    int businessValue;
    int functionalQuality;
    int technicalHealth;
    int strategicAlignment;
    RationalizationDecision rationalizationDecision;

    SysTime createdAt;
    SysTime updatedAt;
}

struct PortfolioStats {
    size_t totalApplications;
    double totalAnnualCost;
    double averageBusinessValue;
    double averageFunctionalQuality;
    double averageTechnicalHealth;
    double averageStrategicAlignment;
    size_t highRiskCount;
    size_t redundantCapabilityCount;

    size_t investCount;
    size_t tolerateCount;
    size_t migrateCount;
    size_t retireCount;
}

final class PortfolioStore {
    private PortfolioApplication[] applications;
    private int sequence = 100;

    PortfolioApplication[] all() {
        return applications.dup;
    }

    PortfolioApplication* find(string id) {
        foreach (ref app; applications) {
            if (app.id == id) {
                return &app;
            }
        }

        return null;
    }

    bool create(
        string name,
        string owner,
        string vendor,
        bool isInHouse,
        string licenseModel,
        double annualCost,
        int monthlyActiveUsers,
        string businessCapability,
        string technology,
        string lifecycleStatus,
        bool vendorSupportEnding,
        int businessValue,
        int functionalQuality,
        int technicalHealth,
        int strategicAlignment,
        RationalizationDecision rationalizationDecision
    ) {
        auto cleanedName = name.strip;
        auto cleanedOwner = owner.strip;
        auto cleanedCapability = businessCapability.strip;

        if (cleanedName.empty || cleanedOwner.empty || cleanedCapability.empty) {
            return false;
        }

        if (annualCost < 0 || monthlyActiveUsers < 0) {
            return false;
        }

        if (!isValidScore(businessValue)
            || !isValidScore(functionalQuality)
            || !isValidScore(technicalHealth)
            || !isValidScore(strategicAlignment)) {
            return false;
        }

        sequence += 1;
        auto now = Clock.currTime();

        applications ~= PortfolioApplication(
            format("APP-%s", sequence.to!string),
            cleanedName,
            cleanedOwner,
            vendor.strip,
            isInHouse,
            licenseModel.strip,
            annualCost,
            monthlyActiveUsers,
            cleanedCapability,
            technology.strip,
            lifecycleStatus.strip,
            vendorSupportEnding,
            businessValue,
            functionalQuality,
            technicalHealth,
            strategicAlignment,
            rationalizationDecision,
            now,
            now
        );

        return true;
    }

    bool update(
        string id,
        string name,
        string owner,
        string vendor,
        bool isInHouse,
        string licenseModel,
        double annualCost,
        int monthlyActiveUsers,
        string businessCapability,
        string technology,
        string lifecycleStatus,
        bool vendorSupportEnding,
        int businessValue,
        int functionalQuality,
        int technicalHealth,
        int strategicAlignment,
        RationalizationDecision rationalizationDecision
    ) {
        auto app = find(id);
        if (app is null) {
            return false;
        }

        auto cleanedName = name.strip;
        auto cleanedOwner = owner.strip;
        auto cleanedCapability = businessCapability.strip;

        if (cleanedName.empty || cleanedOwner.empty || cleanedCapability.empty) {
            return false;
        }

        if (annualCost < 0 || monthlyActiveUsers < 0) {
            return false;
        }

        if (!isValidScore(businessValue)
            || !isValidScore(functionalQuality)
            || !isValidScore(technicalHealth)
            || !isValidScore(strategicAlignment)) {
            return false;
        }

        app.name = cleanedName;
        app.owner = cleanedOwner;
        app.vendor = vendor.strip;
        app.isInHouse = isInHouse;
        app.licenseModel = licenseModel.strip;
        app.annualCost = annualCost;
        app.monthlyActiveUsers = monthlyActiveUsers;
        app.businessCapability = cleanedCapability;
        app.technology = technology.strip;
        app.lifecycleStatus = lifecycleStatus.strip;
        app.vendorSupportEnding = vendorSupportEnding;
        app.businessValue = businessValue;
        app.functionalQuality = functionalQuality;
        app.technicalHealth = technicalHealth;
        app.strategicAlignment = strategicAlignment;
        app.rationalizationDecision = rationalizationDecision;
        app.updatedAt = Clock.currTime();

        return true;
    }

    bool remove(string id) {
        foreach (index, app; applications) {
            if (app.id == id) {
                applications = applications[0 .. index] ~ applications[index + 1 .. $];
                return true;
            }
        }

        return false;
    }

    PortfolioStats stats() {
        PortfolioStats result;
        result.totalApplications = applications.length;

        if (applications.empty) {
            return result;
        }

        double businessValueSum;
        double functionalQualitySum;
        double technicalHealthSum;
        double strategicAlignmentSum;

        foreach (app; applications) {
            result.totalAnnualCost += app.annualCost;
            businessValueSum += app.businessValue;
            functionalQualitySum += app.functionalQuality;
            technicalHealthSum += app.technicalHealth;
            strategicAlignmentSum += app.strategicAlignment;

            if (isHighRisk(app)) {
                result.highRiskCount += 1;
            }

            final switch (app.rationalizationDecision) {
                case RationalizationDecision.invest: result.investCount += 1; break;
                case RationalizationDecision.tolerate: result.tolerateCount += 1; break;
                case RationalizationDecision.migrate: result.migrateCount += 1; break;
                case RationalizationDecision.retire: result.retireCount += 1; break;
            }
        }

        result.averageBusinessValue = businessValueSum / applications.length;
        result.averageFunctionalQuality = functionalQualitySum / applications.length;
        result.averageTechnicalHealth = technicalHealthSum / applications.length;
        result.averageStrategicAlignment = strategicAlignmentSum / applications.length;
        result.redundantCapabilityCount = countRedundantCapabilities();

        return result;
    }

    size_t countRedundantCapabilities() {
        size_t redundancies;

        foreach (candidate; applications) {
            size_t overlapCount;
            foreach (other; applications) {
                if (candidate.id != other.id
                    && toLower(candidate.businessCapability.strip) == toLower(other.businessCapability.strip)) {
                    overlapCount += 1;
                }
            }

            if (overlapCount > 0) {
                redundancies += 1;
            }
        }

        return redundancies;
    }

    bool isHighRisk(PortfolioApplication app) {
        return app.technicalHealth <= 2 || app.vendorSupportEnding;
    }

    private bool isValidScore(int value) {
        return value >= 1 && value <= 5;
    }
}

__gshared PortfolioStore portfolioStore;

void main() {
    portfolioStore = new PortfolioStore;
    seedData();

    auto settings = new HTTPServerSettings;
    settings.port = 8080;
    settings.bindAddresses = ["127.0.0.1"];

    auto router = new URLRouter;
    router.get("/", &showDashboard);
    router.get("/applications/new", &showCreateApplication);
    router.post("/applications", &createApplication);
    router.get("/applications/:id", &showApplication);
    router.get("/applications/:id/edit", &showEditApplication);
    router.post("/applications/:id", &updateApplication);
    router.post("/applications/:id/delete", &deleteApplication);

    listenHTTP(settings, router);
    runApplication();
}

void showDashboard(HTTPServerRequest req, HTTPServerResponse res) {
    auto html = renderDashboard(portfolioStore.all(), portfolioStore.stats());
    respondHtml(res, HTTPStatus.ok, html);
}

void showCreateApplication(HTTPServerRequest req, HTTPServerResponse res) {
    respondHtml(res, HTTPStatus.ok, renderApplicationForm("Create Application", "/applications"));
}

void createApplication(HTTPServerRequest req, HTTPServerResponse res) {
    auto form = req.form;

    auto name = form.get("name", "").strip;
    auto owner = form.get("owner", "").strip;
    auto vendor = form.get("vendor", "").strip;
    auto isInHouse = form.get("isInHouse", "") == "on";
    auto licenseModel = form.get("licenseModel", "").strip;
    auto annualCost = parseDoubleNonNegative(form.get("annualCost", "0"));
    auto monthlyActiveUsers = parseIntNonNegative(form.get("monthlyActiveUsers", "0"));
    auto businessCapability = form.get("businessCapability", "").strip;
    auto technology = form.get("technology", "").strip;
    auto lifecycleStatus = form.get("lifecycleStatus", "").strip;
    auto vendorSupportEnding = form.get("vendorSupportEnding", "") == "on";

    auto businessValue = parseScore(form.get("businessValue", "3"));
    auto functionalQuality = parseScore(form.get("functionalQuality", "3"));
    auto technicalHealth = parseScore(form.get("technicalHealth", "3"));
    auto strategicAlignment = parseScore(form.get("strategicAlignment", "3"));
    auto decision = parseDecision(form.get("rationalizationDecision", "tolerate"));

    if (annualCost < 0 || monthlyActiveUsers < 0) {
        respondHtml(
            res,
            HTTPStatus.badRequest,
            renderApplicationForm(
                "Create Application",
                "/applications",
                "Annual cost and active users must be non-negative numbers.",
                formFromInputs(
                    name,
                    owner,
                    vendor,
                    isInHouse,
                    licenseModel,
                    annualCost,
                    monthlyActiveUsers,
                    businessCapability,
                    technology,
                    lifecycleStatus,
                    vendorSupportEnding,
                    businessValue,
                    functionalQuality,
                    technicalHealth,
                    strategicAlignment,
                    decision
                )
            )
        );
        return;
    }

    if (!portfolioStore.create(
        name,
        owner,
        vendor,
        isInHouse,
        licenseModel,
        annualCost,
        monthlyActiveUsers,
        businessCapability,
        technology,
        lifecycleStatus,
        vendorSupportEnding,
        businessValue,
        functionalQuality,
        technicalHealth,
        strategicAlignment,
        decision
    )) {
        respondHtml(
            res,
            HTTPStatus.badRequest,
            renderApplicationForm(
                "Create Application",
                "/applications",
                "Required fields are missing or score values are invalid (use 1-5).",
                formFromInputs(
                    name,
                    owner,
                    vendor,
                    isInHouse,
                    licenseModel,
                    annualCost,
                    monthlyActiveUsers,
                    businessCapability,
                    technology,
                    lifecycleStatus,
                    vendorSupportEnding,
                    businessValue,
                    functionalQuality,
                    technicalHealth,
                    strategicAlignment,
                    decision
                )
            )
        );
        return;
    }

    redirectTo(res, "/");
}

void showApplication(HTTPServerRequest req, HTTPServerResponse res) {
    auto id = req.params["id"].strip;
    auto app = portfolioStore.find(id);
    if (app is null) {
        respondNotFound(res);
        return;
    }

    respondHtml(res, HTTPStatus.ok, renderApplicationDetails(*app));
}

void showEditApplication(HTTPServerRequest req, HTTPServerResponse res) {
    auto id = req.params["id"].strip;
    auto app = portfolioStore.find(id);
    if (app is null) {
        respondNotFound(res);
        return;
    }

    auto formValues = formFromApplication(*app);
    respondHtml(
        res,
        HTTPStatus.ok,
        renderApplicationForm("Edit Application", format("/applications/%s", escapeUrlSegment(id)), "", formValues)
    );
}

void updateApplication(HTTPServerRequest req, HTTPServerResponse res) {
    auto id = req.params["id"].strip;
    auto app = portfolioStore.find(id);
    if (app is null) {
        respondNotFound(res);
        return;
    }

    auto form = req.form;

    auto name = form.get("name", "").strip;
    auto owner = form.get("owner", "").strip;
    auto vendor = form.get("vendor", "").strip;
    auto isInHouse = form.get("isInHouse", "") == "on";
    auto licenseModel = form.get("licenseModel", "").strip;
    auto annualCost = parseDoubleNonNegative(form.get("annualCost", "0"));
    auto monthlyActiveUsers = parseIntNonNegative(form.get("monthlyActiveUsers", "0"));
    auto businessCapability = form.get("businessCapability", "").strip;
    auto technology = form.get("technology", "").strip;
    auto lifecycleStatus = form.get("lifecycleStatus", "").strip;
    auto vendorSupportEnding = form.get("vendorSupportEnding", "") == "on";

    auto businessValue = parseScore(form.get("businessValue", "3"));
    auto functionalQuality = parseScore(form.get("functionalQuality", "3"));
    auto technicalHealth = parseScore(form.get("technicalHealth", "3"));
    auto strategicAlignment = parseScore(form.get("strategicAlignment", "3"));
    auto decision = parseDecision(form.get("rationalizationDecision", "tolerate"));

    if (annualCost < 0 || monthlyActiveUsers < 0) {
        respondHtml(
            res,
            HTTPStatus.badRequest,
            renderApplicationForm(
                "Edit Application",
                format("/applications/%s", escapeUrlSegment(id)),
                "Annual cost and active users must be non-negative numbers.",
                formFromInputs(
                    name,
                    owner,
                    vendor,
                    isInHouse,
                    licenseModel,
                    annualCost,
                    monthlyActiveUsers,
                    businessCapability,
                    technology,
                    lifecycleStatus,
                    vendorSupportEnding,
                    businessValue,
                    functionalQuality,
                    technicalHealth,
                    strategicAlignment,
                    decision
                )
            )
        );
        return;
    }

    if (!portfolioStore.update(
        id,
        name,
        owner,
        vendor,
        isInHouse,
        licenseModel,
        annualCost,
        monthlyActiveUsers,
        businessCapability,
        technology,
        lifecycleStatus,
        vendorSupportEnding,
        businessValue,
        functionalQuality,
        technicalHealth,
        strategicAlignment,
        decision
    )) {
        respondHtml(
            res,
            HTTPStatus.badRequest,
            renderApplicationForm(
                "Edit Application",
                format("/applications/%s", escapeUrlSegment(id)),
                "Required fields are missing or score values are invalid (use 1-5).",
                formFromInputs(
                    name,
                    owner,
                    vendor,
                    isInHouse,
                    licenseModel,
                    annualCost,
                    monthlyActiveUsers,
                    businessCapability,
                    technology,
                    lifecycleStatus,
                    vendorSupportEnding,
                    businessValue,
                    functionalQuality,
                    technicalHealth,
                    strategicAlignment,
                    decision
                )
            )
        );
        return;
    }

    redirectTo(res, format("/applications/%s", escapeUrlSegment(id)));
}

void deleteApplication(HTTPServerRequest req, HTTPServerResponse res) {
    auto id = req.params["id"].strip;
    portfolioStore.remove(id);
    redirectTo(res, "/");
}

double parseDoubleNonNegative(string value) {
    try {
        auto parsed = value.strip.to!double;
        return parsed >= 0 ? parsed : -1;
    } catch (Exception) {
        return -1;
    }
}

int parseIntNonNegative(string value) {
    try {
        auto parsed = value.strip.to!int;
        return parsed >= 0 ? parsed : -1;
    } catch (Exception) {
        return -1;
    }
}

int parseScore(string value) {
    try {
        auto parsed = value.strip.to!int;
        if (parsed < 1 || parsed > 5) {
            return 3;
        }
        return parsed;
    } catch (Exception) {
        return 3;
    }
}

RationalizationDecision parseDecision(string raw) {
    auto value = raw.strip.toLower();
    switch (value) {
        case "invest": return RationalizationDecision.invest;
        case "migrate": return RationalizationDecision.migrate;
        case "retire": return RationalizationDecision.retire;
        default: return RationalizationDecision.tolerate;
    }
}

string decisionLabel(RationalizationDecision decision) {
    final switch (decision) {
        case RationalizationDecision.invest: return "Invest";
        case RationalizationDecision.tolerate: return "Tolerate";
        case RationalizationDecision.migrate: return "Migrate";
        case RationalizationDecision.retire: return "Retire";
    }
}

string currency(double value) {
    return format("$%,.2f", value);
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

void respondNotFound(HTTPServerResponse res) {
    respondHtml(res, HTTPStatus.notFound, pageLayout("Not Found", "<h1>404 - Application Not Found</h1><a class=\"button\" href=\"/\">Back to dashboard</a>"));
}

string renderDashboard(PortfolioApplication[] applications, PortfolioStats stats) {
    string rows;

    if (applications.empty) {
        rows = "<tr><td colspan=\"9\">No applications in portfolio yet.</td></tr>";
    } else {
        foreach (app; applications) {
            rows ~= format(
                "<tr>"
                ~ "<td><a href=\"/applications/%s\">%s</a></td>"
                ~ "<td>%s</td>"
                ~ "<td>%s</td>"
                ~ "<td>%s</td>"
                ~ "<td>%s</td>"
                ~ "<td>%s</td>"
                ~ "<td>%s</td>"
                ~ "<td>%s</td>"
                ~ "<td><a class=\"button\" href=\"/applications/%s/edit\">Edit</a></td>"
                ~ "</tr>",
                escapeUrlSegment(app.id),
                escapeHtml(app.name),
                escapeHtml(app.owner),
                app.isInHouse ? "In-house" : "Third-party",
                currency(app.annualCost),
                escapeHtml(app.businessCapability),
                format("%s/%s/%s", app.businessValue, app.functionalQuality, app.technicalHealth),
                decisionLabel(app.rationalizationDecision),
                app.vendorSupportEnding ? "High" : (app.technicalHealth <= 2 ? "High" : "Normal"),
                escapeUrlSegment(app.id)
            );
        }
    }

    auto body = format(
        "<div class=\"topbar\">"
        ~ "<div><h1>Application Portfolio Manager</h1><p class=\"muted\">Single source of truth for inventory, metrics, rationalization, and strategic alignment.</p></div>"
        ~ "<a class=\"button primary\" href=\"/applications/new\">Add Application</a>"
        ~ "</div>"
        ~ "<section class=\"cards\">"
        ~ "<article><h3>Total Applications</h3><p>%s</p></article>"
        ~ "<article><h3>Total Annual Cost</h3><p>%s</p></article>"
        ~ "<article><h3>High Risk Apps</h3><p>%s</p></article>"
        ~ "<article><h3>Capability Overlaps</h3><p>%s</p></article>"
        ~ "</section>"
        ~ "<section class=\"cards\">"
        ~ "<article><h3>Average Scores (B/F/T/A)</h3><p>%.2f / %.2f / %.2f / %.2f</p></article>"
        ~ "<article><h3>Rationalization Mix</h3><p>Invest: %s · Tolerate: %s · Migrate: %s · Retire: %s</p></article>"
        ~ "</section>"
        ~ "<h2>Portfolio Inventory</h2>"
        ~ "<table>"
        ~ "<thead><tr><th>Name</th><th>Owner</th><th>Type</th><th>Cost</th><th>Capability</th><th>Scores</th><th>Decision</th><th>Risk</th><th>Action</th></tr></thead>"
        ~ "<tbody>%s</tbody>"
        ~ "</table>",
        stats.totalApplications,
        currency(stats.totalAnnualCost),
        stats.highRiskCount,
        stats.redundantCapabilityCount,
        stats.averageBusinessValue,
        stats.averageFunctionalQuality,
        stats.averageTechnicalHealth,
        stats.averageStrategicAlignment,
        stats.investCount,
        stats.tolerateCount,
        stats.migrateCount,
        stats.retireCount,
        rows
    );

    return pageLayout("Application Portfolio", body);
}

string renderApplicationDetails(PortfolioApplication app) {
    auto riskLabel = app.vendorSupportEnding || app.technicalHealth <= 2 ? "High" : "Normal";

    auto body = format(
        "<div class=\"topbar\">"
        ~ "<div><h1>%s</h1><p class=\"muted\">%s · %s</p></div>"
        ~ "<div class=\"actions\"><a class=\"button\" href=\"/\">Dashboard</a><a class=\"button primary\" href=\"/applications/%s/edit\">Edit</a></div>"
        ~ "</div>"
        ~ "<section class=\"detail-grid\">"
        ~ "<article><h3>Inventory</h3><p><strong>ID:</strong> %s</p><p><strong>Owner:</strong> %s</p><p><strong>Vendor:</strong> %s</p><p><strong>License:</strong> %s</p><p><strong>Users (MAU):</strong> %s</p><p><strong>Annual Cost:</strong> %s</p></article>"
        ~ "<article><h3>Assessment</h3><p><strong>Business Value:</strong> %s/5</p><p><strong>Functional Quality:</strong> %s/5</p><p><strong>Technical Health:</strong> %s/5</p><p><strong>Strategic Alignment:</strong> %s/5</p></article>"
        ~ "<article><h3>Rationalization</h3><p><strong>Decision:</strong> %s</p><p><strong>Lifecycle:</strong> %s</p><p><strong>Vendor Support Ending:</strong> %s</p><p><strong>Risk Level:</strong> %s</p></article>"
        ~ "<article><h3>Strategic Context</h3><p><strong>Business Capability:</strong> %s</p><p><strong>Technology:</strong> %s</p><p><strong>Created:</strong> %s</p><p><strong>Updated:</strong> %s</p></article>"
        ~ "</section>"
        ~ "<form method=\"post\" action=\"/applications/%s/delete\" onsubmit=\"return confirm('Delete this application?');\">"
        ~ "<button type=\"submit\">Delete Application</button>"
        ~ "</form>",
        escapeHtml(app.name),
        app.isInHouse ? "In-house" : "Third-party",
        escapeHtml(app.businessCapability),
        escapeUrlSegment(app.id),
        escapeHtml(app.id),
        escapeHtml(app.owner),
        escapeHtml(app.vendor),
        escapeHtml(app.licenseModel),
        app.monthlyActiveUsers,
        currency(app.annualCost),
        app.businessValue,
        app.functionalQuality,
        app.technicalHealth,
        app.strategicAlignment,
        decisionLabel(app.rationalizationDecision),
        escapeHtml(app.lifecycleStatus),
        app.vendorSupportEnding ? "Yes" : "No",
        riskLabel,
        escapeHtml(app.businessCapability),
        escapeHtml(app.technology),
        app.createdAt.toISOExtString(),
        app.updatedAt.toISOExtString(),
        escapeUrlSegment(app.id)
    );

    return pageLayout(app.name, body);
}

FormFields formFromApplication(PortfolioApplication app) {
    FormFields fields;
    fields["name"] = app.name;
    fields["owner"] = app.owner;
    fields["vendor"] = app.vendor;
    fields["isInHouse"] = app.isInHouse ? "on" : "";
    fields["licenseModel"] = app.licenseModel;
    fields["annualCost"] = format("%.2f", app.annualCost);
    fields["monthlyActiveUsers"] = app.monthlyActiveUsers.to!string;
    fields["businessCapability"] = app.businessCapability;
    fields["technology"] = app.technology;
    fields["lifecycleStatus"] = app.lifecycleStatus;
    fields["vendorSupportEnding"] = app.vendorSupportEnding ? "on" : "";
    fields["businessValue"] = app.businessValue.to!string;
    fields["functionalQuality"] = app.functionalQuality.to!string;
    fields["technicalHealth"] = app.technicalHealth.to!string;
    fields["strategicAlignment"] = app.strategicAlignment.to!string;
    fields["rationalizationDecision"] = toLower(decisionLabel(app.rationalizationDecision));
    return fields;
}

alias FormFields = string[string];

FormFields formFromInputs(
    string name,
    string owner,
    string vendor,
    bool isInHouse,
    string licenseModel,
    double annualCost,
    int monthlyActiveUsers,
    string businessCapability,
    string technology,
    string lifecycleStatus,
    bool vendorSupportEnding,
    int businessValue,
    int functionalQuality,
    int technicalHealth,
    int strategicAlignment,
    RationalizationDecision decision
) {
    FormFields fields;
    fields["name"] = name;
    fields["owner"] = owner;
    fields["vendor"] = vendor;
    fields["isInHouse"] = isInHouse ? "on" : "";
    fields["licenseModel"] = licenseModel;
    fields["annualCost"] = annualCost >= 0 ? format("%.2f", annualCost) : "0";
    fields["monthlyActiveUsers"] = monthlyActiveUsers >= 0 ? monthlyActiveUsers.to!string : "0";
    fields["businessCapability"] = businessCapability;
    fields["technology"] = technology;
    fields["lifecycleStatus"] = lifecycleStatus;
    fields["vendorSupportEnding"] = vendorSupportEnding ? "on" : "";
    fields["businessValue"] = businessValue.to!string;
    fields["functionalQuality"] = functionalQuality.to!string;
    fields["technicalHealth"] = technicalHealth.to!string;
    fields["strategicAlignment"] = strategicAlignment.to!string;
    fields["rationalizationDecision"] = toLower(decisionLabel(decision));
    return fields;
}

string renderApplicationForm(string title, string actionPath, string error = "", FormFields fields = null) {
    auto name = getField(fields, "name");
    auto owner = getField(fields, "owner");
    auto vendor = getField(fields, "vendor");
    auto isInHouse = getField(fields, "isInHouse") == "on";
    auto licenseModel = getField(fields, "licenseModel");
    auto annualCost = getField(fields, "annualCost", "0");
    auto monthlyActiveUsers = getField(fields, "monthlyActiveUsers", "0");
    auto businessCapability = getField(fields, "businessCapability");
    auto technology = getField(fields, "technology");
    auto lifecycleStatus = getField(fields, "lifecycleStatus");
    auto vendorSupportEnding = getField(fields, "vendorSupportEnding") == "on";

    auto businessValue = getField(fields, "businessValue", "3");
    auto functionalQuality = getField(fields, "functionalQuality", "3");
    auto technicalHealth = getField(fields, "technicalHealth", "3");
    auto strategicAlignment = getField(fields, "strategicAlignment", "3");
    auto decision = getField(fields, "rationalizationDecision", "tolerate");

    string errorHtml;
    if (!error.empty) {
        errorHtml = format("<p class=\"error\">%s</p>", escapeHtml(error));
    }

    auto body = format(
        "<div class=\"topbar\"><h1>%s</h1><a class=\"button\" href=\"/\">Back to Dashboard</a></div>"
        ~ "%s"
        ~ "<form class=\"form-grid\" method=\"post\" action=\"%s\">"
        ~ "<label>Application Name<input required type=\"text\" name=\"name\" value=\"%s\"></label>"
        ~ "<label>Owner<input required type=\"text\" name=\"owner\" value=\"%s\"></label>"
        ~ "<label>Vendor<input type=\"text\" name=\"vendor\" value=\"%s\"></label>"
        ~ "<label><input type=\"checkbox\" name=\"isInHouse\" %s> In-house Application</label>"
        ~ "<label>License Model<input type=\"text\" name=\"licenseModel\" value=\"%s\" placeholder=\"Subscription, perpetual, open-source\"></label>"
        ~ "<label>Annual Cost<input type=\"number\" min=\"0\" step=\"0.01\" name=\"annualCost\" value=\"%s\"></label>"
        ~ "<label>Monthly Active Users<input type=\"number\" min=\"0\" step=\"1\" name=\"monthlyActiveUsers\" value=\"%s\"></label>"
        ~ "<label>Business Capability<input required type=\"text\" name=\"businessCapability\" value=\"%s\" placeholder=\"Finance, Sales Ops, HR\"></label>"
        ~ "<label>Technology<input type=\"text\" name=\"technology\" value=\"%s\" placeholder=\"Java, D, .NET, SaaS\"></label>"
        ~ "<label>Lifecycle Status<input type=\"text\" name=\"lifecycleStatus\" value=\"%s\" placeholder=\"Production, pilot, sunset\"></label>"
        ~ "<label><input type=\"checkbox\" name=\"vendorSupportEnding\" %s> Vendor support ending / obsolete technology risk</label>"
        ~ "<fieldset><legend>Assessment Scores (1-5)</legend>"
        ~ "<label>Business Value<input type=\"number\" min=\"1\" max=\"5\" name=\"businessValue\" value=\"%s\"></label>"
        ~ "<label>Functional Quality<input type=\"number\" min=\"1\" max=\"5\" name=\"functionalQuality\" value=\"%s\"></label>"
        ~ "<label>Technical Health<input type=\"number\" min=\"1\" max=\"5\" name=\"technicalHealth\" value=\"%s\"></label>"
        ~ "<label>Strategic Alignment<input type=\"number\" min=\"1\" max=\"5\" name=\"strategicAlignment\" value=\"%s\"></label>"
        ~ "</fieldset>"
        ~ "<label>Rationalization Decision"
        ~ "<select name=\"rationalizationDecision\">"
        ~ "<option value=\"invest\" %s>Invest</option>"
        ~ "<option value=\"tolerate\" %s>Tolerate</option>"
        ~ "<option value=\"migrate\" %s>Migrate</option>"
        ~ "<option value=\"retire\" %s>Retire</option>"
        ~ "</select></label>"
        ~ "<div class=\"actions\"><button class=\"primary\" type=\"submit\">Save</button><a class=\"button\" href=\"/\">Cancel</a></div>"
        ~ "</form>",
        escapeHtml(title),
        errorHtml,
        escapeHtml(actionPath),
        escapeHtml(name),
        escapeHtml(owner),
        escapeHtml(vendor),
        isInHouse ? "checked" : "",
        escapeHtml(licenseModel),
        escapeHtml(annualCost),
        escapeHtml(monthlyActiveUsers),
        escapeHtml(businessCapability),
        escapeHtml(technology),
        escapeHtml(lifecycleStatus),
        vendorSupportEnding ? "checked" : "",
        escapeHtml(businessValue),
        escapeHtml(functionalQuality),
        escapeHtml(technicalHealth),
        escapeHtml(strategicAlignment),
        decision == "invest" ? "selected" : "",
        decision == "tolerate" ? "selected" : "",
        decision == "migrate" ? "selected" : "",
        decision == "retire" ? "selected" : ""
    );

    return pageLayout(title, body);
}

string getField(FormFields fields, string key, string fallback = "") {
    if (fields is null) {
        return fallback;
    }

    auto ptr = key in fields;
    if (ptr is null) {
        return fallback;
    }

    return *ptr;
}

string pageLayout(string title, string body) {
    auto layoutTemplate = "<!DOCTYPE html>\n"
        ~ "<html lang=\"en\">\n"
        ~ "<head>\n"
        ~ "  <meta charset=\"utf-8\">\n"
        ~ "  <meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">\n"
        ~ "  <title>%s</title>\n"
        ~ "  <style>\n"
        ~ "    body { font-family: system-ui, sans-serif; max-width: 1200px; margin: 2rem auto; padding: 0 1rem; color: #1a1a1a; }\n"
        ~ "    h1, h2, h3 { margin-bottom: 0.4rem; }\n"
        ~ "    .muted { color: #5c6166; }\n"
        ~ "    .topbar { display: flex; justify-content: space-between; align-items: flex-start; gap: 1rem; margin-bottom: 1rem; }\n"
        ~ "    .cards { display: grid; grid-template-columns: repeat(auto-fit, minmax(220px, 1fr)); gap: 0.75rem; margin: 0.75rem 0 1rem; }\n"
        ~ "    article { border: 1px solid #d8d8d8; border-radius: 0.4rem; padding: 0.75rem; background: #fcfcfc; }\n"
        ~ "    table { width: 100%; border-collapse: collapse; margin-top: 0.6rem; }\n"
        ~ "    th, td { border: 1px solid #ddd; text-align: left; padding: 0.55rem; vertical-align: top; }\n"
        ~ "    th { background: #f5f5f5; }\n"
        ~ "    .detail-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(250px, 1fr)); gap: 0.75rem; margin-bottom: 1rem; }\n"
        ~ "    .form-grid { display: grid; gap: 0.75rem; max-width: 760px; }\n"
        ~ "    fieldset { border: 1px solid #d9d9d9; border-radius: 0.3rem; padding: 0.65rem; display: grid; gap: 0.6rem; }\n"
        ~ "    label { display: grid; gap: 0.35rem; }\n"
        ~ "    input[type=text], input[type=number], select { font: inherit; padding: 0.5rem; border: 1px solid #c8c8c8; border-radius: 0.3rem; }\n"
        ~ "    a.button, button { display: inline-block; font: inherit; border: 1px solid #8f8f8f; background: #f2f2f2; color: inherit; text-decoration: none; padding: 0.45rem 0.7rem; border-radius: 0.3rem; cursor: pointer; }\n"
        ~ "    a.button.primary, button.primary { background: #e8eefc; border-color: #98acd9; }\n"
        ~ "    .actions { display: flex; gap: 0.55rem; align-items: center; }\n"
        ~ "    .error { color: #9f1b1b; margin: 0.2rem 0; }\n"
        ~ "  </style>\n"
        ~ "</head>\n"
        ~ "<body>%s</body>\n"
        ~ "</html>\n";

    return format(layoutTemplate, escapeHtml(title), body);
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

string escapeUrlSegment(string value) {
    return value;
}

void seedData() {
    portfolioStore.create(
        "ERP Core",
        "Finance IT",
        "Contoso Systems",
        false,
        "Subscription",
        320_000,
        1800,
        "Financial Management",
        "Java + Oracle",
        "Production",
        false,
        5,
        4,
        3,
        5,
        RationalizationDecision.invest
    );

    portfolioStore.create(
        "Legacy CRM",
        "Sales Ops",
        "OldVendor Inc.",
        false,
        "Perpetual + Support",
        210_000,
        650,
        "Customer Relationship",
        "On-prem .NET",
        "Sunset Candidate",
        true,
        3,
        2,
        1,
        2,
        RationalizationDecision.retire
    );

    portfolioStore.create(
        "HR Self-Service Portal",
        "HR Technology",
        "Internal",
        true,
        "Internal Build",
        95_000,
        2400,
        "Workforce Administration",
        "D + vibe.d",
        "Production",
        false,
        4,
        4,
        4,
        4,
        RationalizationDecision.tolerate
    );

    portfolioStore.create(
        "Marketing Automation Suite",
        "Marketing IT",
        "SkyReach",
        false,
        "Subscription",
        150_000,
        310,
        "Campaign Management",
        "SaaS",
        "Production",
        false,
        4,
        4,
        4,
        4,
        RationalizationDecision.migrate
    );
}
