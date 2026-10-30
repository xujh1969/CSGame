"""Measure candidate fingertips and actual foregrip geometry in gun-local metres."""
import bpy,json
from pathlib import Path
from mathutils import Matrix
r=Path(__file__).resolve().parents[2];C=Matrix(((1,0,0),(0,0,1),(0,-1,0)))
bpy.ops.wm.open_mainfile(filepath=str(r/'assets/source/task009/v009/Arms_Palmar_Candidate.blend'))
rig=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE');fingers={}
for family in ('index_L','middle_L','ring_L','pink_L','thumb_L'):
 bone=next(b for b in rig.data.bones if b.name.startswith(family+'.L_'));chain=[]
 while bone:
  chain.append(list(C@(rig.matrix_world@bone.head_local)))
  bone=next((b for b in bone.children if b.name.startswith(family)),None)
 fingers[family]=chain
before=set(bpy.data.objects)
bpy.ops.import_scene.gltf(filepath=str(r/'assets/models/task009/v003/ar15_revision.glb'))
rows=[]
for obj in set(bpy.data.objects)-before:
 if obj.type!='MESH':continue
 points=[C@(obj.matrix_world@v.co) for v in obj.data.vertices];slice_points=[p for p in points if abs(p.z+.23)<.015]
 rows.append({'mesh':obj.name,'bounds':[[min(p[i] for p in points),max(p[i] for p in points)] for i in range(3)],'foregrip_section':[[min(p[i] for p in slice_points),max(p[i] for p in slice_points)] for i in range(3)] if slice_points else None})
report={'fingers':fingers,'gun':rows};(r/'logs/TASK-009-foregrip-audit.json').write_text(json.dumps(report,indent=2),encoding='utf-8');print('FOREGRIP_AUDIT',json.dumps(report))
