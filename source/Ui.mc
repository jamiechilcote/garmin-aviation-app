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
        if(app.screen.equals("select")) { plans(dc); }
        else if(app.screen.equals("summary")) { summary(dc); }
        else if(app.screen.equals("menu")) { menu(dc); }
        else if(app.screen.equals("confirm")) { confirm(dc); }
        else if(app.screen.equals("timers")) { timers(dc); }
        else if(app.screen.equals("alerts")) { alertSettings(dc); }
        else if(app.screen.equals("recovery") || app.screen.equals("review")) { recovery(dc); }
        else if(app.screen.equals("completed")) { completed(dc); }
        else if(app.screen.equals("radio")) { radio(dc); }
        else { navigation(dc); }
    }
    function shortLabel(value,limit) { return value.length()>limit ? value.substring(0,limit-3)+"..." : value; }
    function stateText() {
        var n=app.nav;
        if(n.s["discarded"]) { return "FLIGHT DISCARDED"; }
        if(app.persistence.error) { return "STORAGE WARNING"; }
        var state=app.flightState();
        if(state.equals("FINISH_PENDING")) { return "SAVE PENDING"; }
        if(state.equals("FINISHED")) { return "FLIGHT FINISHED"; }
        if(state.equals("RECOVERY_REQUIRED")) { return "RECOVERY REQUIRED"; }
        if(state.equals("RECORDING_ERROR")) { return "RECORDING WARNING"; }
        if(!n.s["started"]) { return "FLIGHT NOT STARTED"; }
        if(n.s["radioPending"]) { return n.timers.s["airStart"]==null ? "ON GROUND / RADIO!" : "AIRBORNE / RADIO!"; }
        if(n.timers.s["airStart"]==null) { return n.timers.s["periods"].size()>0 ? "LANDED" : "ON GROUND"; }
        var p=n.progress(); return "AIRBORNE / CHECK "+p["current"]+"/"+p["total"];
    }
    function navigation(dc) {
        var n=app.nav; var leg=n.leg(); var check=n.check.s["state"];
        if(n.s["demo"]) { row(dc,18,23,"DEMO",18,AMBER); }
        row(dc,43,29,shortLabel(leg["from"]+" > "+leg["to"],23)+"  "+(n.s["index"]+1)+"/"+n.plan.size(),26,Graphics.COLOR_WHITE);
        var clock=System.getClockTime(); row(dc,73,86,clockText(clock.hour,clock.min,clock.sec),84,Graphics.COLOR_WHITE);
        text(dc,40,163,180,27,"HEADING",22,MUTED); text(dc,234,163,180,27,"CLEAROFF",22,MUTED);
        text(dc,40,191,180,67,leg["heading"].format("%03d")+"°",64,Graphics.COLOR_WHITE);
        var value="IDLE"; var size=52; var color=GREEN; var detail="CHECKS IDLE";
        if(check.equals("running")) { value=durationText(n.check.countdown(n.timers.s["elapsed"])); size=62; detail="CHECKS RUNNING"; }
        if(check.equals("due")) { value="CHECK DUE"; size=32; color=AMBER; detail="+"+durationText(n.timers.s["elapsed"]-n.check.s["dueElapsed"]); }
        if(check.equals("complete") || check.equals("legCompleted")) { value="COMPLETE"; size=34; detail="CHECKS COMPLETE"; }
        if(n.s["finished"] || n.s["discarded"]) { value="ENDED"; size=42; detail="FLIGHT FINISHED"; color=MUTED; }
        text(dc,234,191,180,67,value,size,color);
        text(dc,40,259,180,25,"MAGNETIC",20,MUTED); text(dc,234,259,180,25,detail,18,color);
        text(dc,64,289,110,35,"ACTIVE",23,MUTED); text(dc,178,289,212,35,leg["active"],38,Graphics.COLOR_WHITE);
        text(dc,64,329,110,35,"STBY",23,MUTED); text(dc,178,329,212,35,leg["standby"],38,Graphics.COLOR_WHITE);
        var attention=app.persistence.error || app.recording.warning || n.s["radioPending"] || app.storageBlocked || n.s["finishRequested"];
        row(dc,369,28,stateText(),24,attention ? AMBER : Graphics.COLOR_WHITE);
        var action=app.primaryAction();
        if(action.equals("COMPLETE CHECK")) { action="COMPLETE"; }
        if(action.equals("CHECKS COMPLETE")) { action="CHECKS COMPLETE"; }
        else if(!action.equals("START CHECKS")) { action="START "+action; }
        row(dc,400,28,action,22,check.equals("due") ? AMBER : GREEN);
    }
    function plans(dc) {
        var choices=FlightPlan.catalogue(); var plan=choices[app.planChoice]; var count=FlightPlan.legsFor(plan["id"]).size();
        row(dc,42,36,"SELECT FLIGHT",32,Graphics.COLOR_WHITE);
        row(dc,88,28,"DEMO PLANS",22,AMBER);
        row(dc,137,27,(app.planChoice+1)+" / "+choices.size(),22,MUTED);
        row(dc,180,48,shortLabel(plan["name"],24),36,Graphics.COLOR_WHITE);
        row(dc,244,32,plan["departure"]+" > "+plan["destination"],26,MUTED);
        row(dc,284,30,count+" legs / Rev "+plan["revision"],24,MUTED);
        row(dc,328,27,"UP / DOWN choose",22,MUTED);
        row(dc,369,32,"START SELECT",26,GREEN);
        if(app.notice!=null) { row(dc,407,24,shortLabel(app.notice,24),18,AMBER); }
    }
    function summary(dc) {
        var plan=FlightPlan.find(app.nav.s["planId"]);
        row(dc,46,34,"FLIGHT SUMMARY",30,Graphics.COLOR_WHITE);
        row(dc,102,30,"DEMO / NOT VALIDATED",23,AMBER);
        row(dc,157,45,shortLabel(app.nav.s["flight"],24),34,Graphics.COLOR_WHITE);
        row(dc,220,32,plan["departure"]+" > "+plan["destination"],28,Graphics.COLOR_WHITE);
        row(dc,267,30,app.nav.plan.size()+" legs / Rev "+plan["revision"],24,MUTED);
        row(dc,305,27,plan["date"],22,MUTED);
        row(dc,354,33,"START FLIGHT >",28,GREEN);
        row(dc,400,26,"BACK: flight selection",20,MUTED);
    }
    function timers(dc) {
        var n=app.nav; var leg=n.leg(); row(dc,40,38,"FLIGHT TIMERS",32,Graphics.COLOR_WHITE);
        row(dc,98,42,"SESSION  "+durationText(n.timers.s["elapsed"]),34,Graphics.COLOR_WHITE);
        row(dc,148,42,"AIRBORNE  "+durationText(n.timers.airborne()),34,Graphics.COLOR_WHITE);
        row(dc,198,42,"LEG  "+durationText(n.legSeconds()),34,Graphics.COLOR_WHITE);
        row(dc,252,30,stateText(),24,Graphics.COLOR_WHITE);
        row(dc,291,27,"GS "+leg["gs"].format("%.0f")+" kt / ALT "+leg["altitude"]+" ft",22,MUTED);
        row(dc,326,27,app.recording.gps.quality,22,MUTED);
        row(dc,360,29,shortLabel(app.recording.status,30),22,app.recording.warning ? AMBER : MUTED);
        row(dc,401,26,"UP / DOWN actions",20,GREEN);
    }
    function menu(dc) {
        var ids=app.menuIds(); var selected=app.selected<ids.size() ? app.selected : ids.size()-1;
        row(dc,49,38,"FLIGHT ACTIONS",32,Graphics.COLOR_WHITE);
        row(dc,108,28,(selected+1)+" / "+ids.size(),24,MUTED);
        if(selected>0) { row(dc,156,30,app.actionLabel(ids[selected-1]),24,MUTED); }
        row(dc,209,50,app.actionLabel(ids[selected]),36,ids[selected]==11 ? 0xFF6666 : GREEN);
        if(selected+1<ids.size()) { row(dc,285,30,app.actionLabel(ids[selected+1]),24,MUTED); }
        row(dc,347,29,"START SELECT",24,Graphics.COLOR_WHITE);
        row(dc,397,26,"BACK: timers",22,MUTED);
    }
    function alertSettings(dc) {
        var order=[2,0,1,3]; var labels=["Vibration + sound","Vibration only","Sound only","Off"];
        row(dc,42,37,"ALERT SETTINGS",30,Graphics.COLOR_WHITE);
        for(var i=0;i<4;i+=1) { row(dc,119+i*51,39,(app.alertChoice==order[i] ? "> " : "")+labels[i],28,app.alertChoice==order[i] ? GREEN : MUTED); }
        row(dc,341,29,"START SAVE",24,GREEN); row(dc,394,27,"BACK CANCEL",22,MUTED);
    }
    function radio(dc) {
        row(dc,46,40,"RADIO CHANGE",34,AMBER);
        var clock=System.getClockTime(); row(dc,100,70,clockText(clock.hour,clock.min,clock.sec),64,Graphics.COLOR_WHITE);
        row(dc,188,30,"REFERENCE ONLY",24,MUTED);
        row(dc,235,41,"ACTIVE  "+app.nav.leg()["active"],36,Graphics.COLOR_WHITE);
        row(dc,287,41,"STBY  "+app.nav.leg()["standby"],36,Graphics.COLOR_WHITE);
        row(dc,350,32,"START ACKNOWLEDGE",26,GREEN);
        row(dc,397,25,"BACK: remind later",20,MUTED);
    }
    function confirm(dc) {
        var id=app.pending; var destructive=id==11;
        row(dc,48,40,id==12 ? "START FLIGHT" : "CONFIRM",32,destructive ? 0xFF6666 : Graphics.COLOR_WHITE);
        row(dc,127,53,app.actionLabel(id),36,destructive ? 0xFF6666 : Graphics.COLOR_WHITE);
        if(id==12) {
            row(dc,211,32,shortLabel(app.nav.s["flight"],24),28,Graphics.COLOR_WHITE);
            row(dc,257,30,"Starts session and recording",24,MUTED);
            row(dc,294,28,"Takeoff remains manual",22,AMBER);
        } else if(id==4 || id==10) {
            row(dc,210,31,app.nav.timers.s["airStart"]!=null ? "Landing NOT confirmed" : "Close flight session",24,AMBER);
            row(dc,252,30,"No invented waypoint arrival",22,MUTED);
            if(id==10) { row(dc,292,28,"FIT may remain unresolved",22,AMBER); }
        } else if(id==11) {
            row(dc,212,32,"Flight will NOT be saved",26,0xFF6666);
            row(dc,262,29,"Discards log and native FIT",22,MUTED);
        } else if(id==3) { row(dc,220,35,"Pilot-confirmed event",26,AMBER); }
        row(dc,346,32,"START CONFIRM",26,destructive ? 0xFF6666 : GREEN); row(dc,395,28,"BACK CANCEL",22,MUTED);
    }
    function recovery(dc) {
        var unresolved=app.nav.s["finished"] || app.nav.s["finishRequested"];
        row(dc,42,40,unresolved ? "SAVE NEEDS REVIEW" : "RECORDING RECOVERY",28,AMBER);
        if(app.screen.equals("review")) {
            row(dc,113,32,"Local log is retained",26,Graphics.COLOR_WHITE);
            row(dc,170,30,"Original FIT not identified",24,AMBER);
            row(dc,222,29,"No automatic replacement",23,MUTED);
            row(dc,271,29,"Do not reset app data",23,MUTED);
            row(dc,346,30,"BACK: safe options",24,GREEN); return;
        }
        row(dc,105,32,app.storageBlocked ? "Local data needs review" : (unresolved ? "Completion not verified" : (app.recording.state.equals("unavailable") ? "Flight log retained" : "Local timers restored")),26,Graphics.COLOR_WHITE);
        row(dc,153,29,app.storageBlocked ? "Checkpoints are retained" : "FIT/GPS gaps may remain",23,MUTED);
        if(app.notice!=null) { row(dc,195,30,shortLabel(app.notice,29),23,AMBER); }
        var ids=app.recoveryIds(); var index=app.selected<ids.size() ? app.selected : 0; var id=ids[index];
        row(dc,239,27,(index+1)+" / "+ids.size()+"  UP / DOWN",22,MUTED);
        row(dc,281,42,app.actionLabel(id),30,GREEN);
        var consequence="Keep original data for review";
        if(id==10) { consequence="Close log; FIT may stay pending"; }
        if(id==14) { consequence="Navigate with recording warning"; }
        if(id==8) { consequence="Try recording once; gaps possible"; }
        if(id==4) { consequence="Retry retained recording save"; }
        row(dc,337,30,consequence,20,MUTED);
        row(dc,392,28,"BACK: navigation",22,MUTED);
    }
    function completed(dc) {
        row(dc,64,43,app.nav.s["discarded"] ? "FLIGHT DISCARDED" : "FLIGHT FINISHED",32,Graphics.COLOR_WHITE);
        row(dc,153,43,app.nav.s["fitOutcome"].equals("saved") ? "FIT + LOG SAVED" : (app.nav.s["discarded"] ? "Not saved" : "LOCAL LOG ONLY"),30,GREEN);
        row(dc,226,35,"SESSION "+durationText(app.nav.timers.s["elapsed"]),28,Graphics.COLOR_WHITE);
        row(dc,275,35,"AIRBORNE "+durationText(app.nav.timers.airborne()),28,Graphics.COLOR_WHITE);
        row(dc,344,31,"Returning to Garmin",24,MUTED);
        row(dc,393,28,"START EXIT",24,GREEN);
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
