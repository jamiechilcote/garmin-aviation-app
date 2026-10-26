// Separate simulator-only lifecycle probe. Never included in production jungle/sourcePath.
import Toybox.Application.Storage;
import Toybox.Activity;
import Toybox.ActivityRecording;
import Toybox.System;
import Toybox.Time;
class PendingProofRecording extends Recording {
    function initialize() { Recording.initialize(); }
    function createSession() { return ActivityRecording.createSession({:name=>"Navlog Pending",:sport=>Activity.SPORT_FLYING,:subSport=>Activity.SUB_SPORT_GENERIC}); }
}
class PendingAcceptanceApp extends NavlogApp {
    var phase=0; var stage=0; var launched;
    function initialize() { NavlogApp.initialize(); persistence.prefix="pending-proof-"; recording=new PendingProofRecording(); }
    function identity() {
        var info=Activity.getActivityInfo();
        return {"startUtc"=>info.startTime==null ? null : info.startTime.value(),"timerMs"=>info.timerTime,"elapsedMs"=>info.elapsedTime};
    }
    function onStart(state) {
        NavlogApp.onStart(state); var value=Storage.getValue("probePhase"); phase=value==null ? 0 : value;
        launched=System.getTimer(); System.println("PENDING_PROBE_PHASE "+phase+" initial="+identity());
        if(phase==0) { nav=new Navigation(); screen="nav"; }
    }
    function tick() as Void {
        NavlogApp.tick(); var elapsed=monotonicDelta(System.getTimer(),launched)/1000;
        if(phase==0) {
            if(stage==0 && elapsed>=1) { input("select"); stage=1; }
            if(stage==1 && elapsed>=3) { execute(3,Time.now().value()); stage=2; }
            if(stage==2 && elapsed>=8) { execute(10,Time.now().value()); checkpoint(); stage=3; }
            if(stage==3 && elapsed>=9) {
                Storage.setValue("nativeIdentity",identity()); Storage.setValue("probePhase",1);
                System.println("PENDING_LOCAL_END finished="+nav.s["finished"]+" pending="+nav.s["fitPending"]+" identity="+identity()); System.exit();
            }
        } else if(stage==0 && elapsed>=2) {
            System.println("RESTART_LOCAL_STATE finished="+nav.s["finished"]+" pending="+nav.s["fitPending"]+" sessionNull="+(recording.session==null));
            System.println("EXPECTED_NATIVE_IDENTITY "+Storage.getValue("nativeIdentity"));
            execute(4,Time.now().value()); System.println("PRODUCTION_GUARD "+notice);
            var candidate=ActivityRecording.createSession({:name=>"Probe Unstarted",:sport=>Activity.SPORT_GENERIC,:subSport=>Activity.SUB_SPORT_GENERIC});
            System.println("CANDIDATE recording="+candidate.isRecording()+" identity="+identity());
            var saved=candidate.save(); System.println("CANDIDATE_SAVE_WITHOUT_START "+saved);
            Storage.setValue("probePhase",phase+1); stage=1; System.exit();
        }
    }
}
