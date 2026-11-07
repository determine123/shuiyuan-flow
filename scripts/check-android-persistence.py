"""对指定测试模拟器，通过真实界面写入数据并跨进程验证；不会清除应用数据。"""
import argparse
import json
import re
import subprocess
import time
import xml.etree.ElementTree as ET
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument('--adb', required=True)
parser.add_argument('--serial', required=True)
parser.add_argument('--output', required=True)
args = parser.parse_args()
output = Path(args.output).resolve()
output.mkdir(parents=True, exist_ok=True)
package = 'io.determine.shuiyuan_flow'

def adb(*parts):
    return subprocess.run([args.adb, '-s', args.serial, *parts],
        check=True, capture_output=True, timeout=40).stdout.decode('utf-8', errors='replace')

def nodes(name):
    adb('shell', 'uiautomator', 'dump', '/sdcard/flow-ui.xml')
    target = output / f'{name}.xml'
    adb('pull', '/sdcard/flow-ui.xml', str(target))
    return list(ET.parse(target).iter('node'))

def label(node):
    return node.get('text', '') + '\n' + node.get('content-desc', '')

def tap(node):
    x1, y1, x2, y2 = map(int, re.findall(r'\d+', node.attrib['bounds']))
    adb('shell', 'input', 'tap', str((x1+x2)//2), str((y1+y2)//2))
    time.sleep(0.7)

def tap_label(text, name):
    matches = [n for n in nodes(name) if text in label(n) and n.get('clickable') == 'true']
    if not matches:
        raise AssertionError(f'找不到可点击控件：{text}')
    tap(matches[0])

def screenshot(name):
    adb('shell', 'screencap', '-p', '/sdcard/flow-check.png')
    adb('pull', '/sdcard/flow-check.png', str(output / f'{name}.png'))

tap_label('收藏话题', 'home-before')
tap_label('写点什么', 'home-bookmarked')
fields = [n for n in nodes('composer') if n.get('class') == 'android.widget.EditText']
assert len(fields) == 2, '标题和正文输入框不完整'
tap(fields[0])
adb('shell', 'input', 'text', 'Android%spersistence%scheck')
fields = [n for n in nodes('composer-title') if n.get('class') == 'android.widget.EditText']
tap(fields[-1])
adb('shell', 'input', 'text', 'Persistence%ssurvives%sprocess%srestart.')
adb('shell', 'input', 'keyevent', 'KEYCODE_BACK')
time.sleep(0.7)
current = nodes('composer-filled')
if any('保留这次编辑' in label(n) for n in current):
    tap_label('保存草稿', 'save-on-back')
else:
    # 顶部工具栏的保存按钮，与底部的保存为本地草稿按钮分开匹配。
    exact = [n for n in current if n.get('clickable') == 'true' and
             ('保存' == n.get('text') or '保存' == n.get('content-desc'))]
    assert exact, '找不到保存按钮'
    tap(exact[0])
time.sleep(1)
adb('shell', 'am', 'force-stop', package)
launch = adb('shell', 'am', 'start', '-W', '-n', f'{package}/.MainActivity')
(output / 'persistence-launch.txt').write_text(launch, encoding='utf-8')
assert 'Status: ok' in launch
time.sleep(5)
tap_label('草稿', 'home-after-restart')
draft_ui = nodes('draft-after-restart')
assert any('Android persistence check' in label(n) for n in draft_ui), '重启后未恢复草稿标题'
assert any('Persistence survives process restart.' in label(n) for n in draft_ui), '重启后未恢复草稿正文'
screenshot('persistence-draft')
tap_label('收藏', 'draft-verified')
assert any('欢迎来到源流' in label(n) for n in nodes('bookmark-after-restart')), '重启后未恢复收藏'
screenshot('persistence-bookmark')
tap_label('发现', 'bookmark-verified')
screenshot('home-final')
result = {'draft_survived_process_restart': True, 'bookmark_survived_process_restart': True,
          'title': 'Android persistence check', 'package': package, 'serial': args.serial}
(output / 'persistence-result.json').write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding='utf-8')
print('PASS: 草稿与收藏已通过强制停止、重新启动后的真实界面验证。')
