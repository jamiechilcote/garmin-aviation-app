import Toybox.Application;
import Toybox.WatchUi;
import Toybox.Timer;
import Toybox.System;
import Toybox.Time;

class NavlogApp extends Application.AppBase {
    var pulse; var nav; var screen = "nav"; var selected = 0; var pending = null;
    var lastMillis; var remainder = 0; var lastInput = null;
    var recording; var alerts; var persistence; var recovered = null; var lastSaved = 0; var testing = false; var notice = null;
    var actions = ["Confirm radio", "Advance waypoint", "Undo advancement", "Takeoff / landing", "Finish and save", "Change alert mode", "New flight", "Exit app"];
    function initialize() { AppBase.initialize(); nav = new Navigation(); recording = new Recording(); alerts = new Alerts(); persistence = new Persistence(); }
    function getInitialView() { return [new NavView(self), new NavDelegate(self)]; }
    function onStart(state) {
        recovered = persistence.load();
        if (recovered != null) {
            if (recovered["navigation"]["started"] && !recovered["navigation"]["finished"]) { screen = "recovery"; }
            else { nav = persistence.restore(recovered, Time.now().value()); recovered = null; }
        }
        try {
            var mode = Application.Storage.getValue("alertMode");
            if (mode instanceof Toybox.Lang.Number && mode >= 0 && mode < 4) { alerts.mode = mode; }
        } catch (e) { persistence.error = true; }
        lastMillis = System.getTimer();
        pulse = new Timer.Timer(); pulse.start(method(:tick), 1000, true);
    }
    function updateElapsed() {
        var now = System.getTimer();
        var delta = monotonicDelta(now, lastMillis);
        lastMillis = now;
        if (nav.s["started"] && !nav.s["finished"]) {
            remainder += delta;
            nav.timers.s["elapsed"] += (remainder / 1000).toNumber();
            remainder %= 1000;
        }
    }
    function tick() as Void {
        updateElapsed(); if (nav.tick()) { alerts.fire(); checkpoint(); }
        if (nav.s["started"] && !nav.s["finished"] && nav.timers.s["elapsed"] - lastSaved >= 15) { checkpoint(); }
        WatchUi.requestUpdate();
    }
    function checkpoint() {
        if (recovered != null || testing) { return; }
        persistence.save(nav, Time.now().value()); lastSaved = nav.timers.s["elapsed"];
    }
    function onStop(state) { pulse.stop(); updateElapsed(); checkpoint(); recording.suspend(); }
    function input(action) {
        var now = System.getTimer();
        if (lastInput != null && now - lastInput >= 0 && now - lastInput < 450) { return; }
        lastInput = now; notice = null; updateElapsed(); if (nav.tick()) { alerts.fire(); }
        var utc = Time.now().value();
        if (recovered != null) {
            if (action.equals("select")) {
                if (recording.start()) { nav = persistence.restore(recovered, utc); recovered = null; screen = "nav"; remainder = 0; checkpoint(); }
            }
            WatchUi.requestUpdate(); return;
        }
        if (action.equals("back")) { screen = "nav"; pending = null; }
        else if (action.equals("up") || action.equals("down")) {
            if (screen.equals("menu")) { selected = (selected + (action.equals("up") ? actions.size()-1 : 1)) % actions.size(); }
            else { screen = action.equals("up") ? "menu" : "timers"; }
        } else if (action.equals("select")) {
            if (screen.equals("confirm")) { execute(pending, utc); pending = null; screen = "nav"; }
            else if (screen.equals("menu")) {
                if (selected == 0) { nav.s["radioPending"] = false; screen = "nav"; }
                else { pending = selected; screen = "confirm"; }
            } else if (screen.equals("nav")) {
                if (!nav.s["started"]) { if (recording.start()) { nav.start(utc); remainder = 0; } }
                else { nav.checkAction(utc); }
            }
        }
        checkpoint(); WatchUi.requestUpdate();
    }
    function execute(action, utc) {
        if (action == 5) {
            alerts.mode = (alerts.mode+1)%4;
            try { Application.Storage.setValue("alertMode", alerts.mode); }
            catch (e) { notice = "Settings save failed"; }
            return;
        }
        if (action == 6 && nav.s["finished"]) {
            if (persistence.archive(nav, utc)) { nav = new Navigation(); recording = new Recording(); remainder = 0; } return;
        }
        if (action == 7 && (!nav.s["started"] || nav.s["finished"])) { System.exit(); return; }
        if (action == 6 || action == 7) { notice = "Finish flight first"; return; }
        if (!nav.s["started"] || nav.s["finished"]) { return; }
        if (action == 1) { nav.advance(utc); }
        if (action == 2) { nav.undo(utc); }
        if (action == 3) {
            if (nav.timers.s["airStart"] == null) { nav.timers.takeoff(utc); }
            else { nav.timers.land(utc); }
        }
        if (action == 4) {
            if (recording.save(nav.timers.airborne())) { nav.finish(utc); }
            else { notice = recording.status; }
        }
    }
}
function monotonicDelta(now, previous) {
    var delta = now.toLong() - previous.toLong();
    return delta < 0 ? delta + 4294967296l : delta;
}
