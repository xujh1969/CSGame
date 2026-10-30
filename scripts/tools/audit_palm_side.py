import bpy,numpy as np
from pathlib import Path
from mathutils import Matrix,Vector
r=Path(r'C:/Users/AYOU/Desktop/CS');bpy.ops.wm.open_mainfile(filepath=str(r/'assets/source/task009/v005/Gloves_Derived.blend'));a=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE');o=bpy.data.objects['Object_7'];h=a.data.bones['R_Hand'];f=lambda n:next(b for b in a.data.bones if b.name.startswith(n+'.R_'));y=(h.head_local-f('middle_L').head_local).normalized();x=-(f('index_L').head_local-f('pink_L').head_local).normalized();x=(x-y*x.dot(y)).normalized();z=x.cross(y);group=o.vertex_groups['R_Hand'].index
mat=o.data.materials[0];bsdf=next(n for n in mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED');tex=bsdf.inputs['Base Color'].links[0].from_node;image=tex.image;pixels=np.array(image.pixels[:]).reshape(image.size[1],image.size[0],4);rows={'+Z':[],'-Z':[]}
for p in o.data.polygons:
 amount=sum(sum(g.weight for g in o.data.vertices[v].groups if g.group==group) for v in p.vertices)/len(p.vertices)
 dot=p.normal.dot(z)
 if amount>.5 and abs(dot)>.65:
  uv=sum((o.data.uv_layers.active.data[i].uv for i in p.loop_indices),Vector((0,0)))/len(p.loop_indices);color=pixels[int(uv.y*image.size[1])%image.size[1],int(uv.x*image.size[0])%image.size[0],:3];rows['+Z' if dot>0 else '-Z'].append(float(color.mean()))
print('PALM_SIDE_TEXTURE',image.name,{k:(len(v),float(np.median(v)) if v else None) for k,v in rows.items()})
