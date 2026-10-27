import Toybox.Test;
import Toybox.Graphics;
(:test) class V3FixedClockView extends NavView {
    function initialize(owner) { NavView.initialize(owner); }
    function localClock() { return "23:59:59"; }
}
(:test) class V3RenderChecks {
    static function contains(view,value) { for(var i=0;i<view.bounds.size();i+=1) { if(view.bounds[i]["text"].equals(value)) { return true; } } return false; }
    static function box(view,value) { for(var i=0;i<view.bounds.size();i+=1) { if(view.bounds[i]["text"].equals(value)) { return view.bounds[i]; } } return null; }
    static function draw(app) { var view=new V3FixedClockView(app); var buffer=Graphics.createBufferedBitmap({:width=>454,:height=>454}).get(); view.onUpdate(buffer.getDc()); Test.assert(!view.layoutError); return view; }
    static function circle(view,dc) {
        for(var i=0;i<view.bounds.size();i+=1) { var a=view.bounds[i]; Test.assert(view.inside(dc,a["x"],a["y"],a["w"],a["h"]));
            for(var j=i+1;j<view.bounds.size();j+=1) { var b=view.bounds[j]; Test.assert(!(a["x"]<b["x"]+b["w"] && a["x"]+a["w"]>b["x"] && a["y"]<b["y"]+b["h"] && a["y"]+a["h"]>b["y"])); }
        }
    }
}
(:test) function v3NavigationHasOnlyRequiredContent(logger) {
    var app=V2Harness.active(); var view=V3RenderChecks.draw(app);
    var required=["23:59:59","HEADING","CLEAROFF","135°","TAKEOFF","ACTIVE","123.450","STBY","124.550"];
    Test.assertEqual(view.bounds.size(),required.size()); for(var i=0;i<required.size();i+=1) { Test.assert(V3RenderChecks.contains(view,required[i])); }
    // Demo/route/progress/status/instructions must not creep back into either demo or non-demo navigation.
    app.nav.s["demo"]=false; app.notice="Some status"; app.nav.s["radioPending"]=true; view=V3RenderChecks.draw(app); Test.assertEqual(view.bounds.size(),9); return true;
}
(:test) function v3ContextActionMatchesActualStart(logger) {
    var app=V2Harness.active(); var view=V3RenderChecks.draw(app); Test.assert(V3RenderChecks.contains(view,"TAKEOFF")); V2Harness.press(app,"select");
    view=V3RenderChecks.draw(app); Test.assert(V3RenderChecks.contains(view,"START")); Test.assert(V3RenderChecks.contains(view,"CLEAROFF")); Test.assertEqual(view.bounds.size(),10);
    V2Harness.press(app,"select"); Test.assertEqual(app.nav.check.s["state"],"running"); view=V3RenderChecks.draw(app); Test.assert(V3RenderChecks.contains(view,"06:00"));
    app.nav.timers.s["elapsed"]=300; V2Harness.press(app,"select"); Test.assertEqual(app.nav.progress()["done"],1); Test.assertEqual(app.nav.check.countdown(app.nav.timers.s["elapsed"]),360);
    app.nav.timers.s["elapsed"]=660; V2Harness.press(app,"select"); app.nav.timers.s["elapsed"]=840; V2Harness.press(app,"select");
    view=V3RenderChecks.draw(app); Test.assert(V3RenderChecks.contains(view,"COMPLETE")); Test.assertEqual(app.nav.s["index"],0); return true;
}
(:test) function v3OverdueIsAmberAndStillAcknowledges(logger) {
    var app=V2Harness.active(); app.execute(3,1000); app.nav.checkAction(1000); app.nav.timers.s["elapsed"]=400; app.nav.tick();
    var view=V3RenderChecks.draw(app); var due=V3RenderChecks.box(view,"DUE"); Test.assert(due!=null); Test.assertEqual(due["color"],view.AMBER); Test.assert(due["h"]>=82);
    V2Harness.press(app,"select"); Test.assertEqual(app.nav.check.s["dueElapsed"],760); return true;
}
(:test) function v3GroundAndPendingActionsOverrideOldCountdown(logger) {
    var app=V2Harness.active(); app.nav.checkAction(1000); app.nav.timers.s["elapsed"]=400; app.nav.tick();
    var view=V3RenderChecks.draw(app); Test.assert(V3RenderChecks.contains(view,"TAKEOFF")); Test.assert(!V3RenderChecks.contains(view,"DUE"));
    app.nav.s["finishRequested"]=true; view=V3RenderChecks.draw(app); Test.assert(V3RenderChecks.contains(view,"REVIEW")); Test.assert(V3RenderChecks.contains(view,"SAVE"));
    V2Harness.press(app,"select"); Test.assertEqual(app.screen,"recovery"); Test.assert(!app.exitRequested); return true;
}
(:test) function v3LongestDigitsAndRadioAlignment(logger) {
    var app=V2Harness.active(); app.execute(3,1000); app.nav.checkAction(1000);
    app.nav.plan[0]["heading"]=360; app.nav.plan[0]["active"]="136.975"; app.nav.plan[0]["standby"]="399.999";
    var countdowns=[0,3599];
    for(var i=0;i<countdowns.size();i+=1) {
        app.nav.check.s["dueElapsed"]=countdowns[i]; var view=V3RenderChecks.draw(app);
        Test.assert(V3RenderChecks.contains(view,"23:59:59")); Test.assert(V3RenderChecks.contains(view,"360°")); Test.assert(V3RenderChecks.contains(view,i==0 ? "00:00" : "59:59"));
        var a=V3RenderChecks.box(view,"136.975"); var b=V3RenderChecks.box(view,"399.999"); Test.assertEqual(a["x"]+a["w"],b["x"]+b["w"]);
        Test.assertEqual(V3RenderChecks.box(view,"ACTIVE")["x"],V3RenderChecks.box(view,"STBY")["x"]);
        Test.assertEqual(a["h"],54); Test.assertEqual(V3RenderChecks.box(view,"23:59:59")["h"],104); Test.assertEqual(V3RenderChecks.box(view,"360°")["h"],86);
        var bitmap=Graphics.createBufferedBitmap({:width=>454,:height=>454}).get(); V3RenderChecks.circle(view,bitmap.getDc());
        Test.assertEqual(bitmap.getDc().getTextWidthInPixels("111111",view.fontFor(104)),bitmap.getDc().getTextWidthInPixels("888888",view.fontFor(104)));
    }
    var plans=FlightPlan.catalogue(); for(var p=0;p<plans.size();p+=1) { var legs=FlightPlan.legsFor(plans[p]["id"]); for(var l=0;l<legs.size();l+=1) { Test.assert(legs[l]["active"].length()<=7); Test.assert(legs[l]["standby"].length()<=7); } } return true;
}
(:test) function v3ResponsiveCircularRegions(logger) {
    var app=V2Harness.active(); app.execute(3,1000); app.nav.checkAction(1000); var sizes=[360,454];
    for(var i=0;i<sizes.size();i+=1) { var bitmap=Graphics.createBufferedBitmap({:width=>sizes[i],:height=>sizes[i]}).get(); var view=new V3FixedClockView(app); view.onUpdate(bitmap.getDc()); Test.assert(!view.layoutError); V3RenderChecks.circle(view,bitmap.getDc()); } return true;
}
(:test) function v3LargeMenusPreserveRingAndConfirmations(logger) {
    var app=V2Harness.active(); V2Harness.press(app,"back"); Test.assertEqual(app.screen,"timers");
    V2Harness.press(app,"up"); var view=V3RenderChecks.draw(app); Test.assert(V3RenderChecks.contains(view,"DISCARD")); Test.assert(V3RenderChecks.box(view,"DISCARD")["h"]>=70);
    V2Harness.press(app,"select"); Test.assertEqual(app.pending,11); view=V3RenderChecks.draw(app); Test.assert(V3RenderChecks.contains(view,"START DISCARD")); Test.assert(V3RenderChecks.contains(view,"BACK CANCEL"));
    V2Harness.press(app,"back"); Test.assertEqual(app.recording.fake.discarded,0); V2Harness.press(app,"back"); V2Harness.press(app,"down");
    view=V3RenderChecks.draw(app); Test.assert(V3RenderChecks.contains(view,"ADVANCE")); Test.assert(V3RenderChecks.box(view,"ADVANCE")["h"]>=70);
    app.selectAction(4,"menu"); view=V3RenderChecks.draw(app); Test.assert(V3RenderChecks.contains(view,"FINISH")); Test.assert(V3RenderChecks.contains(view,"START SAVE")); V2Harness.press(app,"back"); Test.assertEqual(app.recording.fake.saved,0); return true;
}
(:test) function v3TimerAndAlertProminence(logger) {
    var app=V2Harness.active(); app.screen="timers"; var view=V3RenderChecks.draw(app);
    Test.assertEqual(V3RenderChecks.box(view,"00:00")["h"],64); Test.assert(V3RenderChecks.contains(view,"SESSION")); Test.assert(V3RenderChecks.contains(view,"AIRBORNE")); Test.assert(V3RenderChecks.contains(view,"LEG"));
    app.selectAction(5,"menu"); view=V3RenderChecks.draw(app); Test.assert(V3RenderChecks.contains(view,"VIBRATE")); Test.assert(V3RenderChecks.box(view,"VIBRATE")["h"]>=64);
    V2Harness.press(app,"up"); view=V3RenderChecks.draw(app); Test.assert(V3RenderChecks.contains(view,"BOTH")); V2Harness.press(app,"back"); Test.assertEqual(app.alerts.mode,0); return true;
}


(:test) function v3UndoMenuLabelsTheRestoredLeg(logger) {
    var app=V2Harness.active(); app.execute(1,1100); app.openMenu(false); V2Harness.press(app,"down");
    var view=V3RenderChecks.draw(app); Test.assert(V3RenderChecks.contains(view,"UNDO")); Test.assert(V3RenderChecks.contains(view,"YSCN > YSHL")); Test.assert(V3RenderChecks.contains(view,"LEG 1/4"));
    Test.assertEqual(app.nav.s["index"],1); return true;
}

(:test) function v3TimersRetainAccurateRecordingAndFixStatus(logger) {
    var app=V2Harness.active(); app.screen="timers"; var view=V3RenderChecks.draw(app); Test.assert(V3RenderChecks.contains(view,"FIT ON / GPS WAIT"));
    app.recording.gps.quality="GPS fix / recording"; view=V3RenderChecks.draw(app); Test.assert(V3RenderChecks.contains(view,"FIT ON / GPS FIX"));
    app.recording.gps.fault=true; app.recording.warning=true; view=V3RenderChecks.draw(app); Test.assert(V3RenderChecks.contains(view,"FIT ON / GPS ERROR"));
    app.recording=new TestRecording(); app.recording.state="paused"; view=V3RenderChecks.draw(app); Test.assert(V3RenderChecks.contains(view,"FIT NEEDS REVIEW"));
    app.screen="nav"; view=V3RenderChecks.draw(app); Test.assertEqual(view.bounds.size(),9); return true;
}
