// All bundled values are invented demo fixtures, never operational navigation data.
module FlightPlan {
    const DEMO=true;
    const NAME="Camden - Goulburn Return";
    const DEFAULT_ID="demo-return-r1";
    function catalogue() {
        return [
            {"id"=>DEFAULT_ID,"name"=>"YSCN-YGLB-YSCN","departure"=>"YSCN","destination"=>"YSCN","revision"=>"1","date"=>"2026-10-27","demo"=>true},
            {"id"=>"demo-outbound-r1","name"=>"YSCN-YGLB","departure"=>"YSCN","destination"=>"YGLB","revision"=>"1","date"=>"2026-10-27","demo"=>true}
        ];
    }
    function find(id) { var plans=catalogue(); for(var i=0;i<plans.size();i+=1) { if(plans[i]["id"].equals(id)) { return plans[i]; } } return null; }
    function legsFor(id) { var all=legs(); if(id.equals("demo-outbound-r1")) { return [all[0],all[1]]; } return all; }
    function legs() {
        return [
            {"from"=>"YSCN", "to"=>"YSHL", "heading"=>135, "altitude"=>3500, "nm"=>25.0, "gs"=>100.0, "active"=>"123.450", "standby"=>"124.550"},
            {"from"=>"YSHL", "to"=>"YGLB", "heading"=>270, "altitude"=>4500, "nm"=>32.0, "gs"=>120.0, "active"=>"124.550", "standby"=>"125.650"},
            {"from"=>"YGLB", "to"=>"Mittagong", "heading"=>65, "altitude"=>3500, "nm"=>18.0, "gs"=>90.0, "active"=>"125.650", "standby"=>"126.750"},
            {"from"=>"Mittagong", "to"=>"YSCN", "heading"=>35, "altitude"=>2500, "nm"=>24.0, "gs"=>110.0, "active"=>"126.750", "standby"=>"123.450"}
        ];
    }
}
