"""Original fictional rifle and distant city kit. Isolated Blender factory-startup only.
Godot (x,y,z) meters -> Blender (x,-z,y). No user asset or interactive scene edited.
"""
import bpy
import math
import json
from pathlib import Path
from mathutils import Vector
import numpy as np
import bmesh

root = Path(__file__).resolve().parents[2]
assert bpy.data.filepath == '', 'Use isolated --factory-startup'
bpy.ops.wm.read_factory_settings(use_empty=True)
out = root/'assets/models/task009'
source = root/'assets/source/task009'
tex = root/'assets/textures/task009'
for folder in (out, source, tex):
    folder.mkdir(parents=True,exist_ok=True)
(source/'.gdignore').touch()
bpy.context.scene.unit_settings.system = 'METRIC'
current = None

def image(name, pixels, color=False):
    img = bpy.data.images.new(name,pixels.shape[1],pixels.shape[0],alpha=False)
    img.colorspace_settings.name = 'sRGB' if color else 'Non-Color'
    img.pixels.foreach_set(pixels.astype(np.float32).ravel())
    img.filepath_raw = str(tex/(name+'.png'))
    img.file_format = 'PNG'
    img.save()
    img.pack()
    return img

rng = np.random.default_rng(20261029)

def surface_maps(name,n,base,polymer=False):
    grain = rng.random((n,n),dtype=np.float32)
    y,x = np.mgrid[:n,:n].astype(np.float32)/n
    broad = (np.sin(x*17+y*4)*np.sin(y*13-x*3)+1)*.5
    brushed = rng.random(n,dtype=np.float32)[:,None]
    scratches = np.zeros((n,n),dtype=np.float32)
    if not polymer:
        for i in range(120):
            sx,sy = rng.integers(0,n,2)
            length = int(rng.integers(5,70))
            scratches[sy,min(sx,n-1):min(sx+length,n)] = rng.uniform(.2,.8)
    height = grain*.006 + brushed*.002 - scratches*.012
    if polymer:
        height += (np.sin(x*850)*np.sin(y*850))*.008
    roughness = np.clip((.72+grain*.17) if polymer else (.37+grain*.11+broad*.07-scratches*.15),.2,.95)
    tint = .9+grain*.16+broad*.08
    rgba = np.ones((n,n,4),dtype=np.float32)
    rgba[:,:,:3] = np.clip(np.array(base,dtype=np.float32)[None,None,:]*tint[:,:,None]+scratches[:,:,None]*.055,0,1)
    color = image(name+'_albedo_v002',rgba,True)
    rgba[:,:,:3] = roughness[:,:,None]
    rough = image(name+'_roughness_v002',rgba)
    dx = np.roll(height,-1,axis=1)-np.roll(height,1,axis=1)
    dy = np.roll(height,-1,axis=0)-np.roll(height,1,axis=0)
    normals = np.stack((-dx*1.8,-dy*1.8,np.ones_like(height)),axis=-1)
    normals /= np.linalg.norm(normals,axis=-1,keepdims=True)
    rgba[:,:,:3] = normals*.5+.5
    normal = image(name+'_normal_v002',rgba)
    return color,rough,normal

metal_maps = surface_maps('rifle_anodized',2048,(.145,.16,.17))
polymer_maps = surface_maps('rifle_polymer',1024,(.16,.17,.155),True)

def material(name, tint, metallic=0, roughness=.65, textured=False):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = next(n for n in mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
    bsdf.inputs['Base Color'].default_value = (*tint,1)
    bsdf.inputs['Metallic'].default_value = metallic
    bsdf.inputs['Roughness'].default_value = roughness
    if textured:
        color,rough,normal = polymer_maps if textured=='polymer' else metal_maps
        for img, target in ((color,'Base Color'),(rough,'Roughness')):
            node = mat.node_tree.nodes.new('ShaderNodeTexImage')
            node.image = img
            mat.node_tree.links.new(node.outputs['Color'],bsdf.inputs[target])
        node = mat.node_tree.nodes.new('ShaderNodeTexImage')
        node.image = normal
        bump = mat.node_tree.nodes.new('ShaderNodeNormalMap')
        mat.node_tree.links.new(node.outputs['Color'],bump.inputs['Color'])
        mat.node_tree.links.new(bump.outputs['Normal'],bsdf.inputs['Normal'])
    return mat

metal = material('Anodized_receiver',(.16,.18,.2),.8,.45,True)
steel = material('Machined_steel',(.07,.08,.085),.9,.4)
black = material('Recess_dark',(.016,.021,.024),.15,.7)
polymer = material('Black_polymer',(.024,.029,.027),.02,.78,'polymer')
edge_wear = material('Subtle_exposed_edges',(.055,.06,.064),.85,.38)
rubber = material('Rubber',(.025,.028,.024),0,.95)
mark = material('Etched_markings',(.48,.5,.46),.35,.6)
glass = material('Coated_optic_glass',(.24,.38,.42),.05,.08)
glass_bsdf = next(n for n in glass.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
glass_bsdf.inputs['Alpha'].default_value = .10
glass_bsdf.inputs['IOR'].default_value = 1.48

def collection(name):
    global current
    current = bpy.data.collections.new(name)
    bpy.context.scene.collection.children.link(current)
    return current

def finish(obj,name,mat,bevel=0):
    obj.name = name
    for col in list(obj.users_collection):
        col.objects.unlink(obj)
    current.objects.link(obj)
    obj.data.materials.append(mat)
    if bevel:
        modifier = obj.modifiers.new('Machined_edge_bevel','BEVEL')
        modifier.width,modifier.segments = bevel,2
        if mat==metal:
            obj.data.materials.append(edge_wear)
            modifier.material=1
        modifier = obj.modifiers.new('Weighted_surface_normals','WEIGHTED_NORMAL')
        modifier.keep_sharp = True
    return obj

def box(name,position,size,mat,bevel=.0015):
    bpy.ops.mesh.primitive_cube_add(size=1,location=(position[0],-position[2],position[1]))
    obj = bpy.context.object
    obj.dimensions = (size[0],size[2],size[1])
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    return finish(obj,name,mat,bevel)

def cylinder(name,position,radius,length,mat,axis='z',vertices=24):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices,radius=radius,depth=length,
                                      location=(position[0],-position[2],position[1]))
    obj = bpy.context.object
    direction = {'x':Vector((1,0,0)), 'y':Vector((0,0,1)), 'z':Vector((0,-1,0))}[axis]
    obj.rotation_euler = direction.to_track_quat('Z','Y').to_euler()
    for p in obj.data.polygons:
        p.use_smooth = len(p.vertices)==4
    return finish(obj,name,mat,.0007)

def profile(name,points,width,mat,bevel=.003):
    vertices=[(x,-z,y) for x in (-width/2,width/2) for z,y in points]
    count=len(points)
    faces=[tuple(reversed(range(count))),tuple(range(count,count*2))]
    faces += [(i,(i+1)%count,(i+1)%count+count,i+count) for i in range(count)]
    mesh=bpy.data.meshes.new(name+'_profile')
    mesh.from_pydata(vertices,[],faces)
    obj=bpy.data.objects.new(name,mesh)
    current.objects.link(obj)
    obj.data.materials.append(mat)
    modifier=obj.modifiers.new('Profile_bevel','BEVEL')
    modifier.width,modifier.segments=bevel,3
    if mat==metal:
        obj.data.materials.append(edge_wear)
        modifier.material=1
    obj.modifiers.new('Weighted_normals','WEIGHTED_NORMAL')
    return obj

def cut(obj,position,size):
    cutter=box('Temporary_cut',position,size,black,0)
    bpy.context.view_layer.objects.active=obj
    modifier=obj.modifiers.new('Actual_vent_opening','BOOLEAN')
    modifier.operation='DIFFERENCE'
    modifier.object=cutter
    bpy.ops.object.modifier_apply(modifier=modifier.name)
    bpy.data.objects.remove(cutter,do_unlink=True)

rifle = collection('rifle_v002')
profile('Upper_receiver',[(.14,-.025),(.14,.04),(.11,.06),(-.1,.06),(-.125,.037),(-.125,-.025)],.075,metal)
profile('Lower_receiver',[(.14,-.022),(.13,-.061),(.075,-.069),(.05,-.046),(-.05,-.094),(-.087,-.085),(-.105,-.025)],.068,metal)
box('Ejection_port',(.038,.024,-.002),(.002,.029,.082),black,.002)
box('Bolt_carrier',(.040,.025,-.006),(.002,.012,.065),steel,.001)
box('Dust_cover',(.041,.002,-.005),(.004,.008,.087),metal)
box('Charging_handle',(0,.052,.143),(.105,.014,.018),steel)
for x in (-.039,.039):
    for z in (-.065,.09):
        cylinder('Receiver_pin',(x,-.03,z),.004,.006,steel,'x',12)
profile('Pistol_grip',[(.08,-.055),(.128,-.064),(.175,-.19),(.116,-.197),(.086,-.105)],.048,polymer,.006)
for i in range(6):
    box('Grip_texture',(0,-.075-i*.016,.147),(.046,.004,.003),rubber,.0005)
for x in (-.022,.022):
    box('Trigger_guard_side',(x,-.091,.035),(.006,.009,.075),metal)
box('Trigger_guard_front',(0,-.073,-.002),(.047,.043,.007),metal)
box('Trigger',(0,-.078,.04),(.006,.04,.009),steel)
cylinder('Buffer_tube',(0,.014,.212),.022,.15,steel)
profile('Adjustable_stock',[(.18,.026),(.325,.043),(.35,.025),(.35,-.086),(.317,-.086),(.317,-.03),(.222,-.054),(.18,-.035)],.066,polymer,.005)
box('Stock_cheek_rest',(0,.041,.257),(.08,.022,.12),polymer,.006)
box('Rubber_buttpad',(0,-.016,.348),(.078,.12,.018),rubber,.006)
box('Stock_adjuster',(0,-.07,.257),(.048,.016,.064),black)
# Tapered segmented magazine; a separate mesh, not fused into the receiver.
verts,faces=[],[]
sections=[(-.055,-.035),(-.10,-.027),(-.15,-.012),(-.20,.011),(-.245,.042)]
for y,z in sections:
    for x,dz in ((-.024,-.031),(.024,-.031),(.024,.031),(-.024,.031)):
        verts.append((x,-(z+dz),y))
faces.append((3,2,1,0))
for i in range(len(sections)-1):
    for j in range(4):
        faces.append((i*4+j,i*4+(j+1)%4,(i+1)*4+(j+1)%4,(i+1)*4+j))
faces.append(tuple(range(16,20)))
mesh=bpy.data.meshes.new('Magazine_geometry')
mesh.from_pydata(verts,[],faces)
magazine=bpy.data.objects.new('Magazine',mesh)
current.objects.link(magazine)
magazine.data.materials.append(polymer)
for i in range(4):
    for x in (-.026,.026):
        detail=box('Magazine_rib',(x,-.095-i*.037,-.021+i*.014),(.003,.027,.055),black,.001)
        detail.parent=magazine
box('Magazine_floorplate',(0,-.25,.042),(.055,.014,.073),rubber,.002)
# Open-sided layered handguard and inset vent panels.
handguard=box('Handguard_core',(0,.008,-.245),(.068,.068,.275),metal,0)
cut(handguard,(0,.008,-.245),(.052,.046,.29))
for z in (-.14,-.185,-.23,-.275,-.32,-.365):
    cut(handguard,(0,.012,z),(.085,.025,.026))
bevel=handguard.modifiers.new('Vent_edge_bevel','BEVEL')
bevel.width,bevel.segments=.0012,2
handguard.data.materials.append(edge_wear)
bevel.material=1
handguard.modifiers.new('Weighted_vent_normals','WEIGHTED_NORMAL')
for x in (-.035,.035):
    for z in (-.14,-.185,-.23,-.275,-.32,-.365):
        cylinder('Handguard_bolt',(x,-.014,z+.012),.0025,.005,steel,'x',8)
box('Top_rail',(0,.059,-.105),(.034,.013,.49),steel,.001)
for i in range(32):
    box('Picatinny_tooth',(0,.07,.13-i*.015),(.046,.01,.008),metal,.0008)
box('Lower_rail',(0,-.035,-.255),(.03,.009,.2),steel)
cylinder('Barrel',(0,.006,-.447),.012,.16,steel)
cylinder('Gas_block',(0,.006,-.396),.019,.028,metal)
cylinder('Muzzle_brake',(0,.006,-.551),.018,.058,steel)
cylinder('Muzzle_bore',(0,.006,-.581),.010,.001,black,vertices=24)
for x in (-.018,.018):
    for z in (-.535,-.552,-.569):
        box('Brake_slot',(x,.006,z),(.002,.017,.007),black,.0005)
# Hollow reflex sight: no opaque glass that hides the real target.
box('Optic_mount',(0,.088,.042),(.056,.025,.075),black,.002)
for x in (-.038,.038):
    box('Optic_frame',(x,.135,.042),(.012,.08,.035),metal,.003)
box('Optic_top',(0,.175,.042),(.08,.012,.035),metal,.003)
box('Optic_bottom',(0,.095,.042),(.08,.012,.035),metal,.003)
optic_glass = box('Optic_Glass',(0,.135,.042),(.062,.065,.001),glass,0)
cylinder('Optic_adjuster',(.052,.122,.042),.017,.016,black,'x')
for z in (.0,.09):
    cylinder('Optic_screw',(.028,.08,z),.004,.01,steel,'y',12)
# Small etched scale marks, no borrowed manufacturer trademarks.
for i in range(7):
    box('Rail_index',(.025,.076,-.08-i*.036),(.005,.001,.003),mark,.0001)
box('Selector_plate',(-.037,-.038,.073),(.003,.019,.033),black)
box('Selector_lever',(-.042,-.035,.08),(.008,.007,.029),steel)

# Ensure floorplate follows the one independently animated magazine.
for obj in list(rifle.objects):
    if obj.name.startswith('Magazine_floorplate'):
        obj.parent=magazine

skyline=collection('skyline_v002')
facades=[material('Haze_layer_'+str(i),c,0,.95) for i,c in enumerate(((.27,.30,.30),(.33,.36,.37),(.39,.42,.43)))]
window=material('Distant_windows',(.12,.15,.16),0,.9)
for layer in range(3):
    for i in range(9):
        x=(i-4)*7.6+(layer%2)*2.1
        z=-45-layer*22-(i%3)*2
        width=5.5+(i%3)*.6
        height=10+((i*7+layer*5)%13)
        depth=5.5
        box('Distant_building',(x,height/2,z),(width,height,depth),facades[layer],.06)
        box('Roof_parapet',(x,height+.18,z),(width+.12,.36,depth+.12),facades[layer],.01)
        for floor in range(2,int(height)-1,3):
            for dx in (-1.6,0,1.6):
                box('Distant_window',(x+dx,floor,z+depth/2+.015),(.7,1.1,.025),window,0)
        if i%3==0:
            cylinder('Rooftop_water_tank',(x,height+1.2,z),.65,1.6,facades[layer],'y',12)
        if i%4==1:
            box('Roof_stairwell',(x+1,height+1.2,z),(1.7,2.4,2),facades[layer],.01)

# Readable distant old-city silhouettes beyond the solid playable boundary.
box('Landmark_dome_base',(1.7,12,-80),(10,24,9),facades[2],.08)
vertices,faces=[],[]
segments,rings=24,10
for ring in range(rings):
    phi=(math.pi/2)*ring/rings
    for segment in range(segments):
        angle=math.tau*segment/segments
        vertices.append((1.7+4.6*math.cos(phi)*math.cos(angle),
                         -(-80+4.6*math.cos(phi)*math.sin(angle)),24+4.4*math.sin(phi)))
for ring in range(rings-1):
    for segment in range(segments):
        a=ring*segments+segment
        b=ring*segments+(segment+1)%segments
        faces.append((a,b,b+segments,a+segments))
tip=len(vertices)
vertices.append((1.7,80,28.4))
for segment in range(segments):
    faces.append(((rings-1)*segments+segment,(rings-1)*segments+(segment+1)%segments,tip))
faces.append(tuple(range(segments)))
mesh=bpy.data.meshes.new('Distant_dome_geometry')
mesh.from_pydata(vertices,[],faces)
bm=bmesh.new()
bm.from_mesh(mesh)
bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
bm.to_mesh(mesh)
bm.free()
obj=bpy.data.objects.new('Skyline_Dome',mesh)
current.objects.link(obj)
obj.data.materials.append(facades[2])
for polygon in mesh.polygons:
    polygon.use_smooth=True
cylinder('Landmark_Tower_Shaft',(-8,16,-76),.75,32,facades[1],'y',16)
for y in (26.5,30):
    cylinder('Landmark_balcony',(-8,y,-76),1.15,.28,facades[1],'y',16)
cylinder('Landmark_lantern',(-8,32.6,-76),.55,1.7,facades[1],'y',16)
bpy.ops.mesh.primitive_cone_add(vertices=16,radius1=.65,radius2=0,depth=2.7,location=(-8,76,34.8))
finish(bpy.context.object,'Landmark_spire',facades[1])

report={'blender_version':bpy.app.version_string,'source':'Original project meshes and seeded mathematical PBR; no external meshes',
        'license':'Project original; fictional unbranded rifle','assets':[],'muzzle_godot':[0,.006,-.582],
        'sight_center_godot':[0,.135,.042],'seed':20261029,'revision':'v002',
        'source_blend':'assets/source/task009/CinematicKit_v002.blend',
        'texture_resolutions':{'anodized':[2048,2048],'polymer':[1024,1024]}}
# Save the editable authored components, then optimize only the runtime exports.
bpy.ops.object.select_all(action='DESELECT')
for obj in rifle.objects:
    obj.select_set(True)
bpy.context.view_layer.objects.active = next(iter(rifle.objects))
bpy.ops.object.mode_set(mode='EDIT')
bpy.ops.mesh.select_all(action='SELECT')
bpy.ops.uv.cube_project(cube_size=.1)
bpy.ops.object.mode_set(mode='OBJECT')
bpy.ops.wm.save_as_mainfile(filepath=str(source/'CinematicKit_v002.blend'))
for col in (rifle,skyline):
    authored_parts = [o.name for o in col.objects]
    for obj in list(col.objects):
        bpy.context.view_layer.objects.active = obj
        for modifier in list(obj.modifiers):
            bpy.ops.object.modifier_apply(modifier=modifier.name)
    groups = ([o for o in col.objects if o == magazine or o.parent == magazine],
              [o for o in col.objects if o != magazine and o.parent != magazine and o != optic_glass]) if col==rifle else (list(col.objects),)
    for group in groups:
        bpy.ops.object.select_all(action='DESELECT')
        for obj in group:
            obj.select_set(True)
        bpy.context.view_layer.objects.active = magazine if magazine in group else group[0]
        bpy.ops.object.join()
        bpy.context.object.name = 'Magazine' if magazine in group else ('Rifle_Body' if col==rifle else 'Distant_City')
    bpy.ops.object.select_all(action='DESELECT')
    for obj in col.objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active=next(iter(col.objects))
    if col==rifle:
        bpy.ops.object.select_all(action='DESELECT')
        for obj in col.objects:
            if obj.type=='MESH':
                bpy.context.view_layer.objects.active=obj
                obj.select_set(True)
                bpy.ops.object.mode_set(mode='EDIT')
                bpy.ops.mesh.select_all(action='SELECT')
                bpy.ops.uv.cube_project(cube_size=.1)
                bpy.ops.object.mode_set(mode='OBJECT')
                obj.select_set(False)
        for obj in col.objects:
            obj.select_set(True)
    bpy.ops.export_scene.gltf(filepath=str(out/(col.name+'.glb')),export_format='GLB',
                              use_selection=True,export_apply=True,export_yup=True,export_cameras=False,export_lights=False)
    graph=bpy.context.evaluated_depsgraph_get()
    triangles=sum(sum(len(p.vertices)-2 for p in o.evaluated_get(graph).data.polygons) for o in col.objects if o.type=='MESH')
    report['assets'].append({'id':col.name,'objects':len(col.objects),'triangles':triangles,'authored_parts':authored_parts})
(root/'logs/TASK-009-asset-audit.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
(root/'logs/TASK-009-asset-audit-v002.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print('CINEMATIC ASSET AUDIT',json.dumps({**report,'assets':[{k:v for k,v in a.items() if k!='authored_parts'} for a in report['assets']]}),flush=True)
