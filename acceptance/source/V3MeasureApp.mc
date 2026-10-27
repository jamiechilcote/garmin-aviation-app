// Frozen appearance/measurement fixtures. No native recording or persistent writes.
import Toybox.System;
import Toybox.Time;
import Toybox.Timer;
import Toybox.WatchUi;
class V3MeasureApp extends NavlogApp {
    var scene=0;
    var scenes=["ground","airborne","running","due","complete","timers","menu","select","radio","finish","discard","alerts","recovery","summary","start","saved","review"];
    function initialize() { NavlogApp.initialize(); testing=true; }
    function getInitialView() { return [new V3MeasureView(self),new NavDelegate(self)]; }
    function onStart(state) { lastMillis=System.getTimer(); showScene(); pulse=new Timer.Timer(); pulse.start(method(:tick),1000,true); }
    function tick() as Void { WatchUi.requestUpdate(); }
    function input(action) { if(action.equals("select")) { scene=(scene+1)%scenes.size(); showScene(); } }
    function showScene() {
        nav=new Navigation(); nav.selectPlan(FlightPlan.DEFAULT_ID); nav.start(Time.now().value()-400); recording=new Recording(); notice=null; pending=null; screen="nav"; selected=0;
        var name=scenes[scene];
        if(name.equals("airborne") || name.equals("running") || name.equals("due") || name.equals("complete")) { nav.timers.takeoff(Time.now().value()-400); }
        if(name.equals("running") || name.equals("due") || name.equals("complete")) { nav.checkAction(Time.now().value()-400); nav.timers.s["elapsed"]=15; }
        if(name.equals("due")) { nav.timers.s["elapsed"]=400; nav.tick(); }
        if(name.equals("complete")) { nav.check.s["remainingNm"]=0; nav.check.s["state"]="complete"; }
        if(name.equals("timers")) { screen="timers"; nav.timers.s["elapsed"]=3599; }
        if(name.equals("menu")) { openMenu(false); }
        if(name.equals("select") || name.equals("radio") || name.equals("alerts") || name.equals("recovery") || name.equals("review") || name.equals("summary")) { screen=name; }
        if(name.equals("finish") || name.equals("discard") || name.equals("start")) { screen="confirm"; pending=name.equals("finish") ? 4 : (name.equals("discard") ? 11 : 12); }
        if(name.equals("recovery")) { recording.state="unavailable"; recording.warning=true; notice="Recording failed"; }
        if(name.equals("saved")) { nav.finish(Time.now().value()); nav.s["fitOutcome"]="saved"; screen="completed"; }
        WatchUi.requestUpdate();
    }
}
class V3MeasureView extends NavView {
    var lastScene=-1;
    function initialize(owner) { NavView.initialize(owner); }
    function onUpdate(dc) {
        NavView.onUpdate(dc);
        if(lastScene==app.scene) { return; } lastScene=app.scene;
        for(var i=0;i<bounds.size();i+=1) { var b=bounds[i]; System.println("METRIC|"+app.scenes[app.scene]+"|"+b["text"]+"|"+b["x"]+"|"+b["y"]+"|"+b["w"]+"|"+b["h"]+"|"+(b.hasKey("font") ? b["font"] : 0)); }
        System.println("DIGITS|"+dc.getTextWidthInPixels("111111",fontFor(84))+"|"+dc.getTextWidthInPixels("888888",fontFor(84)));
    }
}
