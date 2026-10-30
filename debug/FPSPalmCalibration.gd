extends RefCounted
## Derive a palm marker from actual bind-space mesh, skin weights and black palm texture.
## This never moves a mesh, a bone, an animation, or a weapon socket.

static func _bind(skin: Skin, skeleton: Skeleton3D, bone: int) -> int:
 if bone < 0:
  return -1
 for i in skin.get_bind_count():
  var name: StringName = skin.get_bind_name(i)
  if (name != &"" and name == skeleton.get_bone_name(bone)) or (name == &"" and skin.get_bind_bone(i) == bone):
   return i
 return -1

static func _child(skeleton: Skeleton3D, parent: int, prefix: String) -> int:
 for i in skeleton.get_bone_count():
  if skeleton.get_bone_parent(i) == parent and skeleton.get_bone_name(i).begins_with(prefix):
   return i
 return -1

static func _median(values: Array) -> float:
 values.sort()
 return float(values[int(values.size() / 2)])

static func calibrate(mesh: MeshInstance3D, skeleton: Skeleton3D, hand: String) -> Dictionary:
 var hand_index := skeleton.find_bone(hand)
 var hand_bind := _bind(mesh.skin, skeleton, hand_index)
 var index_bind := _bind(mesh.skin, skeleton, _child(skeleton, hand_index, "index"))
 var pink_bind := _bind(mesh.skin, skeleton, _child(skeleton, hand_index, "pink"))
 var middle_bind := _bind(mesh.skin, skeleton, _child(skeleton, hand_index, "middle"))
 if mini(mini(hand_bind, index_bind), mini(pink_bind, middle_bind)) < 0:
  return {"valid":false,"reason":"required hand/finger skin binds are unresolved"}
 var wrist := mesh.skin.get_bind_pose(hand_bind).affine_inverse().origin
 var index := mesh.skin.get_bind_pose(index_bind).affine_inverse().origin
 var pink := mesh.skin.get_bind_pose(pink_bind).affine_inverse().origin
 var middle := mesh.skin.get_bind_pose(middle_bind).affine_inverse().origin
 var up := (middle - wrist).normalized()
 var across := (index - pink).normalized()
 var plane := across.cross(up).normalized()
 var descendants := {}
 for bone in skeleton.get_bone_count():
  var ancestor := bone
  while ancestor >= 0 and ancestor != hand_index:
   ancestor = skeleton.get_bone_parent(ancestor)
  if ancestor == hand_index:
   var binding := _bind(mesh.skin,skeleton,bone)
   if binding >= 0:descendants[binding] = true
 var palm_length := (middle-wrist).length()
 var anatomical_center := wrist+up*palm_length*.55
 var palm_half_width := (index-pink).length()*.7
 var halves := [[], []]
 for surface in mesh.mesh.get_surface_count():
  var arrays: Array = mesh.mesh.surface_get_arrays(surface)
  var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
  var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
  var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
  var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
  var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
  var influences: int = weights.size() / vertices.size()
  var material := mesh.mesh.surface_get_material(surface) as StandardMaterial3D
  if material == null or material.albedo_texture == null:
   return {"valid":false,"reason":"source glove PBR albedo is missing"}
  var image := material.albedo_texture.get_image()
  if image.is_compressed():
   image.decompress()
  for vertex in vertices.size():
   var hand_weight := 0.0
   for influence in influences:
    var slot := vertex * influences + influence
    if descendants.has(bones[slot]):
     hand_weight += weights[slot]
   var dot := normals[vertex].normalized().dot(plane)
   var along := (vertices[vertex]-wrist).dot(up)/palm_length
   var across_palm := absf((vertices[vertex]-anatomical_center).dot(across))
   if hand_weight < .5 or along < .25 or along > .8 or across_palm > palm_half_width or absf(dot) < .65:
    continue
   var px := clampi(int(fposmod(uv[vertex].x, 1) * image.get_width()), 0, image.get_width()-1)
   var py := clampi(int((1.0 - fposmod(uv[vertex].y, 1)) * image.get_height()), 0, image.get_height()-1)
   var color := image.get_pixel(px,py)
   halves[0 if dot > 0 else 1].append({"luma":(color.r+color.g+color.b)/3,"point":vertices[vertex],"vertex":vertex,"surface":surface})
 if halves[0].is_empty() or halves[1].is_empty():
  return {"valid":false,"reason":"not enough palm/back surface samples; no invented marker"}
 var light := [[],[]]
 for half in range(2):
  for sample in halves[half]:light[half].append(sample.luma)
 var medians := [_median(light[0]),_median(light[1])]
 var selected := 0 if medians[0] < medians[1] else 1
 var centers := []
 for half in range(2):
  var coordinates := [[],[],[]]
  for sample in halves[half]:
   for axis in range(3):coordinates[axis].append(sample.point[axis])
  centers.append(Vector3(_median(coordinates[0]),_median(coordinates[1]),_median(coordinates[2])))
 var selected_samples:Array=halves[selected].duplicate()
 selected_samples.sort_custom(func(a:Dictionary,b:Dictionary)->bool:return a.point.distance_squared_to(anatomical_center)<b.point.distance_squared_to(anatomical_center))
 var center:=Vector3.ZERO
 var vertex_ids:=[]
 for i in mini(5,selected_samples.size()):
  center+=selected_samples[i].point
  vertex_ids.append([selected_samples[i].surface,selected_samples[i].vertex])
 center/=mini(5,selected_samples.size())
 var authored_normal := plane * (1 if selected == 0 else -1)
 # A dark texture sample alone does not prove an outward normal. Verify the shell sides.
 var signed_separation:float = (center-centers[1-selected]).dot(plane)
 if absf(signed_separation)<.002:
  return {"valid":false,"reason":"palm/back surface separation is ambiguous"}
 var normal := plane * (1 if signed_separation>0 else -1)
 up = (up-normal*normal.dot(up)).normalized()
 var x := up.cross(normal).normalized()
 var frame := Basis(x,normal.cross(x).normalized(),normal)
 var local := mesh.skin.get_bind_pose(hand_bind) * Transform3D(frame,center)
 local.basis = local.basis.orthonormalized()
 return {"valid":true,"transform":local,"metadata":{"kind":"black_palmar_surface_from_skin_and_texture","algorithm":"anatomical_midpalm_v2","sample_vertices":vertex_ids,"wrist_to_mcp_m":palm_length,"longitudinal_fraction":(center-wrist).dot(up)/palm_length,"shell_separation_m":absf(signed_separation),"authored_normals_agree":normal.dot(authored_normal)>.9,"image_sampling":"3D UV V flipped for CPU Image row coordinates","bone":hand,"hand_bind":hand_bind,"surface_samples":halves[selected].size(),"median_palm_luma":medians[selected],"median_dorsal_luma":medians[1-selected],"bone_local_position":[local.origin.x,local.origin.y,local.origin.z],"bone_local_basis":[[local.basis.x.x,local.basis.x.y,local.basis.x.z],[local.basis.y.x,local.basis.y.y,local.basis.y.z],[local.basis.z.x,local.basis.z.y,local.basis.z.z]],"hand_bind_frame":_transform_data(mesh.skin.get_bind_pose(hand_bind).affine_inverse()),"anatomy_user_approved":false}}

static func _transform_data(value:Transform3D)->Dictionary:
 return {"origin":[value.origin.x,value.origin.y,value.origin.z],"basis":[[value.basis.x.x,value.basis.x.y,value.basis.x.z],[value.basis.y.x,value.basis.y.y,value.basis.y.z],[value.basis.z.x,value.basis.z.y,value.basis.z.z]]}
