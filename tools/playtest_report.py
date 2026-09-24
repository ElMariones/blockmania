"""Aggregates persona playtest logs from tools/playtest.gd into markdown tables and a JSON summary.

Usage:
    python tools/playtest_report.py out_dir file1.json [file2.json ...]

Writes out_dir/summary.md (tables) and out_dir/summary.json (numbers for charts). Dev-only.
Estimated run length uses ~5 s per placement, ~35 s per shop visit and ~8 s per round transition,
a rough guess for a focused human.
"""
import itertools
import json
import os
import statistics as st
import sys
from collections import Counter, defaultdict

SEC_PLACE, SEC_SHOP, SEC_ROUND = 5, 35, 8


def pct(a, b):
    return 100.0 * a / b if b else 0.0


def q(vals, p):
    if not vals:
        return 0
    s = sorted(vals)
    return s[min(len(s) - 1, int(p * (len(s) - 1) + 0.5))]


def jaccard(a, b):
    a, b = set(a), set(b)
    return len(a & b) / len(a | b) if a | b else 1.0


def persona_summary(data):
    runs = data["runs"]
    n = len(runs)
    wins = [r for r in runs if r["won"]]
    out = {"persona": data["persona"], "about": data["about"], "kit": data["kit"], "runs": n,
           "wins": len(wins), "win_pct": pct(len(wins), n)}
    out["avg_round"] = st.mean(r["campaign_round"] for r in runs)
    end = Counter()
    for r in runs:
        end["W" if r["won"] else r["campaign_round"]] += 1
    out["end_hist"] = {str(k): v for k, v in end.items()}
    ot = [r["overtime_round"] for r in wins]
    out["ot_avg"] = st.mean(ot) if ot else 0
    out["ot_max"] = max(ot) if ot else 0
    out["ot_hist"] = dict(Counter(ot))
    out["broken"] = sum(1 for r in runs if r["broken"])
    peaks = [r["peak_points"] for r in runs]
    out["peak_med"], out["peak_p90"], out["peak_max"] = q(peaks, 0.5), q(peaks, 0.9), max(peaks)
    out["peak_mult_max"] = max(r["peak_mult"] for r in runs)
    out["peak_xmult_max"] = max(r["peak_xmult"] for r in runs)
    out["peak_mult_med"] = q([r["peak_mult"] for r in runs], 0.5)
    pl = sum(r["placements"] for r in runs)
    camp_points = 0
    camp_pl = 0
    for r in runs:
        for rd in r["rounds"]:
            if rd["round"] <= 12:
                camp_points += rd["score"]
                camp_pl += rd["used"]
    out["ppp"] = camp_points / camp_pl if camp_pl else 0
    out["clear_rate"] = pct(sum(r["clears"] for r in runs), pl)
    out["multi_rate"] = pct(sum(r["multi"] for r in runs), pl)
    out["triple_per_run"] = sum(r["triple"] for r in runs) / n
    out["hype_per_run"] = sum(r["hype"] for r in runs) / n
    out["forced_rate"] = pct(sum(r["forced"] for r in runs), pl)
    out["cands_per_place"] = sum(r["candidates"] for r in runs) / pl if pl else 0
    feats = Counter()
    hands = Counter()
    for r in runs:
        feats.update(r["feats"])
        hands.update(r["hands"])
    out["feats_per_run"] = {k: v / n for k, v in feats.items()}
    out["hands_per_run"] = {k: v / n for k, v in hands.items()}
    reasons = Counter()
    for r in runs:
        if not r["won"] or r["overtime_round"]:
            reason = r["end_reason"].split(":")[0] if r["end_reason"] else "?"
            reasons[("campaign: " if not r["won"] else "overtime: ") + reason] += 1
    out["reasons"] = dict(reasons)
    # Difficulty curve and tension, campaign rounds only.
    curve = {}
    for rn in range(1, 13):
        rows = [rd for r in runs for rd in r["rounds"] if rd["round"] == rn]
        if not rows:
            continue
        won = [rd for rd in rows if rd["won"]]
        margins = [rd["score"] / rd["target"] for rd in won]
        curve[rn] = {"reached": len(rows), "won": len(won), "clear_pct": pct(len(won), len(rows)),
                     "used": st.mean(rd["used"] for rd in won) if won else 0,
                     "left": st.mean(rd["left"] for rd in won) if won else 0,
                     "margin": st.mean(margins) if margins else 0,
                     "close": pct(sum(1 for rd in won if rd["left"] <= 2), len(won)),
                     "blowout": pct(sum(1 for m in margins if m >= 1.5), len(won)),
                     "peak_share": st.mean(rd["peak"] / rd["target"] for rd in rows),
                     "jokers": st.mean(rd["jokers"] for rd in rows)}
    out["curve"] = curve
    # Overtime rounds, per round.
    otc = {}
    for r in wins:
        for rd in r["rounds"]:
            if rd["round"] > 12:
                e = otc.setdefault(rd["round"], {"reached": 0, "won": 0, "scores": []})
                e["reached"] += 1
                e["won"] += rd["won"]
                e["scores"].append(rd["score"] / rd["target"])
    out["ot_curve"] = {k: {"reached": v["reached"], "won": v["won"], "ratio": st.mean(v["scores"])} for k, v in sorted(otc.items())}
    # Shops.
    shops = [s for r in runs for s in r["shops"]]
    out["shop_visits_per_run"] = len(shops) / n
    if shops:
        out["shop_credits"] = st.mean(s["credits"] for s in shops)
        out["shop_affordable"] = st.mean(s["affordable"] for s in shops)
        out["shop_zero_buy"] = pct(sum(1 for s in shops if s["bought"] == 0), len(shops))
        out["shop_spent"] = st.mean(s["spent"] for s in shops)
        out["shop_left"] = st.mean(s.get("left_with", 0) for s in shops)
        early = [s for s in shops if s["round"] <= 4]
        out["shop_credits_act1"] = st.mean(s["credits"] for s in early) if early else 0
        out["shop_affordable_act1"] = st.mean(s["affordable"] for s in early) if early else 0
    out["rerolls_per_run"] = sum(r["rerolls"] for r in runs) / n
    out["sells_per_run"] = sum(r["sells"] for r in runs) / n
    # Builds.
    finals = [r["final_jokers"] for r in runs if r["campaign_round"] >= 8 or r["won"]]
    win_builds = [r.get("final_jokers", []) for r in wins]
    jc = Counter(j for b in finals for j in set(b))
    out["top_jokers"] = jc.most_common(10)
    out["distinct_jokers"] = len(jc)
    pairs = list(itertools.combinations(finals, 2))
    out["build_similarity"] = st.mean(jaccard(a, b) for a, b in pairs) if pairs else 0
    wc = Counter(j for b in win_builds for j in set(b))
    out["win_jokers"] = wc.most_common(12)
    out["avg_jokers_final"] = st.mean(len(r["final_jokers"]) for r in runs)
    out["avg_bag_final"] = st.mean(r["final_bag"] for r in runs)
    out["avg_upgraded"] = st.mean(r["upgraded"] for r in runs)
    purchases = Counter()
    for r in runs:
        purchases.update(r["purchases"])
    out["purchases_per_run"] = {k: v / n for k, v in purchases.most_common()}
    # Joker trigger rates (placements where the card scored while owned).
    trig = defaultdict(lambda: [0, 0])
    for r in runs:
        for j, s in r["joker_stats"].items():
            trig[j][0] += s["triggers"]
            trig[j][1] += s["placements"]
    out["trigger_rates"] = {j: pct(t, p) for j, (t, p) in trig.items() if p >= 50}
    # Bosses.
    boss = defaultdict(lambda: [0, 0])
    for r in runs:
        for b, won in r["bosses"]:
            boss[b][1] += 1
            boss[b][0] += 1 if won else 0
    out["bosses"] = {b: {"won": w, "met": m, "pct": pct(w, m)} for b, (w, m) in boss.items()}
    # Length estimate (campaign part).
    mins = []
    for r in runs:
        rounds = [rd for rd in r["rounds"] if rd["round"] <= 12]
        places = sum(rd["used"] for rd in rounds)
        shops_c = sum(1 for s in r["shops"] if s["round"] <= 12)
        mins.append((places * SEC_PLACE + shops_c * SEC_SHOP + len(rounds) * SEC_ROUND) / 60)
    out["minutes_med"] = q(mins, 0.5)
    win_mins = []
    for r in wins:
        rounds = [rd for rd in r["rounds"] if rd["round"] <= 12]
        win_mins.append((sum(rd["used"] for rd in rounds) * SEC_PLACE + 11 * SEC_SHOP + 12 * SEC_ROUND) / 60)
    out["minutes_win"] = st.mean(win_mins) if win_mins else 0
    return out


def fmt(v, d=1):
    return f"{v:,.{d}f}"


def main():
    out_dir = sys.argv[1]
    files = sys.argv[2:]
    os.makedirs(out_dir, exist_ok=True)
    summaries = []
    for f in files:
        with open(f) as fh:
            summaries.append(persona_summary(json.load(fh)))
    by = {s["persona"]: s for s in summaries}
    lines = ["# Persona playtest summary", ""]
    lines += ["| Persona | Kit | Runs | Win % | Avg round | OT avg / max | Broken | PPP | Clears / place | Multi-line % | Hype / run | Peak med / max | Max Mult | Max xMult |",
              "|---|---|---:|---:|---:|---|---:|---:|---:|---:|---:|---|---:|---:|"]
    for s in summaries:
        lines.append(f"| {s['persona']} | {s['kit']} | {s['runs']} | {s['win_pct']:.0f}% | {s['avg_round']:.2f} | "
                     f"{s['ot_avg']:.1f} / {s['ot_max']} | {s['broken']} | {s['ppp']:.0f} | {s['clear_rate']:.0f}% | "
                     f"{s['multi_rate']:.1f}% | {s['hype_per_run']:.1f} | {s['peak_med']:,} / {s['peak_max']:,} | "
                     f"{s['peak_mult_max']:.1f} | {s['peak_xmult_max']:.2f} |")
    lines += ["", "## Shop and builds", "",
              "| Persona | Shops/run | Credits at entry (act 1) | Affordable offers (act 1) | Zero-buy visits | Rerolls/run | Sells/run | Jokers at end | Bag at end | Upgraded | Distinct Jokers | Build similarity | Est. minutes (median, win) |",
              "|---|---:|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---|"]
    for s in summaries:
        lines.append(f"| {s['persona']} | {s['shop_visits_per_run']:.1f} | {s.get('shop_credits', 0):.1f} ({s.get('shop_credits_act1', 0):.1f}) | "
                     f"{s.get('shop_affordable', 0):.1f} ({s.get('shop_affordable_act1', 0):.1f}) | {s.get('shop_zero_buy', 0):.0f}% | "
                     f"{s['rerolls_per_run']:.1f} | {s['sells_per_run']:.1f} | {s['avg_jokers_final']:.1f} | {s['avg_bag_final']:.1f} | "
                     f"{s['avg_upgraded']:.1f} | {s['distinct_jokers']} | {s['build_similarity']:.2f} | {s['minutes_med']:.0f}, {s['minutes_win']:.0f} |")
    for s in summaries:
        lines += ["", f"## {s['persona']}", "", s["about"], ""]
        lines.append("End of run: " + ", ".join(f"{k}: {v}" for k, v in sorted(s["end_hist"].items(), key=lambda kv: (kv[0] == 'W', int(kv[0]) if kv[0] != 'W' else 99))))
        lines.append("")
        lines.append("Reasons: " + ", ".join(f"{k} ({v})" for k, v in s["reasons"].items()))
        lines.append("")
        lines.append("| Round | Reached | Clear % | Placements used | Left at win | Score/target | Close (≤2 left) | Blowout (≥1.5x) | Best placement / target | Jokers |")
        lines.append("|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|")
        for rn, c in s["curve"].items():
            lines.append(f"| {rn} | {c['reached']} | {c['clear_pct']:.0f}% | {c['used']:.1f} | {c['left']:.1f} | {c['margin']:.2f} | "
                         f"{c['close']:.0f}% | {c['blowout']:.0f}% | {c['peak_share']:.2f} | {c['jokers']:.1f} |")
        if s["ot_curve"]:
            lines.append("")
            lines.append("Overtime: " + ", ".join(f"R{k} {v['won']}/{v['reached']} (x{v['ratio']:.2f})" for k, v in s["ot_curve"].items()))
        lines.append("")
        lines.append("Top Jokers in late builds: " + ", ".join(f"{j} ({c})" for j, c in s["top_jokers"]))
        lines.append("")
        lines.append("Jokers in winning builds: " + ", ".join(f"{j} ({c})" for j, c in s["win_jokers"]))
        lines.append("")
        lines.append("Bosses: " + ", ".join(f"{b} {v['won']}/{v['met']}" for b, v in sorted(s["bosses"].items())))
        lines.append("")
        lines.append("Feats per run: " + ", ".join(f"{k} {v:.1f}" for k, v in sorted(s["feats_per_run"].items())))
        lines.append("")
        lines.append("Hands per run: " + ", ".join(f"{k} {v:.1f}" for k, v in sorted(s["hands_per_run"].items())))
        lines.append("")
        if s["purchases_per_run"]:
            lines.append("Workshop per run: " + ", ".join(f"{k} {v:.1f}" for k, v in s["purchases_per_run"].items()))
            lines.append("")
        tr = sorted(s["trigger_rates"].items(), key=lambda kv: -kv[1])
        lines.append("Trigger rates: " + ", ".join(f"{j} {v:.0f}%" for j, v in tr))
    with open(os.path.join(out_dir, "summary.md"), "w") as fh:
        fh.write("\n".join(lines) + "\n")
    with open(os.path.join(out_dir, "summary.json"), "w") as fh:
        json.dump(summaries, fh, indent=1, default=str)
    print("\n".join(lines[:40]))


if __name__ == "__main__":
    main()
