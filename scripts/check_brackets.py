from pathlib import Path
p=Path('c:/Hoctap/PTUDCCTBDD/BTT/LifeMap/lib/views/map/map_view.dart')
s=p.read_text(encoding='utf-8')
stack=[]
pairs={')':'(',']':'[','}':'{'}
line=1
col=0
for i,ch in enumerate(s):
    if ch=='\n':
        line+=1
        col=0
        continue
    col+=1
    if ch in '([{':
        stack.append((ch,line,col))
    elif ch in ')]}':
        if not stack:
            print('Unmatched closing',ch,'at',line,col)
            break
        last, lline, lcol = stack[-1]
        if last!=pairs[ch]:
            print('Mismatched',last,'opened at',lline,lcol,'but closing',ch,'at',line,col)
            break
        stack.pop()
else:
    if stack:
        print('Unclosed at end, first unclosed:',stack[-1])
    else:
        print('All balanced')
print('--- Done')
