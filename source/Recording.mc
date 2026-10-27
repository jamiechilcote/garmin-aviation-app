import Toybox.ActivityRecording;
import Toybox.Activity;
import Toybox.FitContributor;
class Recording {
    var session=null; var gps; var airborneField=null;
    var phaseField=null; var phaseSecondsField=null; var takeoffField=null; var landingField=null;
    var state="idle"; var status="FIT not started"; var warning=false; var cleanupWarning=false;
    function initialize() { gps=new GpsRecorder(); }
    function createSession() { return ActivityRecording.createSession({:name=>"Aviation Navlog",:sport=>Activity.SPORT_FLYING,:subSport=>Activity.SUB_SPORT_GENERIC}); }
    function cleanupGps() {
        try { cleanupWarning=!gps.stop(); } catch(e) { cleanupWarning=true; }
    }
    function start() {
        if(state.equals("saved") || state.equals("discarded")) { return false; }
        warning=false;
        var gpsOk=false; try { gpsOk=gps.start(); } catch(e) { gpsOk=false; }
        try {
            if(session==null) { session=createSession(); }
            if(!session.isRecording() && !session.start()) { throw new Toybox.Lang.Exception(); }
        } catch(e) { state="unavailable"; status="FIT unavailable - retry"; warning=true; cleanupGps(); return false; }
        if(airborneField==null) {
            try { airborneField=session.createField("Airborne seconds",0,FitContributor.DATA_TYPE_UINT32,{:mesgType=>FitContributor.MESG_TYPE_SESSION,:units=>"s"}); }
            catch(e) { warning=true; }
            try {
                phaseField=session.createField("Air phase",1,FitContributor.DATA_TYPE_UINT8,{:mesgType=>FitContributor.MESG_TYPE_LAP,:units=>"code"});
                phaseSecondsField=session.createField("Air period seconds",2,FitContributor.DATA_TYPE_UINT32,{:mesgType=>FitContributor.MESG_TYPE_LAP,:units=>"s"});
                takeoffField=session.createField("Takeoff UTC",3,FitContributor.DATA_TYPE_UINT32,{:mesgType=>FitContributor.MESG_TYPE_LAP,:units=>"unix s"});
                landingField=session.createField("Landing UTC",4,FitContributor.DATA_TYPE_UINT32,{:mesgType=>FitContributor.MESG_TYPE_LAP,:units=>"unix s"});
                setPhase(0,0,0,0);
            } catch(e) { warning=true; }
        }
        state="recording"; warning=warning || !gpsOk;
        status=!gpsOk ? "FIT on / GPS failed" : (warning ? "FIT on / summary limited" : "FIT recording");
        return true;
    }
    function setPhase(kind,seconds,takeoff,landing) {
        if(phaseField==null || phaseSecondsField==null || takeoffField==null || landingField==null) { return false; }
        try { phaseField.setData(kind); phaseSecondsField.setData(seconds); takeoffField.setData(takeoff); landingField.setData(landing); return true; }
        catch(e) { warning=true; status="FIT on / lap fields failed"; return false; }
    }
    function closePhase(kind,seconds,takeoff,landing) {
        if(session==null || !state.equals("recording")) { return false; }
        try {
            if(!setPhase(kind,seconds,takeoff,landing) || !session.addLap()) { warning=true; status="FIT on / lap failed"; return false; }
            setPhase(0,0,0,0); return true;
        } catch(e) { warning=true; status="FIT on / lap failed"; return false; }
    }
    function prepareFinal(nav) {
        if(nav.timers.s["airStart"]==null) {
            var periods=nav.timers.s["periods"];
            if(nav.s["finished"] && periods.size()>0 && periods[periods.size()-1]["status"].equals("unconfirmed")) {
                var last=periods[periods.size()-1]; setPhase(2,last["seconds"],last["takeoffUtc"],0);
            } else { setPhase(0,0,0,0); }
        }
        else {
            var p=nav.timers.s["periods"][nav.timers.s["periods"].size()-1];
            setPhase(2,nav.timers.s["elapsed"]-nav.timers.s["airStart"],p["takeoffUtc"],0);
        }
    }
    function resumeAfterSaveFailure() {
        warning=true;
        try {
            if(session.isRecording() || session.start()) { state="recording"; status="FIT on / save failed"; return; }
        } catch(e) {}
        state="savePending"; status="FIT stopped - retry";
    }
    function save(airborne) {
        if(state.equals("saved")) { return true; }
        if(session==null) { status="No FIT - local only"; warning=true; return false; }
        try {
            if(airborneField!=null) { airborneField.setData(airborne); }
            if(session.isRecording() && !session.stop()) {
                if(!session.isRecording()) { resumeAfterSaveFailure(); }
                else { status="FIT stop failed"; warning=true; } return false;
            }
            if(!session.save()) { resumeAfterSaveFailure(); return false; }
        } catch(e) { resumeAfterSaveFailure(); return false; }
        // Saving is irreversible; cleanup cannot change the reported result.
        session=null; airborneField=null; state="saved"; warning=false; status="FIT saved";
        cleanupGps(); if(cleanupWarning) { status="FIT saved / GPS cleanup"; warning=true; }
        return true;
    }
    function discard() {
        if(state.equals("discarded")) { return true; }
        if(state.equals("saved")) { status="Already saved - cannot discard"; return false; }
        try {
            if(session!=null) {
                if(session.isRecording() && !session.stop()) { warning=true; status="Cannot stop for discard"; return false; }
                if(!session.discard()) { resumeAfterSaveFailure(); status="Discard failed - retained"; return false; }
            }
        } catch(e) { warning=true; status="Discard uncertain - retained"; return false; }
        session=null; airborneField=null; state="discarded"; status="Flight discarded"; warning=false; cleanupGps(); return true;
    }
    function suspend() {
        if(session!=null && !state.equals("saved")) {
            try {
                if(session.isRecording() && !session.stop()) { warning=true; status="FIT pause failed"; }
                else { state="paused"; status="FIT interrupted - retry"; warning=true; }
            } catch(e) { state="savePending"; status="FIT state unknown"; warning=true; }
        }
        cleanupGps();
    }
}
