class FlightTimers {
    var s;
    function initialize() {
        s = {"elapsed"=>0, "airStart"=>null, "airTotal"=>0, "periods"=>[]};
    }
    function takeoff(utc) {
        if (s["airStart"] != null) { return; }
        s["airStart"] = s["elapsed"];
        s["periods"].add({"takeoffUtc"=>utc, "landingUtc"=>null, "seconds"=>0});
    }
    function land(utc) {
        if (s["airStart"] == null) { return; }
        var seconds = s["elapsed"] - s["airStart"];
        s["airTotal"] += seconds;
        var period = s["periods"][s["periods"].size()-1];
        period["landingUtc"] = utc; period["seconds"] = seconds;
        s["airStart"] = null;
    }
    function airborne() {
        return s["airTotal"] + (s["airStart"] == null ? 0 : s["elapsed"] - s["airStart"]);
    }
}

