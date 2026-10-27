import Toybox.Graphics;
import Toybox.System;
import Toybox.WatchUi;
import Toybox.Math;
function durationText(seconds) { seconds=seconds.toNumber(); return (seconds/60).format("%02d")+":"+(seconds%60).format("%02d"); }
function clockText(hour,minute,second) { return hour.format("%02d")+":"+minute.format("%02d")+":"+second.format("%02d"); }
class NavView extends WatchUi.View {
    var app; var fonts={}; var bounds=[]; var layoutError=false;
    const MUTED=0xCCCCCC;
    const GREEN=0x66EE88;
    const AMBER=0xFFCC44;
    function initialize(owner) { View.initialize(); app=owner; }
    function fontFor(size) {
        if(!fonts.hasKey(size)) { fonts[size]=Graphics.getVectorFont({:face=>"RobotoCondensedRegular",:size=>size}); }
        return fonts[size];
    }
    function localClock() { var clock=System.getClockTime(); return clockText(clock.hour,clock.min,clock.sec); }
    function inside(dc,x,y,w,h) {
        var radius=(dc.getWidth()<dc.getHeight() ? dc.getWidth() : dc.getHeight())/2.0;
        radius-=10.0*radius/227.0;
        var dx=x-dc.getWidth()/2.0; var dy=y-dc.getHeight()/2.0;
        var xs=[dx,dx+w]; var ys=[dy,dy+h];
        for(var i=0;i<2;i+=1) { for(var j=0;j<2;j+=1) { if(xs[i]*xs[i]+ys[j]*ys[j]>radius*radius+1) { return false; } } }
        return true;
    }
    // Each role has its own allocated region and readable font floor. No shared minimum-size layout.
    // Reference strings reserve the widest supported digits, preventing countdown/clock size changes.
    function region(dc,x,y,w,h,value,maxSize,minSize,color,align,reference) {
        var scale=(dc.getWidth()<dc.getHeight() ? dc.getWidth() : dc.getHeight())/454.0;
        var left=(dc.getWidth()-454*scale)/2.0+x*scale; var top=(dc.getHeight()-454*scale)/2.0+y*scale;
        w*=scale; h*=scale; var font=null; var chosen=(minSize*scale).toNumber(); var tx=left; var ty=top; var tw=0; var th=0; var found=false;
        for(var size=(maxSize*scale).toNumber();size>=(minSize*scale).toNumber();size-=2) {
            var candidate=fontFor(size); if(candidate==null) { continue; }
            th=dc.getFontHeight(candidate); tw=dc.getTextWidthInPixels(value,candidate);
            var rw=reference==null ? tw : dc.getTextWidthInPixels(reference,candidate); if(tw>rw) { rw=tw; }
            var rx=align<0 ? left : (align>0 ? left+w-rw : left+(w-rw)/2.0);
            ty=top+(h-th)/2.0;
            if(rw<=w && th<=h && inside(dc,rx,ty,rw,th)) { font=candidate; chosen=size; found=true; break; }
        }
        if(!found) { layoutError=true; font=fontFor(chosen); }
        tw=dc.getTextWidthInPixels(value,font); th=dc.getFontHeight(font); ty=top+(h-th)/2.0;
        tx=align<0 ? left : (align>0 ? left+w-tw : left+(w-tw)/2.0);
        bounds.add({"text"=>value,"x"=>tx,"y"=>ty,"w"=>tw,"h"=>th,"color"=>color,"font"=>chosen});
        dc.setColor(color,Graphics.COLOR_TRANSPARENT); dc.drawText(tx,ty,font,value,Graphics.TEXT_JUSTIFY_LEFT);
    }
    // Compatibility helpers for existing isolated acceptance views; production roles use explicit floors.
    function text(dc,x,y,w,h,value,maxSize,color) { region(dc,x,y,w,h,value,maxSize,12,color,0,null); }
    function row(dc,y,h,value,size,color) { text(dc,32,y,390,h,value,size,color); }
    function centre(dc,y,h,value,maxSize,minSize,color) { region(dc,32,y,390,h,value,maxSize,minSize,color,0,null); }
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
        if(n.s["radioPending"]) { return "RADIO PENDING"; }
        return n.timers.s["airStart"]==null ? (n.timers.s["periods"].size()>0 ? "LANDED" : "ON GROUND") : "AIRBORNE";
    }
    // Display semantics come from exactly the same primary action used by the controller.
    function clearoffLines() {
        var action=app.primaryAction();
        if(action.equals("TAKEOFF")) { return ["TAKEOFF"]; }
        if(action.equals("START CHECKS")) { return ["START","CLEAROFF"]; }
        if(action.equals("REVIEW SAVE")) { return ["REVIEW","SAVE"]; }
        if(action.equals("EXIT")) { return ["EXIT"]; }
        if(action.equals("SELECT FLIGHT")) { return ["SELECT","FLIGHT"]; }
        if(action.equals("CHECKS COMPLETE")) { return ["COMPLETE"]; }
        return [app.nav.check.s["state"].equals("due") ? "DUE" : durationText(app.nav.check.countdown(app.nav.timers.s["elapsed"]))];
    }
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
    function navigation(dc) {
        var white=Graphics.COLOR_WHITE; var n=app.nav;
        region(dc,32,76,390,104,localClock(),104,100,white,0,"23:59:59");
        region(dc,31,181,190,30,"HEADING",28,28,white,0,null);
        region(dc,233,181,190,30,"CLEAROFF",28,28,white,0,null);
        region(dc,31,211,190,86,n.leg()["heading"].format("%03d")+"°",86,82,white,0,"360°");
        var lines=clearoffLines(); var countdown=app.primaryAction().equals("COMPLETE CHECK");
        var color=countdown ? (n.check.s["state"].equals("due") ? AMBER : white) : GREEN;
        if(lines.size()==2) {
            region(dc,233,211,190,42,lines[0],42,38,color,0,null);
            region(dc,233,255,190,42,lines[1],42,38,color,0,null);
        } else {
            var size=countdown ? 86 : 80;
            region(dc,233,211,190,86,lines[0],size,countdown ? 82 : 40,color,0,countdown && !lines[0].equals("DUE") ? "59:59" : null);
        }
        radioRows(dc,298,352,54);
    }
    function radioRows(dc,first,second,size) {
        var white=Graphics.COLOR_WHITE;
        region(dc,100,first,100,54,"ACTIVE",32,32,white,-1,null);
        region(dc,194,first,154,54,app.nav.leg()["active"],size,size,white,1,"199.999");
        region(dc,100,second,100,54,"STBY",32,32,white,-1,null);
        region(dc,194,second,154,54,app.nav.leg()["standby"],size,size,white,1,"199.999");
    }
    function menuLabel(id) {
        if(id==3) { return app.nav.timers.s["airStart"]==null ? "TAKEOFF" : "LAND"; }
        if(id==4) { return app.nav.s["finishRequested"] || app.nav.s["finished"] ? "RETRY SAVE" : "FINISH"; }
        var labels=["RADIO","ADVANCE","UNDO","LAND","FINISH","ALERTS","SELECT","EXIT","RETRY FIT","RETRY LOG","LOCAL LOG","DISCARD","START FLIGHT","RADIO","RETURN","REVIEW"];
        return labels[id];
    }
    function plans(dc) {
        var plan=FlightPlan.catalogue()[app.planChoice];
        centre(dc,52,52,"SELECT FLIGHT",42,38,Graphics.COLOR_WHITE);
        centre(dc,119,36,"DEMO",30,30,AMBER);
        centre(dc,183,70,shortLabel(plan["name"],24),50,32,Graphics.COLOR_WHITE);
        centre(dc,283,38,FlightPlan.legsFor(plan["id"]).size()+" LEGS / REV "+plan["revision"],30,28,MUTED);
        centre(dc,346,42,"START SELECT",36,34,GREEN);
        if(app.notice!=null) { centre(dc,397,30,shortLabel(app.notice,24),26,24,AMBER); }
    }
    function summary(dc) {
        var plan=FlightPlan.find(app.nav.s["planId"]);
        centre(dc,52,50,"FLIGHT",44,42,Graphics.COLOR_WHITE);
        centre(dc,121,36,"DEMO / NOT VALIDATED",28,26,AMBER);
        centre(dc,181,68,shortLabel(app.nav.s["flight"],24),50,32,Graphics.COLOR_WHITE);
        centre(dc,277,36,app.nav.plan.size()+" LEGS / REV "+plan["revision"],32,30,MUTED);
        centre(dc,336,44,"START FLIGHT",38,36,GREEN);
        centre(dc,390,34,"BACK SELECT",30,28,MUTED);
    }
    function recordingText() {
        if(app.recording.state.equals("saved")) { return "FIT SAVED"; }
        if(app.recording.state.equals("recording")) {
            if(app.recording.gps.fault || !app.recording.gps.enabled) { return "FIT ON / GPS ERROR"; }
            return app.recording.gps.quality.equals("GPS fix / recording") ? "FIT ON / GPS FIX" : "FIT ON / GPS WAIT";
        }
        if(app.nativeUnresolved()) { return "FIT NEEDS REVIEW"; }
        return app.nav.s["started"] ? "FIT NOT ON" : "FIT NOT STARTED";
    }
    function timers(dc) {
        var white=Graphics.COLOR_WHITE;
        centre(dc,44,32,"SESSION",28,28,white); centre(dc,78,64,durationText(app.nav.timers.s["elapsed"]),64,56,white);
        centre(dc,151,32,"AIRBORNE",28,28,white); centre(dc,185,64,durationText(app.nav.timers.airborne()),64,56,white);
        centre(dc,257,32,"LEG",28,28,white); centre(dc,291,64,durationText(app.nav.legSeconds()),64,56,white);
        centre(dc,365,30,stateText(),28,24,app.recording.warning || app.nav.s["radioPending"] || app.storageBlocked ? AMBER : white);
        centre(dc,400,28,recordingText(),24,22,app.recording.warning || app.recording.gps.fault ? AMBER : MUTED);
    }
    function menu(dc) {
        var ids=app.menuIds(); var index=app.selected<ids.size() ? app.selected : ids.size()-1; var id=ids[index];
        centre(dc,58,50,"ACTIONS",42,40,Graphics.COLOR_WHITE);
        centre(dc,177,108,menuLabel(id),84,54,id==11 ? 0xFF6666 : Graphics.COLOR_WHITE);
        if(id==1 || id==2 || id==13) {
            var leg=app.nav.leg(); var legNumber=app.nav.s["index"]+1; if(id==2 && app.nav.undoState!=null) { leg=app.nav.plan[app.nav.undoState["index"]]; legNumber=app.nav.undoState["index"]+1; }
            centre(dc,308,42,shortLabel(leg["from"]+" > "+leg["to"],25),34,28,MUTED);
            centre(dc,365,30,"LEG "+legNumber+"/"+app.nav.plan.size(),28,26,MUTED);
        }
    }
    function alertSettings(dc) {
        var names=["VIBRATE","SOUND","BOTH","OFF"]; var details=["Vibration only","Sound only","Vibration + sound","Alerts disabled"];
        centre(dc,58,52,"ALERTS",44,42,Graphics.COLOR_WHITE);
        centre(dc,171,98,names[app.alertChoice],80,64,Graphics.COLOR_WHITE);
        centre(dc,278,40,details[app.alertChoice],34,30,MUTED);
        centre(dc,339,42,"START SAVE",36,34,GREEN); centre(dc,391,34,"BACK CANCEL",30,28,MUTED);
    }
    function radio(dc) {
        centre(dc,62,64,"RADIO",56,54,AMBER);
        centre(dc,139,35,"REFERENCE ONLY",28,28,MUTED);
        radioRows(dc,200,270,52);
        centre(dc,343,42,"START ACK",36,34,GREEN); centre(dc,395,32,"BACK LATER",28,26,MUTED);
    }
    function confirm(dc) {
        var id=app.pending; var red=id==11 ? 0xFF6666 : Graphics.COLOR_WHITE;
        var title=id==12 ? "START" : (id==11 ? "DISCARD" : (id==4 ? "FINISH" : menuLabel(id)));
        centre(dc,69,72,title,64,48,red); centre(dc,145,68,id==12 || id==11 || id==4 ? "FLIGHT?" : "CONFIRM?",60,48,red);
        if(id==4) { centre(dc,227,34,app.nav.timers.s["airStart"]!=null ? "Landing unconfirmed" : "Save flight and FIT",30,28,AMBER); centre(dc,270,32,"No invented arrival",28,26,MUTED); }
        if(id==11) { centre(dc,232,40,"WILL NOT BE SAVED",34,30,0xFF6666); }
        if(id==12) { centre(dc,227,34,"Starts recording",32,30,MUTED); centre(dc,270,32,"Takeoff is manual",28,28,AMBER); }
        if(id==10) { centre(dc,229,36,"FIT may stay pending",32,28,AMBER); centre(dc,272,32,"Only saves local log",28,26,MUTED); }
        if(id==3) { centre(dc,236,40,"Pilot-confirmed event",30,28,AMBER); }
        centre(dc,332,44,id==4 ? "START SAVE" : (id==11 ? "START DISCARD" : "START CONFIRM"),36,32,id==11 ? 0xFF6666 : GREEN);
        centre(dc,387,36,"BACK CANCEL",30,28,MUTED);
    }
    function recovery(dc) {
        var white=Graphics.COLOR_WHITE;
        if(app.screen.equals("review")) {
            centre(dc,55,60,"FIT REVIEW",48,44,AMBER);
            centre(dc,139,40,"Local log retained",34,32,white);
            centre(dc,193,40,"Original FIT unknown",32,30,AMBER);
            centre(dc,247,40,"No new recording",32,30,white);
            centre(dc,301,40,"Do not reset data",32,30,white);
            centre(dc,370,40,"BACK OPTIONS",32,30,GREEN); return;
        }
        centre(dc,55,60,app.nav.s["finishRequested"] || app.nav.s["finished"] ? "SAVE PENDING" : "RECOVERY",46,42,AMBER);
        centre(dc,129,40,app.storageBlocked ? "Checkpoints retained" : "Local log retained",32,30,white);
        if(app.notice!=null) { centre(dc,174,34,shortLabel(app.notice,31),28,24,AMBER); }
        var ids=app.recoveryIds(); var index=app.selected<ids.size() ? app.selected : 0; var id=ids[index];
        centre(dc,217,56,menuLabel(id),44,36,GREEN);
        var first="Keep original data"; var second="Review before replacing";
        if(id==10) { first="Close local log only"; second="FIT may stay pending"; }
        if(id==14) { first="Manual navigation"; second="Recording warning stays"; }
        if(id==8) { first="One recording retry"; second="FIT/GPS gaps possible"; }
        if(id==4) { first="Retry original save"; second="Do not start a new flight"; }
        centre(dc,281,34,first,28,26,white); centre(dc,318,34,second,28,26,white);
        centre(dc,358,36,"START SELECT",30,28,GREEN); centre(dc,400,32,"BACK FLIGHT",28,24,MUTED);
    }
    function completed(dc) {
        var white=Graphics.COLOR_WHITE;
        centre(dc,76,86,app.nav.s["discarded"] ? "DISCARDED" : "FINISHED",64,54,white);
        centre(dc,195,56,app.nav.s["fitOutcome"].equals("saved") ? "FIT + LOG SAVED" : (app.nav.s["discarded"] ? "NOT SAVED" : "LOCAL LOG ONLY"),40,36,app.nav.s["fitOutcome"].equals("saved") ? GREEN : AMBER);
        centre(dc,296,44,"Returning to Garmin",32,28,MUTED); centre(dc,373,40,"START EXIT",36,32,GREEN);
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
