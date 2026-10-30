import bpy
import numpy as np
from pathlib import Path
import json

root=Path(__file__).resolve().parents[2]
report={}
for asset in ('new_ar','arms'):
    bpy.ops.wm.open_mainfile(filepath=str(root/'assets/source/task009/v003'/asset/'Baked.blend'))
    obj=bpy.data.objects[asset+'_Low']
    p=np.array([[v.co.x,v.co.z,-v.co.y] for v in obj.data.vertices])
    rows=[]
    if asset=='new_ar':
        for step in range(-15,31):
            q=p[(p[:,2]>=step*.01)&(p[:,2]<(step+1)*.01)&(p[:,1]>.085)]
            if len(q): rows.append({'z':step*.01,'count':len(q),'bounds':[q.min(axis=0).tolist(),q.max(axis=0).tolist()]})
    else:
        for side in (-1,1):
            for step in range(17):
                q=p[(p[:,0]*side>0)&(p[:,1]>=step*.05)&(p[:,1]<(step+1)*.05)]
                if len(q): rows.append({'side':side,'y':step*.05,'mean':q.mean(axis=0).tolist(),'bounds':[q.min(axis=0).tolist(),q.max(axis=0).tolist()]})
    report[asset]=rows
(root/'logs/TASK-009-v003-joint-analysis.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print(json.dumps(report))
