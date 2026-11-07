"""在指定测试模拟器采样进程冷启动；不清除应用数据，不代表首次安装或真机性能。"""
import argparse
import json
import re
import subprocess
import time
from pathlib import Path

p = argparse.ArgumentParser()
p.add_argument('--adb', required=True)
p.add_argument('--serial', required=True)
p.add_argument('--output', required=True)
a = p.parse_args()
output = Path(a.output)
output.mkdir(parents=True, exist_ok=True)
package = 'io.determine.shuiyuan_flow'

def adb(*args):
    return subprocess.run([a.adb, '-s', a.serial, *args], check=True,
        capture_output=True, timeout=45).stdout.decode('utf-8', errors='replace')

samples = []
for i in range(3):
    adb('shell', 'am', 'force-stop', package)
    raw = adb('shell', 'am', 'start', '-W', '-n', f'{package}/.MainActivity')
    (output / f'cold-start-{i+1}.txt').write_text(raw, encoding='utf-8')
    status = re.search(r'Status:\s*(\S+)', raw)
    total = re.search(r'TotalTime:\s*(\d+)', raw)
    samples.append({'run': i+1, 'status': status.group(1) if status else 'unknown',
                    'total_time_ms': int(total.group(1)) if total else None,
                    'cold': 'LaunchState: COLD' in raw})
    time.sleep(3)
adb('shell', 'screencap', '-p', '/sdcard/ux-home.png')
adb('pull', '/sdcard/ux-home.png', str(output / 'restored-home.png'))
pid = adb('shell', 'pidof', package).strip()
(output / 'restored-runtime.txt').write_text(adb('logcat', '-d', '--pid', pid), encoding='utf-8')
result = {'mode': 'debug', 'device': a.serial,
    'condition': 'process cold start; system/disk caches warmed; existing local data preserved',
    'samples': samples}
(output / 'cold-start.json').write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding='utf-8')
print(json.dumps(result, ensure_ascii=False, indent=2))
