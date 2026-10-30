shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
uniform float strength = 0.0;
uniform float seed = 0.0;
void fragment() {
 vec2 p=(UV-.5)*2.0;
 float a=atan(p.y,p.x)+seed;
 float r=length(p);
 float edge=.40+.14*sin(a*3.0+seed)+.045*sin(a*7.0-seed*.7);
 float flame=1.0-smoothstep(edge-.045,edge+.025,r);
 float core=exp(-r*r*34.0);
 vec3 heat=mix(vec3(1.0,.12,.015),vec3(1.0,.58,.12),smoothstep(.12,.62,r));
 heat=mix(heat,vec3(1.0,.88,.62),core*.72);
 ALBEDO=heat;
 EMISSION=heat*(1.5+core*4.5)*strength;
 ALPHA=clamp((flame*.76+core*.55)*strength,0.0,1.0);
}
