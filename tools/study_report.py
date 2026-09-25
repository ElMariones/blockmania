"""Tables for the release-style playability study (tools/study.gd).

    python tools/study_report.py <out_dir> <study json files...>

Writes <out_dir>/study_tables.md (every table) and <out_dir>/study_summary.json (numbers the
report and its charts use). Population files come from `study.gd -- population`, arm files from
`study.gd -- <arm>`; arms with the same name (split across processes) are merged.
"""
import json
import os
import re
import sys
from collections import Counter, defaultdict
from statistics import mean, median

CATALOG_RE = re.compile(r'\{"id": "([a-z_]+)", "name": "([^"]+)", "rarity": ([A-Z]+), "phase": "([a-z_]+)"')
ITEM_RE = re.compile(r'\{"id": "([a-z_]+)", "name": "([^"]+)", "cost": (\d+)')
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def load_catalogs():
    jok = {}
    with open(os.path.join(ROOT, "game/content/jokers.gd"), encoding="utf-8") as f:
        for m in CATALOG_RE.finditer(f.read()):
            jok[m.group(1)] = {"name": m.group(2), "rarity": m.group(3), "phase": m.group(4)}
    items = {}
    with open(os.path.join(ROOT, "game/content/consumables.gd"), encoding="utf-8") as f:
        for m in ITEM_RE.finditer(f.read()):
            items[m.group(1)] = {"name": m.group(2), "cost": int(m.group(3))}
    tools = {}
    with open(os.path.join(ROOT, "game/content/tools.gd"), encoding="utf-8") as f:
        for m in ITEM_RE.finditer(f.read()):
            tools[m.group(1)] = {"name": m.group(2), "cost": int(m.group(3))}
    return jok, items, tools


JOKERS, ITEMS, TOOLS = load_catalogs()
LOCKED = ["snowball", "hot_streak", "overachiever", "solo_act", "double_stamp", "rainbow_road",
          "big_game_hunter", "demolition_crew", "mimic", "jackpot_window",
          "avalanche", "hall_of_mirrors", "philosophers_stone", "supernova"]
BOOSTS = ["polish", "spark", "overclock"]
RESCUES = ["second_tray", "coffee_break", "extra_turn", "eraser", "punch", "color_purge", "blueprint", "emergency_brick"]
TAGS = {
    "color": ["blue_mood", "color_cycle", "rainbow_road"],
    "multi_line": ["jackpot_window", "wide_awake", "crossbar", "keystone", "snowball", "demolition_crew", "chain_link", "compound_interest", "supernova", "avalanche"],
    "bag_engine": ["foundry", "specialist", "hoarder", "collector", "lean_bag", "recycler", "postmaster", "neon_sign", "glass_cannon", "veteran", "philosophers_stone", "double_stamp", "breakage_bonus"],
    "economy": ["loan_shark", "spare_parts", "overflow", "coin_pusher", "full_pockets", "vending_machine", "fire_sale"],
    "shape": ["small_change", "heavy_hand", "architect", "straight_edge", "square_deal", "big_game_hunter", "countdown"],
    "hands": ["hot_hand", "card_sharp"],
    "scaling": ["hot_streak", "overachiever", "bonsai", "tally_counter"],
    "safety": ["tiny_insurance", "second_look", "insurance_policy", "patch_panel", "periscope", "draftsman", "long_game", "mirror_maze"],
}
TAG_OF = {j: t for t, js in TAGS.items() for j in js}


def pct(a, b):
    return 100.0 * a / b if b else 0.0


def f1(x):
    return f"{x:.1f}"


def table(headers, rows):
    out = ["| " + " | ".join(headers) + " |", "|" + "|".join("---" if i == 0 else "---:" for i in range(len(headers))) + "|"]
    for r in rows:
        out.append("| " + " | ".join(str(c) for c in r) + " |")
    return "\n".join(out)


def build_tag(jokers):
    c = Counter(TAG_OF.get(j, "generic") for j in jokers)
    c.pop("generic", None)
    c.pop("safety", None)
    if not c:
        return "generalist"
    tag, n = c.most_common(1)[0]
    return tag if n >= 2 else "generalist"


def joker_offer_metrics(run):
    offers = []
    owned_reoffers = 0
    shops_with_owned = 0
    for s in run["shops"]:
        seen_owned = False
        for f in s["fills"]:
            for j, o in zip(f["jokers"], f["owned"]):
                if j:
                    offers.append(j)
                    if o:
                        owned_reoffers += 1
                        seen_owned = True
        shops_with_owned += 1 if seen_owned else 0
    c = Counter(offers)
    repeats = sum(n - 1 for n in c.values())
    return {"offers": len(offers), "distinct": len(c), "repeats": repeats, "max_same": max(c.values()) if c else 0,
            "owned_reoffers": owned_reoffers, "shops": len(run["shops"]), "shops_with_owned": shops_with_owned,
            "counts": c}


def main():
    out_dir = sys.argv[1]
    os.makedirs(out_dir, exist_ok=True)
    pop = []
    arms = defaultdict(list)
    for path in sys.argv[2:]:
        with open(path, encoding="utf-8") as f:
            d = json.load(f)
        if d["mode"] == "population":
            pop.extend(d["runs"])
        else:
            arms[d["mode"]].extend(d["runs"])
    for k in arms:
        arms[k].sort(key=lambda r: r["seed"])
    md = []
    summary = {}
    everything = pop + [r for rs in arms.values() for r in rs]

    # ---------------------------------------------------------------- population overview
    md.append("## A. Population overview\n")
    by_arch = defaultdict(list)
    for r in pop:
        by_arch[r["archetype"]].append(r)
    rows = []
    summary["archetypes"] = {}
    for a in ["first_timer", "casual_regular", "engaged", "expert", "item_lover"]:
        rs = by_arch.get(a, [])
        if not rs:
            continue
        pids = {r["pid"] for r in rs}
        wins = sum(r["won"] for r in rs)
        rounds = mean(r["round"] for r in rs)
        tmin = mean(r["time_s"] for r in rs) / 60
        pl = sum(r["placements"] for r in rs)
        multi = sum(r["multi"] for r in rs)
        rows.append([a, len(pids), len(rs), f1(pct(wins, len(rs))) + "%", f1(rounds), f1(tmin), f1(pct(multi, pl)) + "%",
                     int(median(r["peak"] for r in rs))])
        summary["archetypes"][a] = {"participants": len(pids), "runs": len(rs), "win": pct(wins, len(rs)), "round": rounds, "minutes": tmin}
    allw = sum(r["won"] for r in pop)
    rows.append(["**all**", len({r["pid"] for r in pop}), len(pop), f1(pct(allw, len(pop))) + "%", f1(mean(r["round"] for r in pop)),
                 f1(mean(r["time_s"] for r in pop) / 60), f1(pct(sum(r["multi"] for r in pop), sum(r["placements"] for r in pop))) + "%",
                 int(median(r["peak"] for r in pop))])
    md.append(table(["Archetype", "Participants", "Runs", "Win", "Avg round", "Minutes/run", "Multi-line of placements", "Median best placement"], rows))
    summary["population"] = {"participants": len({r["pid"] for r in pop}), "runs": len(pop), "win": pct(allw, len(pop))}

    # Loss causes and rounds.
    md.append("\n### Where runs end (population)\n")
    ends = Counter()
    for r in pop:
        if r["won"]:
            ends["won"] += 1
        else:
            reason = r["end_reason"]
            key = "out of placements" if reason.startswith("Out of placements") else ("no fit" if "fits" in reason else reason[:40])
            ends[key] += 1
    md.append(table(["Outcome", "Runs", "Share"], [[k, v, f1(pct(v, len(pop))) + "%"] for k, v in ends.most_common()]))
    lost_round = Counter(r["round"] for r in pop if not r["won"])
    md.append("\nLosses by round: " + ", ".join(f"R{k}: {v}" for k, v in sorted(lost_round.items())))
    summary["loss_by_round"] = dict(sorted(lost_round.items()))
    near = 0
    lost_n = 0
    for r in pop:
        if not r["won"] and r["rounds"]:
            last = r["rounds"][-1]
            lost_n += 1
            if last["score"] >= 0.9 * last["target"]:
                near += 1
    md.append(f"\nLosses within 10% of the target: {near} of {lost_n} ({f1(pct(near, lost_n))}%).")

    # ---------------------------------------------------------------- pacing per round
    md.append("\n## B. Round pacing (population, all archetypes)\n")
    per_round = defaultdict(list)
    for r in pop:
        for rd in r["rounds"]:
            per_round[rd["round"]].append(rd)
    rows = []
    summary["rounds"] = {}
    for n in range(1, 13):
        rds = per_round.get(n, [])
        if not rds:
            continue
        won = [x for x in rds if x["won"]]
        clr = pct(len(won), len(rds))
        ratio = mean(x["score"] / x["target"] for x in won) if won else 0
        left = mean(x["left"] for x in won) if won else 0
        dry = mean(x["max_dry"] for x in rds)
        big = mean(x["big"] for x in rds)
        plc = mean(x["placements"] for x in rds)
        clears = pct(sum(x["clears"] for x in rds), sum(x["placements"] for x in rds))
        close = pct(sum(1 for x in won if x["left"] <= 2), len(won)) if won else 0
        blow = pct(sum(1 for x in won if x["score"] >= 1.5 * x["target"]), len(won)) if won else 0
        rows.append([n, len(rds), f1(clr) + "%", f1(plc), f1(left), f1(close) + "%", f"{ratio:.2f}", f1(blow) + "%", f1(clears) + "%", f1(dry), f1(big)])
        summary["rounds"][n] = {"clear": clr, "placements": plc, "left": left, "close": close, "ratio": ratio, "blowout": blow, "clear_rate": clears, "dry": dry, "big": big}
    md.append(table(["Round", "Played", "Cleared", "Placements", "Left at win", "Won with <=2 left", "Score/target at win", "Won at 1.5x+", "Placements that clear", "Longest dry streak", "Placements >= 25% of target"], rows))

    # Bosses
    md.append("\n### Bosses (population)\n")
    boss = defaultdict(lambda: [0, 0])
    for r in pop:
        for rd in r["rounds"]:
            if rd["boss"]:
                boss[rd["boss"]][0] += 1
                boss[rd["boss"]][1] += rd["won"]
    md.append(table(["Boss", "Fought", "Cleared"], [[b, v[0], f1(pct(v[1], v[0])) + "%"] for b, v in sorted(boss.items(), key=lambda kv: pct(kv[1][1], kv[1][0]))]))

    # ---------------------------------------------------------------- items
    md.append("\n## C. Items (consumables)\n")
    offered = Counter()
    bought = Counter()
    for r in everything:
        for s in r["shops"]:
            for f in s["fills"]:
                for it in f["items"]:
                    if it:
                        offered[it] += 1
            for b in s["bought"]:
                if b["kind"] == "item":
                    bought[b["id"]] += 1
    obtained = Counter()
    sources = Counter()
    used = Counter()
    wasted = Counter()
    for r in everything:
        for o in r["items_obtained"]:
            obtained[o["id"]] += 1
            sources[o["source"]] += 1
        for u in r["items_used"]:
            used[u["id"]] += 1
        for w in r["items_end"]:
            wasted[w] += 1
    boost_rows = defaultdict(list)
    for r in everything:
        for u in r["items_used"]:
            if u["mode"] == "boost" and "pct" in u:
                act = (u["round"] - 1) // 4 + 1
                boost_rows[(u["id"], act)].append(u["pct"])
    rows = []
    summary["items"] = {}
    for it in ITEMS:
        bpct = []
        for act in (1, 2, 3):
            v = boost_rows.get((it, act))
            bpct.append(f1(100 * median(v)) + "%" if v else "–")
        rows.append([ITEMS[it]["name"], ITEMS[it]["cost"], offered[it], f1(pct(bought[it], offered[it])) + "%", obtained[it], used[it],
                     f1(pct(used[it], obtained[it])) + "%", wasted[it]] + (bpct if it in BOOSTS else ["", "", ""]))
        summary["items"][it] = {"offered": offered[it], "buy_rate": pct(bought[it], offered[it]), "obtained": obtained[it], "used": used[it], "wasted": wasted[it]}
    md.append("All runs (population + experiment arms). *Boost value* = median points the item added to the placement it was used on, as a share of that round's target.\n")
    md.append(table(["Item", "Cost", "Offered", "Bought when offered", "Obtained", "Used", "Used / obtained", "Still held at run end", "Boost value act 1", "act 2", "act 3"], rows))
    md.append("\nWhere items came from: " + ", ".join(f"{k} {v}" for k, v in sources.most_common()))

    # Items per run by archetype
    md.append("\n### Items per run (population)\n")
    rows = []
    summary["items_by_archetype"] = {}
    for a in ["first_timer", "casual_regular", "engaged", "expert", "item_lover"]:
        rs = by_arch.get(a, [])
        if not rs:
            continue
        ob = mean(len(r["items_obtained"]) for r in rs)
        us = mean(len(r["items_used"]) for r in rs)
        zero = pct(sum(1 for r in rs if not r["items_used"]), len(rs))
        spent_items = mean(sum(b["price"] for s in r["shops"] for b in s["bought"] if b["kind"] == "item") for r in rs)
        spent_all = mean(sum(b["price"] for s in r["shops"] for b in s["bought"]) for r in rs)
        rows.append([a, f1(ob), f1(us), f1(zero) + "%", f1(spent_items), f1(pct(spent_items, spent_all)) + "%"])
        summary["items_by_archetype"][a] = {"obtained": ob, "used": us, "zero_use": zero, "share_spend": pct(spent_items, spent_all)}
    md.append(table(["Archetype", "Items obtained", "Items used", "Runs with 0 items used", "Credits on items", "Share of all spending"], rows))

    # By item style
    rows = []
    by_style = defaultdict(list)
    for r in pop:
        by_style[r["traits"]["items"]].append(r)
    for st, rs in sorted(by_style.items()):
        rows.append([st, len(rs), f1(mean(len(r["items_obtained"]) for r in rs)), f1(mean(len(r["items_used"]) for r in rs)),
                     f1(pct(sum(1 for r in rs if not r["items_used"]), len(rs))) + "%", f1(pct(sum(r["won"] for r in rs), len(rs))) + "%"])
    md.append("\nBy item habit (population):\n")
    md.append(table(["Item habit", "Runs", "Obtained", "Used", "0 used", "Win"], rows))

    # Emergencies
    stuck_rounds = sum(1 for r in pop for rd in r["rounds"] if rd["stuck"] > 0)
    all_rounds = sum(len(r["rounds"]) for r in pop)
    rescue = [u for r in everything for u in r["items_used"] if u["mode"] == "rescue"]
    md.append(f"\nEmergencies: {stuck_rounds} of {all_rounds} rounds ({f1(pct(stuck_rounds, all_rounds))}%) ever reached a 'nothing fits' state (the free Refresh handles most). Rescue item uses across all runs: {len(rescue)} ({', '.join(f'{k} {v}' for k, v in Counter(u['id'] for u in rescue).most_common())}).")
    summary["stuck_round_share"] = pct(stuck_rounds, all_rounds)
    lost_holding = [r for r in pop if not r["won"] and r["items_end"]]
    md.append(f"Runs lost while still holding items: {len(lost_holding)} of {sum(1 for r in pop if not r['won'])} losses; items held: " +
              ", ".join(f"{k} {v}" for k, v in Counter(i for r in lost_holding for i in r["items_end"]).most_common()))

    # ---------------------------------------------------------------- Jokers: repetition
    md.append("\n## D. Joker offers: repetition and duplicates\n")
    def rep_rows(groups):
        rows = []
        out = {}
        for name, rs in groups:
            if not rs:
                continue
            ms = [joker_offer_metrics(r) for r in rs]
            offers = sum(m["offers"] for m in ms)
            rep = sum(m["repeats"] for m in ms)
            own = sum(m["owned_reoffers"] for m in ms)
            shops = sum(m["shops"] for m in ms)
            sw = sum(m["shops_with_owned"] for m in ms)
            dup_runs = pct(sum(1 for r in rs if r["dup_ids"]), len(rs))
            seen3 = pct(sum(1 for m in ms if m["max_same"] >= 3), len(rs))
            distinct = mean(m["distinct"] for m in ms)
            win = pct(sum(r["won"] for r in rs), len(rs))
            rows.append([name, len(rs), f1(offers / len(rs)), f1(distinct), f1(pct(rep, offers)) + "%", f1(seen3) + "%",
                         f1(pct(sw, shops)) + "%", f1(dup_runs) + "%", f1(win) + "%"])
            out[name] = {"offers": offers / len(rs), "distinct": distinct, "repeat_share": pct(rep, offers), "seen3": seen3,
                         "shops_with_owned": pct(sw, shops), "dup_runs": dup_runs, "win": win, "owned_share": pct(own, offers)}
        return rows, out
    heads = ["Group", "Runs", "Joker offers/run", "Distinct Jokers seen", "Offers that repeat an earlier offer", "Runs where one Joker is offered 3+ times", "Shop visits offering a Joker you own", "Runs that end up with a duplicate", "Win"]
    groups = [("population, fresh profile (14 locked)", [r for r in pop if r["traits"].get("locked")]),
              ("population, all unlocked", [r for r in pop if not r["traits"].get("locked")])]
    rows, summary["repetition_pop"] = rep_rows(groups)
    md.append(table(heads, rows))
    md.append("\nPaired-seed arms (same seeds, same player; expert-lite hands, meta shopping, 120 seeds):\n")
    arm_groups = [(a, arms.get(a, [])) for a in ["profile_fresh", "profile_full", "shop_current", "shop_no_owned", "shop_fresh", "dup_avoid", "dup_neutral", "dup_stack", "dup_stack_fav"]]
    rows, summary["repetition_arms"] = rep_rows(arm_groups)
    md.append(table(heads, rows))

    # Copies
    copies = Counter(r["max_copies"] for r in pop)
    md.append("\nMost copies of one Joker held (population): " + ", ".join(f"{k}x: {v} runs" for k, v in sorted(copies.items())))
    dupc = Counter(j for r in everything for j in r["dup_ids"])
    md.append("\nJokers most often doubled (all runs): " + ", ".join(f"{JOKERS.get(k, {'name': k})['name']} {v}" for k, v in dupc.most_common(12)))
    # Win rate with/without dup
    wd = [r for r in pop if r["dup_ids"]]
    wn = [r for r in pop if not r["dup_ids"] and r["archetype"] in ("engaged", "expert")]
    wd2 = [r for r in wd if r["archetype"] in ("engaged", "expert")]
    md.append(f"\nEngaged/expert runs with a duplicate: {len(wd2)} runs, {f1(pct(sum(r['won'] for r in wd2), len(wd2)))}% win; without: {len(wn)} runs, {f1(pct(sum(r['won'] for r in wn), len(wn)))}% win.")

    # ---------------------------------------------------------------- Joker usage table
    md.append("\n## E. Every Joker: offered, bought, kept, triggered\n")
    j_off = Counter()
    j_buy = Counter()
    j_final = Counter()
    j_final_won = Counter()
    j_sold = Counter()
    j_crate_off = Counter()
    j_crate_pick = Counter()
    trig = defaultdict(lambda: [0, 0])
    for r in everything:
        for s in r["shops"]:
            for f in s["fills"]:
                for j in f["jokers"]:
                    if j:
                        j_off[j] += 1
        for b in r["joker_buys"]:
            if b.get("crate"):
                j_crate_pick[b["id"]] += 1
            else:
                j_buy[b["id"]] += 1
        for c in r["crates"]:
            cj = c["offer"][0]["id"]
            if cj:
                j_crate_off[cj] += 1
        for j in set(r["final_jokers"]):
            j_final[j] += 1
            if r["won"]:
                j_final_won[j] += 1
        for s in r["joker_sells"]:
            j_sold[s["id"]] += 1
        for j, st in r.get("joker_stats", {}).items():
            trig[j][0] += st["placements"]
            trig[j][1] += st["triggers"]
    base_win = pct(sum(r["won"] for r in everything), len(everything))
    rows = []
    summary["jokers"] = {}
    for j, d in sorted(JOKERS.items(), key=lambda kv: (["COMMON", "UNCOMMON", "RARE", "LEGENDARY"].index(kv[1]["rarity"]), -j_buy[kv[0]])):
        tr = pct(trig[j][1], trig[j][0]) if trig[j][0] and d["phase"] != "rule" else None
        wr = pct(j_final_won[j], j_final[j]) if j_final[j] >= 10 else None
        rows.append([d["name"], d["rarity"].title(), "yes" if j in LOCKED else "", j_off[j], j_buy[j], f1(pct(j_buy[j], j_off[j])) + "%" if j_off[j] else "–",
                     f"{j_crate_pick[j]}/{j_crate_off[j]}", j_sold[j], f1(tr) + "%" if tr is not None else ("rule" if d["phase"] == "rule" else "–"), (f1(wr) + "%") if wr is not None else "–"])
        summary["jokers"][j] = {"name": d["name"], "rarity": d["rarity"], "offered": j_off[j], "bought": j_buy[j], "crate_taken": j_crate_pick[j], "crate_offered": j_crate_off[j], "sold": j_sold[j],
                                "trigger": tr, "win_when_kept": wr, "kept": j_final[j]}
    md.append(f"All runs. Win rate across all runs: {f1(base_win)}%. *Win when kept* only when kept at the end in 10+ runs (biased toward cards bought by strong players).\n")
    md.append(table(["Joker", "Rarity", "Locked at first", "Offered", "Bought", "Bought when offered", "Crate: taken/offered", "Sold", "Trigger rate", "Win when kept"], rows))

    # ---------------------------------------------------------------- Workshop
    md.append("\n## F. Workshop and pieces\n")
    t_off = Counter()
    t_buy = Counter()
    p_buy = 0
    for r in everything:
        for s in r["shops"]:
            for f in s["fills"]:
                for t in f["tools"]:
                    if t:
                        t_off[t] += 1
            for b in s["bought"]:
                if b["kind"] == "tool":
                    t_buy[b["id"]] += 1
                if b["kind"] == "piece":
                    p_buy += 1
    md.append(table(["Workshop card", "Cost", "Offered", "Bought", "Bought when offered"],
                    [[TOOLS[t]["name"], TOOLS[t]["cost"], t_off[t], t_buy[t], f1(pct(t_buy[t], t_off[t])) + "%"] for t in TOOLS]))
    md.append(f"\nPieces bought: {p_buy} across {len(everything)} runs.")

    # ---------------------------------------------------------------- Shop economy
    md.append("\n## G. Shop visits and Credits (population)\n")
    rows = []
    shop_round = defaultdict(list)
    for r in pop:
        for s in r["shops"]:
            shop_round[s["round"]].append(s)
    summary["shops"] = {}
    for n in sorted(shop_round):
        ss = shop_round[n]
        cin = mean(s["credits"] for s in ss)
        spent = mean(s["spent"] for s in ss)
        left = mean(s["left_with"] for s in ss)
        nothing = pct(sum(1 for s in ss if not s["bought"] and not s["sold"]), len(ss))
        aff = mean(s["affordable_jokers"] for s in ss)
        full = pct(sum(1 for s in ss if s["jokers_in"] >= s["slots"]), len(ss))
        rr = mean(s["rerolls"] for s in ss)
        rows.append([n, len(ss), f1(cin), f1(spent), f1(left), f1(aff), f1(full) + "%", f1(nothing) + "%", f"{rr:.2f}"])
        summary["shops"][n] = {"credits": cin, "spent": spent, "left": left, "full": full, "nothing": nothing}
    md.append(table(["After round", "Visits", "Credits in", "Spent", "Left with", "Affordable Joker offers", "Rack full on entry", "Bought nothing", "Rerolls"], rows))
    kinds = Counter()
    for r in pop:
        for s in r["shops"]:
            for b in s["bought"]:
                kinds[b["kind"]] += b["price"]
    tot = sum(kinds.values())
    md.append("\nWhere Credits go (population): " + ", ".join(f"{k} {f1(pct(v, tot))}%" for k, v in kinds.most_common()))
    summary["spend_share"] = {k: pct(v, tot) for k, v in kinds.items()}

    # ---------------------------------------------------------------- Round cards
    md.append("\n## H. Round cards\n")
    played = defaultdict(lambda: [0, 0])
    for r in everything:
        for rd in r["rounds"]:
            played[rd["card"]][0] += 1
            played[rd["card"]][1] += rd["won"]
    offered_c = Counter()
    picked_c = Counter()
    for r in pop:
        for s in r["shops"]:
            for c in s["cards"][1:]:
                offered_c[c] += 1
            picked_c[s["card"]] += 1
    md.append(table(["Round card", "Offered (pop)", "Picked (pop)", "Rounds played (all)", "Cleared"],
                    [[c, offered_c[c], picked_c[c], v[0], f1(pct(v[1], v[0])) + "%"] for c, v in sorted(played.items(), key=lambda kv: -kv[1][0])]))

    # ---------------------------------------------------------------- Experiment arms
    md.append("\n## I. Paired-seed experiments (same 120 seeds per arm)\n")
    rows = []
    summary["arms"] = {}
    for a in ["skill_casual", "skill_smart", "skill_lite", "skill_expert", "items_never", "items_hoarder", "items_impulse", "items_smart", "items_savvy", "items_lover",
              "cards_standard", "cards_random", "cards_greedy", "cards_ev", "dup_avoid", "dup_neutral", "dup_stack", "dup_stack_fav", "shop_current", "shop_no_owned", "shop_fresh",
              "profile_fresh", "profile_full"]:
        rs = arms.get(a, [])
        if not rs:
            continue
        w = pct(sum(r["won"] for r in rs), len(rs))
        rd = mean(r["round"] for r in rs)
        iu = mean(len(r["items_used"]) for r in rs)
        ic = mean(sum(b["price"] for s in r["shops"] for b in s["bought"] if b["kind"] == "item") for r in rs)
        cr = mean(r["credits_end"] for r in rs)
        r12 = [rd_ for r in rs for rd_ in r["rounds"] if rd_["round"] == 12]
        fin = pct(sum(x["won"] for x in r12), len(r12)) if r12 else 0
        rows.append([a, len(rs), f1(w) + "%", f1(rd), f1(fin) + "%", f1(iu), f1(ic), f1(cr)])
        summary["arms"][a] = {"runs": len(rs), "win": w, "round": rd, "items_used": iu, "item_credits": ic, "final_boss": fin}
    md.append(table(["Arm", "Runs", "Win", "Avg round", "Final boss cleared", "Items used/run", "Credits on items/run", "Credits at end"], rows))

    # ---------------------------------------------------------------- Strategies
    md.append("\n## J. Strategies seen (population)\n")
    tagc = defaultdict(list)
    for r in pop:
        tagc[build_tag(r["final_jokers"])].append(r)
    md.append(table(["Final build", "Runs", "Win", "Avg round"],
                    [[t, len(rs), f1(pct(sum(r["won"] for r in rs), len(rs))) + "%", f1(mean(r["round"] for r in rs))] for t, rs in sorted(tagc.items(), key=lambda kv: -len(kv[1]))]))
    summary["builds"] = {t: {"runs": len(rs), "win": pct(sum(r["won"] for r in rs), len(rs))} for t, rs in tagc.items()}
    # Behaviour patterns
    pats = defaultdict(list)
    for r in pop:
        shops = r["shops"]
        if r["dup_ids"]:
            pats["stacks a duplicate Joker"].append(r)
        if any(len(s["sold"]) > 0 for s in shops):
            pats["sells a Joker to upgrade"].append(r)
        if sum(s["rerolls"] for s in shops) >= 3:
            pats["rerolls 3+ times"].append(r)
        if any(s["round"] >= 8 and s["left_with"] >= 25 for s in shops):
            pats["banks 25+ Credits late"].append(r)
        if not r["won"] and r["items_end"]:
            pats["dies holding items"].append(r)
        if r["items_obtained"] and not r["items_used"]:
            pats["owns items, never uses one"].append(r)
        if any(s["card"] != "standard" for s in shops):
            pats["plays a round twist"].append(r)
        if sum(1 for s in shops if s["card"] in ("double_or_nothing", "tight_budget")) >= 2:
            pats["takes risky twists twice+"].append(r)
        full_at = next((s["round"] for s in shops if s["jokers_in"] >= s["slots"]), None)
        if full_at is not None and full_at <= 4:
            pats["full rack by round 4"].append(r)
        if r["holds"] > 0:
            pats["uses Hold"].append(r)
    md.append(table(["Pattern", "Runs", "Share of runs", "Win"],
                    [[p, len(rs), f1(pct(len(rs), len(pop))) + "%", f1(pct(sum(r["won"] for r in rs), len(rs))) + "%"] for p, rs in sorted(pats.items(), key=lambda kv: -len(kv[1]))]))
    summary["patterns"] = {p: {"share": pct(len(rs), len(pop)), "win": pct(sum(r["won"] for r in rs), len(rs))} for p, rs in pats.items()}

    # ---------------------------------------------------------------- Never used content
    md.append("\n## K. Content that never (or almost never) comes into play\n")
    never_bought = [JOKERS[j]["name"] for j in JOKERS if j_buy[j] == 0]
    rare_bought = [f"{JOKERS[j]['name']} ({f1(pct(j_buy[j], j_off[j]))}%)" for j in JOKERS if j_off[j] >= 50 and pct(j_buy[j], j_off[j]) < 5]
    dead = [f"{JOKERS[j]['name']} ({f1(pct(trig[j][1], trig[j][0]))}%)" for j in JOKERS if JOKERS[j]["phase"] != "rule" and trig[j][0] >= 300 and pct(trig[j][1], trig[j][0]) < 3]
    md.append("- Jokers never bought: " + (", ".join(never_bought) or "none"))
    md.append("- Jokers bought in under 5% of their offers (50+ offers): " + (", ".join(rare_bought) or "none"))
    md.append("- Jokers that trigger on under 3% of placements while owned (300+ placements): " + (", ".join(dead) or "none"))
    md.append("- Items never used: " + (", ".join(ITEMS[i]["name"] for i in ITEMS if used[i] == 0) or "none"))
    md.append("- Rule Jokers (no scoring trigger to count; judge by win when kept): " + ", ".join(JOKERS[j]["name"] for j in JOKERS if JOKERS[j]["phase"] == "rule"))
    md.append("- Workshop cards never bought: " + (", ".join(TOOLS[t]["name"] for t in TOOLS if t_buy[t] == 0) or "none"))
    feats = Counter()
    hands = Counter()
    for r in pop:
        feats.update(r["feats"])
        hands.update(r["hands"])
    md.append("- Feats per 100 runs: " + ", ".join(f"{k} {f1(100 * v / len(pop))}" for k, v in feats.most_common()))
    md.append("- Tray Hand placements per run: " + ", ".join(f"{k} {f1(v / len(pop))}" for k, v in hands.most_common()))

    with open(os.path.join(out_dir, "study_tables.md"), "w", encoding="utf-8") as f:
        f.write("# Release study: full tables\n\nGenerated by `tools/study_report.py` from `tools/study.gd` logs.\n\n" + "\n".join(md) + "\n")
    with open(os.path.join(out_dir, "study_summary.json"), "w", encoding="utf-8") as f:
        json.dump(summary, f, indent=1)
    print("wrote", out_dir)


if __name__ == "__main__":
    main()
