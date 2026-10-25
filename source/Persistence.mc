import Toybox.Application.Storage;
import Toybox.Lang;
class Persistence {
    var error = false; var generation = 0; var prefix = "";
    function initialize() {}
    function snapshot(nav, utc) {
        return {"version"=>1, "generation"=>generation+1, "savedUtc"=>utc,
                "navigation"=>nav.s, "timers"=>nav.timers.s, "clearoff"=>nav.check.s, "undo"=>nav.undoState};
    }
    function save(nav, utc) {
        try {
            var data = snapshot(nav, utc);
            // Alternate slots: retain the last valid checkpoint if a write fails.
            Storage.setValue(prefix + "checkpoint" + ((generation+1)%2), data);
            generation += 1; error = false; return true;
        } catch (e) { error = true; return false; }
    }
    function valid(data) {
        if (!(data instanceof Lang.Dictionary) || !data.hasKey("version") || data["version"] != 1) { return false; }
        if (!data.hasKey("navigation") || !data.hasKey("timers") || !data.hasKey("clearoff") || !data.hasKey("generation") || !data.hasKey("savedUtc") || !data.hasKey("undo")) { return false; }
        var n = data["navigation"]; var t = data["timers"]; var c = data["clearoff"];
        if (!(n instanceof Lang.Dictionary) || !(t instanceof Lang.Dictionary) || !(c instanceof Lang.Dictionary)) { return false; }
        var required = ["started","finished","startUtc","finishUtc","index","legStart","radioPending","arrivalAlerted","legs","checks","corrections"];
        for (var i=0;i<required.size();i+=1) { if (!n.hasKey(required[i])) { return false; } }
        return n["index"] instanceof Lang.Number && n["index"] >= 0 && n["index"] < 4
          && t.hasKey("elapsed") && t.hasKey("airStart") && t.hasKey("airTotal") && t.hasKey("periods")
          && c.hasKey("state") && c.hasKey("remainingNm") && c.hasKey("dueElapsed") && c.hasKey("dueUtc") && c.hasKey("gs")
          && data["generation"] instanceof Lang.Number && data["savedUtc"] instanceof Lang.Number;
    }
    function load() {
        try {
            var a = Storage.getValue(prefix + "checkpoint0"); var b = Storage.getValue(prefix + "checkpoint1");
            var result = valid(a) ? (a as Lang.Dictionary) : null;
            if (valid(b)) {
                var candidate = b as Lang.Dictionary;
                if (result == null || candidate["generation"] > result["generation"]) { result = candidate; }
            }
            if (result != null) { generation = result["generation"]; }
            else if (a != null || b != null) { error = true; }
            return result;
        } catch (e) { error = true; return null; }
    }
    function restore(data, utc) {
        var nav = new Navigation(); nav.s = data["navigation"]; nav.timers.s = data["timers"];
        nav.check.s = data["clearoff"]; nav.undoState = data["undo"];
        // UTC is only a restart fallback; the live timers always use monotonic time.
        var gap = utc - data["savedUtc"]; if (gap < 0) { gap = 0; }
        if (nav.s["started"] && !nav.s["finished"]) {
            nav.timers.s["elapsed"] += gap;
            nav.s["corrections"].add({"utc"=>utc, "interruptionSeconds"=>gap});
            nav.tick();
        }
        return nav;
    }
    function archive(nav, utc) {
        try {
            // Three recent sessions, each separately keyed; never erase current checkpoint on failure.
            var slot = Storage.getValue("historyNext"); if (slot == null) { slot = 0; }
            Storage.setValue("flight" + slot, snapshot(nav,utc));
            Storage.setValue("historyNext", (slot+1)%3); return true;
        } catch (e) { error = true; return false; }
    }
}
