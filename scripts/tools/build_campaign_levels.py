"""Two fixed small combat levels for TASK-007 lifecycle validation, not final art."""
from build_vertical_slice import Scene, vec


def bake(name, encounter, enemy, side, finish_z):
    s = Scene(name)
    environment = s.resource("Environment", "background_mode = 1\nbackground_color = Color(0.43, 0.51, 0.59, 1)\nambient_light_source = 2\nambient_light_energy = 0.65")
    s.node("WorldEnvironment", "WorldEnvironment", properties="environment = " + environment)
    s.node("Sun", "DirectionalLight3D", properties="rotation_degrees = Vector3(-50, -25, 0)\nshadow_enabled = true")
    s.node("WorldGeo", "Node3D")
    s.box("Ground", (0, -.15, -11), (16, .3, 34), "road", "WorldGeo")
    for edge in (-1, 1):
        s.box("Boundary%d" % edge, (edge * 6, 1.5, -11), (.5, 3, 34), "ruin", "WorldGeo")
    for z in (6, -28):
        s.box("End%d" % z, (0, 1.5, z), (12, 3, .4), "concrete", "WorldGeo")
    # Existing independent facade modules remain collision-authoritative.
    facade = s.ext("scenes/levels/modules/%s.tscn" % ("Residential" if side > 0 else "Shopfront"))
    for z in (-2, -10, -18):
        s.node("Facade%d" % -z, instance=facade, properties="position = Vector3(6, 0, %s)\nrotation = Vector3(0, -1.570796, 0)" % z)
    s.node("Cover", "Node3D")
    s.box("EnemyWall", (side * 2.6, .55, -14.5), (2.6, 1.1, .5), "concrete", "Cover", layer=2)
    cover = s.ext("scenes/cover/%s.tscn" % ("JerseyBarrier" if side > 0 else "WoodenCrates"))
    s.node("PlayerCover", instance=cover, parent="Cover", properties="position = %s" % vec((-side * 2.0, 0, -9)))
    s.node("SpawnMarkers", "Node3D")
    spawn = (side * 2.6, 0, -16)
    s.node(enemy, "Marker3D", "SpawnMarkers", 'position = %s\nmetadata/encounter_id = "%s"' % (vec(spawn), encounter))
    s.node("CoverMarkers", "Node3D")
    s.node("C1", "Marker3D", "CoverMarkers", "position = " + vec(spawn))
    s.node("PeekMarkers", "Node3D")
    s.node("P1", "Marker3D", "PeekMarkers", "position = " + vec(spawn))
    s.node("Enemies", "Node3D")
    enemy_scene = s.ext("scenes/enemies/EnemyBase.tscn")
    s.node(enemy, instance=enemy_scene, parent="Enemies", properties='position = %s\nrotation_degrees = Vector3(0, 180, 0)\narchetype = "cover_rifleman"\ncover_path = NodePath("../../CoverMarkers/C1")\npeek_path = NodePath("../../PeekMarkers/P1")' % vec(spawn))
    s.node("Triggers", "Node3D")
    trigger_shape = s.resource("BoxShape3D", "size = Vector3(11, 3, 1)")
    s.node(encounter, "Area3D", "Triggers", 'position = Vector3(0, 1.5, -5)\ncollision_layer = 32\ncollision_mask = 4\nmetadata/enemy_id = "%s"' % enemy)
    s.node("CollisionShape3D", "CollisionShape3D", "Triggers/" + encounter, "shape = " + trigger_shape)
    s.box("TriggerLine", (0, .01, -5), (10, .015, .12), "trigger", collision=False)
    s.node("Route", "Node3D")
    for index, point in enumerate(((0, 0, 3), (0, 0, -7), (0, 0, -12), (0, 0, finish_z))):
        s.node("P%d" % index, "Marker3D", "Route", "position = " + vec(point))
    player = s.ext("scenes/player/player.tscn")
    s.node("Player", instance=player, properties="position = Vector3(0, 0, 3)")
    manager = s.ext("scripts/game/encounter_manager.gd", "Script")
    s.node("EncounterManager", "Node", properties="script = " + manager)
    s.node("FinishArea", "Area3D", properties="position = Vector3(0, 1.5, %s)\ncollision_layer = 32\ncollision_mask = 4" % finish_z)
    s.node("CollisionShape3D", "CollisionShape3D", "FinishArea", "shape = " + trigger_shape)
    s.box("FinishLine", (0, .015, finish_z), (10, .02, .4), "finish", collision=False)
    s.label("FinishSign", "FINISH / " + name.upper(), (0, 3.5, finish_z), size=42)
    s.label("GreyboxSign", "TASK-007 / " + name.upper() + " / GRAYBOX", (0, 4, -4), size=34)
    flow = s.ext("scripts/game/game_flow.gd", "Script")
    s.node("GameFlow", "Node", properties='process_mode = 3\nscript = %s\nrequired_encounters = Array[StringName]([&"%s"])' % (flow, encounter))
    presentation = s.ext("scripts/fx/battle_presentation.gd", "Script")
    s.node("BattlePresentation", "Node3D", properties="script = " + presentation)
    s.save("scenes/levels/campaign/%s.tscn" % name)


if __name__ == "__main__":
    bake("Entry", "A1", "AGuard", 1, -21)
    bake("Yard", "B1", "BGuard", -1, -24)
    print("Baked two fixed graybox campaign levels; no production art or random gameplay.")
