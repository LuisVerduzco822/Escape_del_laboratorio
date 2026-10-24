"""Regenera la selección local FilmCow (requiere ffmpeg y numpy)."""
from pathlib import Path
import json
import subprocess
import wave
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'assets/tmp/filmcow'
OUT = ROOT / 'assets/audio/filmcow'
# Evento: original, duración máxima. Los cortes se desvanecen, no se repiten en bucle.
CHOICES = {
    'drone_move_6': ('vape sound 6', 30.0),
    'drone_move_3': ('vape sound 3', 30.0),
    'drone_move_1': ('vape sound 1', 30.0),
    'robot_step_9': ('metal hit with hammer 9', 30.0),
    'robot_step_8': ('metal hit with hammer 8', 30.0),
    'robot_step_3': ('metal hit with hammer 3', 30.0),
    'robot_step_2': ('metal hit with hammer 2', 30.0),
    'player_death_14': ('oof 14', 30.0),
    'player_death_9': ('oof 9', 30.0),
    'player_death_8': ('oof 8', 30.0),
    'player_death_6': ('oof 6', 30.0),
    'player_death_5': ('oof 5', 30.0),
    'player_hurt_3': ('body hit with grunt 3', 30.0),
    'player_hurt_2': ('body hit with grunt 2', 30.0),
    'player_hurt_1': ('body hit with grunt 1', 30.0),
    'elevator_open': ('screen door open 1', 30.0),
    'ultra': ('deep sci fi stinger 8', 30.0),
    'parry': ('metal hit floor small 4', 30.0),
    'dash': ('swoosh 3', 30.0),
    'super': ('laser gun 1', 30.0),
    'death_robot': ('metal sliding 5', 30.0),
    'death_drone': ('robot sick 2', 30.0),
    'death_bat': ('sipping through empty straw 2', .45),
    'death_spore': ('bubbles 1', .48),
    'death_fireball': ('spray bottle 3', 30.0),
    'robot_shoot': ('laser gun 11', .40),
    'drone_shoot': ('laser gun 14', .35),
    'robot_charge': ('sci fi click 5', .30),
    'drone_charge': ('sci fi click 9', .30),
    'bat_flap': ('swoosh 1', .16),
    'spore_land': ('squishy and wet 3', 30.0),
    'spore_roll': ('paper crunchy 3', 30.0),
}

def main():
    rows = []
    for event, (name, cap) in CHOICES.items():
        matches = list(SOURCE.rglob(name + '.wav'))
        if not matches:
            raise FileNotFoundError(name)
        source = matches[0]
        samples = np.frombuffer(subprocess.check_output([
            'ffmpeg', '-v', 'error', '-i', str(source), '-af', 'highpass=f=75,lowpass=f=12000',
            '-f', 'f32le', '-ac', '1', '-ar', '44100', '-']), dtype=np.float32).copy()
        peak = np.max(np.abs(samples))
        active = np.flatnonzero(np.abs(samples) > peak * .025)
        start = max(0, int(active[0]) - 132)
        end = min(len(samples), int(active[-1]) + 882, start + int(cap * 44100))
        samples = samples[start:end]
        # RMS activo a -20 dBFS, con techo -3 dBFS: no subir sólo picos.
        rms = float(np.sqrt(np.mean(samples ** 2)))
        gain = min(10 ** (-20 / 20) / max(rms, 1e-8), 10 ** (-3 / 20) / np.max(np.abs(samples)))
        samples *= gain
        samples[:132] *= np.linspace(0, 1, 132)
        fade = min(1323, len(samples) // 4)
        samples[-fade:] *= np.linspace(1, 0, fade)
        with wave.open(str(OUT / (event + '.wav')), 'wb') as wav:
            wav.setparams((1, 2, 44100, 0, 'NONE', 'not compressed'))
            wav.writeframes((samples * 32767).astype('<i2').tobytes())
        rows.append(dict(event=event, source=str(source.relative_to(SOURCE)),
                         trim_start_seconds=round(start / 44100, 4), duration_seconds=round(len(samples) / 44100, 4),
                         rms_dbfs=round(float(20 * np.log10(np.sqrt(np.mean(samples ** 2)))), 2),
                         peak_dbfs=round(float(20 * np.log10(np.max(np.abs(samples)))), 2)))
    (OUT / 'enemy_selection.json').write_text(json.dumps(rows, indent=2) + '\n')
    print(json.dumps(rows, indent=2))

if __name__ == '__main__':
    main()
