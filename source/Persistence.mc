import Toybox.Application.Storage;
import Toybox.Lang;
class Persistence {
    var error=false; var errors=[]; var generation=0; var prefix="";
    function initialize() {}
    function fail(message) { error=true; for(var i=0;i<errors.size();i+=1) { if(errors[i].equals(message)) { return; } } if(errors.size()<16) { errors.add(message); } }
    function snapshot(nav,utc) { return {"version"=>2,"generation"=>generation+1,"savedUtc"=>utc,"navigation"=>nav.s,"timers"=>nav.timers.s,"clearoff"=>nav.check.s,"undo"=>nav.undoState}; }
    function readSlot(slot) { return Storage.getValue(prefix+"checkpoint"+slot); }
    function writeSlot(slot,data) { Storage.setValue(prefix+"checkpoint"+slot,data); }
    function save(nav,utc) {
        try { var data=snapshot(nav,utc); if(!valid(data)) { fail("Checkpoint validation failed"); return false; }
            writeSlot((generation+1)%2,data); generation+=1; return true;
        } catch(e) { fail("Checkpoint write failed"); return false; }
    }
    function number(v,min,max) { return (v instanceof Lang.Number || v instanceof Lang.Long || v instanceof Lang.Float || v instanceof Lang.Double) && v>=min && v<=max; }
    function integer(v,min,max) { return v instanceof Lang.Number && v>=min && v<=max; }
    function stamp(v) { return v==null || number(v,0,2147483647); }
    function array(v,limit) { return v instanceof Lang.Array && v.size()<=limit; }
    function dict(v,keys) { if(!(v instanceof Lang.Dictionary)) { return false; } for(var i=0;i<keys.size();i+=1) { if(!v.hasKey(keys[i])) { return false; } } return true; }
    function choice(v,choices) { if(!(v instanceof Lang.String)) { return false; } for(var i=0;i<choices.size();i+=1) { if(v.equals(choices[i])) { return true; } } return false; }
    function checkValid(c,historyCount) {
        if(!dict(c,["state","remainingNm","gs","dueElapsed","dueUtc","segmentNm","lastAck"])) { return false; }
        if(!choice(c["state"],["idle","running","due","acknowledged","complete","legCompleted"]) ||
          !number(c["remainingNm"],0,10000) || !number(c["gs"],0.1,2000) || !number(c["dueElapsed"],0,8640000) ||
          !number(c["dueUtc"],0,2147483647) || !number(c["segmentNm"],0,10) || !stamp(c["lastAck"])) { return false; }
        if(c["state"].equals("due") && (!c.hasKey("historyIndex") || !integer(c["historyIndex"],0,historyCount-1))) { return false; }
        return true;
    }
    function legValid(r,version,elapsed) {
        if(!dict(r,["index","startUtc","plannedArrivalUtc","heading","gs","actualSeconds"]) ||
          !integer(r["index"],0,3) || !number(r["startUtc"],0,2147483647) || !number(r["plannedArrivalUtc"],0,2147483647) ||
          !integer(r["heading"],0,359) || !number(r["gs"],0.1,2000) || !(r["actualSeconds"]==null || number(r["actualSeconds"],0,elapsed))) { return false; }
        if(version==1) { return dict(r,["finishUtc"]) && stamp(r["finishUtc"]); }
        return dict(r,["legClosedUtc","waypointReachedUtc","closure"]) && stamp(r["legClosedUtc"]) && stamp(r["waypointReachedUtc"]) &&
          (r["closure"]==null || choice(r["closure"],["waypoint","sessionEnded","legacyUnknown"])) &&
          ((r["legClosedUtc"]==null)==(r["actualSeconds"]==null)) && (r["waypointReachedUtc"]==null || r["legClosedUtc"]!=null);
    }
    function valid(data) {
        try { return validate(data); } catch(e) { return false; }
    }
    function validate(data) {
        if(!dict(data,["version","navigation","timers","clearoff","generation","savedUtc","undo"]) ||
          !integer(data["version"],1,2) || !integer(data["generation"],0,2147483646) || !number(data["savedUtc"],0,2147483647)) { return false; }
        var n=data["navigation"]; var t=data["timers"];
        var planCount=4;
        if(n instanceof Lang.Dictionary && n.hasKey("planId") && n["planId"]!=null) {
            if(!(n["planId"] instanceof Lang.String)) { return false; }
            var plan=FlightPlan.find(n["planId"]); if(plan==null || !n.hasKey("planRevision") || !plan["revision"].equals(n["planRevision"])) { return false; }
            planCount=FlightPlan.legsFor(n["planId"]).size();
        }
        if(!dict(n,["flight","started","finished","startUtc","finishUtc","index","legStart","radioPending","arrivalAlerted","legs","checks","corrections"]) ||
          !dict(t,["elapsed","airStart","airTotal","periods"])) { return false; }
        if(!(n["flight"] instanceof Lang.String) || n["flight"].length()>120 || !(n["started"] instanceof Lang.Boolean) ||
          !(n["finished"] instanceof Lang.Boolean) || !(n["radioPending"] instanceof Lang.Boolean) || !(n["arrivalAlerted"] instanceof Lang.Boolean) ||
          !stamp(n["startUtc"]) || !stamp(n["finishUtc"]) || !integer(n["index"],0,planCount-1) || !number(t["elapsed"],0,8640000) ||
          !number(n["legStart"],0,t["elapsed"]) || !number(t["airTotal"],0,t["elapsed"]) ||
          !(t["airStart"]==null || number(t["airStart"],0,t["elapsed"])) ||
          !array(n["legs"],4) || !array(n["checks"],512) || !array(n["corrections"],512) || !array(t["periods"],256)) { return false; }
        if(n["started"] && (n["startUtc"]==null || n["legs"].size()!=n["index"]+1)) { return false; }
        if(!n["started"] && (n["finished"] || n["legs"].size()!=0 || t["elapsed"]!=0)) { return false; }
        if(n["finished"] && (n["finishUtc"]==null || t["airStart"]!=null)) { return false; }
        for(var i=0;i<n["legs"].size();i+=1) { if(!legValid(n["legs"][i],data["version"],t["elapsed"]) || n["legs"][i]["index"]!=i) { return false; } }
        for(var j=0;j<n["checks"].size();j+=1) {
            var c=n["checks"][j]; if(!dict(c,["leg","dueUtc","ackUtc","corrected"]) || !integer(c["leg"],0,3) ||
              !number(c["dueUtc"],0,2147483647) || !stamp(c["ackUtc"]) || !(c["corrected"] instanceof Lang.Boolean)) { return false; }
        }
        if(!checkValid(data["clearoff"],n["checks"].size())) { return false; }
        var activePeriods=0; var sum=0;
        for(var k=0;k<t["periods"].size();k+=1) {
            var p=t["periods"][k]; if(!dict(p,["takeoffUtc","landingUtc","seconds"]) || !number(p["takeoffUtc"],0,2147483647) ||
              !stamp(p["landingUtc"]) || !number(p["seconds"],0,t["elapsed"])) { return false; }
            if(data["version"]==2) {
                if(!dict(p,["closedUtc","status"]) || !stamp(p["closedUtc"]) || !choice(p["status"],["airborne","landed","unconfirmed","legacyUnknown"])) { return false; }
                if(p["status"].equals("airborne")) { activePeriods+=1; if(p["closedUtc"]!=null || k!=t["periods"].size()-1) { return false; } }
                else { sum+=p["seconds"]; if(p["closedUtc"]==null) { return false; } }
                if(p["status"].equals("landed") && p["landingUtc"]==null) { return false; }
                if(p["status"].equals("unconfirmed") && p["landingUtc"]!=null) { return false; }
            } else {
                if(p["landingUtc"]==null) { activePeriods+=1; if(k!=t["periods"].size()-1) { return false; } }
                else { sum+=p["seconds"]; }
            }
        }
        if(activePeriods!=(t["airStart"]==null ? 0 : 1) || sum!=t["airTotal"]) { return false; }
        for(var h=0;h<n["corrections"].size();h+=1) {
            var correction=n["corrections"][h]; if(!dict(correction,["utc"]) || !number(correction["utc"],0,2147483647)) { return false; }
            if(correction.hasKey("restoredLeg") && !integer(correction["restoredLeg"],0,3)) { return false; }
            if(correction.hasKey("interruptionSeconds") && !number(correction["interruptionSeconds"],0,8640000)) { return false; }
            if(correction.hasKey("discardedLeg") && correction["discardedLeg"]!=null && !legValid(correction["discardedLeg"],data["version"],t["elapsed"])) { return false; }
        }
        var u=data["undo"];
        if(u!=null && (!dict(u,["index","legStart","check","arrivalAlerted","radioPending","checkCount"]) ||
          !integer(u["index"],0,n["index"]) || !number(u["legStart"],0,t["elapsed"]) || !(u["arrivalAlerted"] instanceof Lang.Boolean) ||
          !(u["radioPending"] instanceof Lang.Boolean) || !integer(u["checkCount"],0,n["checks"].size()) || !checkValid(u["check"],n["checks"].size()))) { return false; }
        if(u!=null && (n["index"]-u["index"]>1 || (n["index"]==u["index"] && (n["index"]!=planCount-1 || !data["clearoff"]["state"].equals("legCompleted"))))) { return false; }
        if(data["version"]==2) {
            if(n.hasKey("finishRequested") && !(n["finishRequested"] instanceof Lang.Boolean)) { return false; }
            if(n.hasKey("discarded") && (!(n["discarded"] instanceof Lang.Boolean) || (n["discarded"] && n["started"]))) { return false; }
            if(n.hasKey("fitPending") && !(n["fitPending"] instanceof Lang.Boolean)) { return false; }
            if(!dict(n,["schema","events","demo","fitOutcome"]) || n["schema"]!=2 || !(n["demo"] instanceof Lang.Boolean) || !choice(n["fitOutcome"],["notStarted","recording","unavailable","paused","savePending","saved","localOnly","legacyUnknown","idle","discarded"]) || !array(n["events"],32)) { return false; }
            for(var e=0;e<n["events"].size();e+=1) { var ev=n["events"][e];
                if(!dict(ev,["kind","leg","dueUtc"]) || !choice(ev["kind"],["checkDue","arrivalDue","radioChange"]) || !integer(ev["leg"],0,3) || !number(ev["dueUtc"],0,2147483647)) { return false; }
            }
        }
        return true;
    }
    function load() {
        var result=null;
        for(var slot=0;slot<2;slot+=1) {
            try { var data=readSlot(slot);
                if(data!=null) {
                    if(!valid(data)) { fail("Invalid checkpoint "+slot); }
                    else if(result==null || data["generation"]>result["generation"]) { result=data; }
                }
            } catch(e) { fail("Unreadable checkpoint "+slot); }
        }
        if(result!=null) { generation=result["generation"]; }
        return result;
    }
    function restore(data,utc) {
        if(!valid(data)) { fail("Cannot restore checkpoint"); return null; }
        var copy=deepCopy(data); var nav=new Navigation(); nav.s=copy["navigation"]; nav.timers.s=copy["timers"]; nav.check.s=copy["clearoff"]; nav.undoState=copy["undo"];
        if(copy["version"]==1) {
            nav.s["schema"]=2; nav.s["demo"]=true; nav.s["events"]=[]; nav.s["fitOutcome"]="legacyUnknown";
            for(var i=0;i<nav.s["legs"].size();i+=1) {
                var leg=nav.s["legs"][i]; leg["legClosedUtc"]=leg["finishUtc"]; leg["waypointReachedUtc"]=null;
                leg["closure"]=leg["finishUtc"]==null ? null : "legacyUnknown";
            }
            for(var j=0;j<nav.timers.s["periods"].size();j+=1) {
                var p=nav.timers.s["periods"][j]; p["closedUtc"]=p["landingUtc"]; p["status"]=p["landingUtc"]==null ? "airborne" : "legacyUnknown";
            }
            // Version 1 did not persist pending delivery. Re-alert overdue states once on migration.
            if(nav.check.s["state"].equals("due")) { nav.event("checkDue",nav.check.s["dueUtc"]); }
            if(nav.s["arrivalAlerted"] && nav.s["legs"].size()>0) { nav.event("arrivalDue",nav.s["legs"][nav.s["legs"].size()-1]["plannedArrivalUtc"]); }
        }
        if(!nav.s.hasKey("fitPending")) { nav.s["fitPending"]=false; }
        if(!nav.s.hasKey("planId")) { nav.s["planId"]=nav.s["started"] ? FlightPlan.DEFAULT_ID : null; nav.s["planRevision"]=nav.s["started"] ? "1" : null; }
        if(nav.s["planId"]!=null) { nav.plan=FlightPlan.legsFor(nav.s["planId"]); }
        if(!nav.s.hasKey("finishRequested")) { nav.s["finishRequested"]=false; }
        if(!nav.s.hasKey("discarded")) { nav.s["discarded"]=false; }
        var gap=utc-copy["savedUtc"]; if(gap<0) { fail("Clock moved backward during interruption"); gap=0; }
        if(nav.s["started"] && !nav.s["finished"]) {
            if(gap>8640000-nav.timers.s["elapsed"]) { fail("Recovery gap exceeds supported session length"); return null; }
            nav.timers.s["elapsed"]+=gap; nav.s["corrections"].add({"utc"=>utc,"interruptionSeconds"=>gap}); nav.tick();
        }
        return nav;
    }
    function discardCurrent(utc) {
        // A newer empty tombstone prevents fallback to the discarded flight after restart.
        var empty=new Navigation(); empty.s["discarded"]=true; empty.s["fitOutcome"]="discarded";
        if(!save(empty,utc)) { return false; }
        try { Storage.deleteValue(prefix+"checkpoint"+((generation+1)%2)); return true; }
        catch(e) { fail("Discard log cleanup failed"); return false; }
    }
    function archive(nav,utc) {
        try { var slot=Storage.getValue(prefix+"historyNext"); if(slot==null) { slot=0; }
            if(!integer(slot,0,2)) { fail("Invalid history slot"); return false; }
            Storage.setValue(prefix+"flight"+slot,snapshot(nav,utc)); Storage.setValue(prefix+"historyNext",(slot+1)%3); return true;
        } catch(e) { fail("History archive failed"); return false; }
    }
}
