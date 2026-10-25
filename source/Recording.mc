import Toybox.ActivityRecording;
import Toybox.Activity;
import Toybox.FitContributor;
class Recording {
    var session = null; var gps; var airborneField; var status = "Not recording";
    function initialize() { gps = new GpsRecorder(); }
    function start() {
        try {
            gps.start();
            session = ActivityRecording.createSession({:name=>"Aviation Navlog", :sport=>Activity.SPORT_FLYING, :subSport=>Activity.SUB_SPORT_GENERIC});
            airborneField = session.createField("Airborne seconds", 0, FitContributor.DATA_TYPE_UINT32,
                {:mesgType=>FitContributor.MESG_TYPE_SESSION, :units=>"s"});
            if (!session.isRecording() && !session.start()) { status = "FIT start failed"; return false; }
            status = "FIT recording"; return true;
        } catch (e) { status = "GPS / FIT error"; return false; }
    }
    function save(airborne) {
        if (session == null) { status = "No FIT session"; return false; }
        try {
            airborneField.setData(airborne);
            if (session.isRecording() && !session.stop()) { status = "FIT stop failed"; return false; }
            if (!session.save()) { status = "FIT save failed"; return false; }
            session = null; gps.stop(); status = "FIT saved"; return true;
        } catch (e) { status = "FIT save error"; return false; }
    }
    function suspend() {
        try { if (session != null && session.isRecording()) { session.stop(); } gps.stop(); }
        catch (e) { status = "FIT interrupt error"; }
    }
}
