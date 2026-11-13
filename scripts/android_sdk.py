#!/usr/bin/env python3
"""Install exact SDK packages through the inherited HTTPS proxy, keeping TLS on."""
import os
from pathlib import Path
import subprocess
import urllib.parse

root = os.environ['ANDROID_HOME']
command = [str(Path(root) / 'cmdline-tools/19.0/bin/sdkmanager'), f'--sdk_root={root}']
proxy = urllib.parse.urlsplit(os.environ.get('HTTPS_PROXY', ''))
if proxy.hostname:
    command += ['--proxy=http', f'--proxy_host={proxy.hostname}', f'--proxy_port={proxy.port or 80}']
subprocess.run(command + ['--licenses'], input='y\n' * 100, text=True, check=True)
subprocess.run(command + ['platform-tools', 'platforms;android-35', 'platforms;android-36', 'build-tools;35.0.0', 'ndk;28.2.13676358', 'cmake;3.22.1'], check=True)
