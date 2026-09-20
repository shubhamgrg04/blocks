"""Edit the preserved native recording; original footage is never modified."""
from pathlib import Path
import json, subprocess
ROOT=Path(__file__).resolve().parent
spec=json.loads((ROOT/'production/edit.json').read_text())
work=ROOT.parent/'.build/showcase-edit';work.mkdir(exist_ok=True)
def run(args): subprocess.run(['ffmpeg','-hide_banner','-loglevel','error','-y',*map(str,args)],check=True)
outputs=[];chapters=[];elapsed=0
for n,scene in enumerate(spec['segments']):
    output=work/f'{n:02}.mp4'
    duration=scene.get('duration',scene.get('end',0)-scene.get('start',0))
    inputs=['-loop','1','-framerate','30','-i',ROOT/scene['image']] if 'image' in scene else ['-ss',scene['start'],'-i',ROOT/'video/native-capture.mp4']
    run([*inputs,'-t',duration,'-an','-vf',"scale=1920:1200:force_original_aspect_ratio=decrease:flags=lanczos,pad=1920:1200:(ow-iw)/2:(oh-ih)/2:color=0x080f12,fps=30,setsar=1",'-c:v','libx264','-preset','fast','-crf','18','-pix_fmt','yuv420p',output])
    outputs.append(output)
    chapters.append((elapsed,elapsed+duration,scene['chapter']));elapsed+=duration
    print(f"Rendered {n+1}/{len(spec['segments'])}: {scene['chapter']}",flush=True)
(work/'concat.txt').write_text(''.join(f"file '{p}'\n" for p in outputs))
metadata=';FFMETADATA1\ntitle=Blocks — One thing at a time\ncomment=Recorded native app interactions with synthetic history. Device frames are illustrative.\n'
for start,end,title in chapters: metadata+=f'[CHAPTER]\nTIMEBASE=1/1000\nSTART={round(start*1000)}\nEND={round(end*1000)}\ntitle={title}\n'
(work/'chapters.txt').write_text(metadata)
run(['-f','concat','-safe','0','-i',work/'concat.txt','-i',work/'chapters.txt','-map_metadata','1','-c','copy','-movflags','+faststart',ROOT/'video/blocks-walkthrough-silent.mp4'])
run(['-i',ROOT/'video/blocks-walkthrough-silent.mp4','-i',ROOT.parent/'launch-video/public/audio/house-vibez.mp3','-map','0:v','-map','1:a','-map_metadata','0','-c:v','copy','-af',f'volume=0.18,afade=t=in:d=1.5,afade=t=out:st={elapsed-3}:d=3','-c:a','aac','-b:a','192k','-t',elapsed,'-movflags','+faststart',ROOT/'video/blocks-walkthrough.mp4'])
def stamp(s):
    ms=round(s*1000);return f'{ms//3600000:02}:{ms//60000%60:02}:{ms//1000%60:02},{ms%1000:03}'
(ROOT/'video/blocks-walkthrough.srt').write_text('\n'.join(f'{n+1}\n{stamp(start)} --> {stamp(end)}\n{title}\n' for n,(start,end,title) in enumerate(chapters)))
(ROOT/'video/chapters.json').write_text(json.dumps([{'start':s,'end':e,'title':t} for s,e,t in chapters],indent=2)+'\n')
print(f'Finished {elapsed:.1f}s, 1920 × 1200, 30fps')
