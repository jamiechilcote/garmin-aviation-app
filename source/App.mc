import Toybox.Application;
import Toybox.WatchUi;
import Toybox.Timer;
import Toybox.System;
import Toybox.Time;

class NavlogApp extends Application.AppBase {
    var pulse; var nav; var screen = "nav"; var selected = 0; var pending = null;
    var lastMillis; var remainder = 0; var lastInput = null;
    var actions = ["Confirm radio reference", "Advance waypoint", "Undo advancement", "Takeoff / landing", "Finish and save"];
    function initialize() { AppBase.initialize(); nav = new Navigation(); }
    function getInitialView() { return [new NavView(self), new NavDelegate(self)]; }
    function onStart(state) {
        lastMillis = System.getTimer();
        pulse = new Timer.Timer(); pulse.start(method(:tick), 1000, true);
    }
    function updateElapsed() {
        var now = System.getTimer();
        var delta = now.toLong() - lastMillis.toLong();
        if (delta < 0) { delta += 4294967296l; }
        lastMillis = now;
        if (nav.s["started"] && !nav.s["finished"]) {
            remainder += delta;
            nav.timers.s["elapsed"] += (remainder / 1000).toNumber();
            remainder %= 1000;
        }
    }
    function tick() as Void { updateElapsed(); nav.tick(); WatchUi.requestUpdate(); }
    function onStop(state) { pulse.stop(); }
    function input(action) {
        var now = System.getTimer();
        if (lastInput != null && now - lastInput >= 0 && now - lastInput < 450) { return; }
        lastInput = now; updateElapsed(); nav.tick();
        var utc = Time.now().value();
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
                if (!nav.s["started"]) { nav.start(utc); remainder = 0; }
                else { nav.checkAction(utc); }
            }
        }
        WatchUi.requestUpdate();
    }
    function execute(action, utc) {
        if (!nav.s["started"] || nav.s["finished"]) { return; }
        if (action == 1) { nav.advance(utc); }
        if (action == 2) { nav.undo(utc); }
        if (action == 3) {
            if (nav.timers.s["airStart"] == null) { nav.timers.takeoff(utc); }
            else { nav.timers.land(utc); }
        }
        if (action == 4) { nav.finish(utc); }
    }
}

