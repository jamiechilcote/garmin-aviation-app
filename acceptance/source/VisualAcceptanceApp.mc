// Test fixtures rendered by the unchanged production NavView in the real FR965 simulator.
// START moves to the next scene. No native recording, app storage writes or navigation inputs.
import Toybox.System;
import Toybox.Time;
import Toybox.Timer;
import Toybox.WatchUi;
class VisualAcceptanceApp extends NavlogApp {
    var scene=0;
    var scenes=["navigation","running","overdue","radio","waypoint","timers","recovery","finish","finished","pending"];
    function initialize() { NavlogApp.initialize(); testing=true; }
    function onStart(state) {
        lastMillis=System.getTimer(); showScene();
        pulse=new Timer.Timer(); pulse.start(method(:tick),1000,true);
    }
    function tick() as Void { WatchUi.requestUpdate(); }
    function input(action) { if(action.equals("select")) { scene=(scene+1)%scenes.size(); showScene(); } }
    function showScene() {
        nav=new Navigation(); recording=new Recording(); screen="nav"; pending=null; notice=null;
        var utc=Time.now().value(); var name=scenes[scene];
        if(scene>0) { nav.start(utc-400); nav.checkAction(utc-400); nav.timers.s["elapsed"]=138; }
        if(name.equals("overdue")) { nav.timers.s["elapsed"]=400; nav.tick(); }
        if(name.equals("radio")) { screen="radio"; }
        if(name.equals("waypoint")) { screen="confirm"; pending=1; }
        if(name.equals("timers")) { nav.timers.takeoff(utc-262); nav.timers.s["elapsed"]=400; screen="timers"; recording.status="No native FIT (UI fixture)"; }
        if(name.equals("recovery")) {
            // Exercise production checkpoint validation and restoration, including an offline gap.
            var snapshot=persistence.snapshot(nav,utc-30); nav=persistence.restore(snapshot,utc);
            screen="recovery"; recording.warning=true; recording.status="FIT not resumed - retry";
        }
        if(name.equals("finish")) { nav.timers.takeoff(utc-262); screen="confirm"; pending=4; }
        if(name.equals("finished") || name.equals("pending")) { nav.finish(utc); }
        if(name.equals("pending")) { nav.s["fitPending"]=true; }
        System.println("VISUAL_SCENE "+name); WatchUi.requestUpdate();
    }
}
