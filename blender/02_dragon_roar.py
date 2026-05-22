"""
02_dragon_roar.py
=================
Dragon roar animation for draconis_fire_dragon.b3d

Bone structure (from 01_dragon_info.py):
  Main armature ('armature'):
    Neck chain : Neck.1.CTRL -> Neck.2.CTRL -> Head.CTRL -> Jaw.CTRL
    Wing chain : Arm.L/R -> LowerArm.L/R -> Finger.1-4.L/R (wings, not hands)
    Tail       : Tail.1.CTRL -> Tail.2.CTRL -> Tail.3.CTRL

Animation: frames 1 – 40  (40 frames at 24 fps = 1.67 s)

Timeline:
  frame  1  : rest pose
  frame 10  : neck begins rising, wings start opening
  frame 18  : peak — head back, jaw open, wings fully spread
  frame 26  : peak hold
  frame 32  : easing back
  frame 40  : rest pose again

After running this script:
  1. Press SPACE in Blender to preview the animation.
  2. Tweak the degree constants below if any motion looks wrong.
  3. To export: select the main armature, File -> Export -> Blender3D (.b3d)
     NOTE: IK is baked automatically by the B3D exporter.
     If not, first: Object -> Animation -> Bake Action (check Visual Keying).

  Lua line to paste into boss/init.lua for the roar trigger:
    self.object:set_animation({x = 1, y = 40}, 24, 0, false)
"""

import bpy
import math

# ── Tuning knobs (degrees) ────────────────────────────────────
# Positive = forward/up/out in standard Blender XYZ pose space.
# Flip sign if a bone moves the wrong way.
NECK1_RAISE    =  20   # Neck.1.CTRL pitches up
NECK2_RAISE    =  15   # Neck.2.CTRL pitches up (stacks on Neck.1)
# Head: we try all three axes at once so at least one will be visible.
# After previewing, zero out the two that look wrong.
HEAD_X         = -40   # tilt back on X
HEAD_Y         =  40   # tilt back on Y (try if X does nothing)
HEAD_Z         =   0   # left/right — leave at 0
JAW_OPEN       =  40   # Jaw.CTRL drops open

WING_ARM_SPREAD =  50  # Arm.L/R rolls outward (Z axis) — main wing spread
WING_ARM_UP     =  15  # Arm.L/R pitches up (X axis)
WING_LOWER_BEND = -20  # LowerArm.L/R bends for dramatic curve
FINGER_FLARE    =  15  # Finger.1-4 spread for membrane tension

# Tail droops DOWN as counterweight when dragon rears back.
# Negative X = downward for these bones. Flip sign if it goes up instead.
TAIL1_DROOP    = -20   # Tail.1.CTRL hangs down at base
TAIL2_DROOP    = -15   # Tail.2.CTRL continues droop
TAIL3_DROOP    = -10   # Tail.3.CTRL tip hangs further

# ─────────────────────────────────────────────────────────────

def d(deg):
    return math.radians(deg)

def arm(name):
    obj = bpy.data.objects.get(name)
    if obj is None:
        print(f"  WARNING: object {name!r} not found — skipped")
    return obj

def ensure_action(obj, name):
    if not obj.animation_data:
        obj.animation_data_create()
    obj.animation_data.action = bpy.data.actions.new(name=name)
    return obj.animation_data.action

def kr(pose, bone_name, frame, xyz_deg):
    """Keyframe rotation on a pose bone."""
    pb = pose.bones.get(bone_name)
    if pb is None:
        print(f"  WARNING: bone {bone_name!r} missing")
        return
    pb.rotation_mode = 'XYZ'
    pb.rotation_euler = (d(xyz_deg[0]), d(xyz_deg[1]), d(xyz_deg[2]))
    pb.keyframe_insert('rotation_euler', frame=frame)

def rest(pose, bone_name, frame):
    kr(pose, bone_name, frame, (0, 0, 0))

# ── Main armature ─────────────────────────────────────────────
main = arm('armature')
if main is None:
    raise RuntimeError("Main armature 'armature' not found — import the dragon first!")

ensure_action(main, 'RoarAction')
bpy.context.view_layer.objects.active = main  # required for reliable keyframe insertion
p = main.pose

# ease-in / peak / ease-out multipliers
curve = [
    # (frame, ease)
    (1,  0.00),
    (10, 0.45),
    (18, 1.00),
    (26, 1.00),
    (32, 0.25),
    (40, 0.00),
]

for (frame, e) in curve:
    # ── Neck / head / jaw ──
    kr(p, 'Neck.1.CTRL', frame, (NECK1_RAISE * e,  0, 0))
    kr(p, 'Neck.2.CTRL', frame, (NECK2_RAISE * e,  0, 0))
    kr(p, 'Head.CTRL',   frame, (HEAD_X * e, HEAD_Y * e, HEAD_Z * e))
    kr(p, 'Jaw.CTRL',    frame, (JAW_OPEN * e,     0, 0))

    # ── Left wing (Arm.L chain) ──
    # Z roll = spread outward, X pitch = lift upward
    kr(p, 'Arm.L',      frame, (WING_ARM_UP * e,    0,  WING_ARM_SPREAD * e))
    kr(p, 'LowerArm.L', frame, (WING_LOWER_BEND * e, 0, 0))
    for i in range(1, 5):
        kr(p, f'Finger.{i}.L', frame, (0, 0, FINGER_FLARE * e))
    kr(p, 'Finger.L',   frame, (0, 0, FINGER_FLARE * e))

    # ── Right wing (Arm.R chain — mirror: negate Z roll) ──
    kr(p, 'Arm.R',      frame, (WING_ARM_UP * e,    0, -WING_ARM_SPREAD * e))
    kr(p, 'LowerArm.R', frame, (WING_LOWER_BEND * e, 0, 0))
    for i in range(1, 5):
        kr(p, f'Finger.{i}.R', frame, (0, 0, -FINGER_FLARE * e))
    kr(p, 'Finger.R',   frame, (0, 0, -FINGER_FLARE * e))

    # ── Tail (droops down as counterweight) ──
    kr(p, 'Tail.1.CTRL', frame, (TAIL1_DROOP * e, 0, 0))
    kr(p, 'Tail.2.CTRL', frame, (TAIL2_DROOP * e, 0, 0))
    kr(p, 'Tail.3.CTRL', frame, (TAIL3_DROOP * e, 0, 0))

# ── Scene ─────────────────────────────────────────────────────
sc = bpy.context.scene
sc.frame_start = 1
sc.frame_end   = max(sc.frame_end, 42)
sc.frame_set(1)
bpy.context.view_layer.update()

print("\n" + "="*55)
print("Roar animation inserted: frames 1 – 40 at 24 fps")
print("Press SPACE in Blender to preview.")
print()
print("Lua line for boss/init.lua:")
print('  self.object:set_animation({x = 1, y = 40}, 24, 0, false)')
print("="*55 + "\n")
