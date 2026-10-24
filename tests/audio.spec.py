from pathlib import Path
import json
import wave
import numpy as np

root = Path(__file__).resolve().parents[1]
catalog = json.loads((root / "assets/music/catalog.json").read_text())
assert len(catalog["tracks"]) == 4 and catalog["originalComposition"]
for track in catalog["tracks"]:
    path = root / track["file"]
    assert path.stat().st_size < 20_000_000
    with wave.open(str(path), "rb") as f:
        assert f.getnchannels() == 2 and f.getframerate() == 44100 and f.getsampwidth() == 2
        duration = f.getnframes()/f.getframerate()
        assert 30 < duration < 60
        audio = np.frombuffer(f.readframes(f.getnframes()), dtype="<i2").reshape(-1, 2)
    assert np.max(np.abs(audio.astype(np.int32))) < 30000, "audio clips"
    assert .05 < np.sqrt(np.mean((audio.astype(float)/32768)**2)) < .3, "silent or excessive mix"
    assert np.max(np.abs(audio[0].astype(int)-audio[-1].astype(int))) <= 1, "loop seam"
assert catalog["tracks"][0]["bpm"] < 90 and all(x["bpm"] >= 150 for x in catalog["tracks"][1:])
print("PASS: four original WAV tracks, format, duration, level, loop seams and tempo contrast")
