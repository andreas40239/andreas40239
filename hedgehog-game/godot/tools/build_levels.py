#!/usr/bin/env python3
"""Builds the grey-box garden scenes (scenes/garden_*.tscn).

Each garden is described in plain Python below: scenery boxes, bushes, food,
nest material, animals... Run this after changing a layout:

    python3 tools/build_levels.py

Note: this overwrites the garden scenes, so edits made to them in the Godot
editor are lost. Either edit the layout here, or stop using this script and
edit the scenes in Godot from then on.
"""
import math
import os

OUT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "scenes")

GRASS = (0.42, 0.62, 0.3)
LAWN = (0.5, 0.7, 0.35)
WOOD = (0.55, 0.4, 0.26)
DARK_WOOD = (0.35, 0.25, 0.17)
BRICK = (0.7, 0.45, 0.38)
STONE = (0.62, 0.6, 0.56)
SOIL = (0.4, 0.28, 0.18)
GRAVEL = (0.68, 0.64, 0.56)
BARK = (0.4, 0.28, 0.18)


def v3(x, y, z):
    return f"Vector3({x:g}, {y:g}, {z:g})"


def transform(pos=(0, 0, 0), yaw=0.0, pitch=0.0, scale=(1, 1, 1)):
    """Godot Transform3D: basis columns (x, y, z axes) then origin."""
    cy, sy = math.cos(yaw), math.sin(yaw)
    cp, sp = math.cos(pitch), math.sin(pitch)
    # R = Ry(yaw) * Rx(pitch), columns scaled.
    x_axis = (cy * scale[0], 0, -sy * scale[0])
    y_axis = (sy * sp * scale[1], cp * scale[1], cy * sp * scale[1])
    z_axis = (sy * cp * scale[2], -sp * scale[2], cy * cp * scale[2])
    vals = ", ".join(f"{v:.5g}" for v in x_axis + y_axis + z_axis + tuple(pos))
    return f"Transform3D({vals})"


class Level:
    def __init__(self, name):
        self.name = name
        self.ext = []
        self.subs = []
        self.nodes = []
        self.mats = {}
        self.counter = 0
        self.scripts = {}

    # --- Resources -------------------------------------------------------------

    def nid(self, prefix):
        self.counter += 1
        return f"{prefix}_{self.counter}"

    def ext_res(self, typ, path):
        for t, p, rid in self.ext:
            if p == path:
                return rid
        rid = f"{len(self.ext) + 1}_{path.split('/')[-1].split('.')[0]}"
        self.ext.append((typ, path, rid))
        return rid

    def scene(self, name):
        return self.ext_res("PackedScene", f"res://scenes/{name}.tscn")

    def script(self, name):
        return self.ext_res("Script", f"res://scripts/{name}.gd")

    def material(self, color, unshaded=False):
        key = (color, unshaded)
        if key not in self.mats:
            rid = self.nid("mat")
            extra = "shading_mode = 0\n" if unshaded else ""
            self.subs.append(f'[sub_resource type="StandardMaterial3D" id="{rid}"]\n{extra}albedo_color = Color({color[0]}, {color[1]}, {color[2]}, 1)\nroughness = 0.9\n')
            self.mats[key] = rid
        return self.mats[key]

    def mesh(self, kind, color, unshaded=False, **params):
        rid = self.nid("mesh")
        lines = [f'[sub_resource type="{kind}" id="{rid}"]', f'material = SubResource("{self.material(color, unshaded)}")']
        for k, v in params.items():
            lines.append(f"{k} = {v}")
        self.subs.append("\n".join(lines) + "\n")
        return rid

    # --- Nodes -----------------------------------------------------------------

    def node(self, name, typ, parent=".", props=None, instance=None):
        head = f'[node name="{name}"'
        if typ:
            head += f' type="{typ}"'
        head += f' parent="{parent}"'
        if instance:
            head += f' instance=ExtResource("{instance}")'
        head += "]"
        lines = [head]
        for k, v in (props or {}).items():
            lines.append(f"{k} = {v}")
        self.nodes.append("\n".join(lines) + "\n")

    def box(self, name, size, pos, color, parent="Scenery", yaw=0.0, solid=True):
        """A box prop. Solid boxes block the hedgehog, animals and their sight."""
        self.node(name, "StaticBody3D" if solid else "Node3D", parent, {"transform": transform(pos, yaw)})
        mesh = self.mesh("BoxMesh", color, size=v3(*size))
        self.node("Mesh", "MeshInstance3D", f"{parent}/{name}", {"mesh": f'SubResource("{mesh}")'})
        if solid:
            shape = self.nid("shape")
            self.subs.append(f'[sub_resource type="BoxShape3D" id="{shape}"]\nsize = {v3(*size)}\n')
            self.node("Collision", "CollisionShape3D", f"{parent}/{name}", {"shape": f'SubResource("{shape}")'})

    def decor(self, name, kind, color, pos, parent="Scenery", yaw=0.0, pitch=0.0, scale=(1, 1, 1), unshaded=False, **params):
        mesh = self.mesh(kind, color, unshaded, **params)
        self.node(name, "MeshInstance3D", parent, {"transform": transform(pos, yaw, pitch, scale), "mesh": f'SubResource("{mesh}")'})

    def flat(self, name, size, pos, color, yaw=0.0):
        self.decor(name, "BoxMesh", color, (pos[0], 0.006, pos[1]), yaw=yaw, size=v3(size[0], 0.012, size[1]))

    def tree(self, name, x, z, colors=((0.75, 0.45, 0.15), (0.6, 0.55, 0.2))):
        self.node(name, "StaticBody3D", "Scenery", {"transform": transform((x, 0, z))})
        trunk = self.mesh("CylinderMesh", (0.4, 0.28, 0.18), top_radius="0.22", bottom_radius="0.3", height="3.0", radial_segments="12")
        self.node("Trunk", "MeshInstance3D", f"Scenery/{name}", {"transform": transform((0, 1.5, 0)), "mesh": f'SubResource("{trunk}")'})
        shape = self.nid("shape")
        self.subs.append(f'[sub_resource type="CylinderShape3D" id="{shape}"]\nradius = 0.3\nheight = 3.0\n')
        self.node("Collision", "CollisionShape3D", f"Scenery/{name}", {"transform": transform((0, 1.5, 0)), "shape": f'SubResource("{shape}")'})
        for k, (ox, oy, oz) in enumerate(((0, 3.4, 0), (0.9, 3.0, 0.3), (-0.8, 3.1, -0.4), (0.2, 3.9, -0.5))):
            self.decor(f"Canopy{k}", "SphereMesh", colors[k % len(colors)], (ox, oy, oz), parent=f"Scenery/{name}",
                       radius="1.1", height="2.0", radial_segments="16", rings="8")

    def fences(self, half=15.0, height=1.3, north_gap=None):
        """A square fence. `north_gap` = (x_from, x_to) leaves room for a house."""
        span = half * 2 + 0.3
        self.box("FenceSouth", (span, height, 0.15), (0, height / 2, half), WOOD)
        self.box("FenceEast", (0.15, height, span), (half, height / 2, 0), WOOD)
        self.box("FenceWest", (0.15, height, span), (-half, height / 2, 0), WOOD)
        if north_gap:
            x0, x1 = north_gap
            self.box("FenceNorth", (half - x1, height, 0.15), ((half + x1) / 2, height / 2, -half), WOOD)
        else:
            self.box("FenceNorth", (span, height, 0.15), (0, height / 2, -half), WOOD)

    def raised_shed(self, prefix, x, z, wall_color=(0.45, 0.55, 0.42), walls=True, gap_side="south"):
        """A shed (or decking) on a raised floor. Hedgehogs fit underneath
        through a gap in the skirting; cats and dogs are too tall."""
        self.box(f"{prefix}Floor", (4, 0.2, 3), (x, 0.5, z), DARK_WOOD)
        if walls:
            self.box(f"{prefix}Walls", (4, 2.2, 3), (x, 1.7, z), wall_color)
            self.box(f"{prefix}Roof", (4.5, 0.15, 3.5), (x, 2.88, z), (0.3, 0.3, 0.32))
            self.decor(f"{prefix}Door", "BoxMesh", (0.3, 0.35, 0.28), (x, 1.5, z + 1.51), size=v3(1.0, 1.7, 0.03))
        else:
            # Decking: railings and a little table instead of walls.
            for i, dx in enumerate((-1.9, 1.9)):
                self.box(f"{prefix}Rail{i}", (0.08, 0.9, 3), (x + dx, 1.05, z), WOOD)
            self.box(f"{prefix}Table", (1.0, 0.7, 1.0), (x, 0.95, z - 0.4), (0.7, 0.55, 0.35))
        self.box(f"{prefix}SkirtLeft", (1.78, 0.4, 0.06), (x - 1.11, 0.2, z + 1.53), DARK_WOOD)
        self.box(f"{prefix}SkirtRight", (1.78, 0.4, 0.06), (x + 1.11, 0.2, z + 1.53), DARK_WOOD)
        self.box(f"{prefix}SkirtBack", (4, 0.4, 0.06), (x, 0.2, z - 1.53), DARK_WOOD)
        self.box(f"{prefix}SkirtWest", (0.06, 0.4, 3.1), (x - 2.03, 0.2, z), DARK_WOOD)
        self.box(f"{prefix}SkirtEast", (0.06, 0.4, 3.1), (x + 2.03, 0.2, z), DARK_WOOD)

    def raised_bed(self, name, x, z, length=4.0, crop="cabbage"):
        self.box(name, (length, 0.3, 1.2), (x, 0.15, z), (0.5, 0.33, 0.2))
        count = int(length / 0.8)
        for j in range(count):
            px = x - length / 2 + 0.4 + j * 0.8
            if crop == "cabbage":
                self.decor(f"{name}Crop{j}", "SphereMesh", (0.4, 0.65, 0.3), (px, 0.42, z), radius="0.22", height="0.36", radial_segments="12", rings="6")
            elif crop == "beans":
                self.decor(f"{name}Crop{j}", "CylinderMesh", (0.35, 0.6, 0.25), (px, 0.95, z), top_radius="0.05", bottom_radius="0.18", height="1.3", radial_segments="8")
            else:  # pumpkins
                self.decor(f"{name}Crop{j}", "SphereMesh", (0.95, 0.5, 0.12), (px, 0.45, z), scale=(1.2, 0.8, 1.2), radius="0.22", height="0.44", radial_segments="12", rings="6")

    # --- Gameplay pieces ---------------------------------------------------------

    def player(self, x, z, yaw=0.0):
        self.node("Player", None, ".", {"transform": transform((x, 0.1, z)), "camera_path": 'NodePath("../CameraRig")'}, instance=self.scene("player"))
        self.node("CameraRig", "Node3D", ".", {"script": f'ExtResource("{self.script("camera_rig")}")', "target_path": 'NodePath("../Player")', "yaw": f"{yaw:g}"})
        self.node("SpringArm3D", "SpringArm3D", "CameraRig", {"spring_length": "3.2", "margin": "0.2"})
        self.node("Camera3D", "Camera3D", "CameraRig/SpringArm3D", {"current": "true", "fov": "65.0", "near": "0.03"})

    def group(self, name):
        self.node(name, "Node3D")

    def checkpoints(self, points):
        self.group("Checkpoints")
        for i, (x, z) in enumerate(points):
            props = {"transform": transform((x, 0, z))}
            if i == 0:
                props["announce"] = "false"
            self.node(f"Checkpoint{i}", None, "Checkpoints", props, instance=self.scene("checkpoint"))

    def hide_spots(self, spots):
        """spots: (name, x, z, size, look, masks_scent, show)"""
        self.group("HideSpots")
        for name, x, z, size, look, masks, show in spots:
            props = {"transform": transform((x, 0, z)), "size": f"{size:g}"}
            if look != "bush":
                props["look"] = f'"{look}"'
            if masks:
                props["masks_scent"] = "true"
            if not show:
                props["show_bush"] = "false"
            self.node(name, None, "HideSpots", props, instance=self.scene("hide_spot"))

    def food(self, items):
        self.group("Food")
        for i, (kind, x, z) in enumerate(items):
            props = {"transform": transform((x, 0, z)), "kind": f'"{kind}"'}
            if kind == "milk":
                props["respawn_time"] = "0.0"
            self.node(f"{kind.capitalize()}{i}", None, "Food", props, instance=self.scene("food"))

    def nest_materials(self, items):
        self.group("NestMaterials")
        for i, (kind, x, z) in enumerate(items):
            self.node(f"{kind.capitalize()}{i}", None, "NestMaterials", {"transform": transform((x, 0, z)), "kind": f'"{kind}"'}, instance=self.scene("nest_material"))

    def hibernation_spots(self, spots):
        """spots: (name, x, z, look, secure, fact, radius)"""
        self.group("HibernationSpots")
        for name, x, z, look, secure, fact, radius in spots:
            props = {"transform": transform((x, 0, z)), "look": f'"{look}"', "fact_id": f'"{fact}"', "radius": f"{radius:g}"}
            if not secure:
                props["secure"] = "false"
            self.node(name, None, "HibernationSpots", props, instance=self.scene("hibernation_spot"))

    def patrol(self, name, points):
        self.node(name, "Node3D")
        for i, (x, z) in enumerate(points):
            self.node(f"Point{i}", "Marker3D", name, {"transform": transform((x, 0, z))})

    def cat(self, name, x, z, patrol, **props):
        values = {"transform": transform((x, 0.1, z)), "patrol_path": f'NodePath("../{patrol}")'}
        values.update(props)
        self.node(name, None, ".", values, instance=self.scene("cat"))

    def environment(self, night=False):
        if night:
            sky = ('sky_top_color = Color(0.03, 0.05, 0.14, 1)\nsky_horizon_color = Color(0.12, 0.14, 0.3, 1)\n'
                   'ground_bottom_color = Color(0.02, 0.03, 0.06, 1)\nground_horizon_color = Color(0.12, 0.14, 0.3, 1)\n')
            ambient = "ambient_light_source = 2\nambient_light_color = Color(0.45, 0.5, 0.8, 1)\nambient_light_energy = 0.55\n"
            light = {"light_color": "Color(0.65, 0.75, 1, 1)", "light_energy": "0.55"}
        else:
            sky = ('sky_top_color = Color(0.45, 0.62, 0.85, 1)\nsky_horizon_color = Color(0.85, 0.78, 0.68, 1)\n'
                   'ground_bottom_color = Color(0.25, 0.22, 0.18, 1)\nground_horizon_color = Color(0.85, 0.78, 0.68, 1)\n')
            ambient = "ambient_light_source = 3\nambient_light_energy = 0.8\n"
            light = {"light_color": "Color(1, 0.9, 0.75, 1)", "light_energy": "1.2"}
        self.subs.append(f'[sub_resource type="ProceduralSkyMaterial" id="sky_mat"]\n{sky}')
        self.subs.append('[sub_resource type="Sky" id="sky"]\nsky_material = SubResource("sky_mat")\n')
        self.subs.append(f'[sub_resource type="Environment" id="env"]\nbackground_mode = 2\nsky = SubResource("sky")\n{ambient}tonemap_mode = 2\nadjustment_enabled = true\n')
        self.node("WorldEnvironment", "WorldEnvironment", ".", {"environment": 'SubResource("env")'})
        props = {"transform": transform((0, 10, 0), yaw=math.radians(35), pitch=math.radians(-50)), "shadow_enabled": "true"}
        props.update(light)
        self.node("Sun", "DirectionalLight3D", ".", props)

    def snow(self):
        self.subs.append('[sub_resource type="StandardMaterial3D" id="snow_mat"]\nshading_mode = 0\nalbedo_color = Color(1, 1, 1, 1)\n')
        self.subs.append('[sub_resource type="SphereMesh" id="snow_mesh"]\nmaterial = SubResource("snow_mat")\nradius = 0.03\nheight = 0.06\nradial_segments = 6\nrings = 3\n')
        self.node("Snow", "CPUParticles3D", ".", {
            "transform": transform((0, 9, 0)), "emitting": "false", "amount": "800", "lifetime": "9.0",
            "mesh": 'SubResource("snow_mesh")', "emission_shape": "3", "emission_box_extents": "Vector3(16, 0.5, 16)",
            "direction": "Vector3(0, -1, 0)", "spread": "15.0", "gravity": "Vector3(0, -0.6, 0)",
            "initial_velocity_min": "0.4", "initial_velocity_max": "0.8",
        })

    def fireflies(self, clusters):
        self.subs.append('[sub_resource type="StandardMaterial3D" id="firefly_mat"]\nshading_mode = 0\nalbedo_color = Color(0.85, 1, 0.35, 1)\n')
        self.subs.append('[sub_resource type="SphereMesh" id="firefly_mesh"]\nmaterial = SubResource("firefly_mat")\nradius = 0.035\nheight = 0.07\nradial_segments = 6\nrings = 3\n')
        self.group("Fireflies")
        for i, (x, z) in enumerate(clusters):
            self.node(f"Fireflies{i}", "CPUParticles3D", "Fireflies", {
                "transform": transform((x, 1.0, z)), "amount": "12", "lifetime": "6.0", "preprocess": "6.0",
                "mesh": 'SubResource("firefly_mesh")', "emission_shape": "1", "emission_sphere_radius": "1.8",
                "direction": "Vector3(0, 1, 0)", "spread": "180.0", "gravity": "Vector3(0, 0, 0)",
                "initial_velocity_min": "0.05", "initial_velocity_max": "0.25",
                "scale_amount_min": "0.6", "scale_amount_max": "1.2",
            })

    def ui(self, tutorial=False, cat_path="../Cat"):
        self.node("HUD", "CanvasLayer", ".", {"script": f'ExtResource("{self.script("hud")}")'})
        self.node("TouchLayer", "CanvasLayer", ".", {"layer": "2"})
        self.node("TouchControls", "Control", "TouchLayer", {
            "script": f'ExtResource("{self.script("touch_controls")}")', "mouse_filter": "2",
            "anchors_preset": "15", "anchor_right": "1.0", "anchor_bottom": "1.0",
            "player_path": 'NodePath("../../Player")', "camera_rig_path": 'NodePath("../../CameraRig")', "hud_path": 'NodePath("../../HUD")',
        })
        self.node("Tutorial", "CanvasLayer", ".", {
            "script": f'ExtResource("{self.script("tutorial")}")', "enabled": "true" if tutorial else "false",
            "player_path": 'NodePath("../Player")', "camera_rig_path": 'NodePath("../CameraRig")',
            "touch_controls_path": 'NodePath("../TouchLayer/TouchControls")', "cat_path": f'NodePath("{cat_path}")',
        })

    # --- Output ------------------------------------------------------------------------

    def write(self, root_props):
        main = self.script("main")
        props = "".join(f"{k} = {v}\n" for k, v in root_props.items())
        root = f'[node name="Main" type="Node3D"]\nscript = ExtResource("{main}")\n{props}'
        path = os.path.join(OUT_DIR, f"{self.name}.tscn")
        with open(path, "w") as f:
            f.write(f"[gd_scene load_steps={len(self.ext) + len(self.subs) + 1} format=3]\n\n")
            for typ, p, rid in self.ext:
                f.write(f'[ext_resource type="{typ}" path="{p}" id="{rid}"]\n')
            f.write("\n")
            for s in self.subs:
                f.write(s + "\n")
            f.write(root + "\n")
            f.write("\n".join(self.nodes))
        print(f"  {self.name}.tscn: {len(self.nodes)} nodes")


def q(text):
    return '"' + text.replace('"', '\\"') + '"'


# ===================================================================================
# Garden 1: The Cottage Garden (tutorial, one cat)
# ===================================================================================

def garden_1():
    g = Level("garden_1")
    g.script("main")
    g.environment()
    g.group("Scenery")
    g.box("Ground", (34, 1, 34), (0, -0.5, 0), GRASS)
    g.flat("Lawn", (15, 13), (1, 2), LAWN)
    g.fences(north_gap=(-15, -3))
    g.decor("HedgehogHighway", "BoxMesh", (0.08, 0.06, 0.05), (-13, 0.08, 14.91), size=v3(0.3, 0.16, 0.02))
    g.box("House", (13, 5, 5), (-8.5, 2.5, -15), BRICK)
    g.decor("BackDoor", "BoxMesh", (0.3, 0.2, 0.15), (-5, 1.0, -12.48), size=v3(1.0, 2.0, 0.04))
    g.flat("Patio", (7, 3), (-6, -10.8), STONE)
    g.raised_shed("Shed", 9.0, -9.0)
    for i, z in enumerate((3.0, 6.0)):
        g.raised_bed(f"RaisedBed{i}", -9, z)
    for i, (x, z) in enumerate(((11, 8), (-8.5, 13), (-11, -6))):
        g.tree(f"Tree{i}", x, z)
    g.decor("Pond", "CylinderMesh", (0.3, 0.5, 0.7), (-9, 0.01, -2), top_radius="1.8", bottom_radius="1.8", height="0.02")
    for i in range(7):
        g.decor(f"SteppingStone{i}", "CylinderMesh", STONE, (-5 + i * 0.4, 0.015, -8 + i * 1.6), top_radius="0.3", bottom_radius="0.32", height="0.03", radial_segments="10")
    for i in range(14):
        a = i * 2.4
        r = 1.2 + (i % 4) * 0.35
        g.decor(f"LongGrass{i}", "BoxMesh", (0.5, 0.6, 0.25), (12.5 + math.cos(a) * r, 0.25, 12.5 + math.sin(a) * r), yaw=a, size=v3(0.05, 0.5, 0.3))

    g.player(-13, 13)
    g.checkpoints(((-13, 13), (0, -5), (6, 11)))
    bushes = [(-6, -4, 1.0), (0, 7, 1.2), (6, -2, 1.0), (-12, -11, 1.3), (5, 10, 1.0), (-3, 12, 1.1), (-7, 1, 0.9), (3.5, 3.5, 0.9)]
    g.hide_spots([(f"Bush{i}", x, z, s, "bush", False, True) for i, (x, z, s) in enumerate(bushes)]
                 + [("UnderShed", 9.0, -9.0, 1.8, "bush", False, False)])
    g.food([
        ("beetle", -11, 9), ("beetle", 2, 8.5), ("beetle", 7.5, 4), ("beetle", -2, -7), ("beetle", 13, -5),
        ("worm", -9, 4.5), ("worm", 4, 12.5), ("worm", -5, 8), ("worm", -9.5, 0.2),
        ("slug", -6.6, 3), ("slug", -11.6, 6), ("slug", -8.8, 7.1),
        ("apple", 10.2, 7.0), ("apple", 11.9, 9.1),
        ("milk", -4.2, -10.6),
    ])
    g.nest_materials([
        ("leaves", 10.5, 6.2), ("leaves", 12.2, 9.8), ("leaves", -12.5, 9.5), ("leaves", -1, 4),
        ("leaves", 6.5, -5), ("leaves", 2, -11), ("moss", -10.2, -0.3), ("moss", 13, -1.5),
        ("leaves", -10.5, -7.2), ("straw", 7, -11.5),
    ])
    g.hibernation_spots([
        ("UnderShed", 9.0, -9.0, "shed", True, "shed", 1.0),
        ("LogPile", 12.5, 12.5, "log_pile", True, "shed", 1.1),
        ("BonfirePile", 2.5, -3, "bonfire", False, "bonfire", 1.2),
    ])
    g.patrol("CatPatrol", ((-4, -1), (7, -1), (8, 6), (1, 9.5), (-4, 6)))
    g.cat("Cat", -4, -1, "CatPatrol")
    g.snow()
    g.ui(tutorial=True)
    g.write({"level_index": "0", "level_title": q("Garden 1: The Cottage Garden")})


# ===================================================================================
# Garden 2: The Allotments (a dog that hunts by smell, compost heaps, balls)
# ===================================================================================

def garden_2():
    g = Level("garden_2")
    g.environment()
    g.group("Scenery")
    g.box("Ground", (34, 1, 34), (0, -0.5, 0), (0.4, 0.58, 0.28))
    g.fences()
    g.decor("HedgehogHighway", "BoxMesh", (0.08, 0.06, 0.05), (12.5, 0.08, 14.91), size=v3(0.3, 0.16, 0.02))
    # Gravel paths in a cross.
    g.flat("PathEastWest", (28, 2), (0, 0), GRAVEL)
    g.flat("PathNorthSouth", (2, 28), (0, 0), GRAVEL, yaw=0.0)
    # Four plots of raised beds.
    crops = ["cabbage", "beans", "pumpkin", "cabbage"]
    for p, (px, pz) in enumerate(((-8, -8), (8, -8), (-8, 7), (8, 7))):
        for r in range(3):
            g.raised_bed(f"Plot{p}Bed{r}", px, pz - 3 + r * 2.6, 5.0, crops[(p + r) % len(crops)])
    g.raised_shed("Shed", 11.0, -12.0, wall_color=(0.5, 0.42, 0.55))
    # Greenhouse frame (north-west).
    for i, (dx, dz) in enumerate(((-1.5, -1), (1.5, -1), (-1.5, 1), (1.5, 1))):
        g.box(f"GreenhousePost{i}", (0.08, 2.0, 0.08), (-11 + dx, 1.0, -12.5 + dz), (0.85, 0.85, 0.85))
    g.decor("GreenhouseRoof", "BoxMesh", (0.8, 0.9, 0.95), (-11, 2.05, -12.5), size=v3(3.2, 0.08, 2.2))
    g.box("WaterButt", (0.8, 1.1, 0.8), (7.8, 0.55, -13.8), (0.25, 0.35, 0.3))
    g.tree("Tree0", -13, 11, colors=((0.8, 0.5, 0.15), (0.7, 0.3, 0.1)))
    g.tree("Tree1", 13, 2, colors=((0.6, 0.55, 0.2), (0.75, 0.45, 0.15)))

    g.player(12.5, 13, yaw=0.0)
    g.checkpoints(((12.5, 13), (-3, 3), (3, -10)))
    g.hide_spots([
        ("Compost0", -4.0, -4.5, 1.2, "compost", True, True),
        ("Compost1", 4.5, 3.5, 1.2, "compost", True, True),
        ("Compost2", -12.5, 1.5, 1.2, "compost", True, True),
        ("Compost3", 13.2, -8.0, 1.1, "compost", True, True),
        ("Bush0", -13, -4, 1.2, "bush", False, True),
        ("Bush1", 2.5, 12.5, 1.1, "bush", False, True),
        ("Bush2", -6, 12.8, 1.0, "bush", False, True),
        ("Bush3", 6, -3.5, 1.0, "bush", False, True),
        ("UnderShed", 11.0, -12.0, 1.8, "bush", True, False),
        ("HedgehogHouse", -12.0, 12.5, 0.9, "bush", True, False),
    ])
    g.food([
        ("slug", -10, -5.7), ("slug", -6, -2.3), ("slug", 9.5, -10.5), ("slug", 6.5, -5.5),
        ("slug", -9, 5.6), ("slug", 10, 9.6), ("worm", -2.5, 6), ("worm", 3, -6.5),
        ("worm", -12, -8), ("beetle", 2.5, 2.5), ("beetle", -13, 4), ("beetle", 12, 5),
        ("caterpillar", -7, -10.4), ("caterpillar", 9, -7.8), ("caterpillar", -7.5, 9.6), ("caterpillar", 7, 4.4),
    ])
    g.nest_materials([
        ("straw", -2, -12), ("straw", 6, 12), ("straw", -13.2, 7.5), ("leaves", -12, 10),
        ("leaves", 12.5, 0.5), ("leaves", 3, 9), ("leaves", -4, 2.5), ("moss", 12.8, -4.5),
        ("leaves", -9, -13), ("moss", 2, -13.2),
    ])
    g.hibernation_spots([
        ("HedgehogHouse", -12.0, 12.5, "hedgehog_house", True, "hedgehog_house", 1.0),
        ("UnderShed", 11.0, -12.0, "shed", True, "shed", 1.0),
        ("BonfirePile", 3.5, -12, "bonfire", False, "bonfire", 1.2),
    ])
    for i, (bx, bz) in enumerate(((-2.5, 1.0), (7.0, -1.2))):
        g.node(f"Ball{i}", None, ".", {"transform": transform((bx, 0, bz))}, instance=g.scene("ball"))
    g.patrol("DogPatrol", ((-11, 0), (-1, 0), (-1, -11), (1, -11), (1, 0), (11, 0), (11, 1.5), (1, 1.5), (1, 11), (-1, 11), (-1, 1.5), (-11, 1.5)))
    g.node("Dog", None, ".", {"transform": transform((-1, 0.1, 0)), "patrol_path": 'NodePath("../DogPatrol")'}, instance=g.scene("dog"))
    g.snow()
    g.ui(cat_path="../Dog")
    g.write({
        "level_index": "1", "level_title": q("Garden 2: The Allotments"),
        "intro_text": q("Biscuit the dog can SMELL you - even in a bush! Compost heaps and the hedgehog house hide your smell. Nudge a ball to keep Biscuit busy."),
        "level_duration": "330.0",
    })


# ===================================================================================
# Garden 3: The Night Garden (an owl, fireflies, a cat with glowing eyes)
# ===================================================================================

def garden_3():
    g = Level("garden_3")
    g.environment(night=True)
    g.group("Scenery")
    g.box("Ground", (34, 1, 34), (0, -0.5, 0), (0.3, 0.5, 0.28))
    g.fences(north_gap=(-15, -3))
    g.decor("HedgehogHighway", "BoxMesh", (0.08, 0.06, 0.05), (-13, 0.08, 14.91), size=v3(0.3, 0.16, 0.02))
    g.box("House", (13, 5, 5), (-8.5, 2.5, -15), (0.55, 0.45, 0.45))
    for i, x in enumerate((-12, -9, -6)):
        g.decor(f"Window{i}", "BoxMesh", (1.0, 0.85, 0.45), (x, 2.6, -12.48), unshaded=True, size=v3(1.0, 1.0, 0.04))
    g.decor("Pond", "CylinderMesh", (0.15, 0.25, 0.45), (2, 0.01, 1), top_radius="2.6", bottom_radius="2.6", height="0.02")
    for i in range(10):
        a = i * 0.63
        g.decor(f"Reed{i}", "CylinderMesh", (0.35, 0.5, 0.25), (2 + math.cos(a) * 2.8, 0.45, 1 + math.sin(a) * 2.8), top_radius="0.01", bottom_radius="0.03", height="0.9", radial_segments="6")
    g.raised_shed("Decking", 9.0, -10.0, walls=False)
    g.tree("Tree0", 12, 9, colors=((0.5, 0.35, 0.15), (0.45, 0.4, 0.15)))
    g.tree("Tree1", -12, 4, colors=((0.55, 0.3, 0.12), (0.45, 0.4, 0.15)))
    # The moon (unshaded, far away).
    g.decor("Moon", "SphereMesh", (0.95, 0.95, 0.85), (-30, 28, -45), parent=".", unshaded=True, radius="3.0", height="6.0")

    g.player(-13, 13)
    g.checkpoints(((-13, 13), (-5, -2), (7, 6)))
    # Two hedges (rows of bushes) make safe routes across the garden.
    hedge_a = [(f"HedgeA{i}", -6.5, -9 + i * 1.6, 1.0, "bush", False, True) for i in range(9)]
    hedge_b = [(f"HedgeB{i}", -2 + i * 1.6, 8.5, 1.0, "bush", False, True) for i in range(8)]
    g.hide_spots(hedge_a + hedge_b + [
        ("Bush0", 6, -3, 1.1, "bush", False, True),
        ("Bush1", 12.5, -3, 1.2, "bush", False, True),
        ("Bush2", -12, 9.5, 1.2, "bush", False, True),
        ("Bush3", 4, 12.5, 1.0, "bush", False, True),
        ("UnderDecking", 9.0, -10.0, 1.8, "bush", False, False),
    ])
    g.food([
        ("worm", -9, 11), ("worm", -3, 5), ("worm", 5, 5.5), ("worm", 10, 2), ("worm", -10, -6),
        ("beetle", -4.5, -6), ("beetle", 6.5, -6), ("beetle", 12, 12.5), ("beetle", -12.5, 0),
        ("slug", 0, -2.5), ("slug", 4.8, -0.6), ("slug", -1.5, 12),
        ("caterpillar", 12.6, 7.5), ("caterpillar", -11, 6),
    ])
    g.nest_materials([
        ("leaves", 11, 10.5), ("leaves", -11, 5.5), ("leaves", -4.5, -10), ("leaves", 3.5, 10.5),
        ("leaves", 9, -2), ("moss", -1, 3), ("moss", 4.5, -2.5), ("leaves", 13, -7),
        ("leaves", -9, -3), ("straw", 0, -12),
    ])
    g.hibernation_spots([
        ("UnderDecking", 9.0, -10.0, "shed", True, "shed", 1.0),
        ("LogPile", -12.3, -11.7, "log_pile", True, "shed", 1.1),
        ("BonfirePile", -1, -6, "bonfire", False, "bonfire", 1.2),
    ])
    g.patrol("CatPatrol", ((3, -8), (11, -6), (10, 5), (-1, 4.5), (-3, -4)))
    g.cat("Cat", 3, -8, "CatPatrol", glowing_eyes="true", fur_color="Color(0.25, 0.25, 0.28, 1)")
    g.node("Owl", None, ".", {"transform": transform((0, 0, 0))}, instance=g.scene("owl"))
    g.fireflies(((-6, -2), (4, 8), (9, -6), (-10, 6), (0, -9), (11, 11), (-3, 13)))
    g.snow()
    g.ui()
    g.write({
        "level_index": "2", "level_title": q("Garden 3: The Night Garden"), "night": "true",
        "intro_text": q("Hedgehogs love the night! But an owl is hunting. When you hear it hoot and see its red shadow, hide in a hedge or roll up!"),
        "level_duration": "360.0",
    })


if __name__ == "__main__":
    print("Building gardens into", os.path.normpath(OUT_DIR))
    garden_1()
    garden_2()
    garden_3()
