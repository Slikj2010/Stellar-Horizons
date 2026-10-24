# Compares a seeded multi-faction game from tools/parity_dump.js with godot/tests/parity_dump.gd.
import json,sys
a=json.load(open(sys.argv[1])); b=json.load(open(sys.argv[2]))
print('steps',a['steps'],b['steps'],'year',a['year'],b['year'])
bad=0
for f in a['facs']:
    A=a['facs'][f]; B=b['facs'][f]
    for k in ['cash','vm','polm','score','ships','bases','tech']:
        if A[k]!=B[k]: print(f,k,'DIFF',str(A[k])[:200],'|',str(B[k])[:200]); bad+=1
    la,lb=A['log'],B['log']
    for i,(x,y) in enumerate(zip(la,lb)):
        if x!=y:
            print(f,'log line',i,'\n JS:',x[:400],'\n GD:',y[:400]); bad+=1; break
    if len(la)!=len(lb): print(f,'log len',len(la),len(lb)); bad+=1
print('MISMATCHES',bad)
if 'all' in a and 'all' in b:
    A,B=a['all'],b['all']
    # Godot records from newWorld on; JS after it: align on JS start
    off=len(B)-len(A) if len(B)>=len(A) else 0
    # find offset by matching first JS line
    if A:
        try: off=B.index(A[0])
        except ValueError: off=0
    for i,x in enumerate(A):
        y=B[i+off] if i+off<len(B) else None
        if x!=y:
            print('FIRST DIVERGENCE at', i)
            for j in range(max(0,i-6),i+3):
                print('  JS', A[j][:300] if j<len(A) else None)
                print('  GD', B[j+off][:300] if j+off<len(B) else None)
            break
