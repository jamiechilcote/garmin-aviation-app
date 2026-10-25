import Toybox.Graphics;
import Toybox.System;
import Toybox.WatchUi;

function durationText(seconds) {
    seconds = seconds.toNumber();
    return (seconds / 60).format("%02d") + ":" + (seconds % 60).format("%02d");
}
class NavView extends WatchUi.View {
    var app;
    function initialize(owner) { View.initialize(); app = owner; }
    function line(dc, y, font, text) { dc.drawText(dc.getWidth()/2, y, font, text, Graphics.TEXT_JUSTIFY_CENTER); }
    function onUpdate(dc) {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK); dc.clear();
        var n = app.nav; var leg = n.leg();
        if (app.screen.equals("recovery")) {
            line(dc, 70, Graphics.FONT_MEDIUM, "Interrupted flight");
            line(dc, 145, Graphics.FONT_XTINY, "START resume timers + FIT");
            line(dc, 190, Graphics.FONT_XTINY, "Offline time is estimated");
            line(dc, 235, Graphics.FONT_XTINY, "GPS gap may remain");
            line(dc, 285, Graphics.FONT_XTINY, "Then use Finish to save");
            line(dc, 330, Graphics.FONT_XTINY, app.recording.status); return;
        }
        if (app.screen.equals("menu")) {
            line(dc, 65, Graphics.FONT_MEDIUM, "Flight actions");
            line(dc, 150, Graphics.FONT_XTINY, "UP / DOWN to choose");
            line(dc, 211, Graphics.FONT_SMALL, app.actions[app.selected]);
            line(dc, 270, Graphics.FONT_XTINY, "Alerts: " + app.alerts.names[app.alerts.mode]);
            line(dc, 310, Graphics.FONT_XTINY, "START select / BACK nav"); return;
        }
        if (app.screen.equals("confirm")) {
            line(dc, 80, Graphics.FONT_MEDIUM, "Confirm action");
            line(dc, 160, Graphics.FONT_SMALL, app.actions[app.pending]);
            if (app.pending == 3) { line(dc, 218, Graphics.FONT_SMALL, n.timers.s["airStart"] == null ? "TAKEOFF" : "LANDING"); }
            line(dc, 280, Graphics.FONT_XTINY, "START confirm / BACK cancel"); return;
        }
        if (app.screen.equals("timers")) {
            line(dc, 48, Graphics.FONT_MEDIUM, "Flight timers");
            line(dc, 120, Graphics.FONT_SMALL, "Session " + durationText(n.timers.s["elapsed"]));
            line(dc, 173, Graphics.FONT_SMALL, "Airborne " + durationText(n.timers.airborne()));
            line(dc, 226, Graphics.FONT_SMALL, "Leg " + durationText(n.legSeconds()));
            line(dc, 281, Graphics.FONT_XTINY, "DUMMY " + leg["gs"] + " kt / " + leg["altitude"] + " ft");
            line(dc, 325, Graphics.FONT_XTINY, app.recording.status);
            line(dc, 360, Graphics.FONT_XTINY, app.recording.gps.quality); return;
        }
        var clock = System.getClockTime();
        line(dc, 42, Graphics.FONT_XTINY, "DUMMY DATA");
        line(dc, 68, Graphics.FONT_NUMBER_MILD, clock.hour.format("%02d") + ":" + clock.min.format("%02d") + ":" + clock.sec.format("%02d"));
        line(dc, 150, Graphics.FONT_MEDIUM, "HDG " + leg["heading"].format("%03d") + " M");
        var state = n.check.s["state"];
        var checkText = "CLEAROFF --:--";
        if (state.equals("running")) { checkText = "CHECK " + durationText(n.check.countdown(n.timers.s["elapsed"])); }
        if (state.equals("due")) { checkText = "CHECK DUE +" + durationText(n.timers.s["elapsed"] - n.check.s["dueElapsed"]); dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_BLACK); }
        if (state.equals("complete") || state.equals("legCompleted")) { checkText = "CHECKS COMPLETE"; }
        line(dc, 202, Graphics.FONT_SMALL, checkText);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        line(dc, 249, Graphics.FONT_SMALL, "ACT " + leg["active"]);
        line(dc, 291, Graphics.FONT_SMALL, "STBY " + leg["standby"]);
        line(dc, 335, Graphics.FONT_XTINY, leg["from"] + " > " + leg["to"]);
        var hint = n.s["radioPending"] ? "UP: verify radio" : "UP actions / DOWN timers";
        if (!n.s["started"]) { hint = "START begin session"; }
        else if (n.s["finished"]) { hint = "Session finished"; }
        else if (n.s["arrivalAlerted"]) { hint = "Arrival due - UP"; }
        else if (state.equals("idle") && !n.s["radioPending"]) { hint = "START: begin checks"; }
        if (app.persistence.error) { hint = "STORAGE ERROR"; }
        if (app.notice != null) { hint = app.notice; }
        if (!n.s["started"] && !app.recording.status.equals("Not recording")) { hint = app.recording.status; }
        line(dc, 371, Graphics.FONT_XTINY, hint);
    }
}
class NavDelegate extends WatchUi.BehaviorDelegate {
    var app;
    function initialize(owner) { BehaviorDelegate.initialize(); app = owner; }
    function onBack() { app.input("back"); return true; }
    function onSelect() { app.input("select"); return true; }
    function onPreviousPage() { app.input("up"); return true; }
    function onNextPage() { app.input("down"); return true; }
    function onMenu() { app.input("up"); return true; }
}
