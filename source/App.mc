import Toybox.Application;
import Toybox.WatchUi;
import Toybox.Timer;
import Toybox.System;
import Toybox.Time;
class NavlogApp extends Application.AppBase {
    var pulse; var nav; var screen="select"; var selected=0; var pending=null;
    var lastMillis; var remainder=0; var lastInput=null;
    var recording; var alerts; var persistence; var recovered=null; var lastSaved=0; var testing=false; var notice=null;
    var deliveredEvents=0; var storageBlocked=false; var planChoice=0; var alertChoice=0; var returnScreen="menu";
    var completionAt=null; var exitRequested=false;
    // Stable command IDs retain the tested recording/history operations. Menus expose only valid IDs.
    var actions=["Radio change","Advance waypoint","Undo advancement","Takeoff / landing","Finish & Save","Alert settings","Select flight","Exit app","Retry recording","Retry recovery","Save local log only","Discard Flight","Start Flight","Radio change","Return to flight","Review recording"];
    function initialize() { AppBase.initialize(); nav=new Navigation(); recording=new Recording(); alerts=new Alerts(); persistence=new Persistence(); }
    function getInitialView() { return [new NavView(self),new NavDelegate(self)]; }
    function nativeUnresolved() {
        if(recording.session!=null || nav.s["fitPending"]) { return true; }
        return nav.s["started"] && !nav.s["finished"] && !nav.s["fitOutcome"].equals("notStarted") && !nav.s["fitOutcome"].equals("unavailable") && !nav.s["fitOutcome"].equals("localOnly");
    }
    // Flight state is derived from canonical navigation/timers/recording, never separately persisted.
    function flightState() {
        if(storageBlocked || screen.equals("recovery") || screen.equals("review")) { return "RECOVERY_REQUIRED"; }
        if(nav.s["finishRequested"] || (nav.s["finished"] && nav.s["fitPending"])) { return "FINISH_PENDING"; }
        if(nav.s["finished"] || nav.s["discarded"]) { return "FINISHED"; }
        if(!nav.s["started"]) { return nav.s["planId"]==null ? "NO_FLIGHT" : "PLAN_SELECTED"; }
        if(recording.warning) { return "RECORDING_ERROR"; }
        return navState();
    }
    function navState() {
        if(nav.timers.s["airStart"]==null) { return nav.timers.s["periods"].size()>0 ? "LANDED" : "GROUND_ACTIVE"; }
        if(nav.check.s["state"].equals("idle")) { return "AIRBORNE_CHECKS_IDLE"; }
        if(nav.check.s["state"].equals("complete") || nav.check.s["state"].equals("legCompleted")) { return "AIRBORNE_CHECKS_COMPLETE"; }
        return "AIRBORNE_CHECKS_RUNNING";
    }
    function primaryAction() {
        if(nav.s["finished"] || nav.s["discarded"]) { return nav.s["fitPending"] || nav.s["finishRequested"] ? "REVIEW SAVE" : "EXIT"; }
        if(storageBlocked || nav.s["finishRequested"]) { return "REVIEW SAVE"; }
        if(!nav.s["started"]) { return "SELECT FLIGHT"; }
        if(nav.timers.s["airStart"]==null) { return "TAKEOFF"; }
        if(nav.check.s["state"].equals("idle")) { return "START CHECKS"; }
        if(nav.check.s["state"].equals("running") || nav.check.s["state"].equals("due")) { return "COMPLETE CHECK"; }
        return "CHECKS COMPLETE";
    }
    function loadRecovery(utc) {
        recovered=persistence.load(); storageBlocked=recovered==null && persistence.error;
        if(recovered!=null) {
            var restored=persistence.restore(recovered,utc);
            if(restored!=null) {
                nav=restored; recovered=null;
                if(nav.s["started"] && !nav.s["finished"]) {
                    // No unverified automatic rebinding: a lost handle may refer to an existing native FIT.
                    if(recording.session==null) { recording.state="paused"; recording.warning=true; recording.status="Recording needs review"; screen="recovery"; }
                    else { screen="nav"; }
                } else if(nav.s["fitPending"] || nav.s["finishRequested"]) { screen="recovery"; }
                else { screen="select"; }
            } else { storageBlocked=true; screen="recovery"; }
        } else { screen=storageBlocked ? "recovery" : "select"; }
    }
    function onStart(state) {
        lastMillis=System.getTimer(); loadRecovery(Time.now().value()); loadAlertMode();
        pulse=new Timer.Timer(); pulse.start(method(:tick),1000,true);
    }
    function loadAlertMode() {
        try { var mode=Application.Storage.getValue("alertMode"); if(mode instanceof Toybox.Lang.Number && mode>=0 && mode<4) { alerts.mode=mode; } }
        catch(e) { persistence.fail("Alert settings unreadable"); }
    }
    function updateElapsed() {
        var now=System.getTimer(); if(lastMillis==null) { lastMillis=now; } var delta=monotonicDelta(now,lastMillis); lastMillis=now;
        if(nav.s["started"] && !nav.s["finished"]) { remainder+=delta; nav.timers.s["elapsed"]+=(remainder/1000).toNumber(); remainder%=1000; }
    }
    function deliverEvents() {
        if(nav.s["events"].size()==0) { return false; }
        try { if(!testing) { alerts.fire(); } var events=nav.takeEvents(); deliveredEvents+=events.size(); return true; }
        catch(e) { notice="Alert delivery failed"; return false; }
    }
    function tick() as Void {
        updateElapsed(); nav.tick(); var delivered=deliverEvents();
        if(delivered || (nav.s["started"] && !nav.s["finished"] && nav.timers.s["elapsed"]-lastSaved>=15)) { checkpoint(); }
        if(completionAt!=null && monotonicDelta(System.getTimer(),completionAt)>=3000) { safeExit(); }
        WatchUi.requestUpdate();
    }
    function checkpoint() {
        if(testing) { return true; }
        if(storageBlocked || recovered!=null) { return false; }
        if(persistence.save(nav,Time.now().value())) { lastSaved=nav.timers.s["elapsed"]; return true; } return false;
    }
    function recordBoundary(utc,reason) {
        nav.s["fitOutcome"]=recording.state; nav.s["fitPending"]=nav.s["fitPending"] || recording.session!=null;
        nav.s["corrections"].add({"utc"=>utc,"recordingBoundary"=>reason,"recordingState"=>recording.state});
    }
    function retryRecording(utc) {
        if(recording.session==null && nativeUnresolved()) { notice="Original FIT needs review"; return; }
        if(recording.start()) { notice=null; } else { notice="Recording failed"; }
        recordBoundary(utc,"startOrRetry");
    }
    function onStop(state) {
        if(pulse!=null) { pulse.stop(); } updateElapsed();
        if(nav.s["started"] && !nav.s["finished"]) { recordBoundary(Time.now().value(),"appStopped"); }
        checkpoint(); recording.suspend();
    }
    function menuIds() {
        if(nav.s["finished"] || nav.s["finishRequested"] || nav.s["discarded"]) { return [15]; }
        var ids=[];
        if(nav.s["started"]) {
            if(!nav.check.s["state"].equals("legCompleted")) { ids.add(1); }
            if(nav.undoState!=null) { ids.add(2); }
            ids.add(3); if(nav.s["radioPending"]) { ids.add(13); }
            if(recording.warning || storageBlocked) { ids.add(15); }
            ids.add(5); ids.add(4); ids.add(11);
        } else { ids=[5]; }
        return ids;
    }
    function recoveryIds() {
        if(storageBlocked) { return [9,15]; }
        if(nav.s["discarded"] && nav.s["finishRequested"]) { return [11,15]; }
        if(nav.s["finished"] || nav.s["finishRequested"]) {
            if(recording.session!=null || recording.state.equals("saved") || !nativeUnresolved()) { if(nav.s["finished"] && recording.session==null && !recording.state.equals("saved") && !nav.s["fitOutcome"].equals("saved")) { return [10,11,15]; } return nav.s["finished"] ? [4,11,15] : [4,10,11,14,15]; }
            return [15];
        }
        var ids=[];
        if(recording.session!=null || !nativeUnresolved()) { ids.add(8); }
        ids.add(14); ids.add(10); ids.add(15); return ids;
    }
    function actionLabel(id) {
        if(id==3) { return nav.timers.s["airStart"]==null ? "Takeoff" : "Land"; }
        if(id==4 && (nav.s["finished"] || nav.s["finishRequested"])) { return "Retry save"; }
        return actions[id];
    }
    function openMenu(last) { var ids=menuIds(); selected=last ? ids.size()-1 : 0; screen="menu"; }
    function choosePlan() {
        if(storageBlocked || nativeUnresolved() || nav.s["started"] && !nav.s["finished"] || nav.s["finishRequested"]) { screen="recovery"; return; }
        if(nav.s["finished"] && !testing && !persistence.archive(nav,Time.now().value())) { notice="History not saved"; return; }
        nav=new Navigation(); nav.selectPlan(FlightPlan.catalogue()[planChoice]["id"]); recording=new Recording(); screen="summary"; checkpoint();
    }
    function selectAction(id,origin) {
        returnScreen=origin;
        if(id==5) { alertChoice=alerts.mode; screen="alerts"; }
        else if(id==0 || id==13) { screen="radio"; }
        else if(id==15) { screen="recovery"; selected=0; }
        else if(id==14 || id==8 || id==9) { execute(id,Time.now().value()); }
        else { pending=id; screen="confirm"; }
    }
    function input(action) {
        var now=System.getTimer(); var threshold=action.equals("select") ? 450 : 180;
        if(lastInput!=null && monotonicDelta(now,lastInput)<threshold) { return; }
        lastInput=now; notice=null; updateElapsed(); nav.tick(); deliverEvents(); var utc=Time.now().value();
        var direction=action.equals("up") ? -1 : 1;
        if(screen.equals("select")) {
            if(action.equals("up") || action.equals("down")) { planChoice=(planChoice+direction+FlightPlan.catalogue().size())%FlightPlan.catalogue().size(); }
            else if(action.equals("select")) { choosePlan(); }
            else if(action.equals("back") && !nativeUnresolved()) { safeExit(); }
        } else if(screen.equals("summary")) {
            if(action.equals("back")) { screen="select"; }
            else if(action.equals("select")) { pending=12; returnScreen="summary"; screen="confirm"; }
        } else if(screen.equals("confirm")) {
            if(action.equals("back")) { screen=returnScreen; pending=null; }
            else if(action.equals("select")) { var id=pending; pending=null; screen="nav"; execute(id,utc); }
        } else if(screen.equals("alerts")) {
            if(action.equals("up") || action.equals("down")) { var order=[2,0,1,3]; var index=0; for(var a=0;a<4;a+=1) { if(order[a]==alertChoice) { index=a; } } alertChoice=order[(index+direction+4)%4]; }
            else if(action.equals("back")) { screen=returnScreen; }
            else if(action.equals("select")) { execute(5,utc); screen=returnScreen; }
        } else if(screen.equals("radio")) {
            if(action.equals("select")) { nav.s["radioPending"]=false; screen="nav"; }
            else if(action.equals("back")) { screen="nav"; }
            else if(action.equals("up") || action.equals("down")) { openMenu(action.equals("up")); }
        } else if(screen.equals("timers") || screen.equals("menu")) {
            var ids=menuIds();
            if(action.equals("back")) { screen=screen.equals("timers") ? "nav" : "timers"; }
            else if(screen.equals("timers")) {
                if(action.equals("up") || action.equals("down")) { openMenu(action.equals("up")); }
            } else if(action.equals("up") || action.equals("down")) {
                if(action.equals("up") && selected==0 || action.equals("down") && selected==ids.size()-1) { screen="timers"; }
                else { selected+=direction; }
            } else if(action.equals("select")) { selectAction(ids[selected],"menu"); }
        } else if(screen.equals("recovery")) {
            var options=recoveryIds();
            if(action.equals("up") || action.equals("down")) { selected=(selected+direction+options.size())%options.size(); }
            else if(action.equals("back")) { screen="nav"; }
            else if(action.equals("select")) {
                var id=options[selected]; if(id==15) { screen="review"; }
                else { selectAction(id,"recovery"); }
            }
        } else if(screen.equals("review")) { if(action.equals("back") || action.equals("select")) { screen="recovery"; selected=0; } }
        else if(screen.equals("completed")) { if(action.equals("select") || action.equals("back")) { safeExit(); } }
        else if(action.equals("back")) { screen="timers"; }
        else if(action.equals("up") || action.equals("down")) { openMenu(action.equals("up")); }
        else if(action.equals("select")) {
            if(storageBlocked || nav.s["finishRequested"] || nav.s["fitPending"] && nav.s["finished"]) { screen="recovery"; selected=0; }
            else if(nav.s["finished"] || nav.s["discarded"]) { safeExit(); }
            else if(!nav.s["started"]) { screen="select"; }
            else if(nav.timers.s["airStart"]==null) { execute(3,utc); }
            else { nav.checkAction(utc); }
        }
        deliverEvents(); checkpoint(); WatchUi.requestUpdate();
    }
    function complete(utc,message) {
        nav.s["finishRequested"]=false;
        if(checkpoint()) { screen="completed"; notice=message; completionAt=System.getTimer(); }
        else { nav.s["finishRequested"]=true; notice="Local log save failed"; screen="recovery"; selected=0; }
    }
    function safeExit() {
        if(nativeUnresolved() || nav.s["finishRequested"] || storageBlocked) { notice="Save pending FIT first"; completionAt=null; return; }
        if(nav.s["started"] && !nav.s["finished"]) { notice="Finish flight first"; return; }
        exitRequested=true; if(!testing) { System.exit(); }
    }
    function execute(action,utc) {
        if(action==5) {
            try { if(!testing) { Application.Storage.setValue("alertMode",alertChoice); } alerts.mode=alertChoice; }
            catch(e) { persistence.fail("Alert settings write failed"); notice="Alert setting not saved"; } return;
        }
        if(action==7) { safeExit(); return; }
        if(action==6 && nav.s["started"] && !nav.s["finished"]) { notice="Finish flight first"; return; }
        if(action==6) { if(nativeUnresolved() || nav.s["finishRequested"]) { notice="Unsaved FIT - retry save"; return; } screen="select"; return; }
        if(action==9) { loadRecovery(utc); return; }
        if(action==14) { screen="nav"; return; }
        if(action==12) {
            if(nav.s["started"] || nav.s["planId"]==null || storageBlocked || nativeUnresolved()) { return; }
            nav.start(utc); remainder=0; retryRecording(utc); screen=recording.state.equals("unavailable") ? "recovery" : "nav"; selected=0; return;
        }
        if(action==8) {
            if(nav.s["finished"]) { recording.cleanupGps(); notice=recording.cleanupWarning ? "GPS cleanup still failed" : "GPS off"; return; }
            if(nav.s["started"] && !storageBlocked) { retryRecording(utc); screen=recording.state.equals("recording") ? "nav" : "recovery"; selected=0; } return;
        }
        if(action==11) {
            if(storageBlocked || recording.session==null && nativeUnresolved() || recording.state.equals("saved")) { notice="Original FIT needs review"; screen="recovery"; selected=0; return; }
            if(!recording.discard()) { nav.s["finishRequested"]=true; nav.s["fitPending"]=recording.session!=null; notice=recording.status; screen="recovery"; selected=0; return; }
            nav=new Navigation(); nav.s["discarded"]=true; nav.s["fitOutcome"]="discarded";
            if(!testing && !persistence.discardCurrent(utc)) { nav.s["finishRequested"]=true; screen="recovery"; selected=0; notice="Local discard incomplete"; return; }
            complete(utc,"Flight discarded"); return;
        }
        if(action==4) {
            if(storageBlocked || !nav.s["started"]) { return; }
            if(recording.session==null && nativeUnresolved()) { notice="FIT recovery needs review"; screen="recovery"; selected=0; return; }
            if(nav.s["finished"] && nav.s["fitOutcome"].equals("saved") && recording.session==null) { complete(utc,"Flight and FIT saved"); return; }
            nav.s["finishRequested"]=true; recording.prepareFinal(nav);
            if(recording.save(nav.timers.airborne())) {
                nav.s["fitPending"]=false; nav.s["fitOutcome"]="saved"; nav.finish(utc); complete(utc,"Flight and FIT saved");
            } else { nav.s["fitPending"]=recording.session!=null; nav.s["fitOutcome"]=recording.state; nav.finish(utc); notice=recording.status; screen="recovery"; selected=0; }
            return;
        }
        if(action==10 && nav.s["finished"] && !nativeUnresolved() && !storageBlocked) { nav.s["fitOutcome"]="localOnly"; complete(utc,"Local log only - no FIT"); return; }
        if(!nav.s["started"] || nav.s["finished"] || storageBlocked || nav.s["finishRequested"] && action!=10) { return; }
        if(action==10) {
            var unresolved=nativeUnresolved(); recording.prepareFinal(nav); recording.suspend(); recordBoundary(utc,"localOnlyFinish");
            nav.s["fitPending"]=unresolved; nav.s["fitOutcome"]="localOnly"; nav.finish(utc);
            if(unresolved) { nav.s["finishRequested"]=true; screen="recovery"; selected=0; notice="Local log saved; FIT unresolved"; }
            else { complete(utc,"Local log only - no FIT"); } return;
        }
        if(action==1 || action==2) {
            var prior=nav.leg(); if(action==1) { nav.advance(utc); } else { nav.undo(utc); }
            if(!prior["active"].equals(nav.leg()["active"]) || !prior["standby"].equals(nav.leg()["standby"])) { screen="radio"; }
        }

        if(action==3) {
            if(nav.timers.s["airStart"]==null) { recording.closePhase(0,0,0,0); nav.timers.takeoff(utc); }
            else { var period=nav.timers.s["periods"][nav.timers.s["periods"].size()-1]; recording.closePhase(1,nav.timers.s["elapsed"]-nav.timers.s["airStart"],period["takeoffUtc"],utc); nav.timers.land(utc); }
        }
    }
}
function monotonicDelta(now,previous) { var delta=now.toLong()-previous.toLong(); return delta<0 ? delta+4294967296l : delta; }
