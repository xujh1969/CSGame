"""TASK-008 original modular art; run in an isolated Blender --factory-startup process.
All shapes, UVs and tileable color/roughness/normal textures are project-generated.
Godot coordinates are converted explicitly: (x,y,z) -> Blender (x,-z,y).
"""
import bpy
import math
import json
from pathlib import Path
import numpy as np
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'assets/models/task008'
SOURCE = ROOT / 'assets/source/task008'
TEX = ROOT / 'assets/textures/task008'
for folder in (OUT, SOURCE, TEX):
    folder.mkdir(parents=True, exist_ok=True)
assert bpy.data.filepath == '', 'Use --factory-startup; never run this against a user blend.'
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
bpy.context.scene.unit_settings.system = 'METRIC'
bpy.context.scene.unit_settings.scale_length = 1.0


def field(n, cells_x, cells_y, seed):
    rng = np.random.default_rng(seed)
    grid = rng.random((cells_y, cells_x)).astype(np.float32)
    x = np.arange(n, dtype=np.float32) / n * cells_x
    y = np.arange(n, dtype=np.float32) / n * cells_y
    ix, iy = x.astype(int), y.astype(int)
    fx, fy = x - ix, y - iy
    fx, fy = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy)
    a = grid[iy[:, None] % cells_y, ix[None, :] % cells_x]
    b = grid[iy[:, None] % cells_y, (ix[None, :] + 1) % cells_x]
    c = grid[(iy[:, None] + 1) % cells_y, ix[None, :] % cells_x]
    d = grid[(iy[:, None] + 1) % cells_y, (ix[None, :] + 1) % cells_x]
    return (a * (1 - fx) + b * fx) * (1 - fy[:, None]) + (c * (1 - fx) + d * fx) * fy[:, None]


def image(name, values, color=False):
    n = values.shape[0]
    rgba = np.ones((n, n, 4), dtype=np.float32)
    rgba[:, :, :3] = values[:, :, None] if values.ndim == 2 else values
    img = bpy.data.images.new(name, n, n, alpha=False)
    img.colorspace_settings.name = 'sRGB' if color else 'Non-Color'
    img.pixels.foreach_set(np.clip(rgba, 0, 1).ravel())
    img.filepath_raw = str(TEX / (name + '.png'))
    img.file_format = 'PNG'
    img.save()
    img.pack()
    return img


def textured(name, base, seed, kind):
    n = 1024
    broad = field(n, 5, 5, seed)
    medium = field(n, 32, 32, seed + 1)
    grain = field(n, 320, 320, seed + 2)
    height = broad * .2 + medium * .35 + grain * .1
    tint = .72 + broad * .3 + medium * .17 + grain * .1
    if kind == 'plaster':
        peel = np.clip((broad * .6 + medium * .4 - .57) * 14, 0, 1)
        stain = field(n, 90, 5, seed + 3) * .16
        tint -= peel * .29 + stain
        height += (1 - peel) * .22
    elif kind == 'asphalt':
        cracks = np.exp(-np.abs(medium - .5) * 160) * np.clip((broad - .4) * 5, 0, 1)
        tint -= cracks * .45
        height -= cracks * .3
    elif kind == 'wood':
        stripes = field(n, 240, 6, seed + 3)
        tint = .6 + stripes * .7 + broad * .2
        height += stripes * .25
    albedo = np.array(base)[None, None, :] * tint[:, :, None]
    roughness = np.clip(.73 + medium * .2, .6, .98)
    dx = np.roll(height, -1, axis=1) - np.roll(height, 1, axis=1)
    dy = np.roll(height, -1, axis=0) - np.roll(height, 1, axis=0)
    normals = np.stack((-dx * 2.2, -dy * 2.2, np.ones_like(height)), axis=-1)
    normals /= np.linalg.norm(normals, axis=-1, keepdims=True)
    normal_img = image(name + '_normal', normals * .5 + .5)
    color_img = image(name + '_albedo', albedo, True)
    if kind == 'plaster':
        color_img = bpy.data.images.load(str(TEX / 'plaster_imagegen_albedo_v001.png'))
        color_img.colorspace_settings.name = 'sRGB'
        color_img.pack()
    rough_img = image(name + '_roughness', roughness)
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    tree = mat.node_tree
    bsdf = tree.nodes.get('Principled BSDF')
    for img, input_name in ((color_img, 'Base Color'), (rough_img, 'Roughness')):
        node = tree.nodes.new('ShaderNodeTexImage')
        node.image = img
        tree.links.new(node.outputs['Color'], bsdf.inputs[input_name])
    node = tree.nodes.new('ShaderNodeTexImage')
    node.image = normal_img
    normal = tree.nodes.new('ShaderNodeNormalMap')
    normal.inputs['Strength'].default_value = .2 if kind == 'plaster' else .55
    tree.links.new(node.outputs['Color'], normal.inputs['Color'])
    tree.links.new(normal.outputs['Normal'], bsdf.inputs['Normal'])
    return mat


def solid(name, color, metallic=0, roughness=.8):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get('Principled BSDF')
    bsdf.inputs['Base Color'].default_value = (*color, 1)
    bsdf.inputs['Roughness'].default_value = roughness
    bsdf.inputs['Metallic'].default_value = metallic
    return mat


M = {
    'plaster': textured('Warm_peeled_plaster', (.64, .57, .43), 8001, 'plaster'),
    'stone': textured('Pitted_concrete', (.46, .44, .38), 8002, 'stone'),
    'road': textured('Cracked_asphalt', (.15, .145, .13), 8003, 'asphalt'),
    'wood': textured('Dry_timber', (.31, .19, .08), 8004, 'wood'),
    'metal': solid('Oxidized_steel', (.13, .16, .15), .55, .7),
    'rust': solid('Rust', (.26, .105, .04), .25, .95),
    'dark': solid('Window_shadow', (.025, .035, .035), 0, .88),
    'red': solid('Faded_oxide_paint', (.33, .095, .055)),
    'white': solid('Worn_white_paint', (.68, .64, .51)),
    'cloth': solid('Awning_fabric', (.24, .29, .20)),
}


class Kit:
    def __init__(self, name):
        self.name, self.groups = name, {}

    def poly(self, vertices, faces, material, uv_scale=2.0):
        group = self.groups.setdefault(material, [[], [], []])
        offset = len(group[0])
        group[0].extend(vertices)
        for face in faces:
            group[1].append([offset + i for i in face])
            a, b, c = (Vector(vertices[i]) for i in face[:3])
            normal = (b-a).cross(c-a)
            axis = max(range(3), key=lambda i: abs(normal[i]))
            axes = (0, 2) if axis == 1 else ((0, 1) if axis == 2 else (2, 1))
            group[2].append([(vertices[i][axes[0]] / uv_scale, vertices[i][axes[1]] / uv_scale) for i in face])

    def box(self, pos, size, material='stone'):
        x, y, z = pos
        a, b, c = (v / 2 for v in size)
        vertices = [(x+dx*a, y+dy*b, z+dz*c) for dx, dy, dz in
                    [(-1,-1,-1),(1,-1,-1),(1,1,-1),(-1,1,-1),(-1,-1,1),(1,-1,1),(1,1,1),(-1,1,1)]]
        self.poly(vertices, [(3,2,1,0),(4,5,6,7),(0,1,5,4),(2,3,7,6),(0,4,7,3),(1,2,6,5)], material)

    def rod(self, start, end, radius, material='metal', sides=8):
        a, b = Vector(start), Vector(end)
        direction = (b-a).normalized()
        cross = direction.cross(Vector((0,1,0)) if abs(direction.y) < .9 else Vector((1,0,0))).normalized()
        up = direction.cross(cross).normalized()
        vertices = [tuple(center + radius * (cross * math.cos(i*math.tau/sides) + up*math.sin(i*math.tau/sides))) for center in (a,b) for i in range(sides)]
        faces = [tuple(reversed(range(sides))), tuple(range(sides, 2*sides))]
        faces += [(i,(i+1)%sides,(i+1)%sides+sides,i+sides) for i in range(sides)]
        self.poly(vertices, faces, material)

    def export(self):
        bpy.ops.object.select_all(action='DESELECT')
        collection = bpy.data.collections.new(self.name)
        bpy.context.scene.collection.children.link(collection)
        objects = []
        for material, (vertices, faces, uvs) in self.groups.items():
            mesh = bpy.data.meshes.new(self.name + '_' + material)
            mesh.from_pydata([(x,-z,y) for x,y,z in vertices], [], faces)
            mesh.materials.append(M[material])
            mesh.update()
            uv = mesh.uv_layers.new(name='UVMap')
            for polygon, face_uv in zip(mesh.polygons, uvs):
                for index, value in zip(polygon.loop_indices, face_uv):
                    uv.data[index].uv = value
            obj = bpy.data.objects.new(mesh.name, mesh)
            collection.objects.link(obj)
            if self.name in ('barrier_v001', 'crates_v001'):
                bevel = obj.modifiers.new('Small edge bevel', 'BEVEL')
                bevel.width = .008
                bevel.segments = 2
                bevel.limit_method = 'ANGLE'
            obj.select_set(True)
            objects.append(obj)
        bpy.context.view_layer.objects.active = objects[0]
        bpy.ops.export_scene.gltf(filepath=str(OUT / (self.name + '.glb')), export_format='GLB',
                                  use_selection=True, export_apply=True, export_yup=True,
                                  export_cameras=False, export_lights=False)
        depsgraph = bpy.context.evaluated_depsgraph_get()
        triangles = 0
        for obj in objects:
            evaluated = obj.evaluated_get(depsgraph)
            evaluated_mesh = evaluated.to_mesh()
            triangles += sum(len(p.vertices)-2 for p in evaluated_mesh.polygons)
            evaluated.to_mesh_clear()
        all_vertices = [v for group in self.groups.values() for v in group[0]]
        bounds = [[min(v[a] for v in all_vertices) for a in range(3)], [max(v[a] for v in all_vertices) for a in range(3)]]
        print('ASSET', self.name, 'tris', triangles, 'bounds', bounds, flush=True)
        return {'id': self.name, 'triangles': triangles, 'bounds_godot': bounds, 'material_count': len(objects)}


def window(kit, x, y, width=1.15):
    kit.box((x,y,-.27), (width,1.55,.08), 'dark')
    for edge in (-1,1):
        kit.box((x+edge*(width/2+.04),y,.015), (.09,1.75,.16), 'stone')
        kit.box((x,y+edge*.825,.04), (width+.2,.1,.22), 'stone')
    kit.box((x,y,-.14), (.045,1.5,.06), 'wood')
    kit.box((x,y,-.14), (width,.045,.06), 'wood')
    for bar in range(5):
        kit.rod((x-width/2+.1+bar*(width-.2)/4, y-.7,.12), (x-width/2+.1+bar*(width-.2)/4,y+.7,.12), .014)


def facade(name, shop=False):
    kit = Kit(name)
    height = 7.5 if shop else 8.5
    kit.box((0,1.7,-.3), (8,3.4,.6), 'plaster')
    kit.box((0,height/2,-1.6), (8,height,.4), 'plaster')
    levels = [5.1] if shop else [4.5,7]
    # Wall strips around genuine recessed window openings.
    last_y = 3.4
    for y in levels:
        bottom, top = y-.825, y+.825
        if bottom > last_y:
            kit.box((0,(last_y+bottom)/2,-.3),(8,bottom-last_y,.6),'plaster')
        last_x = -4
        for x in (-2.5,0,2.5):
            left = x-.675
            kit.box(((last_x+left)/2,y,-.3),(left-last_x,1.65,.6),'plaster')
            window(kit,x,y)
            last_x = x+.675
        kit.box(((last_x+4)/2,y,-.3),(4-last_x,1.65,.6),'plaster')
        last_y = top
    kit.box((0,(last_y+height)/2,-.3),(8,height-last_y,.6),'plaster')
    kit.box((0,.28,.035),(8,.56,.12),'stone')
    kit.box((0,height+.06,-.3),(8.1,.12,.85),'stone')
    if shop:
        for x in (-2,2):
            kit.box((x,1.35,.04),(2.9,2.6,.08),'metal')
            for row in range(22):
                kit.box((x,.13+row*.115,.095),(2.88,.025,.025),'rust' if row%8 == 0 else 'metal')
            kit.box((x,2.8,.1),(3.1,.36,.18),'wood')
        kit.box((0,3.05,.65),(7.8,.1,1.4),'cloth')
        kit.box((0,2.88,1.32),(7.8,.3,.06),'cloth')
        for x in (-3.8,-1.2,1.2,3.8):
            kit.rod((x,2.7,.08),(x,2.98,1.32),.02)
    else:
        kit.box((0,1.2,.025),(1.25,2.4,.06),'wood')
        for x in (-2.5,2.5):
            kit.box((x,3.65,.57),(1.7,.16,1.12),'stone')
            kit.box((x,3.55,1.06),(1.7,.14,.12),'stone')
            for side in (-1,1):
                kit.rod((x+side*.79,3.75,1.02),(x+side*.79,4.45,1.02),.025)
            for bx in range(9):
                px = x-.76+bx*.19
                kit.rod((px,3.75,1.02),(px,4.35,1.02),.013)
            kit.rod((x-.82,4.4,1.02),(x+.82,4.4,1.02),.028)
            for edge in (-1, 1):
                side_x = x + edge * .79
                kit.rod((side_x,3.75,.12),(side_x,4.4,.12),.025)
                kit.rod((side_x,4.4,.12),(side_x,4.4,1.02),.028)
                for depth in (.2,.4,.6,.8):
                    kit.rod((side_x,3.75,depth),(side_x,4.35,depth),.013)
    # Drainpipe, externally mounted AC, cables and narrow masonry courses.
    kit.rod((3.75,.05,.09),(3.75,height,.09),.045,'rust')
    kit.box((1.3,3.25,.27),(.85,.5,.5),'white')
    for bx in range(12):
        kit.box((.94+bx*.065,3.25,.535),(.025,.36,.02),'metal')
    for y in (3.4,6.1):
        kit.box((0,y,.025),(8,.07,.08),'stone')
    return kit


assets = []
assets.append(facade('residential_v002').export())
assets.append(facade('shopfront_v001',True).export())
road = Kit('road_v001')
road.box((0,-.15,-11),(16,.3,34),'road')
for side in (-1,1):
    # Pavement is deliberately level with the authoritative original ground.
    road.box((side*4.8,.003,-11),(1.6,.006,34),'stone')
    for z in np.arange(5,-28,-.8):
        road.box((side*4.8,.007,float(z)),(1.59,.006,.025),'dark')
assets.append(road.export())
barrier = Kit('barrier_v001')
barrier.box((0,.125,0),(2.5,.25,.9),'stone')
barrier.box((0,.625,0),(2.5,.75,.45),'stone')
for x in (-.9,-.3,.3,.9):
    barrier.box((x,.67,.23),(.28,.24,.016),'red')
for x in (-.8,.8):
    for offset in (-.06,.06):
        barrier.rod((x+offset,.94,0),(x+offset,1.06,0),.018)
    barrier.rod((x-.06,1.06,0),(x+.06,1.06,0),.018)
assets.append(barrier.export())
crates = Kit('crates_v001')
for x,height in ((-.45,1.2),(.45,.8)):
    crates.box((x,height/2,0),(.9,height,.8),'wood')
    for side in (-1,1):
        for edge in (-1,1):
            crates.box((x+edge*.34,height/2,side*.405),(.07,height,.025),'metal')
        for y in np.arange(.12,height,.2):
            crates.box((x,float(y),side*.41),(.85,.014,.025),'dark')
assets.append(crates.export())

# Original reusable blockout for the vehicle that the user will replace.
proxy = Kit('vehicle_proxy_v001')
proxy.box((0,.5,0),(1.8,.5,4.2),'metal')
proxy.box((0,1.02,.1),(1.5,.55,2.2),'dark')
for side in (-1,1):
    for z in (-1.35,1.35):
        proxy.rod((side*.75,.32,z),(side*.95,.32,z),.32,'dark',12)
assets.append(proxy.export())

# One noncritical decorative mesh: low rubble only, outside the playable centre.
debris = Kit('street_details_v002')
rng = np.random.default_rng(20261029)
debris_colliders = []

def fragment(center, size, material):
    x,y,z = center
    sx,sy,sz = size
    angle = rng.uniform(0,math.tau)
    vertices = []
    for index in range(7):
        a = angle + index*math.tau/7
        radius = rng.uniform(.65,1)
        vertices.append((x+math.cos(a)*sx*.5*radius, y+rng.uniform(0,sy*.15), z+math.sin(a)*sz*.5*radius))
    vertices += [(x+sx*.08,y+sy,z-sz*.08)]
    faces = [tuple(reversed(range(7)))] + [(i,(i+1)%7,7) for i in range(7)]
    debris.poly(vertices,faces,material)

for side in (-1,1):
    for cluster_z in (-2,-8,-15,-22):
        for i in range(65):
            x = side*max(1.15,min(5.65,abs(rng.normal(4.55,.85))))
            z = max(-26,min(4,rng.normal(cluster_z,1.7)))
            size = rng.uniform(.045,.24)
            fragment((float(x),.008,float(z)),(float(size),float(rng.uniform(.012,.065)),float(size*rng.uniform(.5,1.4))),'stone' if i%5 else 'rust')
        for i in range(5):
            x, z = side*rng.uniform(3.8,5.4), rng.normal(cluster_z,.6)
            sx,sy,sz = rng.uniform(.25,.5),rng.uniform(.12,.25),rng.uniform(.25,.55)
            fragment((float(x),0,float(z)),(float(sx),float(sy),float(sz)),'stone')
            debris_colliders.append({'position':[float(x),float(sy*.5),float(z)],'size':[float(sx),float(sy),float(sz)]})
    for i in range(40):
        x, z = side*rng.uniform(.95,5.6),rng.uniform(-25,4)
        sx, sz = rng.uniform(.12,.3),rng.uniform(.08,.18)
        # Bent paper/flat scrap, <=2cm so no invisible walking obstacles.
        vertices=[(float(x-sx),.012,float(z-sz)),(float(x+sx),.014,float(z-sz)),(float(x+sx*.8),.025,float(z+sz)),(float(x-sx),.01,float(z+sz*.7))]
        debris.poly(vertices,[(0,1,2,3),(3,2,1,0)],'white' if i%3 else 'wood')
    for i in range(16):
        x,z=side*rng.uniform(2.5,5.7),rng.uniform(-25,4)
        debris.box((float(x),.018,float(z)),(.06,.025,float(rng.uniform(.3,.8))),'wood' if i%2 else 'rust')
    for z in (1,-7,-15,-23):
        # Wall-to-wall sagging overhead wire, sampled as short cylinders.
        for t in range(12):
            x1, x2 = -5.8+t*11.6/12, -5.8+(t+1)*11.6/12
            y1, y2 = 6.3-.6*math.sin(math.pi*t/12), 6.3-.6*math.sin(math.pi*(t+1)/12)
            if side == 1:
                debris.rod((x1,y1,z),(x2,y2,z),.012,'dark',6)
assets.append(debris.export())
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE / 'StreetKit_v002.blend'))
audit = {'blender_version': bpy.app.version_string, 'source': 'scripts/tools/build_sample_assets.py',
         'license': 'Original project-generated mesh and mathematical maps; imagegen plaster albedo; sample use, release review pending',
         'units': 'meters', 'godot_forward_surface': '+Z', 'assets': assets,
         'source_blend':'res://assets/source/task008/StreetKit_v002.blend',
         'debris_collision_boxes':debris_colliders,
         'external_missing_images': [i.filepath for i in bpy.data.images if i.source == 'FILE' and not i.packed_file and not Path(bpy.path.abspath(i.filepath)).exists()]}
(ROOT / 'logs/TASK-008-asset-audit.json').write_text(json.dumps(audit,indent=2),encoding='utf-8')
print('TASK-008 ASSET BUILD COMPLETE', flush=True)
