import bpy,json
from pathlib import Path
from mathutils import Vector
r=Path(r'C:/Users/AYOU/Desktop/CS');bpy.ops.wm.open_mainfile(filepath=str(r/'assets/source/task009/v004/Gloves_Inspection.blend'))
a=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE')
for o in list(bpy.context.scene.objects):
 if o.type!='ARMATURE' and o.name not in ('Object_7','Object_9'): bpy.data.objects.remove(o,do_unlink=True)
points=[o.matrix_world@v.co for o in bpy.context.scene.objects if o.type=='MESH' for v in o.evaluated_get(bpy.context.evaluated_depsgraph_get()).to_mesh().vertices];lo=Vector([min(v[i] for v in points) for i in range(3)]);hi=Vector([max(v[i] for v in points) for i in range(3)]);center=(lo+hi)/2;extent=max(hi-lo)
s=bpy.context.scene;s.render.engine='CYCLES';s.cycles.samples=8;s.render.resolution_x=1000;s.render.resolution_y=600;s.render.resolution_percentage=100
s.world=bpy.data.worlds.new('world');s.world.use_nodes=True;s.world.node_tree.nodes['Background'].inputs[0].default_value=(.25,.25,.25,1)
l=bpy.data.lights.new('key','AREA');l.energy=extent*extent*100;l.size=extent;o=bpy.data.objects.new('key',l);s.collection.objects.link(o);o.location=center+Vector((0,-extent,extent));o.rotation_euler=(center-o.location).to_track_quat('-Z','Y').to_euler()
c=bpy.data.cameras.new('inspect_camera');o=bpy.data.objects.new('inspect_camera',c);s.collection.objects.link(o);s.camera=o;c.type='ORTHO';c.ortho_scale=extent*1.15;o.location=center+Vector((0,-extent*2,extent*.2));o.rotation_euler=(center-o.location).to_track_quat('-Z','Y').to_euler();s.render.filepath=str(r/'logs/TASK-009-gloves-source.png');bpy.ops.render.render(write_still=True)

