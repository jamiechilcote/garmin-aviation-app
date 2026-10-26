import Toybox.Test;
(:test) function clearoffInterval(logger) {
    var c = new Clearoff(25.0,100.0); Test.assertEqual(c.interval(),360);
    c.start(0,1000); Test.assertEqual(c.countdown(60),300); return true;
}
(:test) function acknowledgementAnchor(logger) {
    var c = new Clearoff(25.0,100.0); c.start(0,1000);
    Test.assert(c.update(400)); Test.assertEqual(c.countdown(400),0);
    var r = c.acknowledge(400,1400); Test.assertEqual(r["dueUtc"],1360);
    Test.assertEqual(r["ackUtc"],1400); Test.assertEqual(c.s["dueElapsed"],760);
    Test.assert(c.acknowledge(401,1401) == null); return true;
}
(:test) function shortenedFinal(logger) {
    var c = new Clearoff(25.0,100.0); c.start(0,0); c.acknowledge(360,360);
    c.acknowledge(720,720); Test.assertEqual(c.s["dueElapsed"],900);
    c.acknowledge(900,900); Test.assertEqual(c.s["state"],"complete"); return true;
}
(:test) function manualWaypoints(logger) {
    var n = new Navigation(); n.start(1000); n.checkAction(1000);
    n.timers.s["elapsed"] = 1000; n.tick(); Test.assertEqual(n.s["index"],0);
    Test.assert(n.s["arrivalAlerted"]); n.advance(2000);
    Test.assertEqual(n.s["index"],1); Test.assertEqual(n.check.interval(),300);
    Test.assert(n.s["radioPending"]); n.undo(2001); Test.assertEqual(n.s["index"],0);
    Test.assertEqual(n.legSeconds(),1000); Test.assertEqual(n.s["legs"].size(),1); return true;
}
(:test) function independentAirborne(logger) {
    var n = new Navigation(); n.start(0); n.timers.s["elapsed"] = 10; n.timers.takeoff(10);
    n.timers.s["elapsed"] = 110; n.timers.land(110);
    n.timers.s["elapsed"] = 200; n.timers.takeoff(200);
    n.timers.s["elapsed"] = 250; n.timers.land(250);
    Test.assertEqual(n.timers.airborne(),150); Test.assertEqual(n.timers.s["elapsed"],250);
    Test.assertEqual(n.legSeconds(),250); Test.assertEqual(n.timers.s["periods"].size(),2); return true;
}
(:test) function hourBoundary(logger) {
    Test.assertEqual(durationText(3600),"60:00");
    var c = new Clearoff(10.0,120.0); c.start(3590,3590);
    Test.assertEqual(c.countdown(3601),289); Test.assert(!c.update(3601)); return true;
}
(:test) function accidentalInputs(logger) {
    var n = new Navigation(); n.advance(1); Test.assertEqual(n.s["legs"].size(),0);
    n.start(10); n.start(11); Test.assertEqual(n.s["legs"].size(),1);
    n.checkAction(10); n.checkAction(11); Test.assertEqual(n.check.s["dueUtc"],370);
    return true;
}
(:test) function unacknowledgedHistory(logger) {
    var n = new Navigation(); n.start(1000); n.checkAction(1000);
    n.timers.s["elapsed"] = 400; n.tick(); n.tick();
    Test.assertEqual(n.s["checks"].size(),1);
    Test.assert(n.s["checks"][0]["ackUtc"] == null);
    n.checkAction(1400); Test.assertEqual(n.s["checks"].size(),1);
    Test.assertEqual(n.s["checks"][0]["ackUtc"],1400); return true;
}
(:test) function restartRecovery(logger) {
    var n = new Navigation(); n.start(1000); n.checkAction(1000); n.timers.takeoff(1000);
    n.timers.s["elapsed"] = 100;
    var p = new Persistence(); var data = p.snapshot(n,1100);
    var restored = p.restore(data,1400);
    Test.assertEqual(restored.timers.s["elapsed"],400);
    Test.assertEqual(restored.timers.airborne(),400);
    Test.assertEqual(restored.check.s["state"],"due");
    Test.assertEqual(restored.s["index"],0);
    restored.checkAction(1400); Test.assertEqual(restored.check.s["dueElapsed"],760); return true;
}
(:test) function finalLegUndo(logger) {
    var n = new Navigation(); n.start(0);
    for(var i=0;i<4;i+=1) { n.timers.s["elapsed"] += 100; n.advance(n.timers.s["elapsed"]); }
    Test.assertEqual(n.check.s["state"],"legCompleted");
    n.timers.s["elapsed"] += 30; Test.assertEqual(n.legSeconds(),100);
    n.undo(430); Test.assertEqual(n.legSeconds(),130);
    Test.assertEqual(n.s["index"],3); return true;
}
(:test) function radioAndConfirmation(logger) {
    var app = new NavlogApp(); app.testing = true; app.lastMillis = Toybox.System.getTimer(); app.nav.start(1000);
    // Call the same input path used by physical buttons. Reset debounce between simulated presses.
    app.input("up"); app.lastInput=null; app.input("select");
    Test.assert(app.nav.s["radioPending"]); app.lastInput=null; app.input("select");
    Test.assert(!app.nav.s["radioPending"]);
    app.lastInput=null; app.input("up"); app.lastInput=null; app.input("down");
    app.lastInput=null; app.input("select"); Test.assertEqual(app.nav.s["index"],0);
    app.lastInput=null; app.input("back"); Test.assertEqual(app.nav.s["index"],0);
    return true;
}
(:test) function monotonicRollover(logger) {
    Test.assertEqual(monotonicDelta(-2147483600,2147483600),96l);
    Test.assertEqual(monotonicDelta(2500,1000),1500l); return true;
}
(:test) function repeatedButtonIgnored(logger) {
    var app = new NavlogApp(); app.testing=true; app.lastMillis=Toybox.System.getTimer(); app.nav.start(1000);
    app.screen="menu"; app.selected=1; app.input("select");
    app.input("select"); Test.assertEqual(app.nav.s["index"],0);
    app.lastInput=null; app.input("select"); Test.assertEqual(app.nav.s["index"],1); return true;
}
(:test) function persistentRoundTrip(logger) {
    var p = new Persistence(); p.prefix = "test-";
    var n = new Navigation(); n.start(1000); n.checkAction(1000); n.timers.s["elapsed"]=100;
    Test.assert(p.save(n,1100));
    var reader = new Persistence(); reader.prefix="test-";
    var restored = reader.restore(reader.load(),1400);
    Test.assertEqual(restored.timers.s["elapsed"],400);
    Test.assertEqual(restored.check.s["state"],"due");
    Test.assertEqual(restored.s["checks"].size(),1);
    // A malformed newer slot must not displace the surviving checkpoint.
    Toybox.Application.Storage.setValue("test-checkpoint0", {"version"=>1,"generation"=>999});
    Test.assertEqual(reader.load()["savedUtc"],1100);
    Toybox.Application.Storage.deleteValue("test-checkpoint0");
    Toybox.Application.Storage.deleteValue("test-checkpoint1"); return true;
}


(:test) function finishingMustNotInventLanding(logger) {
    var n = new Navigation(); n.start(1000); n.timers.takeoff(1010);
    n.timers.s["elapsed"] = 100; n.finish(1100);
    Test.assert(n.timers.s["periods"][0]["landingUtc"] == null); return true;
}
(:test) function recoveryMustRetainDueEvent(logger) {
    var n = new Navigation(); n.start(1000); n.checkAction(1000);
    var p = new Persistence(); var r = p.restore(p.snapshot(n,1000),1400);
    Test.assert(r has :takeEvents); return true;
}
