import bpy,numpy as np
from pathlib import Path
r=Path(r'C:/Users/AYOU/Desktop/CS');bpy.ops.wm.open_mainfile(filepath=str(r/'assets/source/task009/v003/new_ar/Derived.blend'));o=bpy.data.objects['Rifle_Body'];p=np.array([(v.co.x,v.co.z,-v.co.y) for v in o.data.vertices]);p=p[(abs(p[:,0])<.05)&(p[:,2]>.06)&(p[:,2]<.26)&(p[:,1]<-.06)];print('GRIP_BODY_BOUNDS',p.min(axis=0),p.max(axis=0))

import json
parts=json.loads((r/'logs/TASK-009-v003-parts-new_ar.json').read_text())
cx,cy,_=parts['lens_fit']['source_center']
points=np.array([(v.co.x,v.co.z,-v.co.y) for v in o.data.vertices])
minimum=np.array((-.075-cx,-.50+.135-cy,-.24-.052))
maximum=np.array((.075-cx,-.055+.135-cy,.09-.052))
residual=int(np.sum(np.all((points>minimum+.0005)&(points<maximum-.0005),axis=1)))
mag=bpy.data.objects['Magazine'];mp=np.array([(v.co.x,v.co.z,-v.co.y) for v in mag.data.vertices])
report={'body_vertices_inside_removed_magazine_region':residual,'removed_bounds':[minimum.tolist(),maximum.tolist()],'magazine_bounds':[mp.min(axis=0).tolist(),mp.max(axis=0).tolist()],'grip_bounds':[p.min(axis=0).tolist(),p.max(axis=0).tolist()]}
(r/'logs/TASK-009-v005-magazine-separation.json').write_text(json.dumps(report,indent=2));assert residual==0,report;print('MAGAZINE_SEPARATION_PASS',report)
