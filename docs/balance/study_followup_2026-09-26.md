# Study follow-up balance check (2026-09-26)

Build: the study follow-up (GDD §25) with the shipped settings: board carries over within an act, rubble 0/2/3/4 per round by act, targets of rounds 3+ ×1.15 / ×1.35 / ×1.55 by act, act bosses ×1.15, Holo prices +50% per purchase, at most 3 Negative and 3 AGAIN Jokers. Harness: `tools/study.gd` (bots updated for the new content; the expert search no longer sees the hidden next tray). Paired arms play seeds 7001–7060; the population is participants 1–200, 2 runs each, continuing into Overtime. The three chip color commons were switched to +2 Mult after this batch (see GDD §25.7), so their rows below are the first draft.

## Summary

| Measure | Release study (before) | Now |
|---|---:|---:|
| Planner arm (`skill_lite`) win | 83% | 68% |
| Expert arm win | 85% | 75% |
| Careful arm (`skill_smart`) win | 30% | 25% |
| Casual arm win | 3% | 0% |
| Population: first-timer / casual / engaged / expert / item lover | 1% / 22% / 78% / 85% / 86% | 0% / 21% / 75% / 83% / 84% |
| Losses by board lock ("no room"), population | 2.3% | 21.5% (all among first-timers: 43 of their 70 losses) |
| Machine broken | 0 in ~1,440 Overtime runs | 2 of 400 population runs; 1 of 60 in `ot_best` (7 of 60 before the Holo price rise and caps) |
| Overtime depth (population entrants) | median 15, p90 18 | median 15, p90 20 |

Reading: competent play is a notch harder and now faces real bets (twists) and a late shop worth saving for; loose play loses to a crowded board, which is the loss the owner wanted to be part of the game. Competent bots still never lock the board: they plan whole trays and clear constantly. Human players misread boards more than the bots, so real no-room losses should reach further up the skill ladder; confirm in playtests. If the game still feels too easy, the single knob is `BMRunConfig.act_scale` (a ×1.2 / ×1.4 / ×1.6 ramp gave the planner 67%), and `rubble_by_act` raises board pressure.

## Tables

```
group                       n   win  losses(nofit/place)  died-at
cards_ev                   60   75%    1/14   {5: 2, 6: 1, 7: 1, 8: 2, 9: 4, 10: 1, 11: 2, 12: 2}
cards_standard             60   72%    0/17   {8: 2, 9: 7, 11: 2, 12: 6}
items_never                60   72%    0/17   {7: 1, 8: 5, 9: 3, 11: 1, 12: 7}
items_savvy                60   62%    0/23   {8: 6, 9: 7, 10: 1, 11: 3, 12: 6}
ot_best                    60   88%    0/7    {5: 1, 8: 3, 9: 1, 11: 2}  OT n=53 median=16 p90=24 max=58 broken=1
ot_expert                  60   70%    0/18   {7: 1, 8: 5, 9: 2, 10: 2, 12: 8}  OT n=42 median=16 p90=21 max=37 broken=0
pop:ALL                   400   50%   43/157  {2: 6, 3: 8, 4: 12, 5: 47, 6: 13, 7: 17, 8: 24, 9: 47, 10: 6, 11: 9, 12: 11}  OT n=200 median=15 p90=20 max=65 broken=2
pop:casual_regular        104   21%    0/82   {5: 22, 6: 8, 7: 8, 8: 11, 9: 24, 10: 2, 11: 2, 12: 5}  OT n=22 median=14 p90=15 max=16 broken=0
pop:engaged               130   75%    0/32   {5: 6, 7: 2, 8: 5, 9: 12, 10: 2, 11: 2, 12: 3}  OT n=98 median=15 p90=21 max=65 broken=1
pop:expert                 58   83%    0/10   {9: 2, 10: 2, 11: 4, 12: 2}  OT n=48 median=16 p90=18 max=32 broken=0
pop:first_timer            70    0%   43/27   {2: 6, 3: 8, 4: 12, 5: 19, 6: 4, 7: 7, 8: 7, 9: 6, 11: 1}
pop:item_lover             38   84%    0/6    {6: 1, 8: 1, 9: 3, 12: 1}  OT n=32 median=15 p90=23 max=56 broken=1
skill_casual               60    0%   41/19   {2: 6, 3: 11, 4: 9, 5: 9, 6: 4, 7: 7, 8: 8, 9: 2, 10: 2, 11: 1, 12: 1}
skill_expert               60   75%    0/15   {7: 1, 8: 4, 9: 3, 10: 1, 11: 1, 12: 5}
skill_lite                 60   68%    0/19   {8: 3, 9: 5, 10: 1, 11: 2, 12: 8}
skill_smart                60   25%    0/45   {5: 5, 7: 3, 8: 11, 9: 15, 10: 2, 11: 5, 12: 4}

new jokers: bought / held at end / win% when held
  red_alert         59   30   37%
  citrus_twist      49   25    0%
  lemon_drop        48   21    5%
  green_thumb       48   26   46%
  plum_job          41   17    6%
  red_giant         31   24   79%
  sunset_glow       26   17   88%
  solar_flare       28   25   76%
  evergreen         23   19   47%
  deep_blue         29   22   86%
  royal_purple      30   24   75%
  lone_wolf         43   20   10%
  tee_time          34   19   16%
  zigzagger         45   22   18%
  plus_side         38   15   13%
  solitaire         10    6   50%
  barbell           38   32   84%
  elbow_room        32   25   84%
  town_square       15   12   58%
  t_rex              6    6   67%
  lightning_bolt    12    6   67%
  compass_rose       8    5   40%

items: obtained / used
  spark              774   641   83%
  lucky_draw          93    25   27%
  coin_roll           88    66   75%
  emergency_brick     85    21   25%
  polish              84    64   76%
  double_down         84    50   60%
  overclock           75    58   77%
  mystery_stamp       73    53   73%
  second_tray         65     8   12%
  eraser              64     5    8%
  lucky_paint         60    20   33%
  extra_turn          59    56   95%
  phantom_line        55    46   84%
  tune_up             48    37   77%
  color_purge         46     5   11%

late sinks bought: {'holo_again_seal': 229, 'holo_hologram': 48, 'item_pouch': 174, 'holo_master_schematic': 220, 'holo_negative_film': 205, 'tuning_fork': 312, 'holo_master_tuning': 221}

```
