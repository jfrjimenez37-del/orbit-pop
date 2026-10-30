#!/usr/bin/env python3
"""Unlock timeline for ORBIT POP with 10-minute sessions.

Reads the skins/trails (scripts/game/catalog.gd) and world scores (scripts/game/stages.gd);
the economy numbers below are copied from upgrades.gd / monetization/config.gd / progress.gd.
Player skill is a model (mean score per run grows with runs played), not measured data.

    python3 tools/unlock_sim.py > tools/unlock_timeline.md
"""
import math, random, re, statistics, pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent
cat = (ROOT / "scripts/game/catalog.gd").read_text(encoding="utf-8")
stg = (ROOT / "scripts/game/stages.gd").read_text(encoding="utf-8")
ITEM = re.compile(r'\{"id": "(\w+)", "name": "([^"]+)", "rarity": "(\w+)", "need": \["(\w+)", "?([\w.]+)"?\]')
def items(const):
    block = cat[cat.index("const %s := [" % const):]
    block = block[:block.index("\n]")]
    return [dict(id=m[0], name=m[1], rarity=m[2], kind=m[3], val=m[4]) for m in ITEM.findall(block)]
SKINS, TRAILS = items("SKINS"), items("TRAILS")
TH = [int(x) for x in re.findall(r'"score": (\d+)', stg[:stg.index("const LOOP_FROM")])]

PRICES = [0, 300, 1200, 4000, 12000]
ABIL = {"coins": 5, "shield": 3, "magnet": 5, "slowmo": 3, "teleport": 3, "headstart": 3, "secondlife": 1}
UNLOCK = {"coins": 2, "shield": 3, "magnet": 5, "slowmo": 8, "teleport": 10, "headstart": 12, "secondlife": 15}
NAMES = {"coins": "COINS+", "shield": "SHIELD", "magnet": "MAGNET", "slowmo": "SLOW-MO", "teleport": "TELEPORT",
         "headstart": "HEADSTART", "secondlife": "2ND LIFE"}
HEAD = [1, 3, 5, 8]
DAILY = [30, 40, 70, 60, 80, 140, 300]
def xp_next(L): return int(40 + 10 * L ** 1.8)
def world_of(s): return max(i for i, t in enumerate(TH) if s >= t) + 1

PROFILES = {  # 10-minute sessions per day, days played per week, skill model, optional ads per day
    "casual":    dict(ses=1, week=5, a=16, b=12, cap=120, ads=0, vid=False, mis=1.5, wk=0.3),
    "average":   dict(ses=2, week=6, a=20, b=20, cap=220, ads=1, vid=True,  mis=2.5, wk=0.7),
    "dedicated": dict(ses=4, week=7, a=26, b=30, cap=360, ads=2, vid=True,  mis=3.0, wk=1.0),
}

def sim(p, seed, days=365):
    rnd = random.Random(seed)
    lv, xp, coins, runs, minutes, streak = 1, 0, 0.0, 0, 0.0, 0
    own = {a: 0 for a in ABIL}; best_w = 1; best = 0; total = 0; got = set(); marks = {}
    def mark(k, d):
        if k not in marks: marks[k] = (d, minutes / 60)
    def free_items(d):
        for kind, lst in (("skin", SKINS), ("trail", TRAILS)):
            for it in lst:
                k = "%s %s" % (kind, it["id"]); v = it["val"]
                if k in got or it["kind"] in ("coins", "shop"): continue
                if ((it["kind"] == "best" and best >= int(v)) or (it["kind"] == "world" and best_w >= int(v)) or
                        (it["kind"] == "total" and total >= int(v)) or (it["kind"] == "level" and lv >= int(v))):
                    got.add(k); mark(k, d)
    for d in range(1, days + 1):
        if (d - 1) % 7 >= p["week"]:
            streak = 0; continue
        streak = streak % 7 + 1; coins += DAILY[streak - 1]
        for _ in range(p["ses"]):
            secs = 600
            while secs > 0:
                skill = min(p["cap"], p["a"] + p["b"] * math.log(1 + runs / 15))
                skill *= 1 + 0.04 * own["shield"] + 0.25 * own["secondlife"] + 0.03 * (own["slowmo"] + own["teleport"])
                gained = rnd.gammavariate(2.0, skill / 2.0)
                start_w = min(HEAD[own["headstart"]], max(1, best_w - 1)) if own["headstart"] else 1
                score = TH[start_w - 1] + gained
                t = gained / 1.05 + 12; secs -= t; minutes += t / 60; runs += 1
                best = max(best, score); best_w = max(best_w, world_of(score)); total += gained
                pick = 0.35 + 0.09 * own["magnet"]
                coins += (gained / 10 + (t - 12) / 6.75 * 0.5 + (t - 12) * (3 / 8 + 5 / 45) * pick) * (1 + 0.1 * own["coins"])
                xp += gained + 15
                while lv < 50 and xp >= xp_next(lv):
                    xp -= xp_next(lv); lv += 1; coins += 20 * lv
                    for a in ABIL:
                        if UNLOCK[a] == lv and a != "secondlife":
                            own[a] = max(own[a], 1); mark("ability %s 1" % a, d)
                for w in range(2, len(TH) + 1):
                    if best_w >= w: mark("world %d" % w, d)
                free_items(d)
        coins += 60 * p["ads"] + 100 * p["mis"] + 600 * p["wk"] / 7
        xp += 50 * p["mis"]
        if p["vid"]:   # one free level a day with videos (levels 2 and 3)
            for a in sorted(ABIL, key=lambda a: own[a]):
                if 1 <= own[a] < 3 and own[a] < ABIL[a] and a != "secondlife":
                    own[a] += 1; mark("ability %s %d" % (a, own[a]), d); break
        while True:    # spend: cheapest ability level first
            opts = [((10000 if a == "secondlife" else PRICES[own[a]]), a) for a in ABIL
                    if lv >= UNLOCK[a] and own[a] < ABIL[a] and (own[a] >= 1 or a == "secondlife")]
            if not opts: break
            c, a = min(opts)
            if coins < c: break
            coins -= c; own[a] += 1; mark("ability %s %d" % (a, own[a]), d)
        while True:    # then the cheapest coin skin/trail, keeping 1000 coins for the next upgrade
            nxt = sorted((int(it["val"]), "%s %s" % (kind, it["id"])) for kind, lst in (("skin", SKINS), ("trail", TRAILS))
                         for it in lst if it["kind"] == "coins" and "%s %s" % (kind, it["id"]) not in got)
            if not nxt or coins < nxt[0][0] + 1000: break
            coins -= nxt[0][0]; got.add(nxt[0][1]); mark(nxt[0][1], d)
        free_items(d)
        for L in (5, 10, 20, 30, 40, 50):
            if lv >= L: mark("level %d" % L, d)
    return marks

def need_text(it):
    k, v = it["kind"], it["val"]
    return {"best": "record %s", "world": "world %s", "total": "%s total points", "level": "level %s",
            "coins": "%s coins", "shop": "pack (%s)"}[k] % v

def main(n=200):
    res = {}
    for name, p in PROFILES.items():
        agg = {}
        for s in range(n):
            for k, v in sim(p, s).items(): agg.setdefault(k, []).append(v[0])
        res[name] = {k: (statistics.median(v) if len(v) >= n / 2 else None, 100 * len(v) // n) for k, v in agg.items()}
    def cell(k):
        out = []
        for name in PROFILES:
            m, pct = res[name].get(k, (None, 0))
            out.append(("day %d" % m) if m is not None else ("%d%% in 1 year" % pct if pct else "-"))
        return " | ".join(out)
    print("# ORBIT POP: unlock timeline (10-minute sessions)\n")
    print("Generated by `tools/unlock_sim.py` (median of %d simulated players per profile)." % n)
    print("casual: 1 session/day, 5 days/week, no optional videos. average: 2 sessions/day, 6 days/week.")
    print("dedicated: 4 sessions/day. Coins go to the cheapest ability level first, then to the cheapest")
    print("coin skin/trail (keeping 1000 coins). Pack items (shop) are only bought with real money.\n")
    print("## Worlds\n\n| World | Score | casual | average | dedicated |\n|---|---|---|---|---|")
    for i, t in enumerate(TH[1:], 2):
        print("| %d | %d | %s |" % (i, t, cell("world %d" % i)))
    print("\n## Abilities (level 1 free at the player level, then coins or videos)\n")
    print("| Ability | Level | casual | average | dedicated |\n|---|---|---|---|---|")
    for a, mx in ABIL.items():
        for l in range(1, mx + 1):
            print("| %s | %d | %s |" % (NAMES[a], l, cell("ability %s %d" % (a, l))))
    for kind, lst, title in (("skin", SKINS, "Skins"), ("trail", TRAILS, "Trails")):
        print("\n## %s\n\n| %s | Rarity | Needs | casual | average | dedicated |\n|---|---|---|---|---|---|" % (title, title[:-1]))
        for it in lst:
            k = "%s %s" % (kind, it["id"])
            c = "pack" if it["kind"] == "shop" else ("start" if it["kind"] == "best" and it["val"] == "0" else cell(k))
            if c in ("pack", "start"): c = " | ".join([c] * 3)
            print("| %s | %s | %s | %s |" % (it["name"], it["rarity"], need_text(it), c))
    print("\n## Player level\n\n| Level | casual | average | dedicated |\n|---|---|---|---|")
    for L in (5, 10, 20, 30, 40, 50):
        print("| %d | %s |" % (L, cell("level %d" % L)))
    print("\n## Longest stretches without a new unlock (median player)\n")
    for name, p in PROFILES.items():
        days = sorted({int(m) for m, _ in res[name].values() if m is not None})
        gaps = sorted(((b - a, a, b) for a, b in zip(days, days[1:])), reverse=True)[:3]
        print("- %s: %s" % (name, ", ".join("%d days (day %d to %d)" % g for g in gaps)))

if __name__ == "__main__":
    main()
