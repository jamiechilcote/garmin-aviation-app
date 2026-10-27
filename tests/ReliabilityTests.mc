import Toybox.Test;
import Toybox.Lang;
(:test) class TestField { var data=null; function initialize() {} function setData(value) { data=value; } }
(:test) class TestGps {
    var enabled=false; var fault=false; var quality="GPS off"; var failStart=false; var failStop=false;
    function initialize() {}
    function start() { if(failStart) { throw new Lang.Exception(); } enabled=true; return true; }
    function stop() { if(failStop) { throw new Lang.Exception(); } enabled=false; return true; }
}
(:test) class TestSession {
    var startCalls=0; var discarded=0; var failDiscard=false; var throwDiscard=false; var stopReturnsFalseAfterStopping=false; var laps=0; var failLap=false; var recording=false; var failStart=false; var failStop=false; var failSave=false; var throwSave=false; var throwStart=false; var saved=0;
    function initialize() {}
    function isRecording() { return recording; }
    function discard() { if(throwDiscard) { throw new Lang.Exception(); } if(failDiscard) { return false; } discarded+=1; return true; }
    function start() { startCalls+=1; if(throwStart) { throw new Lang.Exception(); } if(failStart) { return false; } recording=true; return true; }
    function stop() { if(failStop) { return false; } recording=false; return !stopReturnsFalseAfterStopping; }
    function save() { if(throwSave) { throw new Lang.Exception(); } if(failSave) { return false; } saved+=1; return true; }
    function addLap() { if(failLap) { return false; } laps+=1; return true; }
    function createField(name,id,type,options) { return new TestField(); }
}
(:test) class TestRecording extends Recording {
    var fake; var failCreate=false;
    function initialize() { Recording.initialize(); fake=new TestSession(); gps=new TestGps(); }
    function createSession() { if(failCreate) { throw new Lang.Exception(); } return fake; }
}
(:test) class UnreadableSlotPersistence extends Persistence {
    var fallback;
    function initialize() { Persistence.initialize(); }
    function readSlot(slot) { if(slot==0) { throw new Lang.Exception(); } return fallback; }
}
(:test) function finishEarlyHistory(logger) {
    var n=new Navigation(); n.start(1000); n.timers.s["elapsed"]=120; n.finish(1120);
    var leg=n.s["legs"][0]; Test.assert(leg["waypointReachedUtc"]==null); Test.assertEqual(leg["legClosedUtc"],1120);
    Test.assertEqual(leg["actualSeconds"],120); Test.assertEqual(leg["closure"],"sessionEnded"); return true;
}
(:test) function finishAirborneIncomplete(logger) {
    var n=new Navigation(); n.start(1000); n.timers.s["elapsed"]=10; n.timers.takeoff(1010);
    n.timers.s["elapsed"]=100; n.finish(1100); var p=n.timers.s["periods"][0];
    Test.assert(p["landingUtc"]==null); Test.assertEqual(p["closedUtc"],1100); Test.assertEqual(p["status"],"unconfirmed");
    Test.assertEqual(n.timers.airborne(),90); Test.assert(new Persistence().valid(new Persistence().snapshot(n,1100))); return true;
}
(:test) function normalLandingThenFinish(logger) {
    var n=new Navigation(); n.start(1000); n.timers.takeoff(1000); n.timers.s["elapsed"]=50; n.timers.land(1050);
    n.timers.s["elapsed"]=100; n.finish(1100); Test.assertEqual(n.timers.s["periods"][0]["landingUtc"],1050);
    Test.assertEqual(n.timers.airborne(),50); Test.assertEqual(n.timers.s["elapsed"],100); return true;
}
(:test) function actualWaypointSeparate(logger) {
    var n=new Navigation(); n.start(1000); n.timers.s["elapsed"]=90; n.advance(1090);
    Test.assertEqual(n.s["legs"][0]["waypointReachedUtc"],1090); Test.assertEqual(n.s["legs"][0]["actualSeconds"],90);
    n.finish(1091); Test.assert(n.s["legs"][1]["waypointReachedUtc"]==null); return true;
}
(:test) function recoveryDueExactlyOnce(logger) {
    var n=new Navigation(); n.start(1000); n.checkAction(1000); var p=new Persistence();
    var r=p.restore(p.snapshot(n,1000),1400); var events=r.takeEvents();
    Test.assertEqual(events.size(),1); Test.assertEqual(events[0]["kind"],"checkDue");
    r.tick(); Test.assertEqual(r.takeEvents().size(),0); r.checkAction(1400); r.tick();
    Test.assertEqual(r.takeEvents().size(),0); Test.assertEqual(r.check.s["dueElapsed"],760); return true;
}
(:test) function undoArrivalRetainsEvent(logger) {
    var n=new Navigation(); n.start(1000); n.timers.s["elapsed"]=100; n.advance(1100);
    n.timers.s["elapsed"]=950; n.undo(1950); var e=n.takeEvents();
    var arrivals=0; for(var i=0;i<e.size();i+=1) { if(e[i]["kind"].equals("arrivalDue")) { arrivals+=1; } } Test.assertEqual(arrivals,1);
    n.tick(); Test.assertEqual(n.takeEvents().size(),0); return true;
}
(:test) function centralDeliveryDrainsOnce(logger) {
    var app=new NavlogApp(); app.testing=true; app.nav.start(1000); app.nav.checkAction(1000);
    app.nav.timers.s["elapsed"]=400; app.nav.tick(); Test.assert(app.deliverEvents());
    Test.assertEqual(app.deliveredEvents,1); Test.assert(!app.deliverEvents()); return true;
}
(:test) function saveCleanupCannotUndoSuccess(logger) {
    var r=new TestRecording(); Test.assert(r.start()); r.gps.failStop=true;
    Test.assert(r.save(100)); Test.assertEqual(r.state,"saved"); Test.assertEqual(r.fake.saved,1);
    Test.assert(r.cleanupWarning); Test.assert(r.save(100)); Test.assertEqual(r.fake.saved,1); return true;
}
(:test) function failedSaveResumesFit(logger) {
    var r=new TestRecording(); r.start(); r.fake.failSave=true;
    Test.assert(!r.save(10)); Test.assert(r.fake.recording); Test.assertEqual(r.state,"recording");
    r.fake.failSave=false; Test.assert(r.save(20)); return true;
}
(:test) function failedSaveAndRestartIsExplicit(logger) {
    var r=new TestRecording(); r.start(); r.fake.throwSave=true; r.fake.failStart=true;
    Test.assert(!r.save(10)); Test.assertEqual(r.state,"savePending"); Test.assert(r.warning);
    r.fake.throwSave=false; r.fake.failStart=false; Test.assert(r.start()); Test.assert(r.save(20)); return true;
}
(:test) function stopFailureDoesNotSave(logger) {
    var r=new TestRecording(); r.start(); r.fake.failStop=true;
    Test.assert(!r.save(10)); Test.assertEqual(r.fake.saved,0); Test.assert(r.fake.recording); return true;
}
(:test) function gpsFailureDoesNotBlockFit(logger) {
    var r=new TestRecording(); r.gps.failStart=true;
    Test.assert(r.start()); Test.assert(r.fake.recording); Test.assert(r.warning); Test.assert(!r.gps.enabled); return true;
}
(:test) function fitCreationCleansGps(logger) {
    var r=new TestRecording(); r.failCreate=true; Test.assert(!r.start()); Test.assert(!r.gps.enabled);
    r.failCreate=false; Test.assert(r.start()); return true;
}
(:test) function fitStartFailureRetry(logger) {
    var r=new TestRecording(); r.fake.failStart=true; Test.assert(!r.start()); Test.assert(!r.gps.enabled);
    r.fake.failStart=false; Test.assert(r.start()); return true;
}
(:test) function manualNavigationWhenFitUnavailable(logger) {
    var app=V2Harness.selected(); var r=new TestRecording(); r.failCreate=true; app.recording=r;
    app.execute(12,1000); Test.assert(app.nav.s["started"]); Test.assertEqual(r.state,"unavailable");
    app.execute(14,1001); V2Harness.press(app,"select"); Test.assert(app.nav.timers.s["airStart"]!=null);
    V2Harness.press(app,"select"); Test.assertEqual(app.nav.check.s["state"],"running");
    V2Harness.press(app,"back"); Test.assertEqual(app.screen,"timers");
    app.execute(4,1100); Test.assert(app.nav.s["finished"]); app.execute(10,1101);
    Test.assert(app.nav.s["finished"]); Test.assertEqual(app.nav.s["fitOutcome"],"localOnly"); return true;
}
(:test) function recoveredNavigationWhenFitUnavailable(logger) {
    var n=new Navigation(); n.start(1000); n.checkAction(1000); var p=new Persistence();
    var app=V2Harness.active(); app.nav=p.restore(p.snapshot(n,1000),1400);
    app.screen="recovery"; var r=new TestRecording(); r.failCreate=true; app.recording=r;
    app.execute(8,1400); app.execute(14,1400); Test.assertEqual(app.screen,"nav");
    Test.assertEqual(app.nav.s["index"],0); Test.assert(app.deliverEvents());
    V2Harness.press(app,"back"); Test.assertEqual(app.screen,"timers"); return true;
}
(:test) function corruptionBoundaries(logger) {
    var p=new Persistence(); var n=new Navigation(); n.start(1000); var data=p.snapshot(n,1000);
    var d=deepCopy(data); d["timers"]["elapsed"]="bad"; Test.assert(!p.valid(d));
    d=deepCopy(data); d["clearoff"]["state"]="invented"; Test.assert(!p.valid(d));
    d=deepCopy(data); d["navigation"]["checks"]=[{"leg"=>0}]; Test.assert(!p.valid(d));
    d=deepCopy(data); d["timers"]["periods"]=[null]; Test.assert(!p.valid(d));
    d=deepCopy(data); d["undo"]={"index"=>99}; Test.assert(!p.valid(d));
    d=deepCopy(data); d["navigation"]["events"]=[{"kind"=>"wrong","leg"=>0,"dueUtc"=>1000}]; Test.assert(!p.valid(d));
    d=deepCopy(data); d["navigation"]["legs"][0]["heading"]=-1; Test.assert(!p.valid(d)); return true;
}
(:test) function independentUnreadableCheckpoint(logger) {
    var p=new UnreadableSlotPersistence(); var n=new Navigation(); n.start(1000); p.fallback=p.snapshot(n,1000);
    var data=p.load(); Test.assert(data!=null); Test.assert(p.error); Test.assertEqual(p.errors.size(),1);
    Test.assertEqual(data["savedUtc"],1000); return true;
}
(:test) function progressMatchesAcknowledgements(logger) {
    var n=new Navigation(); n.start(1000); n.checkAction(1000); Test.assertEqual(n.progress()["total"],3);
    n.timers.s["elapsed"]=400; n.checkAction(1400); Test.assertEqual(n.progress()["done"],1);
    Test.assertEqual(n.progress()["current"],2); n.timers.s["elapsed"]=760; n.checkAction(1760);
    Test.assertEqual(n.check.interval(),180); n.timers.s["elapsed"]=940; n.checkAction(1940);
    Test.assertEqual(n.progress()["done"],3); Test.assertEqual(n.s["index"],0); return true;
}

(:test) function fitAirborneLapBoundaries(logger) {
    var r=new TestRecording(); r.start(); Test.assert(r.closePhase(0,0,0,0));
    Test.assert(r.closePhase(1,100,1000,1100)); Test.assertEqual(r.fake.laps,2);
    Test.assertEqual(r.phaseField.data,0);
    var n=new Navigation(); n.start(1000); n.timers.takeoff(1000); n.timers.s["elapsed"]=90;
    r.prepareFinal(n); Test.assertEqual(r.phaseField.data,2); Test.assertEqual(r.landingField.data,0);
    Test.assertEqual(r.phaseSecondsField.data,90); Test.assertEqual(r.takeoffField.data,1000); return true;
}
(:test) function lapFailureDoesNotInventFlightEvents(logger) {
    var app=new NavlogApp(); app.testing=true; app.nav.start(1000); var r=new TestRecording(); app.recording=r; r.start(); r.fake.failLap=true;
    app.execute(3,1000); Test.assert(app.nav.timers.s["airStart"]!=null); app.nav.timers.s["elapsed"]=30; app.execute(3,1030);
    Test.assertEqual(app.nav.timers.s["periods"][0]["landingUtc"],1030); Test.assert(r.warning); Test.assertEqual(r.fake.laps,0); return true;
}
// Native lap records need distinct elapsed timestamps. This is a simulator-only integration test.
(:test) function nativeFlyingFitLapSmoke(logger) {
    var r=new Recording(); Test.assert(r.start()); var allLaps=true;
    var utc=Toybox.Time.now().value();
    for(var phase=0;phase<4;phase+=1) {
        var mark=Toybox.System.getTimer();
        while(monotonicDelta(Toybox.System.getTimer(),mark)<1100) {}
        var end=Toybox.Time.now().value();
        var ok=r.closePhase(phase%2==0 ? 0 : 1,phase%2==0 ? 0 : 1,phase%2==0 ? 0 : utc,phase%2==0 ? 0 : end);
        if(!ok) { logger.error("Native lap rejected: "+r.status); allLaps=false; }
        utc=end;
    }
    var saved=r.save(2); Test.assert(saved); Test.assert(allLaps);
    logger.debug("Saved native simulator FIT: two synthetic airborne periods, real elapsed lap boundaries, GPS not asserted.");
    return true;
}
(:test) function alertModeStorageRoundTrip(logger) {
    var previous=Toybox.Application.Storage.getValue("alertMode");
    try {
        var app=new NavlogApp(); app.alerts.mode=1; app.alertChoice=2; app.execute(5,1000);
        Test.assertEqual(Toybox.Application.Storage.getValue("alertMode"),2);
        var reopened=new NavlogApp(); reopened.loadAlertMode(); Test.assertEqual(reopened.alerts.mode,2);
    } finally {
        if(previous==null) { Toybox.Application.Storage.deleteValue("alertMode"); }
        else { Toybox.Application.Storage.setValue("alertMode",previous); }
    }
    return true;
}
(:test) function supportedAttentionModes(logger) {
    Test.assert(Toybox.Attention has :vibrate); Test.assert(Toybox.Attention has :playTone);
    var alerts=new Alerts(); for(var i=0;i<4;i+=1) { alerts.mode=i; alerts.fire(); }
    return true;
}
(:test) function corruptUndoAndStickyErrors(logger) {
    var p=new Persistence(); var n=new Navigation(); n.start(1000); n.advance(1010);
    var data=p.snapshot(n,1010); data["undo"]["index"]=1;
    Test.assert(!p.valid(data));
    p.fail("same failure"); p.fail("same failure"); Test.assertEqual(p.errors.size(),1); Test.assert(p.error); return true;
}

(:test) function ambiguousStopFailureResumes(logger) {
    var r=new TestRecording(); r.start(); r.fake.stopReturnsFalseAfterStopping=true;
    Test.assert(!r.save(10)); Test.assert(r.fake.recording); Test.assertEqual(r.state,"recording"); return true;
}
(:test) function cleanupRetryAfterFinished(logger) {
    var app=new NavlogApp(); app.testing=true; var r=new TestRecording(); app.recording=r; r.start();
    app.nav.start(1000); r.gps.failStop=true; app.execute(4,1100); Test.assert(app.nav.s["finished"]);
    Test.assert(r.cleanupWarning); r.gps.failStop=false; app.execute(8,1101); Test.assert(!r.cleanupWarning); Test.assert(!r.gps.enabled); return true;
}
(:test) function recoveryBackShowsManualRecordingWarning(logger) {
    var n=new Navigation(); n.start(1000); var p=new UnreadableSlotPersistence(); p.fallback=p.snapshot(n,1000);
    var app=new NavlogApp(); app.testing=true; app.persistence=p; app.lastMillis=Toybox.System.getTimer();
    app.loadRecovery(1100); Test.assertEqual(app.screen,"recovery"); Test.assert(app.recording.warning);
    Test.assertEqual(app.recording.state,"paused"); app.input("back"); Test.assertEqual(app.screen,"nav");
    Test.assertEqual(app.nav.timers.s["elapsed"],100); return true;
}
(:test) function localFinishRetainsUnsavedFit(logger) {
    var app=new NavlogApp(); app.testing=true; app.nav.start(1000); var r=new TestRecording(); app.recording=r;
    r.fake.failStart=true; Test.assert(!r.start()); Test.assert(r.session!=null);
    app.nav.timers.takeoff(1000); app.nav.timers.s["elapsed"]=90; app.execute(10,1090);
    Test.assert(app.nav.s["finished"]); Test.assertEqual(app.nav.s["fitOutcome"],"localOnly");
    Test.assert(app.nav.timers.s["periods"][0]["landingUtc"]==null); Test.assert(r.session!=null); Test.assert(app.nav.s["fitPending"]);
    app.execute(6,1091); Test.assert(app.nav.s["finished"]); return true;
}
(:test) function lateSavePreservesLocalEndAndIncompletePhase(logger) {
    var app=new NavlogApp(); app.testing=true; app.nav.start(1000); var r=new TestRecording(); app.recording=r; r.start();
    app.nav.timers.takeoff(1000); app.nav.timers.s["elapsed"]=90; app.execute(10,1090);
    Test.assertEqual(app.nav.s["finishUtc"],1090); app.execute(4,1200);
    Test.assertEqual(r.state,"saved"); Test.assertEqual(app.nav.s["finishUtc"],1090);
    Test.assertEqual(r.phaseField.data,2); Test.assertEqual(r.landingField.data,0);
    Test.assert(app.nav.s["legs"][0]["waypointReachedUtc"]==null); return true;
}

(:test) function pendingFitPreventsSilentNewFlightAfterRestart(logger) {
    var n=new Navigation(); n.start(1000); n.s["fitPending"]=true; n.s["fitOutcome"]="localOnly"; n.finish(1100);
    var p=new Persistence(); var restored=p.restore(p.snapshot(n,1100),1200);
    var app=new NavlogApp(); app.testing=true; app.nav=restored; app.execute(6,1200);
    Test.assert(app.nav.s["finished"]); Test.assert(app.nav.s["fitPending"]); return true;
}
(:test) function legacyCheckpointMigrationIsConservative(logger) {
    var n=new Navigation(); n.start(1000); n.timers.takeoff(1000); n.timers.s["elapsed"]=10; n.timers.land(1010);
    n.timers.s["elapsed"]=20; n.advance(1020); var p=new Persistence(); var data=deepCopy(p.snapshot(n,1020)); data["version"]=1;
    for(var i=0;i<data["navigation"]["legs"].size();i+=1) {
        var l=data["navigation"]["legs"][i]; l["finishUtc"]=l["legClosedUtc"];
        l.remove("legClosedUtc"); l.remove("waypointReachedUtc"); l.remove("closure");
    }
    var period=data["timers"]["periods"][0]; period.remove("closedUtc"); period.remove("status");
    Test.assert(p.valid(data)); var restored=p.restore(data,1030);
    Test.assertEqual(restored.s["legs"][0]["closure"],"legacyUnknown"); Test.assert(restored.s["legs"][0]["waypointReachedUtc"]==null);
    Test.assertEqual(restored.timers.s["periods"][0]["status"],"legacyUnknown"); Test.assert(p.valid(p.snapshot(restored,1030)));
    data["timers"]["airTotal"]=9; Test.assert(!p.valid(data)); return true;
}
(:test) function pendingFitBlocksExplicitExit(logger) {
    var app=new NavlogApp(); app.testing=true; app.nav.start(1000); app.nav.s["fitPending"]=true; app.nav.finish(1100);
    app.execute(7,1101); Test.assertEqual(app.notice,"Save pending FIT first");
    app.nav.s["fitPending"]=false; app.recording=new TestRecording(); app.recording.start(); app.notice=null;
    app.execute(7,1102); Test.assertEqual(app.notice,"Save pending FIT first"); return true;
}
