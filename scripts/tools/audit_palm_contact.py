import bpy,numpy as np
from pathlib import Path
r=Path(r'C:/Users/AYOU/Desktop/CS');bpy.ops.wm.open_mainfile(filepath=str(r/'assets/source/task009/v005/Gloves_Derived.blend'));bpy.context.scene.frame_set(70);bpy.context.view_layer.update();o=bpy.data.objects['Object_7'];g=o.vertex_groups['R_Hand'].index;e=o.evaluated_get(bpy.context.evaluated_depsgraph_get());m=e.to_mesh();rows=[]
for p in m.polygons:
 w=sum(sum(gp.weight for gp in o.data.vertices[v].groups if gp.group==g) for v in p.vertices)/len(p.vertices)
 if w>.5 and p.normal.x<-.5:
  c=p.center;rows.append((c.x,c.z,-c.y))
p=np.array(rows);print('RIGHT_PALM_SKIN',len(p),'median',np.median(p,axis=0),'bounds',p.min(axis=0),p.max(axis=0));e.to_mesh_clear()
