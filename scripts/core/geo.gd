class_name Geo
extends RefCounted

const EARTH := 6378137.0

static func lonlat(q: int, r: int) -> Vector2:
	var lay: Dictionary = DataDB.map.get("layout", {})
	var x := float(lay.get("origin_x_km", 0.0)) + float(lay.get("col_w_km", 50.0)) * (float(q) + float(r) / 2.0)
	var y := float(lay.get("origin_y_km", 0.0)) - float(lay.get("row_h_km", 43.0)) * float(r)
	return _inverse(x, y, lay)


static func _t_of(phi: float) -> float:
	return tan(PI / 4.0 + phi / 2.0)


static func _inverse(x_km: float, y_km: float, lay: Dictionary) -> Vector2:
	var lat0 := deg_to_rad(float(lay.get("lat0", 33.0)))
	var lat1 := deg_to_rad(float(lay.get("lat1", 25.0)))
	var lat2 := deg_to_rad(float(lay.get("lat2", 45.0)))
	var lon0 := deg_to_rad(float(lay.get("lon0", 112.0)))
	var n := log(cos(lat1) / cos(lat2)) / log(_t_of(lat2) / _t_of(lat1))
	var f := cos(lat1) * pow(_t_of(lat1), n) / n
	var rho0 := EARTH * f / pow(_t_of(lat0), n)
	var x := x_km * 1000.0
	var y := y_km * 1000.0
	var sign := 1.0 if n >= 0.0 else -1.0
	var rho := sign * sqrt(x * x + (rho0 - y) * (rho0 - y))
	var theta := atan2(x, rho0 - y)
	var t := pow(EARTH * f / rho, 1.0 / n)
	var phi := 2.0 * atan(t) - PI / 2.0
	var lam := lon0 + theta / n
	return Vector2(rad_to_deg(lam), rad_to_deg(phi))
