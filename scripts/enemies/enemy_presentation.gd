extends Node3D
## Presentation only: delivered skeleton/actions, independent AK, original AI/damage authority.
var actor:CharacterBody3D
var model:Node3D
var skeleton:Skeleton3D
var player:AnimationPlayer
var weapon_hand:BoneAttachment3D
var gun:Node3D
var muzzle:Marker3D
var flash:Node3D
var clips:Dictionary={}
var current_clip:=""
var hips_bone:="mixamorig_Hips"
var crouched:=true
var shot_remaining:=0.0
var death_mount:=Transform3D.IDENTITY
var mount_frozen:=false
var grip:=Vector3(0,-.055,.08)
var aim_point:=Vector3.ZERO
var has_aim_point:=false
func _ready()->void:
 actor=get_parent().get_parent()
 _setup.call_deferred()
func _setup()->void:
 model=load("res://assets/models/task010/enemy_fighter.glb").instantiate();add_child(model)
 skeleton=model.find_children("*","Skeleton3D",true,false)[0]
 player=model.find_children("*","AnimationPlayer",true,false)[0]
 var library:=AnimationLibrary.new()
 for name in player.get_animation_list():
  for wanted in ["Fire","Move","Crouch","Death"]:
   if name.ends_with(wanted):
    var animation:Animation=player.get_animation(name).duplicate(true)
    animation.loop_mode=Animation.LOOP_NONE if wanted=="Death" else Animation.LOOP_LINEAR
    if wanted=="Move":
     for track in animation.get_track_count():
      if animation.track_get_type(track)==Animation.TYPE_POSITION_3D and str(animation.track_get_path(track)).ends_with(hips_bone):
       var first:Vector3=animation.track_get_key_value(track,0)
       for key in animation.track_get_key_count(track):
        var value:Vector3=animation.track_get_key_value(track,key);value.x=first.x;value.z=first.z;animation.track_set_key_value(track,key,value)
    library.add_animation(wanted,animation);clips[wanted]=wanted
 for pair in [["Idle","Fire"],["CrouchIdle","Crouch"]]:
  var pose:Animation=library.get_animation(pair[1]).duplicate(true);pose.length=.1;pose.loop_mode=Animation.LOOP_LINEAR
  for track in pose.get_track_count():
   for key in range(pose.track_get_key_count(track)-1,0,-1):pose.track_remove_key(track,key)
   if pose.track_get_key_count(track)>0:pose.track_set_key_time(track,0,0)
  library.add_animation(pair[0],pose);clips[pair[0]]=pair[0]
 for name in player.get_animation_library_list():player.remove_animation_library(name)
 player.add_animation_library("",library)
 player.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
 player.set_process(false);player.set_physics_process(false)
 player.play("Fire");player.advance(0)
 # Source forward is measured from the delivered two-hand firing pose.
 var forward:=(_palm("Left")-_palm("Right")).normalized()
 var local:Vector3=global_basis.inverse()*forward
 rotation.y=atan2(-local.x,-local.z)
 weapon_hand=BoneAttachment3D.new();weapon_hand.name="WeaponHand";weapon_hand.bone_name="mixamorig_RightHand";skeleton.add_child(weapon_hand)
 gun=load("res://assets/models/task010/ak47.glb").instantiate();gun.name="AK47";weapon_hand.add_child(gun)
 var data:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/enemy_visual.json"))
 var point:Array=data.ak_muzzle
 muzzle=Marker3D.new();muzzle.name="Muzzle";muzzle.position=Vector3(point[0],point[1],point[2]);gun.add_child(muzzle)
 flash=preload("res://scripts/enemies/enemy_muzzle_flash.gd").new();muzzle.add_child(flash)
 actor.get_node("EnemyWeapon").fired.connect(_on_fired)
 actor.state_changed.connect(_on_state)
 _bind_muzzle.call_deferred()
 _process(0)
func _bind_muzzle()->void:
 actor.get_node("EnemyWeapon").muzzle=muzzle
func _bone(name_value:String)->Transform3D:
 return skeleton.global_transform*skeleton.get_bone_global_pose(skeleton.find_bone("mixamorig_"+name_value))
func _palm(side:String)->Vector3:
 return _bone(side+"Hand").origin.lerp(_bone(side+"HandIndex1").origin,.55)
func _on_fired(_origin:Vector3,_impact:Vector3,_collider:Node)->void:
 if not actor.is_alive():return
 shot_remaining=.25;flash.fire()
func aim_at(point:Vector3)->void:
 aim_point=point;has_aim_point=true
func _on_state(_id:StringName,state:StringName)->void:
 if state==&"DEAD":
  death_mount=gun.transform;mount_frozen=true;shot_remaining=0;flash.stop()
func _process(delta:float)->void:
 if player==null:return
 shot_remaining=maxf(0,shot_remaining-delta)
 var moving:=Vector2(actor.velocity.x,actor.velocity.z).length()>.1
 var selected:="Death" if not actor.is_alive() else ("Move" if moving else (("Crouch" if crouched else "Fire") if shot_remaining>0 else ("CrouchIdle" if crouched else "Idle")))
 if selected!=current_clip:
  player.play(clips[selected],.12);current_clip=selected
 player.speed_scale=clampf(Vector2(actor.velocity.x,actor.velocity.z).length()/2.8,.5,1.4) if selected=="Move" else 1.0
 if player.is_playing():player.advance(delta)
 if mount_frozen:
  gun.transform=death_mount
 else:
  var right:=_palm("Right");var left:=_palm("Left")
  var forward:Vector3=(aim_point-right).normalized() if has_aim_point else (left-right).normalized()
  var basis:=Basis.looking_at(forward,Vector3.UP)
  if not has_aim_point:basis=basis*Basis(Vector3.RIGHT,-atan2(.075,.28))
  var desired:=Transform3D(basis,right-basis*grip)
  gun.transform=_bone("RightHand").affine_inverse()*desired
