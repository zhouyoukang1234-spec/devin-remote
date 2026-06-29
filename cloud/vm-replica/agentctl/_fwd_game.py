"""Forward practice (games domain): drive a real-time HTML5 canvas game with NO
a11y at all, purely through the floor's pixel-perception + keyboard primitives.

Loop: find_color(red ball) and find_color(blue paddle) on the live screen, then
hold ArrowLeft/ArrowRight (key_down/key_up) to steer the paddle under the ball.
This is the pure 'pixel floor': screenshot -> locate -> timed key hold -> repeat.
"""
import os, sys, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import osctl

RED = (255, 0, 0)
BLUE = (0, 0, 255)
VK_LEFT, VK_RIGHT = 0x25, 0x27
DEAD = 38  # real-px half-tolerance; within this the paddle is "under" the ball

def main(duration=30.0):
    held = None  # which arrow is currently down
    def hold(vk):
        nonlocal held
        if held == vk:
            return
        if held is not None:
            osctl.key_up(held)
        if vk is not None:
            osctl.key_down(vk)
        held = vk
    t0 = time.time()
    iters = 0
    try:
        while time.time() - t0 < duration:
            iters += 1
            ball, pad = osctl.find_colors([RED, BLUE], tol=40, step=2)  # one frame
            if not ball or not pad:
                hold(None)            # inter-round gap: stop drifting
                time.sleep(0.02)
                continue
            dx = ball["x"] - pad["x"]
            if abs(dx) <= DEAD:
                hold(None)            # aligned: release
            elif dx < 0:
                hold(VK_LEFT)
            else:
                hold(VK_RIGHT)
            time.sleep(0.03)
    finally:
        hold(None)
    rate = iters / (time.time() - t0)
    print(f"played {iters} loops in {duration:.0f}s ({rate:.1f} Hz)")

if __name__ == "__main__":
    main(float(sys.argv[1]) if len(sys.argv) > 1 else 30.0)
