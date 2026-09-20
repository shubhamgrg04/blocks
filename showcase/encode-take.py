"""Usage: python3 showcase/encode-take.py TAKE_DIRECTORY OUTPUT.mp4"""
import csv, subprocess, sys
from pathlib import Path
root=Path(sys.argv[1]).resolve(); output=Path(sys.argv[2]).resolve()
if output.exists(): raise SystemExit(f'Refusing to overwrite {output}; choose a new output filename.')
rows=list(csv.reader((root/'timing.csv').open()))
lines=['ffconcat version 1.0']
for n,(index,t,_) in enumerate(rows):
    frame=root/f'{int(index):06d}.jpg'
    if not frame.exists(): raise SystemExit(f'Missing frame: {frame}')
    duration=float(rows[n+1][1])-float(t) if n+1<len(rows) else 1/12
    lines.extend([f"file '{frame.name}'",f'duration {duration:.6f}'])
lines.append(f"file '{int(rows[-1][0]):06d}.jpg'")
listing=root/'frames.ffconcat'; listing.write_text('\n'.join(lines)+'\n')
subprocess.run(['ffmpeg','-hide_banner','-loglevel','error','-f','concat','-safe','0','-i',str(listing),'-vf','fps=30','-c:v','libx264','-crf','17','-pix_fmt','yuv420p','-movflags','+faststart',str(output)],check=True)
