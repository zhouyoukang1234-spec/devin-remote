"""F209 — find several colours from ONE capture (a perceive->act loop's frame).

Forward practice in the games domain (steering a paddle under a falling ball in
a pure-canvas, no-a11y game) exposed it: a real-time loop must read several
things per frame — the ball *and* the paddle. Doing that with one find_color per
thing grabs the whole screen once per thing (N× the cost) and, worse, each grab
is a *different instant*, so the two positions are skewed in time (the ball has
moved between them). ``find_colors`` grabs the frame once and locates every
target within that single, self-consistent frame.

Asserts:
  1. all targets located from one synthetic frame, list aligned to input order;
  2. an absent colour yields None in its slot (not a shifted list);
  3. results are identical to calling find_color individually on the same frame
     (it truly reuses the frame, same algorithm);
  4. the (r,g,b,tol) per-target tolerance form works;
  5. live: one find_colors over K targets is faster than K separate grabs
     (one capture, not K) — the real-time payoff.

Run: C:\\devin\\python\\python.exe _probe_findcolors.py
"""
import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import osctl

PASS = 0
FAIL = 0


def check(name, cond):
    global PASS, FAIL
    if cond:
        PASS += 1
        print(f"  PASS  {name}")
    else:
        FAIL += 1
        print(f"  FAIL  {name}")


def make_frame(w, h):
    """White frame with a red rect [40..80]x[30..50] and blue rect [200..240]x[150..170]."""
    buf = bytearray(b"\xff" * (w * h * 3))

    def rect(x0, x1, y0, y1, rgb):
        for y in range(y0, y1):
            for x in range(x0, x1):
                i = (y * w + x) * 3
                buf[i], buf[i + 1], buf[i + 2] = rgb
    rect(40, 80, 30, 50, (255, 0, 0))
    rect(200, 240, 150, 170, (0, 0, 255))
    return bytes(buf)


def main():
    W, H = 320, 240
    frame = make_frame(W, H)
    RED, BLUE, GREEN = (255, 0, 0), (0, 0, 255), (0, 255, 0)

    res = osctl.find_colors([RED, BLUE, GREEN], tol=20, rgb=frame, size=(W, H))
    check("returns one slot per target, aligned", len(res) == 3)
    r, b, g = res
    check("red located near its rect center (~60,40)",
          r and abs(r["x"] - 59) <= 3 and abs(r["y"] - 39) <= 3)
    check("blue located near its rect center (~220,160)",
          b and abs(b["x"] - 219) <= 3 and abs(b["y"] - 159) <= 3)
    check("absent green -> None in its own slot (list not shifted)", g is None)

    # 3. identical to individual find_color on the same frame
    ri = osctl.find_color(RED, tol=20, rgb=frame, size=(W, H))
    bi = osctl.find_color(BLUE, tol=20, rgb=frame, size=(W, H))
    check("matches individual find_color (same frame, same algorithm)",
          r == ri and b == bi)

    # 4. per-target tolerance form (r,g,b,tol)
    res2 = osctl.find_colors([(255, 0, 0, 5), (0, 0, 255, 5)], rgb=frame, size=(W, H))
    check("per-target (r,g,b,tol) form works", res2[0] == ri and res2[1] == bi)

    # 5. live perf: one find_colors (one capture) < K separate grabs
    K = 4
    targets = [(255, 0, 0), (0, 0, 255), (0, 255, 0), (255, 255, 0)]
    t = time.time()
    for _ in range(10):
        osctl.find_colors(targets, tol=30, step=2)
    t_single = time.time() - t
    t = time.time()
    for _ in range(10):
        for c in targets:
            osctl.find_color(c, tol=30, step=2)
    t_multi = time.time() - t
    print(f"    one-capture {K} targets: {t_single:.3f}s   vs {K} grabs: {t_multi:.3f}s")
    check("one capture for K targets beats K separate grabs", t_single < t_multi)

    print(f"\n{PASS} passed, {FAIL} failed")
    return FAIL == 0


if __name__ == "__main__":
    sys.exit(0 if main() else 1)
