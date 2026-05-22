"""
01_dragon_info.py
=================
Run this FIRST after importing draconis_fire_dragon.b3d.
It prints everything the AI needs to write the roar animation.

How to run:
  1. File -> Import -> Blender3D (.b3d)  ->  mods/boss/models/draconis_fire_dragon.b3d
  2. Open the Scripting workspace tab
  3. Open this file (or paste it), press Alt+P / Run Script
  4. Copy the full output from the Info / System Console and give it to the AI.
"""

import bpy

print("\n" + "="*60)
print("DRAGON MODEL INFO")
print("="*60)

# ── 1. All objects in the scene ───────────────────────────────
print("\n--- Objects ---")
for obj in bpy.data.objects:
    print(f"  {obj.type:12s}  name={obj.name!r}")

# ── 2. Armature bones + hierarchy ────────────────────────────
print("\n--- Bones ---")
for arm_obj in bpy.data.objects:
    if arm_obj.type != 'ARMATURE':
        continue
    print(f"  Armature object: {arm_obj.name!r}")
    for bone in arm_obj.data.bones:
        parent = bone.parent.name if bone.parent else "None"
        depth  = 0
        b = bone
        while b.parent:
            depth += 1
            b = b.parent
        indent = "    " + "  " * depth
        print(f"{indent}bone: {bone.name!r}  parent: {parent!r}")

# ── 3. Existing animations / frame ranges ────────────────────
print("\n--- Actions (existing animations) ---")
for action in bpy.data.actions:
    frames = sorted({
        int(kp.co[0])
        for fc in action.fcurves
        for kp in fc.keyframe_points
    })
    if frames:
        print(f"  action={action.name!r}   range: {frames[0]} – {frames[-1]}   total keyframes={len(frames)}")
    else:
        print(f"  action={action.name!r}   (no keyframes)")

# ── 4. Which action is active on each armature ───────────────
print("\n--- Active actions on armatures ---")
for arm_obj in bpy.data.objects:
    if arm_obj.type != 'ARMATURE':
        continue
    ad = arm_obj.animation_data
    if ad and ad.action:
        print(f"  {arm_obj.name!r}  ->  active action: {ad.action.name!r}")
    else:
        print(f"  {arm_obj.name!r}  ->  no active action")

# ── 5. Scene FPS ──────────────────────────────────────────────
sc = bpy.context.scene
print(f"\n--- Scene ---")
print(f"  FPS: {sc.render.fps}")
print(f"  Frame range: {sc.frame_start} – {sc.frame_end}")

print("\n" + "="*60)
print("Paste everything above (from the === line) to the AI.")
print("="*60 + "\n")
