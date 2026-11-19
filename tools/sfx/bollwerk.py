"""Original, reproducible Bollwerk sound palette. No sampled or licensed source audio.
Run with Python + numpy. Ambient noise is periodic, so loops have no seam.
"""
from pathlib import Path
import json
import re
import wave
import numpy as np

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'assets/sounds/bollwerk'
RATE = 24000
rng = np.random.default_rng(82671)


def noise(seconds, low=40, high=5000):
    count = round(seconds * RATE)
    frequencies = np.fft.rfftfreq(count, 1 / RATE)
    spectrum = np.fft.rfft(rng.normal(size=count))
    band = (1 - np.exp(-(frequencies / low)**4)) * np.exp(-(frequencies / high)**4)
    result = np.fft.irfft(spectrum * band, n=count)
    return result / max(np.std(result), .001)


def tone(t, frequency, decay, level=1):
    return level * np.sin(2*np.pi*frequency*t) * np.exp(-decay*t)


def save(name, value, loop=False):
    value = np.asarray(value)
    if not loop:
        fade = min(int(.012*RATE), len(value)//4)
        value[:fade] *= np.linspace(0, 1, fade)
        value[-fade:] *= np.linspace(1, 0, fade)
    peak = np.max(np.abs(value))
    value *= .82 / max(peak, .001)
    with wave.open(str(OUT/f'{name}.wav'), 'wb') as file:
        file.setnchannels(1 if value.ndim == 1 else value.shape[1])
        file.setsampwidth(2)
        file.setframerate(RATE)
        file.writeframes((value*32767).astype('<i2').tobytes())
    assert np.isfinite(value).all() and peak > .001


def crows():
    """Distant, raspy caws: irregular harmonic voice with moving formants, not a melody."""
    global rng
    rng = np.random.default_rng(82671)
    OUT.mkdir(parents=True, exist_ok=True)
    for variant in range(3):
        result = np.zeros(round(3.8*RATE))
        for call in range(2+variant%2):
            duration = .34+.06*rng.random()
            t = np.arange(round(duration*RATE))/RATE
            progress = t/duration
            frequency = (475+variant*31)*(1+.075*np.sin(progress*4.8)-.23*progress)
            frequency += 13*np.sin(2*np.pi*34*t)+rng.normal(0,3,len(t))
            phase = 2*np.pi*np.cumsum(frequency)/RATE
            voice = np.zeros_like(t)
            for harmonic in range(1,12):
                formant = np.exp(-((harmonic*frequency-1550)/1150)**2)
                voice += np.sin(phase*harmonic+np.sin(t*93)*.12)*(formant+.08)/harmonic**.55
            rasp = noise(duration,650,4200)[:len(t)]
            envelope = np.sin(np.pi*progress)**.65*np.minimum(t*70,1)
            voice = (voice*.55+rasp*.17)*(1+.26*np.sin(t*2*np.pi*83))*envelope
            start = round((.15+call*(.75+.04*variant))*RATE)
            result[start:start+len(voice)] += voice
            # Quiet, blurred reflection suggests distance outdoors.
            delay = round(.11*RATE)
            result[start+delay:start+delay+len(voice)] += voice*.12
        save('crow_'+str(variant+1),result)
    credits = OUT/'CREDITS.md'
    text = credits.read_text(encoding='utf-8') if credits.exists() else '# Bollwerk audio\n'
    if 'crow calls' not in text:
        credits.write_text(text+'\nThree original synthesized, distant crow calls (`crow_1–3.wav`), produced by the same generator. No source recordings; project license.\n',encoding='utf-8')
    print('Bollwerk: 3 original crow calls, 24 kHz PCM')


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    # Two independent stereo air layers, slowly breathing over a whole loop.
    t = np.arange(48*RATE)/RATE
    air = []
    for phase in (0, 1.7):
        gust = .58+.19*np.sin(2*np.pi*t/16+phase)+.15*np.sin(2*np.pi*t/48+phase)
        air.append(noise(48, 55, 800)*gust + noise(48, 450, 2100)*.07)
    save('wind', np.stack(air, axis=1), True)
    t = np.arange(12*RATE)/RATE
    fire = noise(12, 100, 2800)*.16
    for _ in range(85):
        start = rng.integers(0, len(t)-2400)
        n = rng.integers(120, 2400)
        fire[start:start+n] += rng.normal(size=n)*np.exp(-np.arange(n)/(n*.12))*rng.uniform(.15,.8)
    save('fire_loop', fire, True)
    t = np.arange(3*RATE)/RATE
    save('bell', sum(tone(t, f, d, a) for f,d,a in [(146,1.8,1),(301,2.8,.45),(417,3.4,.28),(637,4,.14)]))
    t = np.arange(RATE)/RATE
    save('steel', noise(1,1800,8500)*np.exp(-22*t)*.55 + sum(tone(t,f,d,a) for f,d,a in [(1283,14,.4),(2137,19,.25),(3461,28,.15)]))
    save('stone', noise(1,70,1700)*np.exp(-13*t)+tone(t,73,18,.7))
    save('chain', noise(1,2500,9000)*(np.sin(t*95)**14)*np.exp(-5*t)+tone(t,1871,12,.15))
    save('swing', noise(1,250,4500)*np.exp(-((t-.15)/.065)**2))
    save('bolt', noise(1,700,6500)*np.exp(-32*t)+tone(t,143,19,.4))
    save('fire', noise(1,70,2700)*np.exp(-5*t)*(1-np.exp(-70*t))+tone(t,57,8,.6))
    save('frost', noise(1,4200,10000)*np.exp(-8*t)+sum(tone(t,f,12,.2) for f in (1883,2543,3911)))
    save('heal', sum(tone(t,f,3,.24) for f in (392,587.33,783.99))*np.minimum(t*18,1))
    save('shadow', noise(1,100,1800)*np.exp(-4*t)+np.sin(2*np.pi*(94*t-20*t*t))*np.exp(-4*t)*.45)
    save('step', noise(1,200,2500)*np.exp(-55*t)+tone(t,112,65,.5))
    path = ROOT/'data/sfx.json'
    text = path.read_text(encoding='utf-8')
    entry = '"hd_wind": {"file": "bollwerk/wind.wav", "db": -22}'
    if '"hd_wind"' in text:
        text = re.sub(r'"hd_wind"\s*:\s*\{[^}]*\}', entry, text)
    else:
        text = text.replace('\t\t"amb_night"', '\t\t'+entry+',\n\t\t"amb_night"')
    assert json.loads(text)['sounds']['hd_wind']['db'] == -22
    path.write_text(text,encoding='utf-8')
    (OUT/'CREDITS.md').write_text('# Bollwerk audio\n\nOriginal procedural audio generated by `tools/sfx/bollwerk.py`. '
        'No source recordings, sample packs or third-party material. Included under the project license. '
        '48-second stereo wind loop, fire crackle loop, resonant bell, steel/stone/chain impacts, '
        'weapon whoosh, bolt, fire, frost, healing, shadow and gravel footstep.\n',encoding='utf-8')
    print(f'Bollwerk audio: {len(list(OUT.glob("*.wav")))} WAV files, original synthesis, 24 kHz PCM')


if __name__ == '__main__':
    import sys
    if '--crows-only' not in sys.argv:
        main()
    crows()
