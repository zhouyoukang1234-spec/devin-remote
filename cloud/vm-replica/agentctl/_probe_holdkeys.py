"""F211 — `mouse_down`/`mouse_up`: a press the agent can ACT during, then release.

Forward practice (games/modeling): a "charge & aim" canvas (no a11y) where the
charge accrues only *while* the left button is held and arrow keys aim *during*
the hold — a gesture no bundled verb can make. `click` is instant (down+up in
one breath, no charge); `press_hold` holds but only *sleeps* (it cannot inject
the arrow keys mid-hold). F211 splits the press into `mouse_down`/`mouse_up`, so
the agent composes: down → wait (charge grows) + arrow keys (aim) → up (fire).

Judged through the **pixel channel only**: green-bar area = charge, yellow
marker y = aim, magenta disk = the frozen shot.
  1. a plain `click` cannot charge (green stays ~0) — the split is *necessary*;
  2. `mouse_down` + wait grows the charge (green area climbs while held);
  3. arrow keys pressed *during* the hold move the aim (yellow marker rises);
  4. `mouse_up` freezes a shot (magenta appears) and ends the hold — the charge
     stops climbing (it would keep growing if the button were still down) —
     a clean, agent-timed release.

Assumes _fixture_charge.html is loaded and visible, no other Chrome on top.
Run: C:\\devin\\python\\python.exe _probe_holdkeys.py
"""
import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import osctl

PASS = 0
FAIL = 0
GREEN = (0, 255, 0)
YELLOW = (255, 255, 0)
MAGENTA = (255, 0, 255)


def check(name, cond, extra=""):
    global PASS, FAIL
    tag = "PASS" if cond else "FAIL"
    if cond:
        PASS += 1
    else:
        FAIL += 1
    print(f"  {tag}  {name}{('  ' + extra) if extra else ''}")


def look():
    g, y, m = osctl.find_colors([GREEN, YELLOW, MAGENTA], tol=40, step=3)
    return (g["count"] if g else 0,
            (y["y"] if y else None),
            (m is not None))


def main():
    # locate the canvas: the yellow marker sits at the canvas center-x
    yh = osctl.find_color(YELLOW, tol=40, step=3)
    if not yh:
        print("[FAIL] charge fixture not visible — load _fixture_charge.html")
        print("\n0 passed, 1 failed")
        return False
    bx, by = yh["x"], yh["y"]              # a point inside the canvas
    print(f"    canvas marker ~ ({bx},{by})")

    # 1. a plain CLICK cannot charge
    osctl.click(bx, by)
    time.sleep(0.25)
    g_click, _, _ = look()
    check("a plain click cannot charge (green stays ~0)", g_click < 800,
          f"green={g_click}")

    # 2. mouse_down + wait grows the charge
    osctl.mouse_down(bx, by)
    time.sleep(0.45)
    g_hold1, aim0, _ = look()
    time.sleep(0.45)
    g_hold2, _, _ = look()
    check("mouse_down holds: charge accrues while held (green climbs)",
          g_hold2 > g_hold1 > 200, f"green {g_hold1}->{g_hold2}")

    # 3. arrow keys DURING the hold move the aim (marker rises => smaller y)
    for _ in range(5):
        osctl.tap(osctl.VK_UP)
        time.sleep(0.03)
    time.sleep(0.2)
    _, aim_y, _ = look()
    check("arrow keys during the hold change the aim (marker moved up)",
          aim_y is not None and aim0 is not None and (aim0 - aim_y) > 40,
          f"marker y {aim0}->{aim_y}")

    # 4. mouse_up fires (magenta appears) and ENDS the hold — the charge stops
    #    climbing (it would keep growing every frame if the button were still
    #    down), proving the release actually landed.
    osctl.mouse_up()
    time.sleep(0.1)
    g_rel, _, shot = look()
    time.sleep(0.5)
    g_rel2, _, _ = look()
    check("mouse_up fires a shot and ends the hold (charge stops climbing)",
          shot and abs(g_rel2 - g_rel) < 200,
          f"shot={shot} green frozen {g_rel}->{g_rel2}")

    print(f"\n{PASS} passed, {FAIL} failed")
    return FAIL == 0


if __name__ == "__main__":
    sys.exit(0 if main() else 1)
