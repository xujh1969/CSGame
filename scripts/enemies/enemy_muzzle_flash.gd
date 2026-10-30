extends Node3D
var remaining:=0.0
var material:ShaderMaterial
var lamp:OmniLight3D
var smoke:GPUParticles3D
var shots:=0
func _ready()->void:
 material=ShaderMaterial.new();material.shader=preload("res://assets/materials/enemy_muzzle.gdshader")
 for index in 3:
  var card:=MeshInstance3D.new();var quad:=QuadMesh.new()
  quad.size=Vector2(.16,.16) if index==0 else Vector2(.08,.23)
  card.mesh=quad;card.material_override=material;card.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  if index>0:
   card.rotation=Vector3(PI/2,0,(index-1)*PI/2);card.position.z=-.065
  add_child(card)
 lamp=OmniLight3D.new();lamp.omni_range=3;lamp.light_color=Color(1,.48,.12);lamp.light_energy=0;add_child(lamp)
 smoke=GPUParticles3D.new();smoke.amount=8;smoke.lifetime=.45;smoke.one_shot=true;smoke.explosiveness=.8;smoke.emitting=false
 var process:=ParticleProcessMaterial.new();process.direction=Vector3(0,.3,-1);process.spread=25
 process.initial_velocity_min=.15;process.initial_velocity_max=.35;process.gravity=Vector3(0,.25,0)
 process.scale_min=.2;process.scale_max=1.1
 var gradient:=Gradient.new();gradient.colors=PackedColorArray([Color(.45,.43,.4,.13),Color(.4,.4,.4,0)])
 var ramp:=GradientTexture1D.new();ramp.gradient=gradient;process.color_ramp=ramp;smoke.process_material=process
 var particle:=QuadMesh.new();particle.size=Vector2(.12,.12)
 var mist:=StandardMaterial3D.new();mist.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;mist.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;mist.billboard_mode=BaseMaterial3D.BILLBOARD_PARTICLES
 var texture:=GradientTexture2D.new();var radial:=Gradient.new();radial.colors=PackedColorArray([Color(1,1,1,.5),Color(1,1,1,0)]);texture.gradient=radial;texture.fill=GradientTexture2D.FILL_RADIAL;texture.fill_from=Vector2(.5,.5);texture.fill_to=Vector2(1,.5)
 mist.albedo_texture=texture;mist.vertex_color_use_as_albedo=true;particle.material=mist
 smoke.draw_pass_1=particle;smoke.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(smoke)
func fire()->void:
 shots+=1;remaining=.045
 material.set_shader_parameter("seed",float(shots)*2.39996)
 smoke.restart();smoke.emitting=true
 _process(0)
func stop()->void:
 remaining=0;lamp.light_energy=0;material.set_shader_parameter("strength",0.0)
func _process(delta:float)->void:
 remaining=maxf(0,remaining-delta)
 var amount:=remaining/.045
 material.set_shader_parameter("strength",amount)
 lamp.light_energy=amount*2.8
