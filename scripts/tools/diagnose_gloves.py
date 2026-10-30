import bpy,json
from pathlib import Path
from mathutils import Vector
r=Path(r'C:/Users/AYOU/Desktop/CS');bpy.ops.wm.open_mainfile(filepath=str(r/'assets/source/task009/v004/Gloves_Inspection.blend'));d=bpy.context.evaluated_depsgraph_get()
for o in bpy.context.scene.objects:
 if o.name in ('Object_7','Object_9'):
  e=o.evaluated_get(d);p=[e.matrix_world@v.co for v in e.to_mesh().vertices]; print('EVAL',o.name,[[min(v[i] for v in p) for i in range(3)],[max(v[i] for v in p) for i in range(3)]], 'meshmat',list(o.matrix_world),'modifier',[(m.type,m.object.name if m.type=='ARMATURE' else '') for m in o.modifiers]);e.to_mesh_clear()
for a in bpy.context.scene.objects:
 if a.type=='ARMATURE':
  for b in a.pose.bones:
   if any(k in b.name for k in ['upperarm','lowerarm','hand_L']): print('BONE',b.name,'POSE',list(a.matrix_world@b.matrix.translation),'REST',list(a.matrix_world@b.bone.head_local),'basis',list(b.matrix_basis))
