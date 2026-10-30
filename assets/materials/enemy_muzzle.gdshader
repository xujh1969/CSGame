shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
uniform float strength = 0.0;
uniform float seed = 0.0;
void fragment() {
 vec2 p=(UV-.5)*2.0;
 float a=atan(p.y,p.x)+seed;
 float r=length(p);
 float jagged=.48+.22*sin(a*5.0+seed*3.0)+.10*sin(a*13.0);
 float flame=1.0-smoothstep(jagged-.14,jagged+.08,r);
 float core=exp(-r*r*22.0);
 vec3 heat=mix(vec3(1.0,.18,.025),vec3(1.0,.78,.26),core);
 heat=mix(heat,vec3(1.0,.97,.80),core*core);
 ALBEDO=heat;
 EMISSION=heat*(2.0+core*6.0)*strength;
 ALPHA=clamp((flame*.8+core)*strength,0.0,1.0);
}
