import Toybox.Math;

// Inputs are session elapsed seconds and UTC epoch seconds, never GPS.
class Clearoff {
    var s;
    function initialize(distance, speed) {
        s = {"state"=>"idle", "remainingNm"=>distance, "gs"=>speed,
             "dueElapsed"=>0, "dueUtc"=>0, "segmentNm"=>0, "lastAck"=>null};
    }
    function interval() {
        var nm = s["remainingNm"] < 10.0 ? s["remainingNm"] : 10.0;
        return Math.ceil(nm * 3600.0 / s["gs"]).toNumber();
    }
    function start(elapsed, utc) {
        if (s["remainingNm"] <= 0) { s["state"] = "complete"; return; }
        s["segmentNm"] = s["remainingNm"] < 10.0 ? s["remainingNm"] : 10.0;
        var seconds = interval();
        s["dueElapsed"] = elapsed + seconds;
        s["dueUtc"] = utc + seconds;
        s["state"] = "running";
    }
    function update(elapsed) {
        if (s["state"].equals("running") && elapsed >= s["dueElapsed"]) {
            s["state"] = "due"; return true;
        }
        return false;
    }
    function acknowledge(elapsed, utc) {
        update(elapsed);
        if (!s["state"].equals("due") && !s["state"].equals("running")) { return null; }
        // Ignore a second press during the first two seconds of each new segment.
        if(elapsed < s["dueElapsed"]-interval()+2) { return null; }
        var record = {"dueUtc"=>s["dueUtc"], "ackUtc"=>utc};
        s["lastAck"] = utc;
        s["state"] = "acknowledged";
        s["remainingNm"] -= s["segmentNm"];
        start(elapsed, utc);
        return record;
    }
    function countdown(elapsed) {
        var left = s["dueElapsed"] - elapsed;
        return left > 0 ? left : 0;
    }
}
