class FlightTimers {
    var s;
    function initialize() { s = {"elapsed"=>0,"airStart"=>null,"airTotal"=>0,"periods"=>[]}; }
    function takeoff(utc) {
        if (s["airStart"] != null) { return; }
        s["airStart"] = s["elapsed"];
        s["periods"].add({"takeoffUtc"=>utc,"landingUtc"=>null,"closedUtc"=>null,"status"=>"airborne","seconds"=>0});
    }
    function closePeriod(utc, confirmed) {
        if (s["airStart"] == null) { return; }
        var seconds = s["elapsed"] - s["airStart"];
        s["airTotal"] += seconds;
        var period = s["periods"][s["periods"].size()-1];
        period["seconds"] = seconds; period["closedUtc"] = utc;
        period["landingUtc"] = confirmed ? utc : null;
        period["status"] = confirmed ? "landed" : "unconfirmed";
        s["airStart"] = null;
    }
    function land(utc) { closePeriod(utc,true); }
    function finish(utc) { closePeriod(utc,false); }
    function airborne() { return s["airTotal"] + (s["airStart"] == null ? 0 : s["elapsed"] - s["airStart"]); }
}
