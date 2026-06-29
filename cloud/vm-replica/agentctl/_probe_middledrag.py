"""F210 — a MIDDLE-button drag (orbit/pan the 3D/CAD viewports that ignore L/R).

Forward practice in the modeling domain: an opaque 3D viewport (a colour-faced
cube software-projected on a canvas, no a11y) following the universal 3D/CAD
convention — **only the middle button orbits**, Shift+middle pans, left/right
drags do nothing (Blender, FreeCAD, Maya, Fusion all bind orbit to MMB). The
floor could middle-*click* but `drag`/`mod_drag` only exposed left/right via
``right: bool`` — so it could not turn the camera at all. F210 adds
``button="middle"`` to the existing drag stroke (the backend already owns the
middle transitions; this just lets the held stroke use them).

Verified through the **pixel channel only** (no CDP): the cube is judged by the
area of each coloured face and its overall centroid on the real screen.
  1. a LEFT drag changes nothing (the app is middle-only) — a middle drag is
     *necessary*, not a nicety;
  2. a horizontal MIDDLE drag orbits — the visible faces' areas change a lot;
  3. a vertical MIDDLE drag tilts — faces change again from the orbited pose;
  4. a Shift+MIDDLE drag (mod_drag with button="middle") pans — the whole cube
     *translates* (centroid moves ~the drag) while the faces stay the same.

Assumes the middle-only fixture (_fixture_orbit.html) is loaded and visible, and
no other Chrome window is on top. Run: C:\\devin\\python\\python.exe _probe_middledrag.py
"""
import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import osctl

PASS = 0
FAIL = 0
COLORS = [(255, 0, 0), (0, 255, 0), (0, 0, 255),
          (255, 255, 0), (255, 0, 255), (0, 255, 255)]


def check(name, cond, extra=""):
    global PASS, FAIL
    tag = "PASS" if cond else "FAIL"
    if cond:
        PASS += 1
    else:
        FAIL += 1
    print(f"  {tag}  {name}{('  ' + extra) if extra else ''}")


def sig():
    """Face areas + cube centroid from one capture (uses F209 find_colors)."""
    hits = osctl.find_colors(COLORS, tol=40, step=3)
    areas = {c: (h["count"] if h else 0) for c, h in zip(COLORS, hits)}
    tot = sum(areas.values()) or 1
    cx = sum((h["x"] * h["count"]) for h in hits if h) / tot
    cy = sum((h["y"] * h["count"]) for h in hits if h) / tot
    return areas, (cx, cy), tot


def area_change(a, b):
    tot = (sum(a.values()) + sum(b.values())) / 2 or 1
    return sum(abs(a[c] - b[c]) for c in COLORS) / tot


def center_now():
    hits = [h for h in osctl.find_colors(COLORS, tol=40, step=3) if h]
    tot = sum(h["count"] for h in hits) or 1
    return (int(sum(h["x"] * h["count"] for h in hits) / tot),
            int(sum(h["y"] * h["count"] for h in hits) / tot))


def main():
    cx, cy = center_now()
    print(f"    cube center ~ ({cx},{cy})")

    a0, _, t0 = sig()
    if t0 < 2000:
        print("[FAIL] cube not on screen — load _fixture_orbit.html and bring it to front")
        print("\n0 passed, 1 failed")
        return False

    # 1. LEFT drag — ignored by a middle-only viewport
    osctl.drag(cx - 90, cy, cx + 90, cy, steps=24, pause=0.01)  # default left
    time.sleep(0.25)
    a1, c1, _ = sig()
    ch_left = area_change(a0, a1)
    check("LEFT drag is ignored (faces unchanged)", ch_left < 0.10,
          f"area_change={ch_left:.3f}")

    # 2. horizontal MIDDLE drag — orbit (faces change a lot)
    cx, cy = center_now()
    osctl.drag(cx - 90, cy, cx + 90, cy, steps=24, pause=0.01, button="middle")
    time.sleep(0.25)
    a2, c2, _ = sig()
    ch_orbit = area_change(a1, a2)
    check("MIDDLE drag orbits (visible faces change)", ch_orbit > 0.25,
          f"area_change={ch_orbit:.3f}")

    # 3. vertical MIDDLE drag — tilt (faces change again)
    cx, cy = center_now()
    osctl.drag(cx, cy - 80, cx, cy + 80, steps=24, pause=0.01, button="middle")
    time.sleep(0.25)
    a3, c3, _ = sig()
    ch_tilt = area_change(a2, a3)
    check("vertical MIDDLE drag tilts (faces change)", ch_tilt > 0.15,
          f"area_change={ch_tilt:.3f}")

    # 4. Shift+MIDDLE drag — pan: cube translates, faces stay the same
    cx, cy = center_now()
    osctl.mod_drag(cx - 80, cy, cx + 80, cy, osctl.VK_SHIFT,
                   steps=24, pause=0.01, button="middle")
    time.sleep(0.25)
    a4, c4, _ = sig()
    dx = c4[0] - c3[0]
    ch_pan = area_change(a3, a4)
    check("Shift+MIDDLE drag pans (cube translates right, faces same)",
          dx > 60 and ch_pan < 0.25, f"dx={dx:.0f}px area_change={ch_pan:.3f}")

    print(f"\n{PASS} passed, {FAIL} failed")
    return FAIL == 0


if __name__ == "__main__":
    sys.exit(0 if main() else 1)
