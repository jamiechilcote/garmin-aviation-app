import Toybox.Test;
(:test) class V2Harness {
    static function press(app,key) { app.lastInput=null; app.input(key); }
    static function selected() {
        var app=new NavlogApp(); app.testing=true; app.lastMillis=Toybox.System.getTimer(); app.nav.selectPlan(FlightPlan.DEFAULT_ID); app.screen="summary"; app.recording=new TestRecording(); return app;
    }
    static function active() { var app=selected(); app.execute(12,1000); return app; }
}
(:test) class V2MemoryPersistence extends Persistence {
    var slots=[null,null]; var failWrite=false;
    function initialize() { Persistence.initialize(); }
    function readSlot(slot) { return slots[slot]; }
    function writeSlot(slot,data) { if(failWrite) { throw new Toybox.Lang.Exception(); } slots[slot]=deepCopy(data); }
}
(:test) function v2NoFlightSelection(logger) {
    var app=new NavlogApp(); app.testing=true; app.persistence=new V2MemoryPersistence(); app.loadRecovery(1000);
    Test.assertEqual(app.screen,"select"); Test.assertEqual(app.flightState(),"NO_FLIGHT");
    V2Harness.press(app,"down"); Test.assertEqual(app.planChoice,1); V2Harness.press(app,"select");
    Test.assertEqual(app.screen,"summary"); Test.assertEqual(app.flightState(),"PLAN_SELECTED");
    Test.assert(!app.nav.s["started"]); Test.assert(app.recording.session==null);
    V2Harness.press(app,"back"); Test.assertEqual(app.screen,"select"); return true;
}
(:test) function v2StartConfirmationExactlyOnce(logger) {
    var app=V2Harness.selected(); var r=app.recording; V2Harness.press(app,"select"); Test.assertEqual(app.screen,"confirm"); Test.assert(!app.nav.s["started"]);
    V2Harness.press(app,"back"); Test.assertEqual(app.screen,"summary"); Test.assertEqual(r.fake.startCalls,0);
    V2Harness.press(app,"select"); V2Harness.press(app,"select"); app.input("select");
    Test.assertEqual(r.fake.startCalls,1); Test.assertEqual(app.flightState(),"GROUND_ACTIVE"); Test.assert(app.nav.timers.s["airStart"]==null);
    app.execute(12,1001); Test.assertEqual(r.fake.startCalls,1); return true;
}
(:test) function v2ContextStartFlight(logger) {
    var app=V2Harness.active(); Test.assertEqual(app.primaryAction(),"TAKEOFF"); V2Harness.press(app,"select");
    Test.assertEqual(app.nav.timers.s["periods"].size(),1); Test.assertEqual(app.flightState(),"AIRBORNE_CHECKS_IDLE");
    Test.assertEqual(app.primaryAction(),"START CHECKS"); V2Harness.press(app,"select");
    Test.assertEqual(app.flightState(),"AIRBORNE_CHECKS_RUNNING"); Test.assertEqual(app.primaryAction(),"COMPLETE CHECK");
    app.nav.timers.s["elapsed"]=300; V2Harness.press(app,"select");
    Test.assertEqual(app.nav.progress()["done"],1); Test.assertEqual(app.nav.check.countdown(app.nav.timers.s["elapsed"]),360);
    Test.assert(app.nav.s["checks"][0]["ackUtc"]<app.nav.s["checks"][0]["dueUtc"]); return true;
}
(:test) function v2EarlyAndLateFixedSegments(logger) {
    var n=new Navigation(); n.start(1000); n.checkAction(1000); n.timers.s["elapsed"]=300; n.checkAction(1300);
    Test.assertEqual(n.s["checks"][0]["dueUtc"],1360); Test.assertEqual(n.s["checks"][0]["ackUtc"],1300); Test.assertEqual(n.check.s["dueElapsed"],660);
    n.timers.s["elapsed"]=700; n.checkAction(1700); Test.assertEqual(n.s["checks"][1]["dueUtc"],1660); Test.assertEqual(n.check.s["dueElapsed"],880);
    n.timers.s["elapsed"]=750; n.checkAction(1750); Test.assertEqual(n.check.s["state"],"complete");
    Test.assertEqual(n.progress()["done"],3); Test.assertEqual(n.s["index"],0); return true;
}
(:test) function v2AntiDoubleCheck(logger) {
    var app=V2Harness.active(); app.execute(3,1000); app.nav.checkAction(1000); app.nav.timers.s["elapsed"]=300;
    V2Harness.press(app,"select"); app.input("select"); Test.assertEqual(app.nav.progress()["done"],1);
    // Even a deliberately separated controller input cannot consume a just-created interval.
    V2Harness.press(app,"select"); Test.assertEqual(app.nav.progress()["done"],1);
    app.nav.timers.s["elapsed"]=302; V2Harness.press(app,"select"); Test.assertEqual(app.nav.progress()["done"],2); return true;
}
(:test) function v2StartOverdueAndComplete(logger) {
    var app=V2Harness.active(); app.execute(3,1000); app.nav.checkAction(1000); app.nav.timers.s["elapsed"]=400; app.nav.tick();
    V2Harness.press(app,"select"); Test.assertEqual(app.nav.check.s["dueElapsed"],760); Test.assertEqual(app.nav.progress()["done"],1);
    app.nav.timers.s["elapsed"]=760; V2Harness.press(app,"select"); app.nav.timers.s["elapsed"]=940; V2Harness.press(app,"select");
    Test.assertEqual(app.flightState(),"AIRBORNE_CHECKS_COMPLETE"); Test.assertEqual(app.primaryAction(),"CHECKS COMPLETE"); return true;
}
(:test) function v2LandingSecondTakeoff(logger) {
    var app=V2Harness.active(); V2Harness.press(app,"select"); app.nav.timers.s["elapsed"]=100; app.selectAction(3,"menu");
    Test.assert(app.nav.timers.s["airStart"]!=null); V2Harness.press(app,"select");
    Test.assertEqual(app.flightState(),"LANDED"); Test.assert(!app.nav.s["finished"]); Test.assert(app.recording.session!=null);
    V2Harness.press(app,"select"); Test.assertEqual(app.nav.timers.s["periods"].size(),2); Test.assertEqual(app.recording.fake.startCalls,1); return true;
}
(:test) function v2UndoAllCheckStates(logger) {
    var variants=[0,300,400,940];
    for(var i=0;i<variants.size();i+=1) {
        var n=new Navigation(); n.start(1000); n.checkAction(1000); var elapsed=variants[i];
        if(i==1) { n.timers.s["elapsed"]=300; n.checkAction(1300); }
        if(i==3) { n.timers.s["elapsed"]=360; n.checkAction(1360); n.timers.s["elapsed"]=720; n.checkAction(1720); n.timers.s["elapsed"]=900; n.checkAction(1900); }
        n.timers.s["elapsed"]=elapsed; n.tick(); var state=n.check.s["state"]; var due=n.check.s["dueElapsed"]; var count=n.s["checks"].size();
        n.advance(1000+elapsed); Test.assertEqual(n.check.s["state"],"idle"); n.undo(1000+elapsed);
        Test.assertEqual(n.check.s["state"],state); Test.assertEqual(n.check.s["dueElapsed"],due); Test.assertEqual(n.s["checks"].size(),count);
        var before=n.s["events"].size(); n.tick(); Test.assertEqual(n.s["events"].size(),before);
    } return true;
}
(:test) function v2GpsCannotChangeSegments(logger) {
    var n=new Navigation(); n.start(1000); n.checkAction(1000); var gps=new GpsRecorder();
    var info=new Toybox.Position.Info(); gps.onPosition(info); Test.assertEqual(n.check.s["dueElapsed"],360);
    gps.quality="synthetic changed fix"; n.timers.s["elapsed"]=300; n.checkAction(1300); Test.assertEqual(n.check.s["dueElapsed"],660); return true;
}
(:test) function v2MenuRingAndBack(logger) {
    var app=V2Harness.active(); V2Harness.press(app,"back"); Test.assertEqual(app.screen,"timers");
    V2Harness.press(app,"down"); Test.assertEqual(app.selected,0); Test.assertEqual(app.screen,"menu");
    V2Harness.press(app,"up"); Test.assertEqual(app.screen,"timers"); V2Harness.press(app,"up"); Test.assertEqual(app.selected,app.menuIds().size()-1);
    V2Harness.press(app,"down"); Test.assertEqual(app.screen,"timers"); V2Harness.press(app,"back"); Test.assertEqual(app.screen,"nav");
    V2Harness.press(app,"up"); Test.assertEqual(app.selected,app.menuIds().size()-1); V2Harness.press(app,"back"); Test.assertEqual(app.screen,"timers");
    Test.assert(!app.nav.s["finished"]); Test.assertEqual(app.recording.fake.saved,0); Test.assertEqual(app.recording.fake.discarded,0); return true;
}
(:test) function v2ContextMenusAndConfirmations(logger) {
    var app=V2Harness.active(); var ids=app.menuIds();
    for(var i=0;i<ids.size();i+=1) { Test.assert(ids[i]!=0 && ids[i]!=2 && ids[i]!=8 && ids[i]!=9 && ids[i]!=10); }
    app.selectAction(4,"menu"); Test.assertEqual(app.screen,"confirm"); Test.assertEqual(app.recording.fake.saved,0);
    V2Harness.press(app,"back"); app.selectAction(11,"menu"); Test.assertEqual(app.recording.fake.discarded,0); V2Harness.press(app,"back");
    Test.assert(!app.nav.s["finished"]); return true;
}
(:test) function v2RadioOnlyOnChanges(logger) {
    var app=V2Harness.active(); Test.assert(!app.nav.s["radioPending"]);
    app.nav.plan[1]["active"]=app.nav.plan[0]["active"]; app.nav.plan[1]["standby"]=app.nav.plan[0]["standby"];
    app.execute(1,1100); Test.assertEqual(app.screen,"nav"); Test.assert(!app.nav.s["radioPending"]);
    app.execute(1,1200); Test.assertEqual(app.screen,"radio"); Test.assert(app.nav.s["radioPending"]);
    V2Harness.press(app,"back"); Test.assert(app.nav.s["radioPending"]); V2Harness.press(app,"back"); Test.assertEqual(app.screen,"timers");
    app.selectAction(13,"menu"); V2Harness.press(app,"select"); Test.assert(!app.nav.s["radioPending"]); return true;
}
(:test) function v2AlertListCancelAndSave(logger) {
    var app=V2Harness.active(); app.alerts.mode=0; app.selectAction(5,"menu"); V2Harness.press(app,"up"); Test.assertEqual(app.alertChoice,2);
    V2Harness.press(app,"back"); Test.assertEqual(app.alerts.mode,0); app.selectAction(5,"menu");
    V2Harness.press(app,"down"); Test.assertEqual(app.alertChoice,1); V2Harness.press(app,"select"); Test.assertEqual(app.alerts.mode,1); return true;
}
(:test) function v2FinishVerifiedAndNoFabrication(logger) {
    var app=V2Harness.active(); app.execute(3,1000); app.nav.timers.s["elapsed"]=90; app.selectAction(4,"menu"); V2Harness.press(app,"select");
    Test.assertEqual(app.screen,"completed"); Test.assertEqual(app.nav.s["fitOutcome"],"saved"); Test.assertEqual(app.recording.fake.saved,1);
    Test.assert(app.nav.timers.s["periods"][0]["landingUtc"]==null); Test.assert(app.nav.s["legs"][0]["waypointReachedUtc"]==null);
    app.safeExit(); Test.assert(app.exitRequested); return true;
}
(:test) function v2FailedSaveStaysPending(logger) {
    var app=V2Harness.active(); app.recording.fake.failSave=true; app.execute(4,1100);
    Test.assertEqual(app.screen,"recovery"); Test.assert(app.nav.s["fitPending"]); Test.assertEqual(app.flightState(),"RECOVERY_REQUIRED");
    app.safeExit(); Test.assert(!app.exitRequested); Test.assert(app.nav.s["finished"]); Test.assertEqual(app.nav.s["finishUtc"],1100);
    app.recording.fake.failSave=false; app.execute(4,1200); Test.assertEqual(app.screen,"completed"); return true;
}
(:test) function v2LocalSaveFailureDoesNotExit(logger) {
    var app=V2Harness.active(); app.testing=false; var p=new V2MemoryPersistence(); p.failWrite=true; app.persistence=p;
    app.execute(4,1100); Test.assertEqual(app.screen,"recovery"); Test.assert(app.nav.s["finishRequested"]); Test.assertEqual(app.recording.fake.saved,1);
    app.testing=true; app.safeExit(); Test.assert(!app.exitRequested); app.execute(4,1200); Test.assertEqual(app.recording.fake.saved,1); Test.assertEqual(app.screen,"completed"); return true;
}
(:test) function v2DiscardFailureRetainsNative(logger) {
    var app=V2Harness.active(); var r=app.recording; r.fake.failDiscard=true; app.execute(11,1100);
    Test.assertEqual(r.fake.discarded,0); Test.assert(r.session!=null); Test.assertEqual(app.screen,"recovery"); app.safeExit(); Test.assert(!app.exitRequested);
    r.fake.failDiscard=false; app.execute(11,1200); Test.assertEqual(r.fake.discarded,1); Test.assertEqual(app.screen,"completed"); Test.assert(app.nav.s["discarded"]); return true;
}
(:test) function v2DiscardUnknownNativeIsBlocked(logger) {
    var app=V2Harness.active(); app.recording=new TestRecording(); app.execute(11,1100);
    Test.assertEqual(app.recording.fake.discarded,0); Test.assert(!app.nav.s["discarded"]); Test.assertEqual(app.screen,"recovery"); return true;
}
(:test) function v2RestartDoesNotCreateDuplicate(logger) {
    var app=V2Harness.active(); var n=app.nav; n.checkAction(1000); var p=new V2MemoryPersistence(); p.slots[0]=p.snapshot(n,1000);
    var reopened=new NavlogApp(); reopened.testing=true; reopened.recording=new TestRecording(); reopened.persistence=p; reopened.loadRecovery(1400);
    Test.assertEqual(reopened.screen,"recovery"); Test.assertEqual(reopened.recording.fake.startCalls,0); Test.assertEqual(reopened.nav.check.s["state"],"due");
    reopened.execute(8,1400); Test.assertEqual(reopened.recording.fake.startCalls,0); Test.assert(reopened.nav.s["events"].size()>0);
    Test.assertEqual(reopened.nav.s["legs"].size(),1); return true;
}
(:test) function v2PendingCannotSelectOrDiscard(logger) {
    var app=V2Harness.active(); app.execute(10,1100); app.recording=new TestRecording(); app.screen="select"; app.choosePlan();
    Test.assertEqual(app.screen,"recovery"); Test.assert(app.nav.s["fitPending"]); app.execute(11,1200); Test.assert(app.nav.s["fitPending"]);
    app.safeExit(); Test.assert(!app.exitRequested); return true;
}
(:test) function v2PlanIdentityAndLegacyRecovery(logger) {
    var n=new Navigation(); n.selectPlan("demo-outbound-r1"); n.start(1000); n.timers.s["elapsed"]=100; var p=new Persistence();
    var data=p.snapshot(n,1100); Test.assert(p.valid(data)); var restored=p.restore(data,1200); Test.assertEqual(restored.plan.size(),2);
    restored.advance(1200); restored.advance(1201); Test.assertEqual(restored.check.s["state"],"legCompleted");
    var bad=deepCopy(data); bad["navigation"]["planId"]="unknown"; Test.assert(!p.valid(bad));
    bad=deepCopy(data); bad["navigation"]["planRevision"]="99"; Test.assert(!p.valid(bad));
    var legacy=new Navigation(); legacy.start(1000); data=p.snapshot(legacy,1000); data["navigation"].remove("planId"); data["navigation"].remove("planRevision");
    restored=p.restore(data,1100); Test.assertEqual(restored.plan.size(),4); Test.assertEqual(restored.s["planId"],FlightPlan.DEFAULT_ID); return true;
}
(:test) function v2DiscardTombstoneRoundTrip(logger) {
    var p=new Persistence(); p.prefix="v2-discard-test-"; var n=new Navigation(); n.start(1000); Test.assert(p.save(n,1000));
    Test.assert(p.discardCurrent(1100)); var reader=new Persistence(); reader.prefix=p.prefix; var restored=reader.restore(reader.load(),1200);
    Test.assert(restored.s["discarded"]); Test.assert(!restored.s["started"]); Test.assertEqual(restored.s["legs"].size(),0);
    Toybox.Application.Storage.deleteValue(p.prefix+"checkpoint0"); Toybox.Application.Storage.deleteValue(p.prefix+"checkpoint1"); return true;
}
(:test) function v2NativeDiscardSmoke(logger) {
    var r=new Recording(); Test.assert(r.start()); var mark=Toybox.System.getTimer(); while(monotonicDelta(Toybox.System.getTimer(),mark)<1100) {}
    Test.assert(r.discard()); Test.assertEqual(r.state,"discarded"); Test.assert(r.session==null); Test.assert(!r.gps.enabled); return true;
}

(:test) function v2PendingRadioSurvivesUnchangedLeg(logger) {
    var app=V2Harness.active(); app.execute(1,1100); V2Harness.press(app,"back");
    app.nav.plan[2]["active"]=app.nav.plan[1]["active"]; app.nav.plan[2]["standby"]=app.nav.plan[1]["standby"];
    app.execute(1,1200); Test.assertEqual(app.screen,"nav"); Test.assert(app.nav.s["radioPending"]); return true;
}

(:test) function v2FailedFinishFreezesLocalEnd(logger) {
    var app=V2Harness.active(); app.execute(3,1000); app.nav.timers.s["elapsed"]=90; app.recording.fake.failSave=true; app.execute(4,1090);
    Test.assertEqual(app.nav.s["finishUtc"],1090); Test.assert(app.nav.timers.s["periods"][0]["landingUtc"]==null);
    Test.assertEqual(app.nav.timers.airborne(),90); Test.assert(app.nav.s["legs"][0]["waypointReachedUtc"]==null);
    app.recording.fake.failSave=false; app.execute(4,1200); Test.assertEqual(app.nav.s["finishUtc"],1090); Test.assertEqual(app.nav.timers.airborne(),90); return true;
}
(:test) function v2NoNewFlightOverUnrecordedActiveSession(logger) {
    var app=V2Harness.selected(); app.recording.failCreate=true; app.execute(12,1000);
    Test.assertEqual(app.recording.state,"unavailable"); app.execute(6,1100);
    Test.assertEqual(app.notice,"Finish flight first"); Test.assert(app.nav.s["started"]); Test.assert(!app.nav.s["finished"]);
    app.screen="select"; app.choosePlan(); Test.assertEqual(app.screen,"recovery"); return true;
}
