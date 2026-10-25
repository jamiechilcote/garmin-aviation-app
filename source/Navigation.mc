class Navigation {
    var plan; var timers; var check; var s; var undoState;
    function initialize() {
        plan = FlightPlan.legs(); timers = new FlightTimers();
        s = {"schema"=>1, "flight"=>FlightPlan.NAME, "started"=>false, "finished"=>false,
             "startUtc"=>null, "finishUtc"=>null, "index"=>0, "legStart"=>0,
             "radioPending"=>true, "arrivalAlerted"=>false, "legs"=>[], "checks"=>[], "corrections"=>[]};
        check = new Clearoff(plan[0]["nm"], plan[0]["gs"]); undoState = null;
    }
    function leg() { return plan[s["index"]]; }
    function start(utc) {
        if (s["started"]) { return; }
        s["started"] = true; s["startUtc"] = utc; activate(utc);
    }
    function activate(utc) {
        s["legStart"] = timers.s["elapsed"]; s["radioPending"] = true; s["arrivalAlerted"] = false;
        check = new Clearoff(leg()["nm"], leg()["gs"]);
        s["legs"].add({"index"=>s["index"], "startUtc"=>utc, "finishUtc"=>null,
          "plannedArrivalUtc"=>utc + Toybox.Math.ceil(leg()["nm"]*3600.0/leg()["gs"]).toNumber(),
          "heading"=>leg()["heading"], "gs"=>leg()["gs"], "actualSeconds"=>null});
    }
    function legSeconds() { return timers.s["elapsed"] - s["legStart"]; }
    function tick() {
        if (!s["started"] || s["finished"]) { return false; }
        var alert = check.update(timers.s["elapsed"]);
        if (!s["arrivalAlerted"] && legSeconds() >= Toybox.Math.ceil(leg()["nm"]*3600.0/leg()["gs"])) {
            s["arrivalAlerted"] = true; alert = true;
        }
        return alert;
    }
    function checkAction(utc) {
        if (!s["started"] || s["finished"] || check.s["state"].equals("legCompleted")) { return; }
        if (check.s["state"].equals("idle")) { check.start(timers.s["elapsed"], utc); }
        else {
            var record = check.acknowledge(timers.s["elapsed"], utc);
            if (record != null) { record["leg"] = s["index"]; s["checks"].add(record); }
        }
    }
    function advance(utc) {
        if (!s["started"] || s["finished"] || check.s["state"].equals("legCompleted")) { return; }
        // Snapshot references are safe: the old check is no longer mutated after activation.
        undoState = {"index"=>s["index"], "legStart"=>s["legStart"], "check"=>check.s,
                     "arrivalAlerted"=>s["arrivalAlerted"], "radioPending"=>s["radioPending"]};
        var record = s["legs"][s["legs"].size()-1];
        record["finishUtc"] = utc; record["actualSeconds"] = legSeconds();
        if (s["index"] == plan.size()-1) { check.s = copyDictionary(check.s); check.s["state"] = "legCompleted"; }
        else { s["index"] += 1; activate(utc); }
    }
    function undo(utc) {
        if (undoState == null || s["finished"]) { return; }
        if (s["index"] != undoState["index"]) { s["legs"].remove(s["legs"][s["legs"].size()-1]); }
        s["corrections"].add({"utc"=>utc, "restoredLeg"=>undoState["index"]});
        s["index"] = undoState["index"]; s["legStart"] = undoState["legStart"];
        s["arrivalAlerted"] = undoState["arrivalAlerted"]; s["radioPending"] = true;
        check.s = undoState["check"];
        var record = s["legs"][s["legs"].size()-1]; record["finishUtc"] = null; record["actualSeconds"] = null;
        undoState = null; tick();
    }
    function finish(utc) {
        if (!s["started"] || s["finished"]) { return; }
        timers.land(utc);
        var record = s["legs"][s["legs"].size()-1];
        if (record["finishUtc"] == null) { record["finishUtc"] = utc; record["actualSeconds"] = legSeconds(); }
        s["finished"] = true; s["finishUtc"] = utc;
    }
}
function copyDictionary(input) {
    var result = {}; var keys = input.keys();
    for (var i=0; i<keys.size(); i+=1) { result[keys[i]] = input[keys[i]]; }
    return result;
}

