import Toybox.ActivityRecording;
import Toybox.Activity;
import Toybox.FitContributor;
class Recording {
    var session=null; var gps; var airborneField=null;
    var state="idle"; var status="FIT not started"; var warning=false; var cleanupWarning=false;
    function initialize() { gps=new GpsRecorder(); }
    function createSession() { return ActivityRecording.createSession({:name=>"Aviation Navlog",:sport=>Activity.SPORT_FLYING,:subSport=>Activity.SUB_SPORT_GENERIC}); }
    function cleanupGps() {
        try { cleanupWarning=!gps.stop(); } catch(e) { cleanupWarning=true; }
    }
    function start() {
        if(state.equals("saved")) { return false; }
        warning=false;
        var gpsOk=false; try { gpsOk=gps.start(); } catch(e) { gpsOk=false; }
        try {
            if(session==null) { session=createSession(); }
            if(!session.isRecording() && !session.start()) { throw new Toybox.Lang.Exception(); }
        } catch(e) { state="unavailable"; status="FIT unavailable - retry"; warning=true; cleanupGps(); return false; }
        if(airborneField==null) {
            try { airborneField=session.createField("Airborne seconds",0,FitContributor.DATA_TYPE_UINT32,{:mesgType=>FitContributor.MESG_TYPE_SESSION,:units=>"s"}); }
            catch(e) { warning=true; }
        }
        state="recording"; warning=warning || !gpsOk;
        status=!gpsOk ? "FIT on / GPS failed" : (warning ? "FIT on / summary limited" : "FIT recording");
        return true;
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
            if(session.isRecording() && !session.stop()) { status="FIT stop failed"; warning=true; return false; }
            if(!session.save()) { resumeAfterSaveFailure(); return false; }
        } catch(e) { resumeAfterSaveFailure(); return false; }
        // Saving is irreversible; cleanup cannot change the reported result.
        session=null; airborneField=null; state="saved"; warning=false; status="FIT saved";
        cleanupGps(); if(cleanupWarning) { status="FIT saved / GPS cleanup"; warning=true; }
        return true;
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

