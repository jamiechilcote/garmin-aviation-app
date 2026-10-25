import Toybox.Application;
import Toybox.WatchUi;
import Toybox.Timer;

class NavlogApp extends Application.AppBase {
    var pulse;
    function initialize() { AppBase.initialize(); }
    function getInitialView() { return [new NavView(), new NavDelegate()]; }
    function onStart(state) {
        pulse = new Timer.Timer();
        pulse.start(method(:tick), 1000, true);
    }
    function tick() as Void { WatchUi.requestUpdate(); }
    function onStop(state) { pulse.stop(); }
}

