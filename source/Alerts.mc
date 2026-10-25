import Toybox.Attention;
class Alerts {
    var mode = 0;
    var names = ["Vibration", "Audible", "Both", "Disabled"];
    function initialize() {}
    function fire() {
        if ((mode == 0 || mode == 2) && (Attention has :vibrate)) {
            Attention.vibrate([new Attention.VibeProfile(80,500), new Attention.VibeProfile(0,200), new Attention.VibeProfile(80,500)]);
        }
        if ((mode == 1 || mode == 2) && (Attention has :playTone)) { Attention.playTone(Attention.TONE_ALERT_HI); }
    }
}
