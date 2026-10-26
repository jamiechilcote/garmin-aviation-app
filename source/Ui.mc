import Toybox.Graphics;
import Toybox.System;
import Toybox.WatchUi;
import Toybox.Math;
function durationText(seconds) { seconds=seconds.toNumber(); return (seconds/60).format("%02d")+":"+(seconds%60).format("%02d"); }
function clockText(hour,minute,second) { return hour.format("%02d")+":"+minute.format("%02d")+":"+second.format("%02d"); }
class NavView extends WatchUi.View {
    var app; var fonts={}; var bounds=[]; var layoutError=false;
    const MUTED=0xAAAAAA;
    const GREEN=0x66EE88;
    const AMBER=0xFFCC44;
    function initialize(owner) { View.initialize(); app=owner; }
    function fontFor(size) {
        if(!fonts.hasKey(size)) {
            var font=null;
            if(Graphics has :getVectorFont) { font=Graphics.getVectorFont({:face=>"RobotoCondensedRegular",:size=>size}); }
            fonts[size]=font;
        }
        return fonts[size];
    }
    // Rectangles are fitted against both the requested box and the circle's inset chord.
    function text(dc,x,y,w,h,value,maxSize,color) {
        var cx=x+w/2.0; var radius=dc.getWidth()/2.0-10;
        var top=y-dc.getHeight()/2.0; if(top<0) { top=-top; }
        var bottom=y+h-dc.getHeight()/2.0; if(bottom<0) { bottom=-bottom; }
        var distance=top>bottom ? top : bottom;
        var half=distance<radius ? Math.sqrt(radius*radius-distance*distance) : 0;
        var left=dc.getWidth()/2.0-half; var right=dc.getWidth()/2.0+half;
        var safe=cx-left<right-cx ? 2*(cx-left) : 2*(right-cx);
        var available=w<safe ? w : safe;
        var font=Graphics.FONT_XTINY; var found=false;
        for(var size=maxSize;size>=12;size-=2) {
            var candidate=fontFor(size);
            if(candidate!=null && dc.getFontHeight(candidate)<=h && dc.getTextWidthInPixels(value,candidate)<=available) { font=candidate; found=true; break; }
        }
        if(!found) {
            var choices=[Graphics.FONT_NUMBER_MILD,Graphics.FONT_MEDIUM,Graphics.FONT_SMALL,Graphics.FONT_XTINY];
            for(var i=0;i<choices.size();i+=1) {
                if(dc.getFontHeight(choices[i])<=h && dc.getTextWidthInPixels(value,choices[i])<=available) { font=choices[i]; found=true; break; }
            }
        }
        var tw=dc.getTextWidthInPixels(value,font); var th=dc.getFontHeight(font);
        if(!found) { layoutError=true; }
        var tx=cx-tw/2.0; var ty=y+(h-th)/2.0;
        bounds.add({"text"=>value,"x"=>tx,"y"=>ty,"w"=>tw,"h"=>th,"color"=>color});
        dc.setColor(color,Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx,ty,font,value,Graphics.TEXT_JUSTIFY_CENTER);
    }
    function row(dc,y,h,value,size,color) { text(dc,32,y,390,h,value,size,color); }
    function onUpdate(dc) {
        bounds=[]; layoutError=false; dc.setColor(Graphics.COLOR_WHITE,Graphics.COLOR_BLACK); dc.clear();
        if(app.screen.equals("menu")) { menu(dc); return; }
        if(app.screen.equals("confirm")) { confirm(dc); return; }
        if(app.screen.equals("timers")) { timers(dc); return; }
        if(app.screen.equals("recovery")) { recovery(dc); return; }
        navigation(dc);
    }
    function navigation(dc) {
        var n=app.nav; var leg=n.leg(); var state=n.check.s["state"];
        if(n.s["demo"]) { row(dc,28,24,"DEMO PLAN",18,AMBER); }
        var clock=System.getClockTime();
        row(dc,58,78,clockText(clock.hour,clock.min,clock.sec),72,Graphics.COLOR_WHITE);
        text(dc,47,151,174,24,"HEADING",18,MUTED);
        text(dc,233,151,174,24,"CLEAROFF",18,MUTED);
        text(dc,47,180,174,62,leg["heading"].format("%03d")+"°",48,Graphics.COLOR_WHITE);
        var value="START CHECKS"; var size=22; var color=GREEN;
        if(state.equals("running")) { value=durationText(n.check.countdown(n.timers.s["elapsed"])); size=48; }
        if(state.equals("due")) { value="CHECK DUE"; size=28; color=AMBER; }
        if(state.equals("complete") || state.equals("legCompleted")) { value="CHECKS COMPLETE"; size=18; color=MUTED; }
        text(dc,233,180,174,62,value,size,color);
        text(dc,47,241,174,22,"MAGNETIC",14,MUTED);
        if(state.equals("due")) { text(dc,233,241,174,22,"+"+durationText(n.timers.s["elapsed"]-n.check.s["dueElapsed"]),18,AMBER); }
        if(!app.screen.equals("radio")) { dc.setColor(0x444444,Graphics.COLOR_TRANSPARENT); dc.drawLine(70,269,384,269); }
        text(dc,65,277,108,32,"ACTIVE",18,MUTED); text(dc,177,277,212,32,leg["active"],32,Graphics.COLOR_WHITE);
        text(dc,65,313,108,32,"STANDBY",18,MUTED); text(dc,177,313,212,32,leg["standby"],32,Graphics.COLOR_WHITE);
        row(dc,349,30,leg["from"]+" > "+leg["to"],24,Graphics.COLOR_WHITE);
        var p=n.progress(); var progress="LEG "+(n.s["index"]+1)+"/"+n.plan.size();
        progress+=" | "+(p["done"]==p["total"] ? "CHECKS "+p["done"]+"/"+p["total"] : "CHECK "+p["current"]+" OF "+p["total"]);
        row(dc,382,24,progress,18,MUTED);
        var hint=n.s["radioPending"] ? "UP: verify radio" : "UP actions  DOWN timers";
        if(!n.s["started"]) { hint="START: begin"; }
        if(n.s["finished"]) { hint="Session finished"; }
        else if(n.s["arrivalAlerted"]) { hint="Arrival due - UP"; }
        var hintColor=MUTED;
        if(app.screen.equals("radio")) { hint="START confirm / BACK"; hintColor=AMBER; }
        else if(app.recording.warning && n.s["started"] && !n.s["finished"]) { hint="FIT/GPS issue - UP"; hintColor=AMBER; }
        if(app.persistence.error) { hint="Storage warning"; hintColor=AMBER; }
        if(app.notice!=null) { hint=app.notice; hintColor=AMBER; }
        if(n.s["fitPending"]) { hint="Unsaved FIT - UP"; hintColor=AMBER; }
        if(app.storageBlocked) { hint="Recovery data retained"; hintColor=0xFF6666; }
        row(dc,409,22,hint,14,hintColor);
        if(app.screen.equals("radio")) { row(dc,264,12,"VERIFY AIRCRAFT RADIO",12,AMBER); }
    }
    function timers(dc) {
        var n=app.nav; var leg=n.leg(); row(dc,45,36,"FLIGHT TIMERS",28,Graphics.COLOR_WHITE);
        row(dc,100,37,"SESSION  "+durationText(n.timers.s["elapsed"]),30,Graphics.COLOR_WHITE);
        row(dc,145,37,"AIRBORNE  "+durationText(n.timers.airborne()),30,Graphics.COLOR_WHITE);
        row(dc,190,37,"LEG  "+durationText(n.legSeconds()),30,Graphics.COLOR_WHITE);
        row(dc,246,29,"PLANNED GS  "+leg["gs"].format("%.0f")+" kt",22,MUTED);
        row(dc,280,29,"PLANNED ALT  "+leg["altitude"]+" ft",22,MUTED);
        row(dc,327,28,app.recording.gps.quality,20,app.recording.gps.fault ? AMBER : MUTED);
        row(dc,362,28,app.recording.status,20,app.recording.warning ? AMBER : MUTED);
        row(dc,403,24,"BACK: navigation",16,MUTED);
    }
    function menu(dc) {
        row(dc,65,38,"FLIGHT ACTIONS",30,Graphics.COLOR_WHITE);
        row(dc,134,26,(app.selected+1)+" / "+app.actions.size(),20,MUTED);
        row(dc,183,55,app.actions[app.selected],30,Graphics.COLOR_WHITE);
        row(dc,273,30,"Alerts: "+app.alerts.names[app.alerts.mode],22,MUTED);
        row(dc,328,28,"UP / DOWN: choose",20,MUTED);
        row(dc,372,26,"START select / BACK nav",18,MUTED);
    }
    function confirm(dc) {
        row(dc,60,38,"CONFIRM",30,Graphics.COLOR_WHITE);
        row(dc,139,55,app.actions[app.pending],30,Graphics.COLOR_WHITE);
        if(app.pending==3) { row(dc,218,34,app.nav.timers.s["airStart"]==null ? "TAKEOFF" : "LANDING",26,Graphics.COLOR_WHITE); }
        if(app.pending==4 || app.pending==10) {
            row(dc,214,29,app.nav.timers.s["airStart"]!=null ? "Landing NOT confirmed" : "Close session",22,AMBER);
            row(dc,253,28,"Unreached waypoint stays open",20,MUTED);
            if(app.pending==10) { row(dc,292,28,"Native FIT remains unsaved",20,AMBER); }
            else if(app.recording.session==null) { row(dc,292,28,"Local history only - no FIT",20,AMBER); }
        }
        row(dc,340,28,"START: confirm",22,Graphics.COLOR_WHITE); row(dc,381,24,"BACK: cancel",18,MUTED);
    }
    function recovery(dc) {
        row(dc,60,38,"INTERRUPTED FLIGHT",28,Graphics.COLOR_WHITE);
        row(dc,132,32,app.storageBlocked ? "Recovery data retained" : "Timers recovered",24,AMBER);
        row(dc,185,28,"Offline time is estimated",20,MUTED);
        row(dc,228,28,"FIT/GPS gaps may remain",20,MUTED);
        row(dc,286,28,app.storageBlocked ? "UP: retry recovery" : "START: retry recording",20,Graphics.COLOR_WHITE);
        row(dc,330,28,"BACK: manual navigation",20,Graphics.COLOR_WHITE);
        row(dc,378,24,"DOWN: flight timers",18,MUTED);
    }
}
class NavDelegate extends WatchUi.BehaviorDelegate {
    var app; function initialize(owner) { BehaviorDelegate.initialize(); app=owner; }
    function onBack() { app.input("back"); return true; }
    function onSelect() { app.input("select"); return true; }
    function onPreviousPage() { app.input("up"); return true; }
    function onNextPage() { app.input("down"); return true; }
    function onMenu() { app.input("up"); return true; }
    function onTap(event) { return true; }
}
