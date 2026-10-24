"""Compose four original seamless synth scores. No third-party recordings."""
from pathlib import Path
import json
import wave
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets/music"
OUT.mkdir(exist_ok=True)
SR = 44100
SCORES = {
    "Lobby": {"title": "Overlook Afterglow", "bpm": 78, "bars": 16, "roots": [45, 41, 50, 43], "mode": "chill"},
    "CrystalGrove": {"title": "Glassfang Pursuit", "bpm": 150, "bars": 24, "roots": [38, 34, 41, 36], "mode": "crystal"},
    "SunsetRuins": {"title": "Ruin Runners", "bpm": 160, "bars": 24, "roots": [40, 41, 43, 38], "mode": "tribal"},
    "NeonHarbor": {"title": "Harbor Overdrive", "bpm": 172, "bars": 24, "roots": [43, 39, 46, 41], "mode": "neon"},
}

def frequency(midi): return 440 * 2 ** ((midi - 69)/12)

def compose(key, score):
    rng = np.random.default_rng(1927 + list(SCORES).index(key))
    beat = 60 / score["bpm"]
    length = int(round(score["bars"] * 4 * beat * SR))
    mix = np.zeros((length, 2), dtype=np.float64)
    def add(sound, at, pan=0):
        pos = int(round(at*SR)) % length
        stereo = sound[:, None] * np.array([np.sqrt((1-pan)/2), np.sqrt((1+pan)/2)])
        first = min(len(stereo), length-pos)
        mix[pos:pos+first] += stereo[:first]
        if first < len(stereo): mix[:len(stereo)-first] += stereo[first:]
    def tone(midi, seconds, kind, amp):
        t = np.arange(max(1, int(seconds*SR)))/SR
        f = frequency(midi)
        if kind == "pad":
            sound = (np.sin(2*np.pi*f*t) + .32*np.sin(2*np.pi*f*1.003*t) + .15*np.sin(2*np.pi*f*2*t))
            env = np.minimum(1, t/.18) * np.minimum(1, (seconds-t)/.6)
        elif kind == "bell":
            sound = np.sin(2*np.pi*f*t) + .4*np.sin(2*np.pi*f*2.01*t)*np.exp(-t*6) + .18*np.sin(2*np.pi*f*3.98*t)*np.exp(-t*11)
            env = (1-np.exp(-t*350))*np.exp(-t*4)
        elif kind == "bass":
            sound = np.sin(2*np.pi*f*t) + .22*np.sin(2*np.pi*f*2*t)
            env = np.minimum(1, t/.008)*np.minimum(1, (seconds-t)/.04)*np.exp(-t*2)
        else:
            sound = sum(np.sin(2*np.pi*f*n*t)/n**1.3 for n in range(1, 7))
            env = np.minimum(1, t/.01)*np.exp(-t*5)*np.minimum(1, (seconds-t)/.025)
        return sound*env*amp
    def drum(kind):
        dur = .38 if kind == "kick" else (.18 if kind == "snare" else (.3 if kind == "tom" else .07))
        t = np.arange(int(dur*SR))/SR
        noise = rng.standard_normal(len(t))
        if kind == "kick": return np.sin(2*np.pi*(48*t+75*.028*(1-np.exp(-t/.028))))*np.exp(-t*13)*.45
        if kind == "tom": return (np.sin(2*np.pi*(105*t+35*.05*(1-np.exp(-t/.05)))) + .07*noise)*np.exp(-t*14)*.24
        if kind == "snare": return (noise*.3 + np.sin(2*np.pi*180*t)*.18)*np.exp(-t*23)
        return np.diff(noise, prepend=0)*np.exp(-t*80)*.045
    chill = score["mode"] == "chill"
    for bar in range(score["bars"]):
        root = score["roots"][(bar//2) % 4]
        at = bar*4*beat
        chord = [root+12, root+15, root+19, root+22]
        for j, note in enumerate(chord): add(tone(note, 4.8*beat, "pad", .042 if chill else .024), at, -.5+j/3)
        notes = [root+24, root+31, root+27, root+34, root+36, root+31, root+27, root+29]
        for i in range(8):
            if chill and i not in (0, 3, 5): continue
            midi = notes[(i+bar%3)%8]
            add(tone(midi, 1.3*beat, "bell" if score["mode"] in ("chill", "crystal") else "lead", .11 if chill else .075), at+i*.5*beat, np.sin(i)*.45)
        for i in range(4 if chill else 8):
            add(tone(root, beat*(.8 if chill else .4), "bass", .13 if chill else .2), at+i*(1 if chill else .5)*beat)
        if chill:
            if bar % 2 == 0: add(drum("kick")*.14, at)
            for i in (1.5, 3.5): add(drum("hat")*.3, at+i*beat, .35)
        else:
            for i in (0, 1.5, 2, 2.75): add(drum("kick"), at+i*beat)
            for i in (1, 3): add(drum("snare"), at+i*beat)
            for i in range(16): add(drum("hat")*(.7 if i%2 else 1), at+i*.25*beat, -.25 if i%2 else .25)
            if score["mode"] == "tribal":
                for i in (.5, 1.75, 2.5, 3.5): add(drum("tom"), at+i*beat, -.4 if i<2 else .4)
            if score["mode"] == "neon":
                for i in (0, 2): add(tone(root+19, .32*beat, "lead", .07), at+i*beat, .2)
    dry = mix.copy()
    for delay, gain in ((.23, .12), (.41, .09), (.68, .045)):
        mix += np.roll(dry[:, ::-1], int(delay*SR), axis=0)*gain
    mix = np.tanh(mix*1.2)
    mix -= np.mean(mix, axis=0)
    mix *= .82 / max(.01, np.max(np.abs(mix)))
    # Join the last/first two milliseconds so every exported cycle has a clean seam.
    seam = 88
    center = (mix[-1]+mix[0])/2
    mix[:seam] = center + (mix[:seam]-center)*np.linspace(0, 1, seam)[:, None]
    mix[-seam:] = center + (mix[-seam:]-center)*np.linspace(1, 0, seam)[:, None]
    pcm = np.round(mix*32767).astype("<i2")
    path = OUT/f"{key}.wav"
    with wave.open(str(path), "wb") as f:
        f.setnchannels(2); f.setsampwidth(2); f.setframerate(SR); f.writeframes(pcm.tobytes())
    return {"key": key, "title": score["title"], "bpm": score["bpm"], "seconds": round(length/SR, 3), "bytes": path.stat().st_size, "peak": round(float(np.max(np.abs(mix))), 3), "rms": round(float(np.sqrt(np.mean(mix**2))), 3), "file": f"assets/music/{key}.wav", "style": score["mode"]}

manifest = {"originalComposition": True, "sampleRate": SR, "channels": 2, "uploaded": False, "tracks": [compose(k, s) for k, s in SCORES.items()]}
(OUT/"catalog.json").write_bytes((json.dumps(manifest, indent=2)+"\n").encode("utf-8"))
print(json.dumps(manifest, indent=2))
