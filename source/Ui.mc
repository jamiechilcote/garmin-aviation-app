import Toybox.Graphics;
import Toybox.System;
import Toybox.WatchUi;

function durationText(seconds) {
    seconds = seconds.toNumber();
    return (seconds / 60).format("%02d") + ":" + (seconds % 60).format("%02d");
}

class NavView extends WatchUi.View {
    function initialize() { View.initialize(); }
    function line(dc, y, font, text) {
        dc.drawText(dc.getWidth()/2, y, font, text, Graphics.TEXT_JUSTIFY_CENTER);
    }
    function onUpdate(dc) {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK); dc.clear();
        var clock = System.getClockTime();
        line(dc, 38, Graphics.FONT_XTINY, "DUMMY PLAN - NOT FOR FLIGHT");
        line(dc, 72, Graphics.FONT_NUMBER_HOT, clock.hour.format("%02d") + ":" + clock.min.format("%02d") + ":" + clock.sec.format("%02d"));
        line(dc, 156, Graphics.FONT_MEDIUM, "HDG 135 M");
        line(dc, 209, Graphics.FONT_MEDIUM, "CLEAROFF --:--");
        line(dc, 265, Graphics.FONT_SMALL, "ACT 123.450");
        line(dc, 309, Graphics.FONT_SMALL, "STBY 124.550");
        line(dc, 355, Graphics.FONT_XTINY, "YSCN > YSHL");
    }
}
class NavDelegate extends WatchUi.BehaviorDelegate {
    function initialize() { BehaviorDelegate.initialize(); }
    function onBack() { return true; }
    function onSelect() { WatchUi.requestUpdate(); return true; }
}
