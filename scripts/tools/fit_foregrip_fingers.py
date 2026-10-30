"""Offline finger flex fitting against the delivered foregrip surface; no wrist movement."""
import bpy,math
from mathutils import Matrix,Vector,Quaternion
from mathutils.bvhtree import BVHTree

def fit_left(rig,C,root,palm_rest):
 before=set(bpy.data.objects)
 bpy.ops.import_scene.gltf(filepath=str(root/'assets/models/task009/v003/ar15_revision.glb'))
 imported=set(bpy.data.objects)-before
 body=next(o for o in imported if o.type=='MESH' and o.name=='Rifle_Body')
 vertices=[C@(body.matrix_world@v.co) for v in body.data.vertices]
 faces=[list(p.vertices) for p in body.data.polygons if -.35<(sum(vertices[i].z for i in p.vertices)/len(p.vertices))<-.14 and 0<(sum(vertices[i].y for i in p.vertices)/len(p.vertices))<.105]
 surface=BVHTree.FromPolygons(vertices,faces,all_triangles=False)
 hand=rig.pose.bones['L_Hand'];report={}
 for family,radius in [('index_L',.009),('middle_L',.010),('ring_L',.009),('pink_L',.008)]:
  bone=next(b for b in rig.pose.bones if b.name.startswith(family+'.L_'));chain=[]
  while bone:
   chain.append(bone);bone=next((b for b in bone.children if b.name.startswith(family)),None)
  local=[];axes=[]
  for i,bone in enumerate(chain):
   parent=chain[i-1].bone if i else hand.bone
   local.append(parent.matrix_local.inverted()@bone.bone.matrix_local)
   if i<3:
    direction=chain[i+1].bone.head_local-bone.bone.head_local
    axes.append((bone.bone.matrix_local.to_3x3().inverted()@direction.normalized().cross(palm_rest)).normalized())
  def points(angles):
   frame=hand.matrix.copy();result=[]
   for i in range(4):
    frame=frame@local[i]
    if i<3:frame=frame@Quaternion(axes[i],angles[i]).to_matrix().to_4x4()
    result.append(C@frame.translation)
   return result
  def cost(angles,aperture=False):
   positions=points(angles);value=0.0
   for a,b in zip(positions,positions[1:]):
    for t in (.3,.65,1.0):
     point=a.lerp(b,t);near,normal,_,distance=surface.find_nearest(point)
     radial=near-Vector((0,.052,near.z))
     if normal.dot(radial)<0:normal=-normal
     signed=(point-near).dot(normal)
     value+=100*max(0,radius-signed)**2+(distance-radius-.002)**2
     # Eye at (0,.135,.33), actual lens at z=.042 with 18mm clear radius.
     # Keep the glove envelope below the diverging aperture cone, not just its centre ray.
     aperture_bottom=.135-.018*(.33-point.z)/(.33-.042)
     if aperture:value+=500*max(0,point.y+radius+.004-aperture_bottom)**2
   return value
  best=[.5,.8,.35];limits=(1.65,1.8,1.35)
  for step in (.3,.1,.025):
   for iteration in range(5):
    previous=best[:]
    for joint in range(3):
     candidates=[]
     for n in range(int(limits[joint]/step)+1):
      candidate=best[:];candidate[joint]=n*step
      candidates.append((cost(candidate),candidate))
     best=min(candidates,key=lambda pair:pair[0])[1]
    if previous==best:break
  # Preserve the proximal contact solution; clear the sight cone with distal joints.
  for step in (.15,.025):
   for iteration in range(4):
    previous=best[:]
    for joint in (1,2):
     candidates=[]
     for n in range(int(limits[joint]/step)+1):
      candidate=best[:];candidate[joint]=n*step
      candidates.append((cost(candidate,True),candidate))
     best=min(candidates,key=lambda pair:pair[0])[1]
    if previous==best:break
  for bone,axis,angle in zip(chain,axes,best):bone.rotation_quaternion=Quaternion(axis,angle)
  report[family]={'joint_angles_rad':best,'centerline_gun_local':[list(p) for p in points(best)],'surface_cost':cost(best),'glove_radius_m':radius}
 bpy.context.view_layer.update()
 # Thumb opposition is an independent two-joint solve outside the left guard shell.
 chain=[];bone=next(b for b in rig.pose.bones if b.name.startswith('thumb_L.L_'))
 while bone:
  chain.append(bone);bone=next((b for b in bone.children if b.name.startswith('thumb_L')),None)
 # Evaluate real mixed-weight webbing for each reachable thumb configuration.
 glove=bpy.data.objects['Object_7'];web_edges=[]
 for edge in glove.data.edges:
  names={glove.vertex_groups[g.group].name for i in edge.vertices for g in glove.data.vertices[i].groups if g.weight>.01}
  if any(n.startswith('thumb_L') and '.L_' in n for n in names) and any(n.startswith('index_L') and '.L_' in n for n in names):web_edges.append(tuple(edge.vertices))
 web_vertices={i for edge in web_edges for i in edge}
 influences={i:[(rig.pose.bones[glove.vertex_groups[g.group].name],g.weight) for g in glove.data.vertices[i].groups if glove.vertex_groups[g.group].name in rig.pose.bones] for i in web_vertices}
 inverse={b.name:b.bone.matrix_local.inverted() for b in rig.pose.bones}
 saved=[bone.matrix_basis.copy() for bone in chain];choices=[]
 for y in (.035,.05,.065):
  for z in (-.27,-.285,-.30):
   for pole_value in [(-1,0,0),(0,0,-1),(-1,0,-1),(1,0,-1)]:
    for bone,basis in zip(chain,saved):bone.matrix_basis=basis
    bpy.context.view_layer.update()
    a,b,c=[bone.matrix.translation.copy() for bone in chain]
    target=C.inverted()@Vector((-.04,y,z));l1=(b-a).length;l2=(c-b).length
    direction=target-a;distance=direction.length
    if not abs(l1-l2)<distance<l1+l2:continue
    direction.normalize();pole=C.inverted()@Vector(pole_value);bend=(pole-direction*pole.dot(direction)).normalized()
    projection=(l1*l1-l2*l2+distance*distance)/(2*distance)
    elbow=a+direction*projection+bend*math.sqrt(l1*l1-projection*projection)
    rotation=(b-a).rotation_difference(elbow-a).to_matrix().to_4x4()
    chain[0].matrix=Matrix.Translation(a)@rotation@Matrix.Translation(-a)@chain[0].matrix
    bpy.context.view_layer.update();b,c=[bone.matrix.translation.copy() for bone in chain[1:]]
    rotation=(c-b).rotation_difference(target-b).to_matrix().to_4x4()
    chain[1].matrix=Matrix.Translation(b)@rotation@Matrix.Translation(-b)@chain[1].matrix
    bpy.context.view_layer.update()
    transforms={bone.name:bone.matrix@inverse[bone.name] for values in influences.values() for bone,_ in values}
    positions={i:sum((transforms[bone.name]@glove.data.vertices[i].co*weight for bone,weight in values),Vector()) for i,values in influences.items()}
    excess=max((positions[i]-positions[j]).length-(glove.data.vertices[i].co-glove.data.vertices[j].co).length for i,j in web_edges)
    near,_,_,distance=surface.find_nearest(C@target)
    choices.append({'excess':excess,'score':excess**2*4+(distance-.009)**2,'target':list(C@target),'basis':[bone.matrix_basis.copy() for bone in chain]})
 valid=[choice for choice in choices if choice['excess']<.029]
 assert valid,('No thumb contact solution meets original webbing bound',min(c['excess'] for c in choices),report)
 best=min(valid,key=lambda choice:choice['score'])
 for bone,basis in zip(chain,best['basis']):bone.matrix_basis=basis
 bpy.context.view_layer.update()
 report['thumb_L']={'target_gun_local':best['target'],'actual_tip_gun_local':list(C@chain[-1].matrix.translation),'webbing_edge_increase_m':best['excess'],'evaluated_candidates':len(choices),'valid_candidates':len(valid),'method':'CMC/MCP surface IK constrained by actual original mixed skin weights; wrist fixed'}
 for obj in imported:bpy.data.objects.remove(obj,do_unlink=True)
 return report
