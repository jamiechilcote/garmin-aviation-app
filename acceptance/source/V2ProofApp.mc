// Isolated appearance fixtures only: overdue, recording error, unresolved-save review, icon alpha proof.
import Toybox.System;
import Toybox.Timer;
import Toybox.Time;
import Toybox.WatchUi;
import Toybox.Graphics;
class V2ProofApp extends NavlogApp {
    var scene=0;
    function initialize() { NavlogApp.initialize(); testing=true; }
    function getInitialView() { return [new V2ProofView(self),new NavDelegate(self)]; }
    function onStart(state) { lastMillis=System.getTimer(); show(); pulse=new Timer.Timer(); pulse.start(method(:tick),1000,true); }
    function tick() as Void { WatchUi.requestUpdate(); }
    function input(action) { if(action.equals("select")) { scene=(scene+1)%5; show(); } }
    function show() {
        nav=new Navigation(); nav.selectPlan(FlightPlan.DEFAULT_ID); nav.start(Time.now().value()-400); nav.timers.takeoff(Time.now().value()-400);
        nav.checkAction(Time.now().value()-400); nav.timers.s["elapsed"]=400; nav.tick(); screen="nav"; recording=new Recording();
        if(scene==1) { screen="recovery"; recording.warning=true; recording.state="unavailable"; recording.status="Recording failed"; notice="Recording failed"; }
        if(scene==2) { nav.finish(Time.now().value()); nav.s["fitPending"]=true; nav.s["finishRequested"]=true; screen="review"; }
        if(scene==4) { nav.check=new Clearoff(nav.leg()["nm"],nav.leg()["gs"]); }
        System.println("PROOF_SCENE "+scene); WatchUi.requestUpdate();
    }
}
class V2ProofView extends NavView {
    var icon;
    function initialize(owner) { NavView.initialize(owner); }
    function onUpdate(dc) {
        if(app.scene!=3) { NavView.onUpdate(dc); return; }
        bounds=[]; dc.setColor(0x777777,0x777777); dc.clear();
        dc.setColor(0x008888,0x777777); dc.fillRectangle(180,180,47,94);
        dc.setColor(0x884488,0x777777); dc.fillRectangle(227,180,47,94);
        if(icon==null) { icon=WatchUi.loadResource(Rez.Drawables.TransparencyProof); }
        dc.drawBitmap(195,195,icon);
        row(dc,100,40,"COMPILED ICON",30,Graphics.COLOR_WHITE);
        row(dc,306,35,"No opaque black square",24,Graphics.COLOR_WHITE);
        row(dc,360,28,"Asset proof / launcher untested",20,Graphics.COLOR_WHITE);
    }
}
