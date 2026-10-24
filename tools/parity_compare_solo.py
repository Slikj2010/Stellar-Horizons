# Compares a seeded solo game from tools/parity_solo.js with godot/tests/parity_solo.gd.
import json,sys
a=json.load(open(sys.argv[1])); b=json.load(open(sys.argv[2]))
A,B=a['all'],b['all']
# Godot records from newGame on (the start lines exist in both since JS wraps after newGame: skip GD extras at start)
off=0
if A and A[0] in B: off=B.index(A[0])
for k in ['steps','year','score','cash']:
    if a[k]!=b[k]: print('DIFF',k,a[k],b[k])
for i,x in enumerate(A):
    y=B[i+off] if i+off<len(B) else None
    if x!=y:
        print('FIRST DIVERGENCE at',i,'of',len(A))
        for j in range(max(0,i-5),i+3):
            print('  JS',A[j][:300] if j<len(A) else None); print('  GD',B[j+off][:300] if j+off<len(B) else None)
        sys.exit()
print('MATCH', len(A), 'lines')
