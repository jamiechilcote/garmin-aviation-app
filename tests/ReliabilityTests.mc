import Toybox.Test;
import Toybox.Lang;
(:test) class TestField { function initialize() {} function setData(value) {} }
(:test) class TestGps {
    var enabled=false; var fault=false; var quality="GPS off"; var failStart=false; var failStop=false;
    function initialize() {}
    function start() { if(failStart) { throw new Lang.Exception(); } enabled=true; return true; }
    function stop() { if(failStop) { throw new Lang.Exception(); } enabled=false; return true; }
}
(:test) class TestSession {
    var recording=false; var failStart=false; var failStop=false; var failSave=false; var throwSave=false; var throwStart=false; var saved=0;
    function initialize() {}
    function isRecording() { return recording; }
    function start() { if(throwStart) { throw new Lang.Exception(); } if(failStart) { return false; } recording=true; return true; }
    function stop() { if(failStop) { return false; } recording=false; return true; }
    function save() { if(throwSave) { throw new Lang.Exception(); } if(failSave) { return false; } saved+=1; return true; }
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
    Test.assertEqual(e.size(),1); Test.assertEqual(e[0]["kind"],"arrivalDue");
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
    var app=new NavlogApp(); app.testing=true; app.lastMillis=Toybox.System.getTimer();
    var r=new TestRecording(); r.failCreate=true; app.recording=r; app.input("select");
    Test.assert(app.nav.s["started"]); Test.assertEqual(app.recording.state,"unavailable");
    app.lastInput=null; app.input("select"); Test.assertEqual(app.nav.check.s["state"],"running");
    app.lastInput=null; app.input("down"); Test.assertEqual(app.screen,"timers");
    app.execute(4,1100); Test.assert(app.nav.s["finished"]); Test.assertEqual(app.nav.s["fitOutcome"],"localOnly"); return true;
}
(:test) function recoveredNavigationWhenFitUnavailable(logger) {
    var n=new Navigation(); n.start(1000); n.checkAction(1000); var p=new Persistence();
    var app=new NavlogApp(); app.testing=true; app.lastMillis=Toybox.System.getTimer(); app.nav=p.restore(p.snapshot(n,1000),1400);
    app.screen="recovery"; var r=new TestRecording(); r.failCreate=true; app.recording=r;
    app.input("select"); Test.assertEqual(app.screen,"nav"); Test.assertEqual(app.nav.s["index"],0);
    Test.assertEqual(app.deliveredEvents,1); app.lastInput=null; app.input("down"); Test.assertEqual(app.screen,"timers"); return true;
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
