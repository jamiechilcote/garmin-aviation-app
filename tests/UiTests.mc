import Toybox.Test;
import Toybox.Graphics;
(:test) function clockDisplayBoundaries(logger) {
    Test.assertEqual(clockText(12,59,59),"12:59:59"); Test.assertEqual(clockText(13,0,0),"13:00:00");
    Test.assertEqual(clockText(23,59,59),"23:59:59"); Test.assertEqual(clockText(0,0,0),"00:00:00"); return true;
}
(:test) function rendererCircularBounds(logger) {
    var buffer=Graphics.createBufferedBitmap({:width=>454,:height=>454}).get(); var dc=buffer.getDc();
    var app=new NavlogApp(); app.testing=true; var view=new NavView(app);
    Test.assert(view.fontFor(24)!=null);
    var scenes=["idle","running","due","radio","advance","timers","recovery","error","finish","complete","longLeg","localFinish"];
    for(var i=0;i<scenes.size();i+=1) {
        app.nav=new Navigation(); app.recording=new TestRecording(); app.screen="nav"; app.notice=null;
        var scene=scenes[i];
        if(!scene.equals("idle")) { app.nav.start(1000); }
        if(scene.equals("running")) { app.nav.checkAction(1000); app.nav.timers.s["elapsed"]=138; }
        if(scene.equals("due")) { app.nav.checkAction(1000); app.nav.timers.s["elapsed"]=400; app.nav.tick(); }
        if(scene.equals("radio")) { app.screen="radio"; }
        if(scene.equals("advance")) { app.screen="confirm"; app.pending=1; }
        if(scene.equals("timers")) { app.screen="timers"; }
        if(scene.equals("recovery")) { app.screen="recovery"; }
        if(scene.equals("error")) { app.recording.warning=true; app.recording.status="FIT stopped - retry"; app.recording.gps.fault=true; }
        if(scene.equals("finish")) { app.screen="confirm"; app.pending=4; app.nav.timers.takeoff(1000); }
        if(scene.equals("localFinish")) { app.screen="confirm"; app.pending=10; }
        if(scene.equals("complete")) { app.nav.check.s["remainingNm"]=0; app.nav.check.s["state"]="complete"; }
        if(scene.equals("longLeg")) { app.nav.advance(1001); app.nav.advance(1002); }
        view.onUpdate(dc);
        if(view.layoutError) { logger.error("Text does not fit: "+scene); }
        Test.assert(!view.layoutError);
        for(var b=0;b<view.bounds.size();b+=1) {
            var r=view.bounds[b];
            var xs=[r["x"],r["x"]+r["w"]]; var ys=[r["y"],r["y"]+r["h"]];
            for(var x=0;x<2;x+=1) { for(var y=0;y<2;y+=1) {
                var dx=xs[x]-227; var dy=ys[y]-227;
                Test.assert(dx*dx+dy*dy<=217*217+1);
            } }
        }
        for(var a=0;a<view.bounds.size();a+=1) { for(var z=a+1;z<view.bounds.size();z+=1) {
            var ar=view.bounds[a]; var br=view.bounds[z];
            var overlap=ar["x"]<br["x"]+br["w"] && ar["x"]+ar["w"]>br["x"] && ar["y"]<br["y"]+br["h"] && ar["y"]+ar["h"]>br["y"];
            if(overlap) { logger.error("Overlap in "+scene+": "+ar["text"]+" / "+br["text"]); }
            Test.assert(!overlap);
        } }
        if(app.screen.equals("radio")) { Test.assert(view.bounds[1]["h"]>view.bounds[3]["h"]); }
        logger.debug("Rendered within circle: "+scene+" ("+view.bounds.size()+" text boxes)");
    }
    return true;
}
(:test) function demoWarningIsConditional(logger) {
    var buffer=Graphics.createBufferedBitmap({:width=>454,:height=>454}).get(); var app=new NavlogApp(); app.testing=true;
    app.nav.s["demo"]=false; var v=new NavView(app); v.onUpdate(buffer.getDc());
    for(var i=0;i<v.bounds.size();i+=1) { Test.assert(!v.bounds[i]["text"].equals("DEMO PLAN")); } return true;
}
(:test) function radioConfirmationPreservesReferences(logger) {
    var app=V2Harness.active(); app.execute(1,1100); var active=app.nav.leg()["active"];
    Test.assertEqual(app.screen,"radio"); Test.assert(app.nav.s["radioPending"]);
    V2Harness.press(app,"back"); Test.assert(app.nav.s["radioPending"]);
    app.selectAction(13,"menu"); V2Harness.press(app,"select");
    Test.assert(!app.nav.s["radioPending"]); Test.assertEqual(app.nav.leg()["active"],active); return true;
}

(:test) function touchTapCannotStartOrAcknowledge(logger) {
    var app=new NavlogApp(); app.testing=true; var delegate=new NavDelegate(app);
    Test.assert(delegate.onTap(new Toybox.WatchUi.ClickEvent(227,227,Toybox.WatchUi.CLICK_TYPE_TAP))); Test.assert(!app.nav.s["started"]);
    app.nav.start(1000); app.nav.checkAction(1000); app.nav.timers.s["elapsed"]=400; app.nav.tick();
    Test.assert(delegate.onTap(new Toybox.WatchUi.ClickEvent(227,227,Toybox.WatchUi.CLICK_TYPE_TAP))); Test.assertEqual(app.nav.check.s["state"],"due"); return true;
}



(:test) function v2AllScreenBoundsAndProminence(logger) {
    var scenes=["select","summary","start","ground","airborne","running","early","overdue","complete","radio","timers","first","last","alerts","landing","finish","discard","saved","recovery","review","pending","long"];
    var buffer=Graphics.createBufferedBitmap({:width=>454,:height=>454}).get();
    for(var s=0;s<scenes.size();s+=1) {
        var app=V2Harness.active(); app.recording.warning=false; var scene=scenes[s];
        if(scene.equals("select")) { app.screen="select"; }
        if(scene.equals("summary")) { app.screen="summary"; }
        if(scene.equals("start")) { app.screen="confirm"; app.pending=12; }
        if(scene.equals("airborne") || scene.equals("running") || scene.equals("early") || scene.equals("overdue") || scene.equals("complete")) { app.nav.timers.takeoff(1000); }
        if(scene.equals("running") || scene.equals("early") || scene.equals("overdue") || scene.equals("complete")) { app.nav.checkAction(1000); app.nav.timers.s["elapsed"]=138; }
        if(scene.equals("early")) { app.nav.timers.s["elapsed"]=300; app.nav.checkAction(1300); }
        if(scene.equals("overdue")) { app.nav.timers.s["elapsed"]=400; app.nav.tick(); }
        if(scene.equals("complete")) { app.nav.check.s["remainingNm"]=0; app.nav.check.s["state"]="complete"; }
        if(scene.equals("radio") || scene.equals("timers") || scene.equals("alerts") || scene.equals("recovery") || scene.equals("review")) { app.screen=scene; }
        if(scene.equals("first") || scene.equals("last")) { app.openMenu(scene.equals("last")); }
        if(scene.equals("landing") || scene.equals("finish") || scene.equals("discard")) { app.nav.timers.takeoff(1000); app.screen="confirm"; app.pending=scene.equals("landing") ? 3 : (scene.equals("finish") ? 4 : 11); }
        if(scene.equals("saved")) { app.execute(4,1100); }
        if(scene.equals("pending")) { app.nav.finish(1100); app.nav.s["finishRequested"]=true; app.screen="recovery"; }
        if(scene.equals("long")) { app.nav.plan[0]["to"]="VERY LONG WAYPOINT NAME FOR TEST"; app.nav.s["flight"]="VERY LONG FLIGHT PLAN NAME THAT MUST BE TRUNCATED"; app.screen="summary"; }
        var view=new NavView(app); view.onUpdate(buffer.getDc()); Test.assert(!view.layoutError);
        var clockHeight=0; var headingHeight=0; var countdownHeight=0;
        for(var i=0;i<view.bounds.size();i+=1) {
            var a=view.bounds[i]; var xs=[a["x"],a["x"]+a["w"]]; var ys=[a["y"],a["y"]+a["h"]];
            for(var x=0;x<2;x+=1) { for(var y=0;y<2;y+=1) { var dx=xs[x]-227; var dy=ys[y]-227; Test.assert(dx*dx+dy*dy<=217*217+1); } }
            for(var j=i+1;j<view.bounds.size();j+=1) { var b=view.bounds[j]; Test.assert(!(a["x"]<b["x"]+b["w"] && a["x"]+a["w"]>b["x"] && a["y"]<b["y"]+b["h"] && a["y"]+a["h"]>b["y"])); }
            if(a["text"].length()==8 && a["text"].substring(2,3).equals(":")) { clockHeight=a["h"]; }
            if(a["text"].equals("135°")) { headingHeight=a["h"]; }
            if(scene.equals("running") && a["text"].equals("03:42")) { countdownHeight=a["h"]; }
        }
        if(app.screen.equals("nav")) { Test.assert(clockHeight>=72); Test.assert(headingHeight>=56); Test.assert(clockHeight>headingHeight); }
        if(scene.equals("running")) { Test.assert(countdownHeight>=56); Test.assert(clockHeight>countdownHeight); }
        logger.debug("V2 bounds and hierarchy verified: "+scene);
    } return true;
}

(:test) function v2LongPlanNameActuallyTruncates(logger) {
    var app=V2Harness.selected(); app.nav.s["flight"]="VERY LONG DEMONSTRATION FLIGHT PLAN NAME FOR TRUNCATION";
    var view=new NavView(app); var bitmap=Graphics.createBufferedBitmap({:width=>454,:height=>454}).get(); view.onUpdate(bitmap.getDc());
    var expected=view.shortLabel(app.nav.s["flight"],24); Test.assertEqual(expected.length(),24); var found=false;
    for(var i=0;i<view.bounds.size();i+=1) { if(view.bounds[i]["text"].equals(expected)) { found=true; } }
    Test.assert(found); Test.assert(!view.layoutError); return true;
}
