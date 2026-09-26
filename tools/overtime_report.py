"""Overtime tables for the release study (tools/study.gd with "overtime").

    python tools/overtime_report.py <out_dir> <study json files...>

Writes <out_dir>/overtime_tables.md and <out_dir>/overtime_summary.json. Population files come
from `study.gd -- population <n> <first> <out> 3 overtime`, arm files from the ot_* arms.
"""
import json
import math
import os
import sys
from collections import Counter, defaultdict
from statistics import mean, median

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from study_report import JOKERS, pct, f1, table  # noqa: E402

LEGENDARY = {"avalanche", "hall_of_mirrors", "philosophers_stone", "supernova"}


def big(n):
    n = float(n)
    for div, suf in ((1e15, "Q"), (1e12, "T"), (1e9, "B"), (1e6, "M"), (1e3, "k")):
        if abs(n) >= div:
            return f"{n / div:.3g}{suf}"
    return f"{n:.0f}"


def pctile(xs, p):
    xs = sorted(xs)
    if not xs:
        return 0
    k = min(len(xs) - 1, max(0, int(math.ceil(p / 100 * len(xs))) - 1))
    return xs[k]


def main():
    out_dir = sys.argv[1]
    os.makedirs(out_dir, exist_ok=True)
    groups = defaultdict(list)
    for path in sys.argv[2:]:
        with open(path, encoding="utf-8") as f:
            d = json.load(f)
        if d["mode"] == "population":
            for r in d["runs"]:
                groups["pop:" + r["archetype"]].append(r)
                groups["pop:all"].append(r)
        else:
            groups[d["mode"]].extend(d["runs"])
    md = []
    S = {}
    order = ["pop:first_timer", "pop:casual_regular", "pop:engaged", "pop:expert", "pop:item_lover", "pop:all",
             "ot_smart", "ot_lite", "ot_expert", "ot_best", "ot_fresh_shop", "ot_legend_probe"]
    fair = [g for g in order if g in groups and g != "ot_legend_probe" and g != "pop:all"]

    # ------------------------------------------------------------------ depth
    md.append("## A. How far Overtime goes\n")
    md.append("*Entrants* won round 12 and pressed KEEP PLAYING. *Cleared* = Overtime rounds won before the losing one (a broken machine counts its round).\n")
    rows = []
    S["depth"] = {}
    for g in order:
        rs = groups.get(g)
        if not rs:
            continue
        ent = [r for r in rs if r.get("overtime")]
        cleared = [(r["ot_round"] - 12) if r.get("broken") else (r["ot_round"] - 13) for r in ent]
        finals = [r["ot_round"] for r in ent]
        # 5 s per placement, 8 s per round screen, 35 s per shop (as in study.gd).
        mins = [(sum(x["placements"] for x in r["rounds"] if x["round"] > 12) * 5 + sum(1 for x in r["rounds"] if x["round"] > 12) * 43) / 60 for r in ent]
        broken = sum(1 for r in ent if r.get("broken"))
        capped = sum(1 for r in ent if r.get("capped"))
        rows.append([g, len(rs), f1(pct(len(ent), len(rs))) + "%", len(ent), f1(mean(cleared)) if ent else "–", int(median(finals)) if ent else "–",
                     pctile(finals, 90) if ent else "–", max(finals) if ent else "–", broken, capped, f1(mean(mins)) if ent else "–"])
        S["depth"][g] = {"runs": len(rs), "entrants": len(ent), "entry": pct(len(ent), len(rs)), "cleared_mean": mean(cleared) if ent else 0,
                         "median_final": median(finals) if ent else 0, "p90": pctile(finals, 90) if ent else 0, "max": max(finals) if ent else 0,
                         "broken": broken, "minutes": mean(mins) if ent else 0}
    md.append(table(["Group", "Runs", "Won campaign", "Entrants", "OT rounds cleared (mean)", "Final round (median)", "p90", "Max", "Machine broken", "Hit round 80 cap", "Minutes in Overtime"], rows))

    # ------------------------------------------------------------------ survival
    md.append("\n## B. Survival: share of entrants still playing at the start of each round\n")
    heads = ["Round", "Target"] + [g for g in order if g in groups]
    S["survival"] = {}
    rows = []
    for rn in range(13, 41):
        row = [rn, big(target(rn))]
        for g in order:
            if g not in groups:
                continue
            ent = [r for r in groups[g] if r.get("overtime")]
            alive = sum(1 for r in ent if r["ot_round"] >= rn)
            v = pct(alive, len(ent))
            S["survival"].setdefault(g, {})[rn] = v
            row.append(f1(v) + "%" if ent else "–")
        rows.append(row)
        if all(S["survival"][g].get(rn, 0) == 0 for g in S["survival"]):
            break
    md.append(table(heads, rows))

    # ------------------------------------------------------------------ per-round anatomy
    md.append("\n## C. Round anatomy in Overtime (all fair groups pooled: population + ot_* arms except the Legendary probe)\n")
    per = defaultdict(list)
    for g in ["pop:all", "ot_smart", "ot_lite", "ot_expert", "ot_best", "ot_fresh_shop"]:
        for r in groups.get(g, []):
            for x in r["rounds"]:
                if x["round"] >= 11:
                    per[x["round"]].append(x)
    rows = []
    S["anatomy"] = {}
    for rn in sorted(per):
        xs = per[rn]
        if len(xs) < 8:
            continue
        won = [x for x in xs if x["won"]]
        bestr = median(x["peak"] / x["target"] for x in xs)
        rows.append([rn, len(xs), big(median(x["target"] for x in xs)), f1(pct(len(won), len(xs))) + "%", big(median(x["peak"] for x in xs)), f"{bestr:.2f}",
                     f1(mean(x["placements"] for x in xs)), f1(mean(x["left"] for x in won)) if won else "–",
                     f1(pct(sum(1 for x in won if x["left"] <= 2), len(won))) + "%" if won else "–",
                     f"{median(x['score'] / x['target'] for x in won):.2f}" if won else "–",
                     "boss" + (" Mk II" if any(x.get("mk2") for x in xs) else "") if any(x["boss"] for x in xs) else ""])
        S["anatomy"][rn] = {"n": len(xs), "target": median(x["target"] for x in xs), "clear": pct(len(won), len(xs)), "peak": median(x["peak"] for x in xs),
                            "peak_ratio": bestr, "placements": mean(x["placements"] for x in xs)}
    md.append(table(["Round", "Played", "Target (median)", "Cleared", "Best placement (median)", "Best placement / target", "Placements", "Left at win", "Won with <=2 left", "Score/target at win", ""], rows))

    # ------------------------------------------------------------------ growth
    md.append("\n## D. Build growth vs target growth (ot_expert + ot_best + engaged/expert population, survivors of each round)\n")
    grow = defaultdict(list)
    for g in ["ot_expert", "ot_best", "pop:engaged", "pop:expert"]:
        for r in groups.get(g, []):
            for x in r["rounds"]:
                grow[x["round"]].append(x)
    rows = []
    prev = None
    S["growth"] = {}
    for rn in sorted(grow):
        xs = grow[rn]
        if len(xs) < 8:
            continue
        pk = median(x["peak"] for x in xs)
        sc = median(x["score"] for x in xs)
        tg = median(x["target"] for x in xs)
        g_p = f"{pk / prev[0]:.2f}x" if prev else ""
        g_t = f"{tg / prev[1]:.2f}x" if prev else ""
        rows.append([rn, len(xs), big(tg), g_t, big(pk), g_p, big(sc)])
        S["growth"][rn] = {"target": tg, "peak": pk, "score": sc, "n": len(xs)}
        prev = (pk, tg)
    md.append(table(["Round", "Played", "Target", "Target growth", "Best placement (median)", "Best placement growth", "Round score (median)"], rows))

    # ------------------------------------------------------------------ deaths
    md.append("\n## E. How Overtime runs end (fair groups)\n")
    deaths = Counter()
    dround = Counter()
    dcards = Counter()
    boss_ot = defaultdict(lambda: [0, 0])
    ent_unique = [r for g in fair for r in groups[g] if r.get("overtime")]
    for r in ent_unique:
        last = r["rounds"][-1]
        if r.get("broken"):
            deaths["machine broken"] += 1
        elif r.get("capped"):
            deaths["still alive at round 80"] += 1
        else:
            reason = r["end_reason"]
            deaths["out of placements" if reason.startswith("Out of") else ("no fit" if "fits" in reason else reason[:30])] += 1
            dround["boss round" if last["boss"] else "normal round"] += 1
            dcards[last["card"]] += 1
            if not last["won"] and last["target"] > 0:
                dround["lost within 10% of target"] += 1 if last["score"] >= 0.9 * last["target"] else 0
        for x in r["rounds"]:
            if x["round"] > 12 and x["boss"]:
                boss_ot[x["boss"] + (" Mk II" if x.get("mk2") else "")][0] += 1
                boss_ot[x["boss"] + (" Mk II" if x.get("mk2") else "")][1] += x["won"]
    n = len(ent_unique)
    md.append(table(["End", "Runs", "Share"], [[k, v, f1(pct(v, n)) + "%"] for k, v in deaths.most_common()]))
    md.append("\nThe losing round was: " + ", ".join(f"{k} {v} ({f1(pct(v, n))}%)" for k, v in dround.most_common()) +
              ". Round card of the losing round: " + ", ".join(f"{k} {v}" for k, v in dcards.most_common()))
    md.append("\nOvertime bosses:\n")
    md.append(table(["Boss", "Fought", "Cleared"], [[b, v[0], f1(pct(v[1], v[0])) + "%"] for b, v in sorted(boss_ot.items(), key=lambda kv: -kv[1][0])]))
    S["ends"] = {k: pct(v, n) for k, v in deaths.items()}

    # ------------------------------------------------------------------ what goes deep
    md.append("\n## F. What the deepest runs hold (fair groups, Jokers at the end of the run)\n")
    deep_cut = pctile([r["ot_round"] for r in ent_unique], 80)
    deep = [r for r in ent_unique if r["ot_round"] >= deep_cut]
    shallow = [r for r in ent_unique if r["ot_round"] <= 13]
    def share(rs, j):
        return pct(sum(1 for r in rs if j in r["final_jokers"]), len(rs))
    cands = Counter(j for r in ent_unique for j in set(r["final_jokers"]))
    rows = []
    for j, _ in cands.most_common():
        d_, s_ = share(deep, j), share(shallow, j)
        if d_ >= 8:
            rows.append([JOKERS.get(j, {"name": j})["name"], f1(d_) + "%", f1(s_) + "%", f"{(d_ + 1) / (s_ + 1):.1f}x"])
    rows.sort(key=lambda r: -float(r[3][:-1]))
    md.append(f"Deep = final round {deep_cut}+ (top 20%, {len(deep)} runs); shallow = lost in round 13 ({len(shallow)} runs).\n")
    md.append(table(["Joker", "Held by deep runs", "Held by shallow runs", "Lift"], rows[:25]))
    leg_d = mean(sum(1 for j in r["final_jokers"] if j in LEGENDARY) for r in deep) if deep else 0
    leg_s = mean(sum(1 for j in r["final_jokers"] if j in LEGENDARY) for r in shallow) if shallow else 0
    slots_d = mean(r["rounds"][-1].get("slots", 5) for r in deep) if deep else 0
    slots_s = mean(r["rounds"][-1].get("slots", 5) for r in shallow) if shallow else 0
    md.append(f"\nLegendaries held at the end: deep {leg_d:.2f}, shallow {leg_s:.2f}. Joker slots: deep {slots_d:.2f}, shallow {slots_s:.2f}.")
    st = defaultdict(list)
    for r in deep:
        for k, v in r["rounds"][-1].get("state", {}).items():
            st[k].append(v)
    md.append("Scaling Jokers at the end of deep runs (median value where held): " + ", ".join(f"{k} {median(v):.2f} ({len(v)} runs)" for k, v in st.items()))
    S["deep"] = {"cut": deep_cut, "n": len(deep), "legendaries_deep": leg_d, "legendaries_shallow": leg_s, "slots_deep": slots_d, "slots_shallow": slots_s}

    # ------------------------------------------------------------------ economy
    md.append("\n## G. Overtime shops (fair groups)\n")
    sh = defaultdict(list)
    for r in ent_unique:
        for s in r["shops"]:
            if s["round"] >= 12:
                sh[min(s["round"], 20)].append(s)
    rows = []
    for rn in sorted(sh):
        ss = sh[rn]
        kinds = Counter(b["kind"] for s in ss for b in s["bought"])
        rows.append([f"{rn}{'+' if rn == 20 else ''}", len(ss), f1(mean(s["credits"] for s in ss)), f1(mean(s["spent"] for s in ss)), f1(mean(s["left_with"] for s in ss)),
                     f1(pct(sum(1 for s in ss if not s["bought"] and not s["sold"]), len(ss))) + "%", f"{mean(s['rerolls'] for s in ss):.2f}",
                     ", ".join(f"{k} {v / len(ss):.2f}" for k, v in kinds.most_common())])
    md.append(table(["After round", "Visits", "Credits in", "Spent", "Left with", "Bought nothing", "Rerolls", "Purchases per visit"], rows))

    # ------------------------------------------------------------------ milestones & probe
    md.append("\n## H. Milestones and the ceiling\n")
    rows = []
    for g in order:
        rs = groups.get(g)
        if not rs:
            continue
        ent = [r for r in rs if r.get("overtime")]
        if not ent:
            continue
        pk = [r["peak"] for r in ent]
        rows.append([g, len(ent), big(median(pk)), big(max(pk)), sum(1 for p in pk if p >= 1e6), sum(1 for p in pk if p >= 1e9), sum(1 for p in pk if p >= 1e12), sum(1 for r in ent if r.get("broken"))])
    md.append(table(["Group", "Entrants", "Best placement (median)", "Best placement (max)", "1M+", "1B+", "1T+", "Machine broken"], rows))
    probe = groups.get("ot_legend_probe", [])
    if probe:
        md.append("\nLegendary probe runs (start with Hall of Mirrors, Supernova, The Avalanche, Snowball, Jackpot Window):\n")
        md.append(table(["Seed", "Won", "Final round", "Best placement", "Broken", "End"],
                        [[r["seed"], "yes" if r["won"] else "no", r["ot_round"] or r["round"], big(r["peak"]), "yes" if r.get("broken") else "", r["end_reason"][:60]] for r in sorted(probe, key=lambda r: r["seed"])]))

    # ------------------------------------------------------------------ time and pacing
    md.append("\n## I. How long Overtime takes (all groups incl. the probe; 5 s per placement, 43 s per round screen + shop)\n")
    allr = [r for g in order if g in groups and g != "pop:all" for r in groups[g] if r.get("overtime")]
    rows = []
    S["time"] = {}
    for lo, hi in ((13, 16), (17, 20), (21, 24), (25, 30), (31, 40), (41, 80)):
        av = [x["placements"] for r in allr for x in r["rounds"] if lo <= x["round"] <= hi and "avalanche" in x["jokers"]]
        no = [x["placements"] for r in allr for x in r["rounds"] if lo <= x["round"] <= hi and "avalanche" not in x["jokers"]]
        rows.append([f"{lo}-{hi}", len(no), f1(median(no)) if no else "–", len(av), f1(median(av)) if av else "–", max(av + no) if av or no else "–"])
    md.append(table(["Rounds", "Rounds without Avalanche", "Placements (median)", "Rounds with Avalanche", "Placements (median)", "Longest round (placements)"], rows))
    rows = []
    for rn in (13, 16, 20, 24, 30, 40, 50, 60):
        reach = [r for r in allr if r["ot_round"] >= rn]
        if not reach:
            continue
        mins = [(sum(x["placements"] for x in r["rounds"] if x["round"] < rn) * 5 + sum(1 for x in r["rounds"] if x["round"] < rn) * 43) / 60 for r in reach]
        rows.append([rn, len(reach), f1(median(mins)), f1(max(mins))])
        S["time"][rn] = median(mins)
    md.append("\nMinutes of play (from round 1) to reach a round:\n")
    md.append(table(["Round", "Runs that reached it", "Minutes (median)", "Minutes (max)"], rows))
    capped = [r for r in allr if r.get("capped")]
    md.append(f"\nRuns stopped by the study's session cap (3,000 placements, about 4 hours) while still alive: {len(capped)}" +
              ("" if not capped else " (" + ", ".join(f"seed {r['seed']} round {r['ot_round']}" for r in capped) + ")") + ".")

    with open(os.path.join(out_dir, "overtime_tables.md"), "w", encoding="utf-8") as f:
        f.write("# Overtime study: full tables\n\nGenerated by `tools/overtime_report.py` from `tools/study.gd` logs (Overtime on).\n\n" + "\n".join(md) + "\n")
    with open(os.path.join(out_dir, "overtime_summary.json"), "w", encoding="utf-8") as f:
        json.dump(S, f, indent=1)
    print("wrote", out_dir)


def target(rn):
    if rn <= 12:
        return [450, 650, 900, 1200, 1800, 2400, 3300, 4400, 5700, 7300, 9300, 12500][rn - 1]
    k = rn - 12
    raw = 12500 * 1.6 ** k * (1 + 0.08 * k * k)
    return min(1e15, raw)


if __name__ == "__main__":
    main()
