import bpy,json
from pathlib import Path
r=Path(r'C:/Users/AYOU/Desktop/CS');bpy.ops.wm.open_mainfile(filepath=str(r/'assets/source/task009/v005/Gloves_Derived.blend'));a=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE');bpy.context.scene.frame_set(70);bpy.context.view_layer.update();o=bpy.data.objects['Object_7'];e=o.evaluated_get(bpy.context.evaluated_depsgraph_get());m=e.to_mesh();rows=[]
for edge in o.data.edges:
 i,j=edge.vertices;l=(o.data.vertices[i].co-o.data.vertices[j].co).length;now=(m.vertices[i].co-m.vertices[j].co).length
 if l>.0005 and now/l>4:
  rows.append({'ratio':now/l,'length':now,'vertices':[i,j],'weights':[[[o.vertex_groups[g.group].name,round(g.weight,3)] for g in o.data.vertices[k].groups if g.weight>.01] for k in [i,j]]})
rows=sorted(rows,key=lambda x:x['length'],reverse=True);(r/'logs/TASK-009-v005-stretched-edges.json').write_text(json.dumps(rows[:30],indent=2));print(json.dumps(rows[:7],indent=1));e.to_mesh_clear()
