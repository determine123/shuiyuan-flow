"""校验交付 APK 的 ABI 声明与实际 Flutter 引擎，防止插件额外带入不支持的架构。"""
import argparse
import json
import zipfile

parser = argparse.ArgumentParser()
parser.add_argument('apk')
args = parser.parse_args()
with zipfile.ZipFile(args.apk) as apk:
    names = set(apk.namelist())
    abis = {name.split('/')[1] for name in names if name.startswith('lib/')}
    assert abis == {'arm64-v8a', 'x86_64'}, f'存在非交付架构或缺失架构：{abis}'
    for abi in abis:
        assert f'lib/{abi}/libflutter.so' in names, f'{abi} 缺少 Flutter 引擎'
    assert 'assets/flutter_assets/kernel_blob.bin' in names, '缺少 Debug Dart 程序'
    print(json.dumps({'result': 'PASS', 'abis': sorted(abis), 'flutter_engine_per_abi': True}, indent=2))
