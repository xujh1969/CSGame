import bpy,json
from pathlib import Path
from mathutils import Vector
r=Path(r'C:/Users/AYOU/Desktop/CS')
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(r/'assets/models/hand_with_gloves.glb'))
a=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE')
d={'rig_matrix':[list(v) for v in a.matrix_world],'bones':{b.name:{'head':list(a.matrix_world@b.head_local),'tail':list(a.matrix_world@b.tail_local),'parent':b.parent.name if b.parent else None} for b in a.data.bones},'meshes':[]}
for o in bpy.context.scene.objects:
 if o.type=='MESH':
  points=[o.matrix_world@v.co for v in o.data.vertices]
  d['meshes'].append({'name':o.name,'vertices':len(points),'bounds':[[min(p[i] for p in points) for i in range(3)],[max(p[i] for p in points) for i in range(3)]],'materials':[m.name if m else None for m in o.data.materials]})
(r/'logs/TASK-009-gloves-inspection.json').write_text(json.dumps(d,indent=2))
p=r/'assets/source/task009/v004';p.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=str(p/'Gloves_Inspection.blend'))
print('GLOVES_INSPECTED',json.dumps(d['meshes']))
