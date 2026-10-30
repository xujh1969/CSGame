# TASK-009 source and limitations

## Current v002 / actual user AR-15

- User confirms Hunyuan3D for AR-15, AK-47 and clutter HP/LP. Six original GLB hashes are checked by scripts/tools/audit_glb_delivery.py; no originals changed. HP assets use keep import sidecars to avoid runtime import cost. AK/clutter are receipt-only for later tasks.
- AR LP originally6369 triangles, no UV/material; HP1500000 triangles with PBR. AR15_SourceInspection_v001.blend preserves inspected copies. prepare_user_rifle.py uniformly scales copies to0.93m, aligns barrel -Z and lens to existing ADS mount, unwraps LP and selected-to-active bakes four2048px maps.
- Derived user_ar15_v002.glb: Rifle_Body6528 + Magazine328 + Optic_Glass188 =7044triangles. Boolean split below magwell, explicit dark interface caps; opaque optic bored through and separate circular glass inserted. Original bake retained, raw SHA unchanged. AR15_Prepared_v002.blend preserves current editable derived copies and packed textures. v001 is a retained pre-interface-fix checkpoint.
- Receiver and magazine interface materials are explicit (initial Boolean inserted empty material slots that glTF omitted; repair_user_rifle_interfaces.py fixes the copied material indices). No white default-material patch remains in reviewed render.
- Procedural rifle_v002.glb (16828triangles) with2K anodized/1K polymer maps remains fallback. Skyline_v002 has13536triangles including dome/tower silhouette; source CinematicKit_v002.blend. v001 files remain intact and old screenshots are under logs/TASK-009-v001/.
- First-person weapon shadow casting is disabled to remove the orphan gun shadow. No full-body actor shadow or skeletal arms are implemented. That requires a separate synchronized world body/weapon pose; asset contract PLAYER_ARMS_AND_SHADOW.md, existing unarmed character may be reused after inspection/rigging.

## v001 historical source notes

- Blender 5.2.3 LTS was verified locally. scripts/tools/build_cinematic_assets.py runs an isolated --background --factory-startup process; no interactive Blender/MCP user scene or supplied model is edited.
- Original project-authored M4/AR-15-style visual sample, following the user's direction: black receiver/polymer, rail handguard, compact reflex sight, separate magazine and glass. No downloaded manufacturer mesh/logo or borrowed commercial game asset. Not a measured manufacturer replica or scan-quality final model.
- CinematicKit_v001.blend retains editable individual authored components and UVs. Runtime rifle_v001.glb joins static components, retains Magazine (including ribs/floorplate) and Optic_Glass separately, with applied bevel/weighted normals. Actual triangle/object counts in logs/TASK-009-asset-audit.json. Handguard vents are actual boolean openings; no runtime boolean processing.
- 512px color/roughness/micro-normal maps use fixed seed 20261029 mathematical grain. Other polymer/steel/rubber use PBR parameters. These are original procedural finishes, not photographic scans or a high-poly texture bake.
- Optic glass uses assets/materials/optic_glass.gdshader: faint coating, view-angle-dependent alpha, specular/clearcoat, real scene depth testing. It does not implement physical optical refraction, magnification or a separate scope-render viewport. A red emissive-looking unshaded dot provides the existing ADS indication; damage is still camera/muzzle real collision.
- Skyline is 27 fixed buildings in three distance layers, window/parapet/roof-tank/stairwell details. Export is one merged mesh with material surfaces to bound rendering submissions. It is beyond the existing solid playable end boundary; no fake traversable city.
- The user additionally specified classic AK-47 with wood stock/handguard and worn steel. Its modeling reference and handoff contract are recorded in docs/asset_requests/TASK-009_WEAPONS.md for the next enemy task. No AK asset is fabricated or registered ready here.
- User-supplied enemy high/low files were discovered in assets/models during Godot's import scan. Their source files were preserved; this TASK does not inspect/rig/integrate them or claim their animation readiness.
- Actual screenshots are produced by Godot, not generated reference art: logs/TASK-009-rifle-right/left.png and TASK-009-[1080-]hip/ads/reload/wall/low.png. Near-camera rifle/sight appearance needs user acceptance. No skeletal hands are provided in this task.

## Downloaded glove arms, v004 (2026-10-30)
Original: assets/models/hand_with_gloves.glb, unchanged. Embedded glTF attribution:
Hand With Gloves, JUST (https://sketchfab.com/teenjust500), CC BY 4.0.
Source: https://sketchfab.com/3d-models/hand-with-gloves-5a6a434b8ec943ffacc581358781eecb
License: https://creativecommons.org/licenses/by/4.0/
The source page returned HTTP 403; attribution is from the delivered GLB metadata, pending download-page confirmation.
Changes: excluded display props/crosshair/camera; normalized meters; retained glove/sleeve textures and skin weights; renamed six semantic arm joints; authored Hold/Reload and native finger poses. 19,734 runtime triangles, 61 exported bones. Original not overwritten. Derived: assets/source/task009/v004/Gloves_Derived.blend and assets/models/task009/v004/gloves_rigged.glb. Local evaluation integration pending visual acceptance.
