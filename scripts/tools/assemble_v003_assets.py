"""Derived gun components, posed skinned arms and individual clutter variants."""
import bpy
import math
import json
import sys
from pathlib import Path
from mathutils import Vector,Matrix,Quaternion
from mathutils.bvhtree import BVHTree
import numpy as np

root=Path(__file__).resolve().parents[2]
asset=sys.argv[sys.argv.index('--')+1]
assert bpy.data.filepath==''
directory=root/'assets/source/task009/v003'/asset
bpy.ops.wm.open_mainfile(filepath=str(directory/'Baked.blend'))
low=bpy.data.objects[asset+'_Low']
out=root/'assets/models/task009/v003'
report={'asset':asset,'variants':[]}

def boolean(obj,cutter,operation):
    bpy.context.view_layer.objects.active=obj
    m=obj.modifiers.new('Component_cut','BOOLEAN')
    m.operation=operation
    m.object=cutter
    bpy.ops.object.modifier_apply(modifier=m.name)

def export(objects,name,animations=False):
    bpy.ops.object.select_all(action='DESELECT')
    for obj in objects: obj.select_set(True)
    bpy.context.view_layer.objects.active=objects[0]
    arguments=dict(filepath=str(out/(name+'.glb')),export_format='GLB',use_selection=True,export_apply=True,
                   export_yup=True,export_cameras=False,export_lights=False,export_animations=animations)
    if animations: arguments.update(export_animation_mode='NLA_TRACKS')
    bpy.ops.export_scene.gltf(**arguments)
    report['runtime_glb']=(out/(name+'.glb')).relative_to(root).as_posix()

def triangles(obj): return sum(len(p.vertices)-2 for p in obj.data.polygons)

if asset=='new_ar':
    source_points=np.array([[v.co.x,v.co.z,-v.co.y] for v in low.data.vertices])
    bpy.ops.mesh.primitive_cube_add(size=1,location=(0,.075,-.2775))
    cutter=bpy.context.object
    cutter.dimensions=(.15,.33,.445)
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    magazine=low.copy(); magazine.data=low.data.copy()
    bpy.context.scene.collection.objects.link(magazine)
    boolean(magazine,cutter,'INTERSECT'); boolean(low,cutter,'DIFFERENCE')
    bpy.data.objects.remove(cutter,do_unlink=True)
    low.name='Rifle_Body'; magazine.name='Magazine'
    # Rear housing is slightly elliptical in the supplied mesh. Fit its real section.
    section=source_points[(source_points[:,2]>.09)&(source_points[:,2]<.10)&(source_points[:,1]>.12)]
    cx=float((section[:,0].min()+section[:,0].max())/2)
    cy=float((section[:,1].min()+section[:,1].max())/2)
    rx=float(np.ptp(section[:,0])*.39)
    ry=float(np.ptp(section[:,1])*.39)
    bpy.ops.mesh.primitive_cylinder_add(vertices=64,radius=1,depth=.40,location=(cx,.04,cy),rotation=(math.pi/2,0,0))
    cutter=bpy.context.object
    cutter.scale=(rx,ry,1)
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    boolean(low,cutter,'DIFFERENCE')
    bpy.data.objects.remove(cutter,do_unlink=True)
    dark=bpy.data.materials.new('Dark_component_interfaces')
    dark.use_nodes=True
    bsdf=next(n for n in dark.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
    bsdf.inputs['Base Color'].default_value=(.015,.018,.02,1)
    bsdf.inputs['Roughness'].default_value=.7
    for obj in (low,magazine):
        index=len(obj.data.materials); obj.data.materials.append(dark)
        for p in obj.data.polygons:
            if obj.data.materials[p.material_index] is None or abs(p.center.z+.055)<.0003: p.material_index=index
    # A seated inner retaining lip masks the coarse cap edge and supports the inset lens.
    vertices=[]
    for scale_x,scale_y in ((1.15,1.1),(.99,.99)):
        vertices.extend((cx+rx*scale_x*math.cos(i*math.tau/64),-.096,cy+ry*scale_y*math.sin(i*math.tau/64)) for i in range(64))
    faces=[(i,(i+1)%64,(i+1)%64+64,i+64) for i in range(64)]
    ring_mesh=bpy.data.meshes.new('Lens_retaining_lip')
    ring_mesh.from_pydata(vertices,[],faces)
    ring=bpy.data.objects.new('Lens_retaining_lip',ring_mesh)
    bpy.context.scene.collection.objects.link(ring)
    ring_mesh.materials.append(dark)
    bpy.ops.object.select_all(action='DESELECT'); low.select_set(True); ring.select_set(True)
    bpy.context.view_layer.objects.active=low
    bpy.ops.object.join()
    mesh=bpy.data.meshes.new('Fitted_lens_surface')
    mesh.from_pydata([(cx+rx*.985*math.cos(i*math.tau/64),-.094,cy+ry*.985*math.sin(i*math.tau/64)) for i in range(64)],[],[tuple(range(64))])
    glass=bpy.data.objects.new('Optic_Glass',mesh)
    bpy.context.scene.collection.objects.link(glass)
    mat=bpy.data.materials.new('Coated_optic_glass'); mat.use_nodes=True
    bsdf=next(n for n in mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
    bsdf.inputs['Alpha'].default_value=.08
    glass.data.materials.append(mat)
    translation=Vector((-cx,.052,.135-cy))
    for obj in (low,magazine,glass): obj.data.transform(Matrix.Translation(translation))
    front=source_points[source_points[:,2]<-.445]
    report.update({'components':{o.name:triangles(o) for o in (low,magazine,glass)},
                   'muzzle_godot':[float((front[:,0].min()+front[:,0].max())/2-cx),float((front[:,1].min()+front[:,1].max())/2+.135-cy),-.518],
                   'sight_center_godot':[0,.135,.042], 'lens_fit':{'source_center':[cx,cy,.094],'radii':[rx,ry],'surface':'single fitted plane'}})
    export([low,magazine,glass],'ar15_revision')

elif asset.startswith('clutter'):
    points=np.array([tuple(v.co) for v in low.data.vertices])
    count=1 if asset=='clutter1' else 6
    # The supplied six-pile sheets are laid out in X/Z, not on one ground plane.
    features=points[:,[0,2]]
    lo,hi=features.min(axis=0),features.max(axis=0)
    centers=np.array([features.mean(axis=0)]) if count==1 else np.array([
        lo+(hi-lo)*np.array((x,z)) for x in (.25,.75) for z in (.16,.5,.84)])
    for iteration in range(40):
        labels=np.argmin(np.sum((features[:,None,:]-centers[None,:,:])**2,axis=2),axis=1)
        updated=np.array([features[labels==i].mean(axis=0) for i in range(count)])
        if np.max(np.abs(updated-centers))<.00001: break
        centers=updated
    # Assign whole connected pieces to one pile, preserving every triangle and UV.
    adjacency=[[] for _ in points]
    for edge in low.data.edges:
        a,b=edge.vertices; adjacency[a].append(b); adjacency[b].append(a)
    vertex_labels=np.full(len(points),-1,dtype=int)
    for vertex in range(len(points)):
        if vertex_labels[vertex]>=0: continue
        stack=[vertex]; component=[]; vertex_labels[vertex]=-2
        while stack:
            v=stack.pop(); component.append(v)
            for other in adjacency[v]:
                if vertex_labels[other]==-1: vertex_labels[other]=-2; stack.append(other)
        label=int(np.argmin(np.sum((centers-features[component].mean(axis=0))**2,axis=1)))
        vertex_labels[component]=label
    objects=[]
    for label in range(count):
        obj=low.copy(); obj.data=low.data.copy(); bpy.context.scene.collection.objects.link(obj)
        # Vertex indices are still those of the baked source at this point.
        import bmesh
        bm=bmesh.new(); bm.from_mesh(obj.data); bm.verts.ensure_lookup_table()
        bmesh.ops.delete(bm,geom=[v for v in bm.verts if vertex_labels[v.index]!=label],context='VERTS')
        bm.to_mesh(obj.data); bm.free()
        if not len(obj.data.vertices): bpy.data.objects.remove(obj,do_unlink=True); continue
        p=np.array([tuple(v.co) for v in obj.data.vertices])
        lo,hi=p.min(axis=0),p.max(axis=0)
        center=(lo+hi)/2; center[2]=lo[2]
        scale=(1.7 if count==1 else 1.05)/max((hi-lo)[:2])
        for v in obj.data.vertices: v.co=(v.co-Vector(center))*scale
        obj.name='Pile'+str(label)
        obj.data.update(); objects.append(obj)
        dims=(hi-lo)*scale
        report['variants'].append({'name':obj.name,'triangles':triangles(obj),'dimensions_godot':[float(dims[0]),float(dims[2]),float(dims[1])]})
    assert sum(triangles(o) for o in objects)==triangles(low),'Pile grouping must not lose source triangles'
    low.hide_render=True; low.hide_set(True)
    export(objects,asset+'_variants')

elif asset=='arms':
    # Matched three-bone chains. Existing curled fingers remain part of each hand.
    p=np.array([[v.co.x,v.co.z,-v.co.y] for v in low.data.vertices])
    def centroid(side,height):
        q=p[(p[:,0]*side>0)&(abs(p[:,1]-height)<.025)]
        return Vector(q.mean(axis=0))
    def blender(v): return Vector((v[0],-v[2],v[1]))
    rests={}
    fingers={}
    for side,label in ((1,'R'),(-1,'L')):
        rests[label]=[centroid(side,.79),centroid(side,.51),centroid(side,.225),centroid(side,.06)]
        wrist=rests[label][2]
        region=p[(p[:,0]*side>0)&(p[:,1]<.105)&((p[:,0]-wrist.x)*side>-.043)]
        centers=np.linspace(region[:,0].min()+.009,region[:,0].max()-.009,4)
        for iteration in range(15):
            labels=np.argmin(abs(region[:,0,None]-centers[None,:]),axis=1)
            centers=np.array([region[labels==i,0].mean() for i in range(4)])
        fingers[label]=[]
        for center in sorted(centers):
            q=p[(p[:,0]*side>0)&(abs(p[:,0]-center)<.012)&(p[:,1]<.145)]
            bottom=float(q[:,1].min()+.005)
            joints=[]
            for height in (.118,(.118+bottom)/2,bottom):
                band=q[abs(q[:,1]-height)<.018]
                joints.append(Vector((float(center),height,float(np.median(band[:,2])))))
            fingers[label].append(joints)
    armature=bpy.data.armatures.new('FP_Arms_Rig')
    rig=bpy.data.objects.new('FP_Arms_Rig',armature)
    bpy.context.scene.collection.objects.link(rig)
    bpy.ops.object.select_all(action='DESELECT'); rig.select_set(True)
    bpy.context.view_layer.objects.active=rig; bpy.ops.object.mode_set(mode='EDIT')
    for label,joints in rests.items():
        parent=None
        for index,name in enumerate(('Upper','Forearm','Hand')):
            bone=armature.edit_bones.new(label+'_'+name)
            bone.head=blender(joints[index]); bone.tail=blender(joints[index+1])
            bone.parent=parent; parent=bone
        for finger_index,finger in enumerate(fingers[label]):
            parent=armature.edit_bones[label+'_Hand']
            for segment in range(2):
                bone=armature.edit_bones.new(label+'_Finger'+str(finger_index)+'_'+str(segment))
                bone.head=blender(finger[segment]); bone.tail=blender(finger[segment+1])
                bone.parent=parent; parent=bone
    bpy.ops.object.mode_set(mode='OBJECT')
    for bone in rig.pose.bones: bone.rotation_mode='QUATERNION'
    groups={bone.name:low.vertex_groups.new(name=bone.name) for bone in armature.bones}
    def smooth(a,b,x):
        t=max(0,min(1,(x-a)/(b-a))); return t*t*(3-2*t)
    for vertex,co in zip(low.data.vertices,p):
        label='R' if co[0]>0 else 'L'
        upper=smooth(.46,.56,co[1]); hand=1-smooth(.18,.27,co[1])
        weights=(upper,(1-upper)*(1-hand),(1-upper)*hand)
        hand_weight=weights[2]
        wrist=rests[label][2]
        side=1 if label=='R' else -1
        if co[1]<.145 and (co[0]-wrist.x)*side>-.043:
            finger_index=int(np.argmin([abs(co[0]-joint[0].x) for joint in fingers[label]]))
            finger=fingers[label][finger_index]
            amount=hand_weight*(1-smooth(.10,.145,co[1]))
            distal=1-smooth(finger[1].y-.015,finger[1].y+.015,co[1])
            weights=(weights[0],weights[1],hand_weight-amount)
            for segment,weight in enumerate((amount*(1-distal),amount*distal)):
                if weight>.0001: groups[label+'_Finger'+str(finger_index)+'_'+str(segment)].add([vertex.index],float(weight),'REPLACE')
        for name,weight in zip(('Upper','Forearm','Hand'),weights):
            if weight>.0001: groups[label+'_'+name].add([vertex.index],float(weight),'REPLACE')
    modifier=low.modifiers.new('Armature','ARMATURE'); modifier.object=rig
    low.parent=rig; low.name='FP_Arms_Mesh'
    conversion=Matrix(((1,0,0),(0,0,-1),(0,1,0)))
    right_rotation=Matrix.Rotation(math.pi/2,3,'Y') @ Matrix.Rotation(math.pi,3,'Z')
    left_rotation=Matrix(((0,-1,0),(0,0,-1),(1,0,0)))
    # Palm toward magazine, thumb upward, fingers around its front/rear rather than pointing up the magwell.
    reload_left_rotation=Matrix(((0,0,-1),(1,0,0),(0,-1,0)))
    def set_pose(label,wrist,hand_rotation):
        joints=rests[label]
        shoulder=Vector((.27,-.28,.35)) if label=='R' else Vector((-.32,-.26,.20))
        l1=(joints[1]-joints[0]).length; l2=(joints[2]-joints[1]).length
        direction=wrist-shoulder; distance=min(direction.length,l1+l2-.001); direction.normalize()
        wrist=shoulder+direction*distance
        projection=(l1*l1-l2*l2+distance*distance)/(2*distance)
        pole=Vector((1 if label=='R' else -1,-1,.1))
        bend=(pole-direction*pole.dot(direction)).normalized()
        elbow=shoulder+direction*projection+bend*math.sqrt(max(0,l1*l1-projection*projection))
        # Transport the palm roll through the forearm instead of applying an abrupt wrist twist.
        fore_rotation=(hand_rotation@(joints[2]-joints[1])).rotation_difference(wrist-elbow).to_matrix() @ hand_rotation
        upper_rotation=(fore_rotation@(joints[1]-joints[0])).rotation_difference(elbow-shoulder).to_matrix() @ fore_rotation
        for i,(name,head,tail,rotation) in enumerate((('Upper',shoulder,elbow,upper_rotation),('Forearm',elbow,wrist,fore_rotation))):
            transform=Matrix.Translation(blender(head)) @ (conversion@rotation@conversion.inverted()).to_4x4() @ Matrix.Translation(-blender(joints[i]))
            rig.pose.bones[label+'_'+name].matrix=transform@armature.bones[label+'_'+name].matrix_local
            bpy.context.view_layer.update()
        transform=Matrix.Translation(blender(wrist)) @ (conversion@hand_rotation@conversion.inverted()).to_4x4() @ Matrix.Translation(-blender(joints[2]))
        rig.pose.bones[label+'_Hand'].matrix=transform@armature.bones[label+'_Hand'].matrix_local
        bpy.context.view_layer.update()
    def curl(label,proximal,distal):
        for finger_index in range(4):
            for segment,angle in enumerate((proximal,distal)):
                name=label+'_Finger'+str(finger_index)+'_'+str(segment)
                axis=armature.bones[name].matrix_local.to_3x3().inverted()@Vector((1,0,0))
                rig.pose.bones[name].rotation_quaternion=Quaternion(axis.normalized(),angle)
    with bpy.data.libraries.load(str(root/'assets/source/task009/v003/new_ar/Derived.blend'),link=False) as (available,loaded):
        loaded.objects=['Rifle_Body']
    gun=loaded.objects[0]; bpy.context.scene.collection.objects.link(gun)
    gun_points=np.array([[v.co.x,v.co.z,-v.co.y] for v in gun.data.vertices])
    grip_z=-.285
    section=gun_points[(abs(gun_points[:,2]-grip_z)<.02)&(gun_points[:,1]>0)&(gun_points[:,1]<.12)]
    base_wrist=Vector((-.14,float(section[:,1].min()+.001),grip_z))
    bpy.context.view_layer.update()
    tree=BVHTree.FromObject(gun,bpy.context.evaluated_depsgraph_get())
    left_indices=np.where((p[:,0]<0)&(p[:,1]<.18))[0][::2]
    best=None
    for offset in (0,-.004,-.008,-.012,-.016,-.022,-.03):
        for factor in (0,.25,.5,.75,1):
            wrist=base_wrist+Vector((0,offset,0))
            set_pose('R',Vector((.014,-.18,.145)),right_rotation)
            set_pose('L',wrist,left_rotation); curl('L',.32*factor,.60*factor)
            bpy.context.view_layer.update()
            evaluated=low.evaluated_get(bpy.context.evaluated_depsgraph_get())
            mesh=evaluated.to_mesh()
            inside=0; distances=[]
            for index in left_indices:
                point=evaluated.matrix_world@mesh.vertices[int(index)].co
                nearest,normal,face,distance=tree.find_nearest(point)
                if nearest is not None:
                    if (point-nearest).dot(normal)<-.001: inside+=1
                    distances.append(float(distance))
            evaluated.to_mesh_clear()
            nearest_mean=float(np.mean(sorted(distances)[:12]))
            score=inside*100+nearest_mean+abs(offset)*.1
            candidate=(score,wrist.copy(),factor,inside,nearest_mean)
            if best is None or score<best[0]: best=candidate
    _,left_hold_wrist,left_hold_curl,penetrations,contact_distance=best
    report['left_grip_fit']={'wrist_godot':list(left_hold_wrist),'curl_factor':left_hold_curl,
                             'penetrating_sample_vertices':penetrations,'nearest12_mean_m':contact_distance,
                             'samples':len(left_indices),'handguard_section_bounds':[section.min(axis=0).tolist(),section.max(axis=0).tolist()]}
    print('LEFT GRIP CONTACT FIT',report['left_grip_fit'],flush=True)
    gun.hide_render=True; gun.hide_set(True)
    rig.animation_data_create()
    for animation in ('Hold','Reload'):
        action=bpy.data.actions.new(animation); rig.animation_data.action=action
        frames=range(1,134,3) if animation=='Reload' else (1,4)
        for frame in frames:
            scene=bpy.context.scene; scene.frame_set(frame)
            progress=(frame-1)/132 if animation=='Reload' else 0
            blend=smooth(.02,.17,progress)*(1-smooth(.84,.98,progress))
            extract=smooth(.18,.38,progress)*(1-smooth(.62,.82,progress))
            left=left_hold_wrist.lerp(Vector((-.024,-.13,-.10)),blend)+Vector((.02,-.14,.15))*extract
            rotation=left_rotation.to_quaternion().slerp(reload_left_rotation.to_quaternion(),blend).to_matrix()
            set_pose('R',Vector((.014,-.18,.145)),right_rotation)
            set_pose('L',left,rotation)
            grasp=1.0
            if animation=='Reload':
                grasp-=smooth(.02,.08,progress)*(1-smooth(.13,.18,progress))
                grasp-=smooth(.82,.88,progress)*(1-smooth(.94,.99,progress))
            curl('R',.50,.85)
            curl('L',(.32*left_hold_curl*(1-blend)+.52*blend)*grasp,
                 (.60*left_hold_curl*(1-blend)+.90*blend)*grasp)
            for bone in rig.pose.bones:
                bone.keyframe_insert(data_path='location',frame=frame)
                bone.keyframe_insert(data_path='rotation_quaternion',frame=frame)
        track=rig.animation_data.nla_tracks.new(); track.name=animation
        track.strips.new(animation,1,action)
    rig.animation_data.action=None
    bpy.context.scene.render.fps=60
    bpy.context.scene.frame_set(1)
    export([rig,low],'arms_rigged',True)
    report.update({'bones':list(groups),'triangles':triangles(low),'animations':['Hold','Reload'],
                   'limitation':'basic arm and four-finger curl skinning; thumb retains supplied shape, detailed contact still needs visual review'})

bpy.ops.wm.save_as_mainfile(filepath=str(directory/'Derived.blend'))
report['source_blend']=(directory/'Derived.blend').relative_to(root).as_posix()
(root/'logs'/('TASK-009-v003-parts-'+asset+'.json')).write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print('ASSEMBLED',asset,report,flush=True)
