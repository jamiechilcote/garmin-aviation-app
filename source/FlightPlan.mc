// Every numeric value is invented demonstration data, never operational data.
module FlightPlan {
    const NAME = "Camden - Goulburn Return";
    function legs() {
        return [
            {"from"=>"YSCN", "to"=>"YSHL", "heading"=>135, "altitude"=>3500, "nm"=>25.0, "gs"=>100.0, "active"=>"123.450", "standby"=>"124.550"},
            {"from"=>"YSHL", "to"=>"YGLB", "heading"=>270, "altitude"=>4500, "nm"=>32.0, "gs"=>120.0, "active"=>"124.550", "standby"=>"125.650"},
            {"from"=>"YGLB", "to"=>"Mittagong", "heading"=>65, "altitude"=>3500, "nm"=>18.0, "gs"=>90.0, "active"=>"125.650", "standby"=>"126.750"},
            {"from"=>"Mittagong", "to"=>"YSCN", "heading"=>35, "altitude"=>2500, "nm"=>24.0, "gs"=>110.0, "active"=>"126.750", "standby"=>"123.450"}
        ];
    }
}

