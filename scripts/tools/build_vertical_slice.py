"""Bake fixed gameplay modules; LevelRuntime owns seeded visual decoration only."""
import hashlib
import json
import math
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DATA_PATH = ROOT / "data/vertical_slice.json"
DATA = json.loads(DATA_PATH.read_text(encoding="utf-8-sig"))


def validate_bake_data(data):
    """Reject unsupported core edits before writing any scene. This is one 80m slice."""
    def position(value):
        return (isinstance(value, list) and len(value) == 3
                and all(type(n) in (int, float) and math.isfinite(n) for n in value))

    assert data["schema_version"] == "1.0" and data["units"] == "meters"
    assert data["axis_convention"] == {"up": "+Y", "forward": "-Z"}
    assert type(data["seed"]) is int and 0 <= data["seed"] <= 2147483647
    assert data["bounds"] == {"z_start": 4, "z_end": -80, "road_width": 8.0, "sidewalk_width_each": 2.0}, "Road dimensions require authoring + navigation review"
    assert position(data["player_spawn"]["position"])
    assert {c["id"] for c in data["covers"]} == {"cover_01", "cover_02", "cover_03"}
    assert len(data["covers"]) == 3
    for cover in data["covers"]:
        assert cover["kind"] in ("low_concrete_wall", "jersey_barrier", "wooden_crates")
        assert position(cover["position"])
    encounters = data["encounters"]
    assert [e["id"] for e in encounters] == ["T1", "T2", "T3"]
    assert [e["enemy_id"] for e in encounters] == ["E01", "E02", "E03"]
    assert [e["style"] for e in encounters] == ["corner_ambusher", "window_sentry", "cover_rifleman"]
    for encounter in encounters:
        assert re.fullmatch(r"[A-Za-z][A-Za-z0-9_]*", encounter["cover_marker_id"])
        assert position(encounter["spawn_position"]) and position(encounter["peek_position"])
        assert -80 <= encounter["activate_at_z"] <= 4
        assert math.isfinite(encounter["facing_yaw_degrees"])
    assert data["objective"]["required_enemies"] == ["E01", "E02", "E03"]
    assert -80 <= data["objective"]["finish_z"] <= 4

PALETTE = {
    "concrete": (0.46, 0.47, 0.44), "residential": (0.55, 0.52, 0.46),
    "shop": (0.43, 0.50, 0.49), "ruin": (0.44, 0.40, 0.36),
    "dark": (0.10, 0.15, 0.18), "metal": (0.26, 0.31, 0.33),
    "wood": (0.44, 0.29, 0.16), "stripe": (0.95, 0.59, 0.12),
    "road": (0.19, 0.21, 0.22), "sidewalk": (0.48, 0.49, 0.46),
    "line": (0.68, 0.66, 0.54), "trigger": (0.15, 0.65, 0.70),
    "finish": (0.26, 0.78, 0.48),
}


def vec(value):
    return "Vector3(%s)" % ", ".join(str(round(v, 6)) for v in value)


class Scene:
    def __init__(self, name):
        self.resources, self.external, self.nodes, self.materials = [], [], [], {}
        self.node(name, "Node3D", None)

    def resource(self, kind, properties):
        key = "R%d" % (len(self.resources) + 1)
        self.resources.append('[sub_resource type="%s" id="%s"]\n%s' % (kind, key, properties))
        return 'SubResource("%s")' % key

    def ext(self, path, kind="PackedScene"):
        key = str(len(self.external) + 1)
        self.external.append('[ext_resource type="%s" path="res://%s" id="%s"]' % (kind, path, key))
        return 'ExtResource("%s")' % key

    def node(self, name, kind=None, parent=".", properties="", instance=None):
        name = name.replace(".", "_")
        if parent not in (None, "."):
            parent = parent.replace(".", "_")
        tag = '[node name="%s"' % name
        if kind:
            tag += ' type="%s"' % kind
        if parent is not None:
            tag += ' parent="%s"' % parent
        if instance:
            tag += " instance=" + instance
        self.nodes.append(tag + "]\n" + properties)

    def material(self, name):
        if name not in self.materials:
            color = PALETTE[name]
            props = "albedo_color = Color(%s, 1)\nroughness = 0.9" % ", ".join(map(str, color))
            if name in ("trigger", "finish", "stripe"):
                props += "\nshading_mode = 0"
            self.materials[name] = self.resource("StandardMaterial3D", props)
        return self.materials[name]

    def box(self, name, position, size, material="concrete", parent=".", collision=True, layer=1):
        mat = self.material(material)
        mesh = self.resource("BoxMesh", "size = %s\nmaterial = %s" % (vec(size), mat))
        if collision:
            shape = self.resource("BoxShape3D", "size = " + vec(size))
            surface = "metal" if material == "metal" else ("wood" if material == "wood" else "concrete")
            self.node(name, "StaticBody3D", parent, 'position = %s\ncollision_layer = %d\nmetadata/surface_type = "%s"' % (vec(position), layer, surface))
            path = name if parent == "." else parent + "/" + name
            self.node("Mesh", "MeshInstance3D", path, "mesh = " + mesh)
            self.node("CollisionShape3D", "CollisionShape3D", path, "shape = " + shape)
        else:
            self.node(name, "MeshInstance3D", parent, "position = %s\nmesh = %s" % (vec(position), mesh))

    def label(self, name, text, position, parent=".", size=40):
        self.node(name, "Label3D", parent, 'position = %s\ntext = %s\nbillboard = 1\nfont_size = %d\npixel_size = 0.008' % (vec(position), json.dumps(text), size))

    def save(self, path):
        target = ROOT / path
        target.parent.mkdir(parents=True, exist_ok=True)
        header = '[gd_scene load_steps=%d format=3]' % (1 + len(self.resources) + len(self.external))
        target.write_text("\n\n".join([header] + self.external + self.resources + self.nodes) + "\n", encoding="utf-8")


def bake_covers():
    s = Scene("ConcreteLowWall")
    s.box("Slab", (0, .55, 0), (2, 1.1, .45), layer=2)
    visual_slot(s, "cover_wall_A")
    s.save("scenes/cover/ConcreteLowWall.tscn")
    s = Scene("JerseyBarrier")
    s.box("Base", (0, .125, 0), (2.5, .25, .9), layer=2)
    s.box("Upper", (0, .625, 0), (2.5, .75, .45), layer=2)
    s.box("SafetyStripe", (0, .7, .228), (2.3, .14, .015), "stripe", collision=False)
    visual_slot(s, "cover_barrier_A")
    s.save("scenes/cover/JerseyBarrier.tscn")
    s = Scene("WoodenCrates")
    s.box("TallCrate", (-.45, .6, 0), (.9, 1.2, .8), "wood", layer=2)
    s.box("ShortCrate", (.45, .4, 0), (.9, .8, .8), "wood", layer=2)
    for x, height in ((-.45, 1.2), (.45, .8)):
        for side in (-1, 1):
            s.box("Band_%s_%s" % (x, side), (x + side * .34, height / 2, .405), (.08, height, .015), "metal", collision=False)
    visual_slot(s, "cover_box_A")
    s.save("scenes/cover/WoodenCrates.tscn")


def visual_slot(scene, asset_id):
    script = scene.ext("scripts/game/asset_visual_slot.gd", "Script")
    scene.node("VisualSlot", "Node3D", properties='script = %s\nasset_id = "%s"' % (script, asset_id))


def bake_decorations():
    for name, asset_id in (("FacadeAC", "facade_ac_A"), ("FacadeVent", "facade_vent_A")):
        s = Scene(name)
        s.box("Housing", (0, 0, 0), (.9, .55, .35), "metal", collision=False)
        if name == "FacadeAC":
            s.box("Grille", (0, 0, .19), (.65, .35, .035), "dark", collision=False)
        else:
            for y in (-.18, 0, .18):
                s.box("Louver%s" % y, (0, y, .2), (.8, .05, .08), "concrete", collision=False)
        visual_slot(s, asset_id)
        s.save("scenes/levels/modules/%s.tscn" % name)


def bake_facades():
    for style in ("Residential", "Shopfront", "Ruin"):
        s = Scene(style)
        palette = {"Residential": "residential", "Shopfront": "shop", "Ruin": "ruin"}[style]
        height = 8.5 if style == "Residential" else 7.5
        if style == "Ruin":
            s.box("LowerWall", (0, 1.4, -.25), (8, 2.8, .5), palette)
            for i, (x, h) in enumerate(((-3, 7.5), (-1, 5.4), (1, 6.5), (3, 4.3))):
                s.box("BrokenPier%d" % i, (x, (h + 2.8) / 2, -.25), (1.8, h - 2.8, .5), palette)
            s.box("InsetBackWall", (0, 3.4, -2), (8, 6.8, .3), "dark")
        else:
            s.box("Wall", (0, height / 2, -.3), (8, height, .6), palette)
            for x in (-2.5, 0, 2.5):
                for y in (4.5, 7.0) if style == "Residential" else (5.1,):
                    s.box("Window_%s_%s" % (x, y), (x, y, .025), (1.1, 1.5, .05), "dark", collision=False)
            if style == "Residential":
                for x in (-2.5, 2.5):
                    s.box("Balcony_%s" % x, (x, 3.7, .55), (1.7, .18, 1.1), "concrete")
                    s.box("Parapet_%s" % x, (x, 4.1, 1.0), (1.7, .65, .14), "metal")
            else:
                for x in (-2, 2):
                    s.box("Shutter_%s" % x, (x, 1.4, .04), (2.8, 2.6, .08), "metal", collision=False)
                s.box("Awning", (0, 3.0, .7), (7.8, .18, 1.4), "stripe")
        s.box("RoofCap", (0, height + .08, -.3), (8.1, .16, .8), "concrete")
        visual_slot(s, {"Residential": "facade_residential_A", "Shopfront": "facade_shopfront_A", "Ruin": "facade_ruin_A"}[style])
        s.save("scenes/levels/modules/%s.tscn" % style)

    s = Scene("HighWindowFacade")
    s.box("LowerWall", (0, 2.1, .9), (8, 4.2, .4), "shop")
    for x in (-2.6, 2.6):
        s.box("WindowSide_%s" % x, (x, 5.25, .9), (2.8, 2.1, .4), "shop")
    s.box("Lintel", (0, 6.9, .9), (8, 1.2, .4), "shop")
    s.box("WindowFloor", (0, 4.1, .0), (3, .2, 2.2), "concrete")
    s.box("RearWall", (0, 3.7, -2), (8, 7.4, .4), "dark")
    s.box("SillHighlight", (0, 4.23, 1.11), (2.4, .06, .08), "stripe", collision=False)
    s.label("WindowSign", "02 / HIGH WINDOW", (0, 7.8, 1.0))
    visual_slot(s, "facade_high_window_A")
    s.save("scenes/levels/modules/HighWindowFacade.tscn")


def bake_road():
    s = Scene("RoadStrip")
    s.box("Ground", (0, -.15, -38), (20, .3, 92), "road")
    for side in (-1, 1):
        s.box("Sidewalk%d" % side, (side * 5, .04, -38), (2, .08, 92), "sidewalk")
        s.box("Boundary%d" % side, (side * 9.7, 2, -38), (.6, 4, 92), "ruin")
    for z in (8, -84):
        s.box("EndBoundary%d" % z, (0, 2, z), (20, 4, .6), "ruin")
    for z in range(0, -81, -4):
        s.box("RoadDash%d" % -z, (0, .006, z), (.10, .012, 1.5), "line", collision=False)
    s.save("scenes/levels/modules/RoadStrip.tscn")


def bake_level():
    s = Scene("VerticalSlice01")
    s.nodes[0] += '\nmetadata/layout_source = "res://data/vertical_slice.json"\nmetadata/layout_sha256 = "%s"\nmetadata/seed = %d' % (hashlib.sha256(DATA_PATH.read_bytes()).hexdigest(), DATA["seed"])
    environment = s.resource("Environment", "background_mode = 1\nbackground_color = Color(0.43, 0.51, 0.59, 1)\nambient_light_source = 2\nambient_light_color = Color(0.75, 0.8, 0.9, 1)\nambient_light_energy = 0.65")
    s.node("WorldEnvironment", "WorldEnvironment", properties="environment = " + environment)
    s.node("Sun", "DirectionalLight3D", properties="rotation_degrees = Vector3(-50, -25, 0)\nlight_energy = 1.2\nshadow_enabled = true")
    road = s.ext("scenes/levels/modules/RoadStrip.tscn")
    s.node("WorldGeo", instance=road)
    s.node("Facades", "Node3D")
    facade_types = {name: s.ext("scenes/levels/modules/%s.tscn" % name) for name in ("Residential", "Shopfront", "Ruin", "HighWindowFacade")}
    for side in (-1, 1):
        for name, centers in (("Residential", (-4, -12, -20)), ("Shopfront", (-32, -40, -48)), ("Ruin", (-60, -68, -76))):
            for z in centers:
                if side == -1 and z == -48:
                    continue
                s.node("%s_%d_%d" % (name, side, -z), parent="Facades", instance=facade_types[name], properties="position = %s\nrotation = %s" % (vec((side * 6, 0, z)), vec((0, -side * math.pi / 2, 0))))
    s.node("HighWindow", parent="Facades", instance=facade_types["HighWindowFacade"], properties="position = Vector3(-6, 0, -46)\nrotation = Vector3(0, 1.570796, 0)")
    s.box("CornerWing", (4.5, 1.3, -24), (2, 2.6, .4), "shop", "WorldGeo")
    for side in (-1, 1):
        s.box("NarrowPier%d" % side, (side * 4.15, 1.5, -70), (2.1, 3, 20), "ruin", "WorldGeo")
    s.node("Cover", "Node3D")
    paths = {"low_concrete_wall": "ConcreteLowWall", "jersey_barrier": "JerseyBarrier", "wooden_crates": "WoodenCrates"}
    for cover in DATA["covers"]:
        resource = s.ext("scenes/cover/%s.tscn" % paths[cover["kind"]])
        s.node(cover["id"], parent="Cover", instance=resource, properties='position = %s\nmetadata/kind = "%s"' % (vec(cover["position"]), cover["kind"]))
        s.label(cover["id"] + "Sign", cover["kind"].upper().replace("_", " "), (cover["position"][0], 1.9, cover["position"][2]), "Cover", 26)
    s.box("EnemyLowWall", (2.6, .55, -68.5), (2.6, 1.1, .5), "concrete", "Cover", layer=2)
    s.node("SpawnMarkers", "Node3D")
    s.node("CoverMarkers", "Node3D")
    s.node("PeekMarkers", "Node3D")
    s.node("Enemies", "Node3D")
    s.node("Triggers", "Node3D")
    enemy_scene = s.ext("scenes/enemies/EnemyBase.tscn")
    colors = ("Color(0.85, 0.30, 0.15, 1)", "Color(0.12, 0.55, 0.9, 1)", "Color(0.8, 0.18, 0.25, 1)")
    for index, encounter in enumerate(DATA["encounters"]):
        enemy, trigger = encounter["enemy_id"], encounter["id"]
        cover = encounter["cover_marker_id"]
        s.node(enemy, "Marker3D", "SpawnMarkers", 'position = %s\nrotation_degrees = Vector3(0, %s, 0)\nmetadata/encounter_id = "%s"\nmetadata/trigger_id = "%s"\nmetadata/archetype = "%s"\nmetadata/cover_marker_id = "%s"' % (vec(encounter["spawn_position"]), encounter["facing_yaw_degrees"], trigger, trigger, encounter["style"], cover))
        s.node(cover, "Marker3D", "CoverMarkers", "position = " + vec(encounter["spawn_position"]))
        s.node(enemy, "Marker3D", "PeekMarkers", "position = " + vec(encounter["peek_position"]))
        props = 'position = %s\nrotation_degrees = Vector3(0, %s, 0)\narchetype = "%s"\ncover_path = NodePath("../../CoverMarkers/%s")\npeek_path = NodePath("../../PeekMarkers/%s")\ntint = %s\nview_distance = %s' % (vec(encounter["spawn_position"]), encounter["facing_yaw_degrees"], encounter["style"], cover, enemy, colors[index], 35.0 if index == 1 else 25.0)
        s.node(enemy, parent="Enemies", instance=enemy_scene, properties=props)
        if index == 0:
            s.node("NavigationAgent3D", "NavigationAgent3D", "Enemies/" + enemy, "path_desired_distance = 0.2\ntarget_desired_distance = 0.15\nradius = 0.28\nheight = 1.8")
        shape = s.resource("BoxShape3D", "size = Vector3(12, 3, 1)")
        s.node(trigger, "Area3D", "Triggers", 'position = Vector3(0, 1.5, %s)\ncollision_layer = 32\ncollision_mask = 4\nmetadata/enemy_id = "%s"\nmetadata/activate_at_z = %s' % (encounter["activate_at_z"], enemy, encounter["activate_at_z"]))
        s.node("CollisionShape3D", "CollisionShape3D", "Triggers/" + trigger, "shape = " + shape)
        s.box(trigger + "Line", (0, .012, encounter["activate_at_z"]), (8, .015, .12), "trigger", "Triggers", collision=False)
        s.label(trigger + "Sign", trigger + " / " + encounter["style"].upper().replace("_", " "), (-3.5, 2.4, encounter["activate_at_z"]), "Triggers", 30)
    for text, z in (("01 / RESIDENTIAL + CORNER", -5), ("02 / SHOPS + HIGH WINDOW", -31), ("03 / NARROW + COVER", -57)):
        s.label("Section%d" % -z, text, (0, 4.0, z))
    s.node("Route", "Node3D")
    points = [(0, 0, 4), (1, 0, -18), (1, 0, -24), (-1, 0, -40), (-1, 0, -46), (.4, 0, -60), (.4, 0, -65), (0, 0, -73), (0, 0, -78)]
    for index, point in enumerate(points):
        s.node("P%02d" % index, "Marker3D", "Route", "position = %s\nmetadata/clearance_m = 1.2" % vec(point))
    s.node("PlayerSpawn", "Marker3D", properties="position = " + vec(DATA["player_spawn"]["position"]))
    player = s.ext("scenes/player/player.tscn")
    s.node("Player", parent=".", instance=player, properties="position = " + vec(DATA["player_spawn"]["position"]))
    navigation = s.ext("scenes/levels/CornerNavigation.tres", "NavigationMesh")
    s.node("CornerNavigation", "NavigationRegion3D", properties="navigation_mesh = " + navigation)
    manager = s.ext("scripts/game/encounter_manager.gd", "Script")
    s.node("EncounterManager", "Node", properties="script = " + manager)
    finish_z = DATA["objective"]["finish_z"]
    s.node("FinishMarker", "Marker3D", properties="position = Vector3(0, 0, %s)" % finish_z)
    finish_shape = s.resource("BoxShape3D", "size = Vector3(12, 3, 1)")
    s.node("FinishArea", "Area3D", properties="position = Vector3(0, 1.5, %s)\ncollision_layer = 32\ncollision_mask = 4" % finish_z)
    s.node("CollisionShape3D", "CollisionShape3D", "FinishArea", "shape = " + finish_shape)
    s.box("FinishLine", (0, .015, finish_z), (8, .02, .4), "finish", collision=False)
    s.label("FinishSign", "FINISH / ROUTE END", (0, 3.5, finish_z), size=55)
    flow = s.ext("scripts/game/game_flow.gd", "Script")
    s.node("GameFlow", "Node", properties="process_mode = 3\nscript = " + flow)
    presentation = s.ext("scripts/fx/battle_presentation.gd", "Script")
    s.node("BattlePresentation", "Node3D", properties="script = " + presentation)
    runtime = s.ext("scripts/game/level_runtime.gd", "Script")
    s.node("LevelRuntime", "Node3D", properties="script = " + runtime)
    debug = s.ext("scripts/game/level_debug.gd", "Script")
    s.node("LevelDebug", "Node3D", properties="process_mode = 3\nscript = " + debug)
    s.save("scenes/levels/VerticalSlice01.tscn")


if __name__ == "__main__":
    validate_bake_data(DATA)
    bake_covers()
    bake_facades()
    bake_road()
    bake_decorations()
    bake_level()
    print("Baked 11 editable scenes from data/vertical_slice.json; seed=%d" % DATA["seed"])
