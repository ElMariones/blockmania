class_name BMUI
extends RefCounted
## Small formatting and node helpers shared by the screens. Visual styling lives in BMStyle.


static func clear_children(n: Node) -> void:
	for c in n.get_children():
		n.remove_child(c)
		c.queue_free()


static func fmt_mult(m: float) -> String:
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
