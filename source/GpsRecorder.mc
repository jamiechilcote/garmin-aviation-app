import Toybox.Position;
class GpsRecorder {
    var quality="GPS off"; var enabled=false; var fault=false;
    function initialize() {}
    function start() {
        try { Position.enableLocationEvents(Position.LOCATION_CONTINUOUS,method(:onPosition)); enabled=true; fault=false; quality="GPS acquiring"; return true; }
        catch(e) { fault=true; quality="GPS start failed"; return false; }
    }
    // No position, speed, heading or altitude is passed to the navigation engine.
    function onPosition(info as Position.Info) as Void { quality=info.accuracy==Position.QUALITY_GOOD ? "GPS fix / recording" : "GPS weak / no fix"; }
    function stop() {
        try { Position.enableLocationEvents(Position.LOCATION_DISABLE,null); enabled=false; fault=false; quality="GPS off"; return true; }
        catch(e) { fault=true; quality="GPS state unknown"; return false; }
    }
}
