import Toybox.Position;
class GpsRecorder {
    var quality = "GPS acquiring";
    function initialize() {}
    function start() { Position.enableLocationEvents(Position.LOCATION_CONTINUOUS, method(:onPosition)); }
    // Intentionally never passes coordinates, speed or heading into navigation.
    function onPosition(info as Position.Info) as Void {
        quality = info.accuracy == Position.QUALITY_GOOD ? "GPS fix" : "GPS weak / no fix";
    }
    function stop() { Position.enableLocationEvents(Position.LOCATION_DISABLE, null); }
}
