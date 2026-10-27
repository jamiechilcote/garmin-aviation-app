// Simulator-only driver. Production source is compiled without this directory.
// Configure the real simulator's FIT playback before manually pressing watch START.
import Toybox.System;
import Toybox.Time;
import Toybox.Position;
class GpsAcceptanceApp extends NavlogApp {
    var stage=0; var launched=null;
    function initialize() { NavlogApp.initialize(); persistence.prefix="gps-acceptance-"; }
    function onStart(state) {
        NavlogApp.onStart(state); nav=new Navigation(); nav.selectPlan(FlightPlan.DEFAULT_ID); screen="summary";
        System.println("GPS_ACCEPTANCE_READY: configure playback, press physical START twice to confirm flight");
    }
    function tick() as Void {
        NavlogApp.tick();
        if(launched==null) {
            if(nav.s["started"]) { launched=System.getTimer(); stage=1; System.println("STARTED "+recording.status); }
            return;
        }
        var elapsed=monotonicDelta(System.getTimer(),launched)/1000;
        if(stage==1 && elapsed>=2) { input("select"); stage=2; }
        if(stage==2 && elapsed>=4) { input("select"); stage=3; }
        if(stage==3 && elapsed>=24) { execute(3,Time.now().value()); stage=4; }
        if(stage==4 && elapsed>=28) {
            var info=Position.getInfo();
            System.println("GPS_STATUS "+recording.gps.quality+" accuracy="+info.accuracy);
            if(info.position!=null) { System.println("GPS_POSITION "+info.position.toDegrees()); }
            execute(4,Time.now().value()); checkpoint();
            System.println("GPS_ACCEPTANCE_FINISHED saved="+nav.s["finished"]+" status="+recording.status+" elapsed="+nav.timers.s["elapsed"]);
            stage=5; if(recording.state.equals("saved")) { System.exit(); }
        }
    }
}
