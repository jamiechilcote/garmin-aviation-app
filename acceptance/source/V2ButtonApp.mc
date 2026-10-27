// Only isolate storage/app identity and report evidence. All inputs use production behaviour.
import Toybox.System;
class V2ButtonApp extends NavlogApp {
    function initialize() { NavlogApp.initialize(); persistence.prefix="v2-button-"; }
    function input(action) {
        NavlogApp.input(action);
        System.println("BUTTON "+action+" screen="+screen+" state="+flightState()+" action="+primaryAction()+" leg="+nav.s["index"]+" checks="+nav.progress()["done"]+" periods="+nav.timers.s["periods"].size()+" native="+recording.state);
    }
    function onStop(state) {
        System.println("END native="+recording.state+" outcome="+nav.s["fitOutcome"]+" pending="+nav.s["fitPending"]+" legs="+nav.s["legs"]+" checks="+nav.s["checks"]+" periods="+nav.timers.s["periods"]);
        NavlogApp.onStop(state);
    }
}
