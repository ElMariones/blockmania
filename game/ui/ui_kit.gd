class_name BMUI
extends RefCounted
## Small formatting and node helpers shared by the screens. Visual styling lives in BMStyle.


static func clear_children(n: Node) -> void:
	for c in n.get_children():
		n.remove_child(c)
		c.queue_free()


static func fmt_mult(m: float) -> String:
	if absf(m) >= 1.0e18 or is_nan(m) or is_inf(m):
		return "%.1e" % m
	if absf(m) >= 1.0e6:
		return fmt_score(int(m))
	if is_equal_approx(m, roundf(m)):
		return str(int(m))
	return ("%.2f" % m).rstrip("0").rstrip(".")


static func fmt_int(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out


## Scores that fit the HUD at any size: exact below a million, then 12.3M / 4.56B / 789T / 1.00Q.
static func fmt_score(n: int) -> String:
	if absi(n) < 1_000_000:
		return fmt_int(n)
	for u in [[1.0e15, "Q"], [1.0e12, "T"], [1.0e9, "B"], [1.0e6, "M"]]:
		if absf(n) >= u[0]:
			var v: float = n / u[0]
			var fmt := "%.2f" if absf(v) < 10.0 else ("%.1f" if absf(v) < 100.0 else "%.0f")
			return (fmt % v) + String(u[1])
	return fmt_int(n)
