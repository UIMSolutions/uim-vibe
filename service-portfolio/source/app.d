module app;

import std.conv : to;
import std.datetime : Clock, SysTime;
import std.format : format;
import std.process : environment;
import std.string : strip, toLower;

import vibe.vibe;

enum ServiceStage {
    pipeline,
    catalog,
    retired
}

enum StrategyDecision {
    invest,
    optimize,
    consolidate,
    retire
}

struct ServiceEntry {
    string id;
    string name;
    string serviceOwner;
    string businessSponsor;
    string serviceDomain;

    ServiceStage lifecycleStage;
    bool customerVisible;

    double annualCost;
    double annualValueEstimate;

    int strategicAlignment;
    int valueScore;
    int riskScore;

    StrategyDecision strategyDecision;

    string sdpOwner;
    string sdpSummary;
    string sdpLastReview;

    SysTime createdAt;
    SysTime updatedAt;
}

struct PortfolioSummary {
    size_t totalServices;
    size_t pipelineCount;
    size_t catalogCount;
    size_t retiredCount;

    double totalAnnualCost;
    double totalAnnualValue;

    double averageAlignment;
    double averageValueScore;
    double averageRiskScore;

    size_t highRiskCount;
    size_t redundantDomainCount;

    size_t investCount;
    size_t optimizeCount;
    size_t consolidateCount;
    size_t retireCount;
}

alias FormFields = string[string];

final class ServicePortfolioStore {
    private ServiceEntry[] entries;
    private int sequence = 300;

    ServiceEntry[] all() {
        return entries.dup;
    }

    ServiceEntry* find(string id) {
        foreach (ref entry; entries) {
            if (entry.id == id) {
                return &entry;
            }
        }

        return null;
    }

    bool create(
        string name,
        string serviceOwner,
        string businessSponsor,
        string serviceDomain,
        ServiceStage lifecycleStage,
        bool customerVisible,
        double annualCost,
        double annualValueEstimate,
        int strategicAlignment,
        int valueScore,
        int riskScore,
        StrategyDecision strategyDecision,
        string sdpOwner,
        string sdpSummary,
        string sdpLastReview
    ) {
        auto cleanedName = name.strip;
        auto cleanedOwner = serviceOwner.strip;
        auto cleanedDomain = serviceDomain.strip;

        if (cleanedName.empty || cleanedOwner.empty || cleanedDomain.empty) {
            return false;
        }

        if (annualCost < 0 || annualValueEstimate < 0) {
            return false;
        }

        if (!isValidScore(strategicAlignment) || !isValidScore(valueScore) || !isValidScore(riskScore)) {
            return false;
        }

        sequence += 1;
        auto now = Clock.currTime();
        entries ~= ServiceEntry(
            format("SVC-%s", sequence.to!string),
            cleanedName,
            cleanedOwner,
            businessSponsor.strip,
            cleanedDomain,
            lifecycleStage,
            customerVisible,
            annualCost,
            annualValueEstimate,
            strategicAlignment,
            valueScore,
            riskScore,
            strategyDecision,
            sdpOwner.strip,
            sdpSummary.strip,
            sdpLastReview.strip,
            now,
            now
        );

        return true;
    }

    bool update(
        string id,
        string name,
        string serviceOwner,
        string businessSponsor,
        string serviceDomain,
        ServiceStage lifecycleStage,
        bool customerVisible,
        double annualCost,
        double annualValueEstimate,
        int strategicAlignment,
        int valueScore,
        int riskScore,
        StrategyDecision strategyDecision,
        string sdpOwner,
        string sdpSummary,
        string sdpLastReview
    ) {
        auto entry = find(id);
        if (entry is null) {
            return false;
        }

        auto cleanedName = name.strip;
        auto cleanedOwner = serviceOwner.strip;
        auto cleanedDomain = serviceDomain.strip;

        if (cleanedName.empty || cleanedOwner.empty || cleanedDomain.empty) {
            return false;
        }

        if (annualCost < 0 || annualValueEstimate < 0) {
            return false;
        }

        if (!isValidScore(strategicAlignment) || !isValidScore(valueScore) || !isValidScore(riskScore)) {
            return false;
        }

        entry.name = cleanedName;
        entry.serviceOwner = cleanedOwner;
        entry.businessSponsor = businessSponsor.strip;
        entry.serviceDomain = cleanedDomain;
        entry.lifecycleStage = lifecycleStage;
        entry.customerVisible = customerVisible;
        entry.annualCost = annualCost;
        entry.annualValueEstimate = annualValueEstimate;
        entry.strategicAlignment = strategicAlignment;
        entry.valueScore = valueScore;
        entry.riskScore = riskScore;
        entry.strategyDecision = strategyDecision;
        entry.sdpOwner = sdpOwner.strip;
        entry.sdpSummary = sdpSummary.strip;
        entry.sdpLastReview = sdpLastReview.strip;
        entry.updatedAt = Clock.currTime();

        return true;
    }

    bool remove(string id) {
        foreach (index, entry; entries) {
            if (entry.id == id) {
                entries = entries[0 .. index] ~ entries[index + 1 .. $];
                return true;
            }
        }

        return false;
    }

    PortfolioSummary summary() {
        PortfolioSummary result;
        result.totalServices = entries.length;

        if (entries.empty) {
            return result;
        }

        double alignmentSum;
        double valueSum;
        double riskSum;

        foreach (entry; entries) {
            result.totalAnnualCost += entry.annualCost;
            result.totalAnnualValue += entry.annualValueEstimate;

            alignmentSum += entry.strategicAlignment;
            valueSum += entry.valueScore;
            riskSum += entry.riskScore;

            final switch (entry.lifecycleStage) {
                case ServiceStage.pipeline: result.pipelineCount += 1; break;
                case ServiceStage.catalog: result.catalogCount += 1; break;
                case ServiceStage.retired: result.retiredCount += 1; break;
            }

            final switch (entry.strategyDecision) {
                case StrategyDecision.invest: result.investCount += 1; break;
                case StrategyDecision.optimize: result.optimizeCount += 1; break;
                case StrategyDecision.consolidate: result.consolidateCount += 1; break;
                case StrategyDecision.retire: result.retireCount += 1; break;
            }

            if (entry.riskScore >= 4) {
                result.highRiskCount += 1;
            }
        }

        result.averageAlignment = alignmentSum / entries.length;
        result.averageValueScore = valueSum / entries.length;
        result.averageRiskScore = riskSum / entries.length;
        result.redundantDomainCount = countRedundantDomains();

        return result;
    }

    size_t countRedundantDomains() {
        size_t count;

        foreach (candidate; entries) {
            if (candidate.lifecycleStage == ServiceStage.retired) {
                continue;
            }

            size_t overlaps;
            foreach (other; entries) {
                if (candidate.id != other.id
                    && other.lifecycleStage != ServiceStage.retired
                    && toLower(candidate.serviceDomain) == toLower(other.serviceDomain)) {
                    overlaps += 1;
                }
            }

            if (overlaps > 0) {
                count += 1;
            }
        }

        return count;
    }

    private bool isValidScore(int value) {
        return value >= 1 && value <= 5;
    }
}

__gshared ServicePortfolioStore serviceStore;

void main() {
    serviceStore = new ServicePortfolioStore;
    seedData();

    auto settings = new HTTPServerSettings;
    settings.port = readEnvPort("PORT", 8080);
    settings.bindAddresses = [readEnvString("BIND_ADDRESS", "127.0.0.1")];

    auto router = new URLRouter;
    router.get("/", &showDashboard);
    router.get("/healthz", &health);

    router.get("/services/new", &showCreate);
    router.post("/services", &createService);

    router.get("/services/:id", &showDetails);
    router.get("/services/:id/edit", &showEdit);
    router.post("/services/:id", &updateService);
    router.post("/services/:id/delete", &deleteService);

    listenHTTP(settings, router);
    runApplication();
}

void showDashboard(HTTPServerRequest req, HTTPServerResponse res) {
    respondHtml(res, HTTPStatus.ok, renderDashboard(serviceStore.all(), serviceStore.summary()));
}

void health(HTTPServerRequest req, HTTPServerResponse res) {
    res.contentType = "application/json; charset=utf-8";
    res.statusCode = HTTPStatus.ok;
    res.writeBody("{\"status\":\"ok\"}");
}

void showCreate(HTTPServerRequest req, HTTPServerResponse res) {
    respondHtml(res, HTTPStatus.ok, renderServiceForm("Create Service", "/services"));
}

void createService(HTTPServerRequest req, HTTPServerResponse res) {
    auto form = req.form;
    auto parsed = parseInput(form);

    if (!parsed.validNumbers) {
        respondHtml(
            res,
            HTTPStatus.badRequest,
            renderServiceForm("Create Service", "/services", "Cost, value estimate, and scores must be valid non-negative numbers (scores 1-5).", parsed.fields)
        );
        return;
    }

    if (!serviceStore.create(
        parsed.name,
        parsed.serviceOwner,
        parsed.businessSponsor,
        parsed.serviceDomain,
        parsed.lifecycleStage,
        parsed.customerVisible,
        parsed.annualCost,
        parsed.annualValueEstimate,
        parsed.strategicAlignment,
        parsed.valueScore,
        parsed.riskScore,
        parsed.strategyDecision,
        parsed.sdpOwner,
        parsed.sdpSummary,
        parsed.sdpLastReview
    )) {
        respondHtml(
            res,
            HTTPStatus.badRequest,
            renderServiceForm("Create Service", "/services", "Required fields are missing or score values are outside 1-5.", parsed.fields)
        );
        return;
    }

    redirectTo(res, "/");
}

void showDetails(HTTPServerRequest req, HTTPServerResponse res) {
    auto id = req.params["id"].strip;
    auto entry = serviceStore.find(id);
    if (entry is null) {
        respondNotFound(res);
        return;
    }

    respondHtml(res, HTTPStatus.ok, renderDetails(*entry));
}

void showEdit(HTTPServerRequest req, HTTPServerResponse res) {
    auto id = req.params["id"].strip;
    auto entry = serviceStore.find(id);
    if (entry is null) {
        respondNotFound(res);
        return;
    }

    respondHtml(
        res,
        HTTPStatus.ok,
        renderServiceForm("Edit Service", format("/services/%s", escapeUrlSegment(id)), "", formFromEntry(*entry))
    );
}

void updateService(HTTPServerRequest req, HTTPServerResponse res) {
    auto id = req.params["id"].strip;
    auto existing = serviceStore.find(id);
    if (existing is null) {
        respondNotFound(res);
        return;
    }

    auto form = req.form;
    auto parsed = parseInput(form);

    if (!parsed.validNumbers) {
        respondHtml(
            res,
            HTTPStatus.badRequest,
            renderServiceForm(
                "Edit Service",
                format("/services/%s", escapeUrlSegment(id)),
                "Cost, value estimate, and scores must be valid non-negative numbers (scores 1-5).",
                parsed.fields
            )
        );
        return;
    }

    if (!serviceStore.update(
        id,
        parsed.name,
        parsed.serviceOwner,
        parsed.businessSponsor,
        parsed.serviceDomain,
        parsed.lifecycleStage,
        parsed.customerVisible,
        parsed.annualCost,
        parsed.annualValueEstimate,
        parsed.strategicAlignment,
        parsed.valueScore,
        parsed.riskScore,
        parsed.strategyDecision,
        parsed.sdpOwner,
        parsed.sdpSummary,
        parsed.sdpLastReview
    )) {
        respondHtml(
            res,
            HTTPStatus.badRequest,
            renderServiceForm(
                "Edit Service",
                format("/services/%s", escapeUrlSegment(id)),
                "Required fields are missing or score values are outside 1-5.",
                parsed.fields
            )
        );
        return;
    }

    redirectTo(res, format("/services/%s", escapeUrlSegment(id)));
}

void deleteService(HTTPServerRequest req, HTTPServerResponse res) {
    auto id = req.params["id"].strip;
    serviceStore.remove(id);
    redirectTo(res, "/");
}

struct ParsedInput {
    bool validNumbers;
    string name;
    string serviceOwner;
    string businessSponsor;
    string serviceDomain;
    ServiceStage lifecycleStage;
    bool customerVisible;
    double annualCost;
    double annualValueEstimate;
    int strategicAlignment;
    int valueScore;
    int riskScore;
    StrategyDecision strategyDecision;
    string sdpOwner;
    string sdpSummary;
    string sdpLastReview;
    FormFields fields;
}

ParsedInput parseInput(T)(T form) {
    ParsedInput result;

    result.name = form.get("name", "").strip;
    result.serviceOwner = form.get("serviceOwner", "").strip;
    result.businessSponsor = form.get("businessSponsor", "").strip;
    result.serviceDomain = form.get("serviceDomain", "").strip;
    result.lifecycleStage = parseStage(form.get("lifecycleStage", "pipeline"));
    result.customerVisible = form.get("customerVisible", "") == "on";

    auto costParsed = parseDoubleNonNegative(form.get("annualCost", "0"));
    auto valueParsed = parseDoubleNonNegative(form.get("annualValueEstimate", "0"));
    auto alignmentParsed = parseScore(form.get("strategicAlignment", "3"));
    auto valueScoreParsed = parseScore(form.get("valueScore", "3"));
    auto riskParsed = parseScore(form.get("riskScore", "3"));

    result.validNumbers = costParsed.valid
        && valueParsed.valid
        && alignmentParsed.valid
        && valueScoreParsed.valid
        && riskParsed.valid;

    result.annualCost = costParsed.value;
    result.annualValueEstimate = valueParsed.value;
    result.strategicAlignment = alignmentParsed.value;
    result.valueScore = valueScoreParsed.value;
    result.riskScore = riskParsed.value;

    result.strategyDecision = parseDecision(form.get("strategyDecision", "optimize"));
    result.sdpOwner = form.get("sdpOwner", "").strip;
    result.sdpSummary = form.get("sdpSummary", "").strip;
    result.sdpLastReview = form.get("sdpLastReview", "").strip;

    result.fields = formFromValues(
        result.name,
        result.serviceOwner,
        result.businessSponsor,
        result.serviceDomain,
        result.lifecycleStage,
        result.customerVisible,
        result.annualCost,
        result.annualValueEstimate,
        result.strategicAlignment,
        result.valueScore,
        result.riskScore,
        result.strategyDecision,
        result.sdpOwner,
        result.sdpSummary,
        result.sdpLastReview
    );

    return result;
}

struct ParseDoubleResult {
    bool valid;
    double value;
}

struct ParseIntResult {
    bool valid;
    int value;
}

ParseDoubleResult parseDoubleNonNegative(string raw) {
    ParseDoubleResult result;

    try {
        auto parsed = raw.strip.to!double;
        if (parsed < 0) {
            return result;
        }

        result.valid = true;
        result.value = parsed;
        return result;
    } catch (Exception) {
        return result;
    }
}

ParseIntResult parseScore(string raw) {
    ParseIntResult result;

    try {
        auto parsed = raw.strip.to!int;
        if (parsed < 1 || parsed > 5) {
            return result;
        }

        result.valid = true;
        result.value = parsed;
        return result;
    } catch (Exception) {
        return result;
    }
}

ServiceStage parseStage(string raw) {
    switch (raw.strip.toLower()) {
        case "catalog": return ServiceStage.catalog;
        case "retired": return ServiceStage.retired;
        default: return ServiceStage.pipeline;
    }
}

StrategyDecision parseDecision(string raw) {
    switch (raw.strip.toLower()) {
        case "invest": return StrategyDecision.invest;
        case "consolidate": return StrategyDecision.consolidate;
        case "retire": return StrategyDecision.retire;
        default: return StrategyDecision.optimize;
    }
}

string stageLabel(ServiceStage stage) {
    final switch (stage) {
        case ServiceStage.pipeline: return "Pipeline";
        case ServiceStage.catalog: return "Catalog";
        case ServiceStage.retired: return "Retired";
    }
}

string decisionLabel(StrategyDecision decision) {
    final switch (decision) {
        case StrategyDecision.invest: return "Invest";
        case StrategyDecision.optimize: return "Optimize";
        case StrategyDecision.consolidate: return "Consolidate";
        case StrategyDecision.retire: return "Retire";
    }
}

string currency(double value) {
    return "$" ~ format("%.2f", value);
}

FormFields formFromEntry(ServiceEntry entry) {
    return formFromValues(
        entry.name,
        entry.serviceOwner,
        entry.businessSponsor,
        entry.serviceDomain,
        entry.lifecycleStage,
        entry.customerVisible,
        entry.annualCost,
        entry.annualValueEstimate,
        entry.strategicAlignment,
        entry.valueScore,
        entry.riskScore,
        entry.strategyDecision,
        entry.sdpOwner,
        entry.sdpSummary,
        entry.sdpLastReview
    );
}

FormFields formFromValues(
    string name,
    string serviceOwner,
    string businessSponsor,
    string serviceDomain,
    ServiceStage lifecycleStage,
    bool customerVisible,
    double annualCost,
    double annualValueEstimate,
    int strategicAlignment,
    int valueScore,
    int riskScore,
    StrategyDecision strategyDecision,
    string sdpOwner,
    string sdpSummary,
    string sdpLastReview
) {
    FormFields fields;
    fields["name"] = name;
    fields["serviceOwner"] = serviceOwner;
    fields["businessSponsor"] = businessSponsor;
    fields["serviceDomain"] = serviceDomain;
    fields["lifecycleStage"] = toLower(stageLabel(lifecycleStage));
    fields["customerVisible"] = customerVisible ? "on" : "";
    fields["annualCost"] = format("%.2f", annualCost);
    fields["annualValueEstimate"] = format("%.2f", annualValueEstimate);
    fields["strategicAlignment"] = strategicAlignment.to!string;
    fields["valueScore"] = valueScore.to!string;
    fields["riskScore"] = riskScore.to!string;
    fields["strategyDecision"] = toLower(decisionLabel(strategyDecision));
    fields["sdpOwner"] = sdpOwner;
    fields["sdpSummary"] = sdpSummary;
    fields["sdpLastReview"] = sdpLastReview;
    return fields;
}

string field(FormFields fields, string key, string fallback = "") {
    auto ptr = key in fields;
    return ptr is null ? fallback : *ptr;
}

string renderDashboard(ServiceEntry[] entries, PortfolioSummary summary) {
    string tableRows;

    if (entries.empty) {
        tableRows = "<tr><td colspan=\"10\">No services yet.</td></tr>";
    } else {
        foreach (entry; entries) {
            tableRows ~= format(
                "<tr>"
                ~ "<td><a href=\"/services/%s\">%s</a></td>"
                ~ "<td>%s</td>"
                ~ "<td>%s</td>"
                ~ "<td>%s</td>"
                ~ "<td>%s</td>"
                ~ "<td>%s</td>"
                ~ "<td>%s</td>"
                ~ "<td>%s</td>"
                ~ "<td>%s</td>"
                ~ "<td><a class=\"button\" href=\"/services/%s/edit\">Edit</a></td>"
                ~ "</tr>",
                escapeUrlSegment(entry.id),
                escapeHtml(entry.name),
                escapeHtml(entry.serviceOwner),
                stageLabel(entry.lifecycleStage),
                escapeHtml(entry.serviceDomain),
                currency(entry.annualCost),
                currency(entry.annualValueEstimate),
                format("%s/%s/%s", entry.strategicAlignment, entry.valueScore, entry.riskScore),
                decisionLabel(entry.strategyDecision),
                entry.riskScore >= 4 ? "High" : "Normal",
                escapeUrlSegment(entry.id)
            );
        }
    }

    auto body = format(
        "<div class=\"topbar\">"
        ~ "<div><h1>Service Portfolio Manager</h1><p class=\"muted\">Centralized repository for pipeline, catalog, and retired services.</p></div>"
        ~ "<a class=\"button primary\" href=\"/services/new\">Add Service</a>"
        ~ "</div>"
        ~ "<section class=\"cards\">"
        ~ "<article><h3>Total Services</h3><p>%s</p></article>"
        ~ "<article><h3>Pipeline / Catalog / Retired</h3><p>%s / %s / %s</p></article>"
        ~ "<article><h3>Total Cost</h3><p>%s</p></article>"
        ~ "<article><h3>Total Value</h3><p>%s</p></article>"
        ~ "</section>"
        ~ "<section class=\"cards\">"
        ~ "<article><h3>Avg Alignment / Value / Risk</h3><p>%.2f / %.2f / %.2f</p></article>"
        ~ "<article><h3>High Risk Services</h3><p>%s</p></article>"
        ~ "<article><h3>Potential Domain Redundancies</h3><p>%s</p></article>"
        ~ "<article><h3>Strategy Mix</h3><p>Invest: %s · Optimize: %s · Consolidate: %s · Retire: %s</p></article>"
        ~ "</section>"
        ~ "<h2>Service Portfolio</h2>"
        ~ "<table>"
        ~ "<thead><tr><th>Name</th><th>Owner</th><th>Stage</th><th>Domain</th><th>Cost</th><th>Value</th><th>A/V/R</th><th>Decision</th><th>Risk</th><th>Action</th></tr></thead>"
        ~ "<tbody>%s</tbody>"
        ~ "</table>",
        summary.totalServices,
        summary.pipelineCount,
        summary.catalogCount,
        summary.retiredCount,
        currency(summary.totalAnnualCost),
        currency(summary.totalAnnualValue),
        summary.averageAlignment,
        summary.averageValueScore,
        summary.averageRiskScore,
        summary.highRiskCount,
        summary.redundantDomainCount,
        summary.investCount,
        summary.optimizeCount,
        summary.consolidateCount,
        summary.retireCount,
        tableRows
    );

    return pageLayout("Service Portfolio", body);
}

string renderDetails(ServiceEntry entry) {
    auto body = format(
        "<div class=\"topbar\">"
        ~ "<div><h1>%s</h1><p class=\"muted\">%s · %s</p></div>"
        ~ "<div class=\"actions\"><a class=\"button\" href=\"/\">Dashboard</a><a class=\"button primary\" href=\"/services/%s/edit\">Edit</a></div>"
        ~ "</div>"
        ~ "<section class=\"detail-grid\">"
        ~ "<article><h3>Lifecycle</h3><p><strong>Stage:</strong> %s</p><p><strong>Strategy:</strong> %s</p><p><strong>Customer Visible:</strong> %s</p><p><strong>Domain:</strong> %s</p></article>"
        ~ "<article><h3>Strategic and Value</h3><p><strong>Alignment:</strong> %s/5</p><p><strong>Value Score:</strong> %s/5</p><p><strong>Risk Score:</strong> %s/5</p><p><strong>Annual Cost:</strong> %s</p><p><strong>Annual Value:</strong> %s</p></article>"
        ~ "<article><h3>Ownership</h3><p><strong>Service Owner:</strong> %s</p><p><strong>Business Sponsor:</strong> %s</p></article>"
        ~ "<article><h3>Service Design Package (SDP)</h3><p><strong>SDP Owner:</strong> %s</p><p><strong>Last Review:</strong> %s</p><p><strong>Summary:</strong><br>%s</p></article>"
        ~ "</section>"
        ~ "<form method=\"post\" action=\"/services/%s/delete\" onsubmit=\"return confirm('Delete this service?');\">"
        ~ "<button type=\"submit\">Delete Service</button>"
        ~ "</form>",
        escapeHtml(entry.name),
        stageLabel(entry.lifecycleStage),
        escapeHtml(entry.serviceDomain),
        escapeUrlSegment(entry.id),
        stageLabel(entry.lifecycleStage),
        decisionLabel(entry.strategyDecision),
        entry.customerVisible ? "Yes" : "No",
        escapeHtml(entry.serviceDomain),
        entry.strategicAlignment,
        entry.valueScore,
        entry.riskScore,
        currency(entry.annualCost),
        currency(entry.annualValueEstimate),
        escapeHtml(entry.serviceOwner),
        escapeHtml(entry.businessSponsor),
        escapeHtml(entry.sdpOwner),
        escapeHtml(entry.sdpLastReview),
        escapeHtml(entry.sdpSummary),
        escapeUrlSegment(entry.id)
    );

    return pageLayout(entry.name, body);
}

string renderServiceForm(string title, string actionPath, string error = "", FormFields fields = null) {
    string name;
    string serviceOwner;
    string businessSponsor;
    string serviceDomain;
    string lifecycleStage;
    bool customerVisible;
    string annualCost;
    string annualValueEstimate;
    string strategicAlignment;
    string valueScore;
    string riskScore;
    string strategyDecision;
    string sdpOwner;
    string sdpSummary;
    string sdpLastReview;

    if (fields is null) {
        lifecycleStage = "pipeline";
        annualCost = "0";
        annualValueEstimate = "0";
        strategicAlignment = "3";
        valueScore = "3";
        riskScore = "3";
        strategyDecision = "optimize";
    } else {
        name = field(fields, "name");
        serviceOwner = field(fields, "serviceOwner");
        businessSponsor = field(fields, "businessSponsor");
        serviceDomain = field(fields, "serviceDomain");
        lifecycleStage = field(fields, "lifecycleStage", "pipeline");
        customerVisible = field(fields, "customerVisible") == "on";
        annualCost = field(fields, "annualCost", "0");
        annualValueEstimate = field(fields, "annualValueEstimate", "0");
        strategicAlignment = field(fields, "strategicAlignment", "3");
        valueScore = field(fields, "valueScore", "3");
        riskScore = field(fields, "riskScore", "3");
        strategyDecision = field(fields, "strategyDecision", "optimize");
        sdpOwner = field(fields, "sdpOwner");
        sdpSummary = field(fields, "sdpSummary");
        sdpLastReview = field(fields, "sdpLastReview");
    }

    string errorHtml;
    if (!error.empty) {
        errorHtml = format("<p class=\"error\">%s</p>", escapeHtml(error));
    }

    auto body = format(
        "<div class=\"topbar\"><h1>%s</h1><a class=\"button\" href=\"/\">Back to Dashboard</a></div>"
        ~ "%s"
        ~ "<form class=\"form-grid\" method=\"post\" action=\"%s\">"
        ~ "<label>Service Name<input required type=\"text\" name=\"name\" value=\"%s\"></label>"
        ~ "<label>Service Owner<input required type=\"text\" name=\"serviceOwner\" value=\"%s\"></label>"
        ~ "<label>Business Sponsor<input type=\"text\" name=\"businessSponsor\" value=\"%s\"></label>"
        ~ "<label>Service Domain<input required type=\"text\" name=\"serviceDomain\" value=\"%s\" placeholder=\"Identity, Payments, Collaboration\"></label>"
        ~ "<label>Lifecycle Stage"
        ~ "<select name=\"lifecycleStage\">"
        ~ "<option value=\"pipeline\" %s>Pipeline</option>"
        ~ "<option value=\"catalog\" %s>Catalog</option>"
        ~ "<option value=\"retired\" %s>Retired</option>"
        ~ "</select></label>"
        ~ "<label><input type=\"checkbox\" name=\"customerVisible\" %s> Visible in service catalog</label>"
        ~ "<label>Annual Cost<input type=\"number\" min=\"0\" step=\"0.01\" name=\"annualCost\" value=\"%s\"></label>"
        ~ "<label>Annual Value Estimate<input type=\"number\" min=\"0\" step=\"0.01\" name=\"annualValueEstimate\" value=\"%s\"></label>"
        ~ "<fieldset><legend>Strategic and Risk Scores (1-5)</legend>"
        ~ "<label>Strategic Alignment<input type=\"number\" min=\"1\" max=\"5\" name=\"strategicAlignment\" value=\"%s\"></label>"
        ~ "<label>Value Score<input type=\"number\" min=\"1\" max=\"5\" name=\"valueScore\" value=\"%s\"></label>"
        ~ "<label>Risk Score<input type=\"number\" min=\"1\" max=\"5\" name=\"riskScore\" value=\"%s\"></label>"
        ~ "</fieldset>"
        ~ "<label>Strategy Decision"
        ~ "<select name=\"strategyDecision\">"
        ~ "<option value=\"invest\" %s>Invest</option>"
        ~ "<option value=\"optimize\" %s>Optimize</option>"
        ~ "<option value=\"consolidate\" %s>Consolidate</option>"
        ~ "<option value=\"retire\" %s>Retire</option>"
        ~ "</select></label>"
        ~ "<label>SDP Owner<input type=\"text\" name=\"sdpOwner\" value=\"%s\" placeholder=\"Design authority or architect\"></label>"
        ~ "<label>SDP Last Review<input type=\"text\" name=\"sdpLastReview\" value=\"%s\" placeholder=\"2026-02-26\"></label>"
        ~ "<label>SDP Summary<textarea name=\"sdpSummary\" rows=\"6\" placeholder=\"Design package summary, constraints, and dependencies\">%s</textarea></label>"
        ~ "<div class=\"actions\"><button class=\"primary\" type=\"submit\">Save</button><a class=\"button\" href=\"/\">Cancel</a></div>"
        ~ "</form>",
        escapeHtml(title),
        errorHtml,
        escapeHtml(actionPath),
        escapeHtml(name),
        escapeHtml(serviceOwner),
        escapeHtml(businessSponsor),
        escapeHtml(serviceDomain),
        lifecycleStage == "pipeline" ? "selected" : "",
        lifecycleStage == "catalog" ? "selected" : "",
        lifecycleStage == "retired" ? "selected" : "",
        customerVisible ? "checked" : "",
        escapeHtml(annualCost),
        escapeHtml(annualValueEstimate),
        escapeHtml(strategicAlignment),
        escapeHtml(valueScore),
        escapeHtml(riskScore),
        strategyDecision == "invest" ? "selected" : "",
        strategyDecision == "optimize" ? "selected" : "",
        strategyDecision == "consolidate" ? "selected" : "",
        strategyDecision == "retire" ? "selected" : "",
        escapeHtml(sdpOwner),
        escapeHtml(sdpLastReview),
        escapeHtml(sdpSummary)
    );

    return pageLayout(title, body);
}

string pageLayout(string title, string body) {
    return "<!DOCTYPE html>\n"
        ~ "<html lang=\"en\">\n"
        ~ "<head>\n"
        ~ "  <meta charset=\"utf-8\">\n"
        ~ "  <meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">\n"
        ~ "  <title>" ~ escapeHtml(title) ~ "</title>\n"
        ~ "  <style>\n"
        ~ "    body { font-family: system-ui, sans-serif; max-width: 1220px; margin: 2rem auto; padding: 0 1rem; color: #1f1f1f; }\n"
        ~ "    h1, h2, h3 { margin: 0.2rem 0 0.45rem; }\n"
        ~ "    .muted { color: #59616a; }\n"
        ~ "    .topbar { display: flex; justify-content: space-between; align-items: flex-start; gap: 1rem; margin-bottom: 1rem; }\n"
        ~ "    .cards { display: grid; grid-template-columns: repeat(auto-fit, minmax(220px, 1fr)); gap: 0.75rem; margin: 0.75rem 0 1rem; }\n"
        ~ "    article { border: 1px solid #d8d8d8; border-radius: 0.4rem; padding: 0.75rem; background: #fcfcfc; }\n"
        ~ "    table { width: 100%; border-collapse: collapse; margin-top: 0.6rem; }\n"
        ~ "    th, td { border: 1px solid #dddddd; text-align: left; padding: 0.55rem; vertical-align: top; }\n"
        ~ "    th { background: #f4f5f7; }\n"
        ~ "    .detail-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(250px, 1fr)); gap: 0.75rem; margin-bottom: 1rem; }\n"
        ~ "    .form-grid { display: grid; gap: 0.75rem; max-width: 780px; }\n"
        ~ "    fieldset { border: 1px solid #d9d9d9; border-radius: 0.3rem; padding: 0.65rem; display: grid; gap: 0.6rem; }\n"
        ~ "    label { display: grid; gap: 0.35rem; }\n"
        ~ "    input[type=text], input[type=number], select, textarea { font: inherit; padding: 0.5rem; border: 1px solid #c8c8c8; border-radius: 0.3rem; }\n"
        ~ "    a.button, button { display: inline-block; font: inherit; border: 1px solid #8f8f8f; background: #f2f2f2; color: inherit; text-decoration: none; padding: 0.45rem 0.7rem; border-radius: 0.3rem; cursor: pointer; }\n"
        ~ "    a.button.primary, button.primary { background: #e8eefc; border-color: #98acd9; }\n"
        ~ "    .actions { display: flex; gap: 0.55rem; align-items: center; }\n"
        ~ "    .error { color: #9f1b1b; margin: 0.2rem 0; }\n"
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

void respondNotFound(HTTPServerResponse res) {
    respondHtml(res, HTTPStatus.notFound, pageLayout("Not Found", "<h1>404 - Service Not Found</h1><a class=\"button\" href=\"/\">Back to dashboard</a>"));
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

void seedData() {
    serviceStore.create(
        "Unified Identity Gateway",
        "Platform Services",
        "CIO Office",
        "Identity & Access",
        ServiceStage.catalog,
        true,
        180_000,
        520_000,
        5,
        5,
        2,
        StrategyDecision.invest,
        "Architecture Guild",
        "OAuth2 and SSO reference implementation with high-availability topology.",
        "2026-02-15"
    );

    serviceStore.create(
        "AI Ticket Classification",
        "Service Desk Engineering",
        "Operations Director",
        "ITSM Automation",
        ServiceStage.pipeline,
        false,
        70_000,
        190_000,
        4,
        4,
        3,
        StrategyDecision.optimize,
        "Automation CoE",
        "Pilot service for automated incident categorization and routing.",
        "2026-02-22"
    );

    serviceStore.create(
        "Legacy File Transfer Hub",
        "Infrastructure Ops",
        "Head of Infrastructure",
        "Data Exchange",
        ServiceStage.retired,
        false,
        95_000,
        20_000,
        1,
        1,
        5,
        StrategyDecision.retire,
        "Infra Architecture",
        "Service retired after migration to managed secure transfer platform.",
        "2025-12-01"
    );

    serviceStore.create(
        "Collaboration Messaging",
        "Workplace Technology",
        "Digital Workplace Lead",
        "Collaboration",
        ServiceStage.catalog,
        true,
        210_000,
        450_000,
        4,
        4,
        2,
        StrategyDecision.consolidate,
        "Workplace Architecture",
        "Consolidation candidate to reduce overlap with legacy chat tooling.",
        "2026-01-30"
    );
}
