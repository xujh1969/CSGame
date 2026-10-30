import bpy,json,math
from pathlib import Path
r=Path(r'C:/Users/AYOU/Desktop/CS');result=[]
for version in ['v004','v005']:
 bpy.ops.wm.open_mainfile(filepath=str(r/f'assets/source/task009/{version}/Gloves_Derived.blend'))
 rig=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE')
 for frame in [1,46,91,133]:
  bpy.context.scene.frame_set(frame);bpy.context.view_layer.update();d=bpy.context.evaluated_depsgraph_get();meshes=[]
  for o in bpy.context.scene.objects:
   if o.type=='MESH':
    e=o.evaluated_get(d);m=e.to_mesh();p=[e.matrix_world@v.co for v in m.vertices];meshes.append({'name':o.name,'bounds':[[min(v[i] for v in p) for i in range(3)],[max(v[i] for v in p) for i in range(3)]]});e.to_mesh_clear()
  scales=[(b.name,list(b.scale),list(b.matrix_basis.to_scale())) for b in rig.pose.bones if max(abs(v-1) for v in b.scale)>.001]
  row={'version':version,'frame':frame,'scaled_bones':scales,'meshes':meshes};result.append(row)
(r/'logs/TASK-009-v005-pose-audit.json').write_text(json.dumps(result,indent=2));print(json.dumps(result,indent=1))
