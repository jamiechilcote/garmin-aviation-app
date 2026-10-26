import Toybox.Application;
import Toybox.WatchUi;
import Toybox.Timer;
import Toybox.System;
import Toybox.Time;
class NavlogApp extends Application.AppBase {
    var pulse; var nav; var screen="nav"; var selected=0; var pending=null;
    var lastMillis; var remainder=0; var lastInput=null;
    var recording; var alerts; var persistence; var recovered=null; var lastSaved=0; var testing=false; var notice=null;
    var deliveredEvents=0; var storageBlocked=false;
    var actions=["Confirm radio","Advance waypoint","Undo advancement","Takeoff / landing","Finish and save","Change alert mode","New flight","Exit app","Retry recording","Retry recovery","Finish local only"];
    function initialize() { AppBase.initialize(); nav=new Navigation(); recording=new Recording(); alerts=new Alerts(); persistence=new Persistence(); }
    function getInitialView() { return [new NavView(self),new NavDelegate(self)]; }
    function loadRecovery(utc) {
        recovered=persistence.load(); storageBlocked=recovered==null && persistence.error;
        if(recovered!=null) {
            var restored=persistence.restore(recovered,utc);
            if(restored!=null) {
                nav=restored; screen=nav.s["started"] && !nav.s["finished"] ? "recovery" : "nav"; recovered=null;
                if(nav.s["started"] && !nav.s["finished"] && recording.session==null) {
                    recording.state="paused"; recording.warning=true; recording.status="FIT not resumed - retry";
                }
            }
            else { storageBlocked=true; screen="recovery"; }
        } else if(storageBlocked) { screen="recovery"; }
    }
    function onStart(state) {
        loadRecovery(Time.now().value());
        loadAlertMode();
        lastMillis=System.getTimer(); pulse=new Timer.Timer(); pulse.start(method(:tick),1000,true);
    }
    function loadAlertMode() {
        try { var mode=Application.Storage.getValue("alertMode"); if(mode instanceof Toybox.Lang.Number && mode>=0 && mode<4) { alerts.mode=mode; } }
        catch(e) { persistence.fail("Alert settings unreadable"); }
    }
    function updateElapsed() {
        var now=System.getTimer(); var delta=monotonicDelta(now,lastMillis); lastMillis=now;
        if(nav.s["started"] && !nav.s["finished"]) { remainder+=delta; nav.timers.s["elapsed"]+=(remainder/1000).toNumber(); remainder%=1000; }
    }
    function deliverEvents() {
        if(nav.s["events"].size()==0) { return false; }
        try {
            if(!testing) { alerts.fire(); }
            var events=nav.takeEvents(); deliveredEvents+=events.size(); return true;
        } catch(e) { notice="Alert delivery failed"; return false; }
    }
    function tick() as Void {
        updateElapsed(); nav.tick(); var delivered=deliverEvents();
        if(delivered || (nav.s["started"] && !nav.s["finished"] && nav.timers.s["elapsed"]-lastSaved>=15)) { checkpoint(); }
        WatchUi.requestUpdate();
    }
    function checkpoint() {
        if(storageBlocked || recovered!=null || testing) { return; }
        if(persistence.save(nav,Time.now().value())) { lastSaved=nav.timers.s["elapsed"]; }
    }
    function recordBoundary(utc,reason) {
        nav.s["fitOutcome"]=recording.state;
        nav.s["corrections"].add({"utc"=>utc,"recordingBoundary"=>reason,"recordingState"=>recording.state});
    }
    function retryRecording(utc) {
        if(recording.start()) { notice="Recording on; gaps possible"; }
        else { notice="FIT unavailable - manual nav"; }
        recordBoundary(utc,"startOrRetry");
    }
    function onStop(state) {
        if(pulse!=null) { pulse.stop(); } updateElapsed();
        if(nav.s["started"] && !nav.s["finished"]) { recordBoundary(Time.now().value(),"appStopped"); }
        checkpoint(); recording.suspend();
    }
    function input(action) {
        var now=System.getTimer(); if(lastInput!=null && monotonicDelta(now,lastInput)<450) { return; }
        lastInput=now; notice=null; updateElapsed(); nav.tick(); deliverEvents(); var utc=Time.now().value();
        if(action.equals("back")) { screen="nav"; pending=null; }
        else if(action.equals("up") || action.equals("down")) {
            if(screen.equals("menu")) { selected=(selected+(action.equals("up") ? actions.size()-1 : 1))%actions.size(); }
            else { screen=action.equals("up") ? "menu" : "timers"; }
        } else if(action.equals("select")) {
            if(screen.equals("recovery")) { if(!storageBlocked && nav.s["started"] && !nav.s["finished"]) { retryRecording(utc); } screen="nav"; }
            else if(screen.equals("radio")) { nav.s["radioPending"]=false; screen="nav"; }
            else if(screen.equals("confirm")) { execute(pending,utc); pending=null; screen="nav"; }
            else if(screen.equals("menu")) {
                if(selected==0) { screen="radio"; }
                else { pending=selected; screen="confirm"; }
            } else if(screen.equals("nav")) {
                if(storageBlocked) { notice="Recovery data retained"; }
                else if(!nav.s["started"]) { nav.start(utc); remainder=0; retryRecording(utc); }
                else { nav.checkAction(utc); }
            }
        }
        deliverEvents(); checkpoint(); WatchUi.requestUpdate();
    }
    function execute(action,utc) {
        if(action==5) {
            alerts.mode=(alerts.mode+1)%4;
            try { if(!testing) { Application.Storage.setValue("alertMode",alerts.mode); } }
            catch(e) { persistence.fail("Alert settings write failed"); } return;
        }
        if(action==9) { loadRecovery(utc); notice=storageBlocked ? "Recovery data retained" : "Recovery checked"; return; }
        if(action==6 && nav.s["finished"]) {
            if(recording.session!=null || (nav.s.hasKey("fitPending") && nav.s["fitPending"])) { notice="Unsaved FIT - retry save"; return; }
            if(persistence.archive(nav,utc)) { nav=new Navigation(); recording=new Recording(); remainder=0; lastSaved=0; } return;
        }
        if(action==7 && (!nav.s["started"] || nav.s["finished"])) { if(!testing) { System.exit(); } return; }
        if(action==6 || action==7) { notice="Finish flight first"; return; }
        if(action==4 && nav.s["finished"] && recording.session==null && nav.s["fitPending"]) { notice="FIT recovery needs review"; return; }
        if(action==4 && nav.s["finished"] && recording.session!=null) {
            recording.prepareFinal(nav);
            if(recording.save(nav.timers.airborne())) { nav.s["fitPending"]=false; recordBoundary(utc,"lateSave"); notice="FIT saved; local end retained"; }
            else { notice=recording.status; } return;
        }
        if(action==8 && nav.s["finished"]) {
            recording.cleanupGps(); notice=recording.cleanupWarning ? "GPS cleanup still failed" : "GPS off"; return;
        }
        if(!nav.s["started"] || nav.s["finished"] || storageBlocked) { return; }
        if(action==8) { retryRecording(utc); return; }
        if(action==10) {
            recording.prepareFinal(nav); recording.suspend(); recordBoundary(utc,"localOnlyFinish");
            nav.s["fitPending"]=recording.session!=null; nav.s["fitOutcome"]="localOnly"; nav.finish(utc); notice=nav.s["fitPending"] ? "Local saved; FIT pending" : "Saved locally - no FIT"; return;
        }
        if(action==1) { nav.advance(utc); }
        if(action==2) { nav.undo(utc); }
        if(action==3) {
            if(nav.timers.s["airStart"]==null) { recording.closePhase(0,0,0,0); nav.timers.takeoff(utc); }
            else {
                var period=nav.timers.s["periods"][nav.timers.s["periods"].size()-1];
                recording.closePhase(1,nav.timers.s["elapsed"]-nav.timers.s["airStart"],period["takeoffUtc"],utc); nav.timers.land(utc);
            }
        }
        if(action==4) {
            recording.prepareFinal(nav); var saved=recording.save(nav.timers.airborne());
            if(saved || recording.session==null) {
                nav.s["fitPending"]=false; nav.s["fitOutcome"]=saved ? "saved" : "localOnly"; nav.finish(utc);
                if(!saved) { recording.cleanupGps(); notice="Saved locally - no FIT"; }
            } else { recordBoundary(utc,"saveFailed"); notice=recording.status; }
        }
    }
}
function monotonicDelta(now,previous) { var delta=now.toLong()-previous.toLong(); return delta<0 ? delta+4294967296l : delta; }
