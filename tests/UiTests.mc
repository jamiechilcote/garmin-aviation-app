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
        if(app.screen.equals("nav") || app.screen.equals("radio")) { Test.assert(view.bounds[1]["h"]>view.bounds[4]["h"]); }
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
    var app=new NavlogApp(); app.testing=true; app.lastMillis=Toybox.System.getTimer(); app.nav.start(1000);
    var active=app.nav.leg()["active"]; app.input("up"); app.lastInput=null; app.input("select");
    Test.assertEqual(app.screen,"radio"); Test.assert(app.nav.s["radioPending"]);
    app.lastInput=null; app.input("back"); Test.assert(app.nav.s["radioPending"]);
    app.lastInput=null; app.input("up"); app.lastInput=null; app.input("select"); app.lastInput=null; app.input("select");
    Test.assert(!app.nav.s["radioPending"]); Test.assertEqual(app.nav.leg()["active"],active); return true;
}

(:test) function touchTapCannotStartOrAcknowledge(logger) {
    var app=new NavlogApp(); app.testing=true; var delegate=new NavDelegate(app);
    Test.assert(delegate.onTap(new Toybox.WatchUi.ClickEvent(227,227,Toybox.WatchUi.CLICK_TYPE_TAP))); Test.assert(!app.nav.s["started"]);
    app.nav.start(1000); app.nav.checkAction(1000); app.nav.timers.s["elapsed"]=400; app.nav.tick();
    Test.assert(delegate.onTap(new Toybox.WatchUi.ClickEvent(227,227,Toybox.WatchUi.CLICK_TYPE_TAP))); Test.assertEqual(app.nav.check.s["state"],"due"); return true;
}
