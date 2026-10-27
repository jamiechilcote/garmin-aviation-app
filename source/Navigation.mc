import Toybox.Lang;
class Navigation {
    var plan; var timers; var check; var s; var undoState;
    function initialize() {
        plan=FlightPlan.legs(); timers=new FlightTimers();
        s={"schema"=>2,"flight"=>FlightPlan.NAME,"demo"=>FlightPlan.DEMO,"started"=>false,"finished"=>false,
           "startUtc"=>null,"finishUtc"=>null,"index"=>0,"legStart"=>0,"radioPending"=>false,
           "arrivalAlerted"=>false,"legs"=>[],"checks"=>[],"corrections"=>[],"events"=>[],"fitOutcome"=>"notStarted","fitPending"=>false,"planId"=>null,"planRevision"=>null,"finishRequested"=>false,"discarded"=>false};
        check=new Clearoff(plan[0]["nm"],plan[0]["gs"]); undoState=null;
    }
    function selectPlan(id) {
        if(s["started"] || s["fitPending"]) { return false; }
        var info=FlightPlan.find(id); if(info==null) { return false; }
        plan=FlightPlan.legsFor(id); s["planId"]=id; s["planRevision"]=info["revision"]; s["flight"]=info["name"]; s["demo"]=info["demo"];
        check=new Clearoff(plan[0]["nm"],plan[0]["gs"]); return true;
    }
    function leg() { return plan[s["index"]]; }
    function start(utc) {
        if(s["started"]) { return; }
        s["started"]=true; s["startUtc"]=utc; activate(utc);
    }
    function activate(utc) {
        s["legStart"]=timers.s["elapsed"]; s["arrivalAlerted"]=false;
        check=new Clearoff(leg()["nm"],leg()["gs"]);
        s["legs"].add({"index"=>s["index"],"startUtc"=>utc,"legClosedUtc"=>null,"waypointReachedUtc"=>null,
          "plannedArrivalUtc"=>utc+Toybox.Math.ceil(leg()["nm"]*3600.0/leg()["gs"]).toNumber(),
          "heading"=>leg()["heading"],"gs"=>leg()["gs"],"actualSeconds"=>null,"closure"=>null});
    }
    function legSeconds() {
        if(s["legs"].size()>0) {
            var current=s["legs"][s["legs"].size()-1];
            if(current["actualSeconds"]!=null) { return current["actualSeconds"]; }
        }
        return timers.s["elapsed"]-s["legStart"];
    }
    function event(kind, utc) { s["events"].add({"kind"=>kind,"leg"=>s["index"],"dueUtc"=>utc}); }
    function takeEvents() { var events=s["events"]; s["events"]=[]; return events; }
    function tick() {
        if(!s["started"] || s["finished"]) { return false; }
        var changed=check.update(timers.s["elapsed"]);
        if(changed) {
            check.s["historyIndex"]=s["checks"].size();
            s["checks"].add({"leg"=>s["index"],"dueUtc"=>check.s["dueUtc"],"ackUtc"=>null,"corrected"=>false});
            event("checkDue",check.s["dueUtc"]);
        }
        if(!s["arrivalAlerted"] && !check.s["state"].equals("legCompleted") &&
           legSeconds()>=Toybox.Math.ceil(leg()["nm"]*3600.0/leg()["gs"])) {
            s["arrivalAlerted"]=true; changed=true;
            event("arrivalDue",s["legs"][s["legs"].size()-1]["plannedArrivalUtc"]);
        }
        return changed;
    }
    function checkAction(utc) {
        if(!s["started"] || s["finished"] || check.s["state"].equals("legCompleted")) { return; }
        tick();
        if(check.s["state"].equals("idle")) { check.start(timers.s["elapsed"],utc); }
        else {
            var wasDue=check.s["state"].equals("due");
            var record=check.acknowledge(timers.s["elapsed"],utc);
            if(record!=null) {
                if(wasDue) { s["checks"][check.s["historyIndex"]]["ackUtc"]=utc; }
                else { s["checks"].add({"leg"=>s["index"],"dueUtc"=>record["dueUtc"],"ackUtc"=>utc,"corrected"=>false}); }
            }
        }
    }
    function closeLeg(utc,reached) {
        var record=s["legs"][s["legs"].size()-1];
        if(record["legClosedUtc"]!=null) { return; }
        var duration=legSeconds();
        record["actualSeconds"]=duration; record["legClosedUtc"]=utc;
        record["waypointReachedUtc"]=reached ? utc : null;
        record["closure"]=reached ? "waypoint" : "sessionEnded";
    }
    function advance(utc) {
        if(!s["started"] || s["finished"] || check.s["state"].equals("legCompleted")) { return; }
        tick();
        undoState={"index"=>s["index"],"legStart"=>s["legStart"],"check"=>deepCopy(check.s),
          "arrivalAlerted"=>s["arrivalAlerted"],"radioPending"=>s["radioPending"],"checkCount"=>s["checks"].size()};
        closeLeg(utc,true);
        if(s["index"]==plan.size()-1) { check.s["state"]="legCompleted"; }
        else {
            var prior=leg(); s["index"]+=1; activate(utc);
            var radioChanged=!prior["active"].equals(leg()["active"]) || !prior["standby"].equals(leg()["standby"]);
            s["radioPending"]=s["radioPending"] || radioChanged;
            if(radioChanged) { event("radioChange",utc); }
        }
    }
    function undo(utc) {
        if(undoState==null || s["finished"]) { return; }
        var priorRadio=leg(); var discarded=null;
        if(s["index"]!=undoState["index"]) {
            discarded=s["legs"][s["legs"].size()-1]; s["legs"].remove(discarded);
        }
        s["corrections"].add({"utc"=>utc,"restoredLeg"=>undoState["index"],"discardedLeg"=>discarded});
        for(var i=undoState["checkCount"];i<s["checks"].size();i+=1) { s["checks"][i]["corrected"]=true; }
        s["index"]=undoState["index"]; s["legStart"]=undoState["legStart"];
        s["arrivalAlerted"]=undoState["arrivalAlerted"]; s["radioPending"]=undoState["radioPending"] || !priorRadio["active"].equals(leg()["active"]) || !priorRadio["standby"].equals(leg()["standby"]); check.s=undoState["check"];
        var record=s["legs"][s["legs"].size()-1];
        record["legClosedUtc"]=null; record["waypointReachedUtc"]=null; record["actualSeconds"]=null; record["closure"]=null;
        undoState=null; tick();
    }
    function finish(utc) {
        if(!s["started"] || s["finished"]) { return; }
        tick(); timers.finish(utc); closeLeg(utc,false);
        s["finished"]=true; s["finishUtc"]=utc;
    }
    function progress() {
        var total=Toybox.Math.ceil(leg()["nm"]/10.0).toNumber();
        var done=check.s["remainingNm"]<=0 ? total : ((leg()["nm"]-check.s["remainingNm"])/10.0).toNumber();
        return {"done"=>done,"total"=>total,"current"=>done<total ? done+1 : total};
    }
}
function copyDictionary(input) { var result={}; var keys=input.keys(); for(var i=0;i<keys.size();i+=1) { result[keys[i]]=input[keys[i]]; } return result; }
function deepCopy(input) {
    if(input instanceof Lang.Dictionary) { var d={}; var keys=input.keys(); for(var i=0;i<keys.size();i+=1) { d[keys[i]]=deepCopy(input[keys[i]]); } return d; }
    if(input instanceof Lang.Array) { var a=[]; for(var j=0;j<input.size();j+=1) { a.add(deepCopy(input[j])); } return a; }
    return input;
}
