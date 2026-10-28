"""Release orchestration; source is checked out separately from these build tools."""
import base64
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
from urllib.parse import quote
import zipfile

STATE = Path('release-state.json')
PUBLICATION = Path('publication-state.json')
VERSION = re.compile(r'v(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:-(alpha|beta|rc)\.([1-9]\d*))?\+([1-9]\d*)')
PREFIX = 'Escape-del-Laboratorio'


def run(*args, **kwargs):
    return subprocess.run(args, check=True, text=True, **kwargs)


def api(endpoint, method='GET', data=None):
    args = ['gh', 'api', f'repos/{os.environ["GH_REPO"]}/{endpoint}', '--method', method]
    if data is not None:
        args += ['--input', '-']
    result = run(*args, input=json.dumps(data) if data is not None else None, capture_output=True)
    return json.loads(result.stdout) if result.stdout.strip() else None


def optional(endpoint):
    try:
        return api(endpoint)
    except subprocess.CalledProcessError as error:
        if 'HTTP 404' in error.stderr:
            return None
        raise


def parse(tag):
    match = VERSION.fullmatch(tag)
    if not match or int(match[6]) > 2100000000:
        raise ValueError('Expected vX.Y.Z[-alpha.N|-beta.N|-rc.N]+CODE, CODE <= 2100000000')
    return {'tag': tag, 'version': tag[1:], 'name': tag[1:].split('+')[0],
            'code': int(match[6]), 'prerelease': match[4] is not None}


def resolve():
    state = parse(os.environ['RELEASE_TAG'])
    encoded = quote(state['tag'], safe='')
    if optional(f'releases/tags/{encoded}'):
        raise ValueError('This version already has a release; use a new tag/code')
    ref = optional(f'git/ref/tags/{encoded}')
    if os.environ.get('GITHUB_EVENT_NAME') == 'push' and not ref:
        raise ValueError('Pushed tag no longer exists')
    sha = ref['object']['sha'] if ref else os.environ['GITHUB_SHA']
    obj_type = ref['object']['type'] if ref else 'commit'
    while obj_type == 'tag':
        obj = api(f'git/tags/{sha}')['object']
        sha, obj_type = obj['sha'], obj['type']
    if obj_type != 'commit':
        raise ValueError('Tag must point to a commit')
    state.update(sha=sha, existing_tag=ref is not None)
    # Validate against every published release, including prereleases and old pages.
    releases = json.loads(run('gh', 'api', '--paginate', '--slurp',
                             f'repos/{os.environ["GH_REPO"]}/releases?per_page=100',
                             capture_output=True).stdout)
    for page in releases:
        for release in page:
            if VERSION.fullmatch(release['tag_name']) and not release['draft']:
                if parse(release['tag_name'])['code'] >= state['code']:
                    raise ValueError('Android code must exceed all previously published codes')
    STATE.write_text(json.dumps(state))
    with open(os.environ['GITHUB_OUTPUT'], 'a') as output:
        output.write(f'sha={sha}\ntag={state["tag"]}\n')


def build():
    state = json.loads(STATE.read_text())
    for secret in ('ANDROID_KEYSTORE_BASE64', 'GODOT_ANDROID_KEYSTORE_RELEASE_USER',
                   'GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD'):
        if not os.environ.get(secret):
            raise ValueError(f'Missing secret: {secret}')
    key = Path(os.environ['RUNNER_TEMP']) / 'android-release.keystore'
    key.write_bytes(base64.b64decode(os.environ['ANDROID_KEYSTORE_BASE64'], validate=True))
    key.chmod(0o600)
    os.environ['GODOT_ANDROID_KEYSTORE_RELEASE_PATH'] = str(key)
    game = Path('source/game').resolve()
    shutil.copy2(Path(__file__).resolve().parents[2] / 'game/scripts/ReleaseSmoke.gd',
                 game / 'scripts/ReleaseSmoke.gd')
    dist = Path('dist').resolve()
    dist.mkdir()
    preset = (game / 'export_presets.cfg').read_text()
    for arch in ('armeabi-v7a', 'arm64-v8a', 'x86', 'x86_64'):
        preset = re.sub(rf'architectures/{re.escape(arch)}=(true|false)', f'architectures/{arch}=true', preset)
    preset = re.sub(r'version/code=\d+', f'version/code={state["code"]}', preset)
    preset = re.sub(r'version/name="[^"]*"', f'version/name="{state["name"]}"', preset)
    # Generate CI presets independently of desktop presets on historical source tags.
    next_index = max(map(int, re.findall(r'^\[preset\.(\d+)\]$', preset, re.M)), default=-1) + 1
    for index, (name, platform) in enumerate((('CI Windows', 'Windows Desktop'), ('CI Linux', 'Linux')), next_index):
        preset += f'''\n[preset.{index}]
name="{name}"
platform="{platform}"
runnable=false
export_filter="all_resources"
include_filter=""
exclude_filter="tests/*,tools/*,.save-check/*,builds/*"
script_export_mode=1
[preset.{index}.options]
binary_format/architecture="x86_64"
binary_format/embed_pck=true
debug/export_console_wrapper=0
application/file_version="{state['name'].split('-')[0]}.0"
application/product_version="{state['name'].split('-')[0]}.0"
'''
    (game / 'export_presets.cfg').write_text(preset)
    project = game / 'project.godot'
    project_text = project.read_text()
    if re.search(r'^config/version=', project_text, re.M):
        project_text = re.sub(r'^config/version=.*$', f'config/version="{state["name"]}"', project_text, flags=re.M)
    else:
        project_text = project_text.replace('[application]', f'[application]\nconfig/version="{state["name"]}"', 1)
    project.write_text(project_text)
    config = Path.home() / '.config/godot/editor_settings-4.7.tres'
    config.parent.mkdir(parents=True, exist_ok=True)
    config.write_text('[gd_resource type="EditorSettings" format=3]\n\n[resource]\n'
                      f'export/android/java_sdk_path={json.dumps(os.environ["JAVA_HOME"])}\n'
                      f'export/android/android_sdk_path={json.dumps(os.environ["ANDROID_HOME"])}\n'
                      'export/android/shutdown_adb_on_exit=false\n')
    godot = 'Godot_v4.7.2-stable_linux.x86_64'
    run(godot, '--headless', '--path', str(game), '--editor', '--import')
    version = state['version']
    apk = dist / f'{PREFIX}-android-universal-{version}.apk'
    exe = dist / f'{PREFIX}-windows-x86_64-{version}.exe'
    appdir = Path('AppDir').resolve()
    appdir.mkdir()
    linux = appdir / 'escape-del-laboratorio'
    for name, path in (('Android', apk), ('CI Windows', exe), ('CI Linux', linux)):
        run(godot, '--headless', '--path', str(game), '--export-release', name, str(path))
        if not path.is_file() or not path.stat().st_size:
            raise ValueError(f'Missing or empty export: {path}')
    run(str(Path(os.environ['ANDROID_HOME']) / 'build-tools/35.0.1/apksigner'), 'verify', '--verbose', str(apk))
    with zipfile.ZipFile(apk) as archive:
        for arch in ('armeabi-v7a', 'arm64-v8a', 'x86', 'x86_64'):
            if not any(name.startswith(f'lib/{arch}/') for name in archive.namelist()):
                raise ValueError(f'APK missing architecture: {arch}')
    linux.chmod(0o755)
    # Godot's official template is self-contained except host graphics/window/audio libraries.
    # Bundle resolvable non-core libraries; leave libc, the loader and GPU drivers to the host.
    libdir = appdir / 'usr/lib'
    libdir.mkdir(parents=True)
    excluded = re.compile(r'^(ld-linux|lib(c|m|pthread|dl|rt|resolv|util)\.so|lib(GL|EGL|GLX|OpenGL|drm|gbm))')
    dependencies = run('ldd', str(linux), capture_output=True).stdout
    if 'not found' in dependencies:
        raise ValueError(dependencies)
    for dependency in re.findall(r'=> (/\S+)', dependencies):
        if not excluded.match(Path(dependency).name):
            shutil.copy2(dependency, libdir / Path(dependency).name)
    apprun = appdir / 'AppRun'
    apprun.write_text('#!/bin/sh\nHERE="$(dirname "$(readlink -f "$0")")"\n'
                      'export LD_LIBRARY_PATH="$HERE/usr/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"\n'
                      'exec "$HERE/escape-del-laboratorio" "$@"\n')
    apprun.chmod(0o755)
    shutil.copy2(game / 'icon.svg', appdir / 'escape-del-laboratorio.svg')
    (appdir / 'escape-del-laboratorio.desktop').write_text('[Desktop Entry]\nType=Application\n'
        'Name=Escape del Laboratorio\nExec=escape-del-laboratorio\nIcon=escape-del-laboratorio\nCategories=Game;\n')
    image = dist / f'{PREFIX}-linux-x86_64-{version}.AppImage'
    metainfo = appdir / 'usr/share/metainfo'
    metainfo.mkdir(parents=True)
    (metainfo / 'mx.udg.alumnos.juegos.escape_del_laboratorio.appdata.xml').write_text(
        '<?xml version="1.0" encoding="UTF-8"?>\n'
        '<component type="desktop-application">'
        '<id>mx.udg.alumnos.juegos.escape_del_laboratorio</id>'
        '<metadata_license>CC0-1.0</metadata_license>'
        '<name>Escape del Laboratorio</name>'
        '<summary>Escape the laboratory and craft the antidote</summary>'
        '<launchable type="desktop-id">escape-del-laboratorio.desktop</launchable>'
        '<description><p>Collect ingredients and defeat bosses to escape the laboratory.</p></description>'
        '</component>\n')
    run(str(Path('tools/appimagetool-x86_64.AppImage').resolve()), '--appimage-extract-and-run',
        str(appdir), str(image), env={**os.environ, 'ARCH': 'x86_64'})
    # Exercise the packaged game rather than just checking the output filename.
    run(str(image), '--appimage-extract-and-run', '--headless', '--script',
        'res://scripts/ReleaseSmoke.gd', timeout=60)
    expected = [apk.name, exe.name, image.name]
    for filename in expected:
        if not (dist / filename).stat().st_size:
            raise ValueError(f'Empty asset: {filename}')
    (dist / 'SHA256SUMS.txt').write_text(''.join(
        f'{hashlib.sha256((dist / name).read_bytes()).hexdigest()}  {name}\n' for name in expected))
    state['assets'] = expected + ['SHA256SUMS.txt']
    STATE.write_text(json.dumps(state))


def cleanup():
    if not PUBLICATION.exists():
        return
    publication = json.loads(PUBLICATION.read_text())
    tag = quote(publication['tag'], safe='')
    release = optional(f'releases/tags/{tag}')
    if release and not release['draft']:
        return  # Publication succeeded, including if the final API response was interrupted.
    if release:
        api(f'releases/{release["id"]}', 'DELETE')
    if publication['created_tag']:
        ref = optional(f'git/ref/tags/{tag}')
        if ref and ref['object']['sha'] == publication['sha']:
            api(f'git/refs/tags/{tag}', 'DELETE')


def publish():
    state = json.loads(STATE.read_text())
    tag = quote(state['tag'], safe='')
    if optional(f'releases/tags/{tag}'):
        raise ValueError('Release appeared during build; refusing to overwrite')
    ref = optional(f'git/ref/tags/{tag}')
    if state['existing_tag']:
        # Resolve again to detect moved/deleted tags, including annotated tags.
        if not ref:
            raise ValueError('Source tag disappeared')
        obj = ref['object']
        while obj['type'] == 'tag':
            obj = api(f'git/tags/{obj["sha"]}')['object']
        if obj['sha'] != state['sha']:
            raise ValueError('Source tag moved during build')
    elif ref:
        raise ValueError('Tag appeared during build; refusing to overwrite')
    publication = {**state, 'created_tag': not state['existing_tag']}
    PUBLICATION.write_text(json.dumps(publication))
    try:
        if publication['created_tag']:
            api('git/refs', 'POST', {'ref': f'refs/tags/{state["tag"]}', 'sha': state['sha']})
        release = api('releases', 'POST', {'tag_name': state['tag'], 'name': state['tag'],
            'target_commitish': state['sha'], 'draft': True, 'prerelease': state['prerelease'],
            'generate_release_notes': True})
        run('gh', 'release', 'upload', state['tag'], *[str(Path('dist') / name) for name in state['assets']])
        remote = api(f'releases/{release["id"]}/assets?per_page=100')
        expected = {name: (Path('dist') / name).stat().st_size for name in state['assets']}
        if {asset['name']: asset['size'] for asset in remote if asset['state'] == 'uploaded'} != expected:
            raise ValueError('Uploaded assets do not match the complete local build')
        api(f'releases/{release["id"]}', 'PATCH', {'draft': False, 'make_latest': 'false' if state['prerelease'] else 'true'})
    except BaseException:
        cleanup()
        raise


if __name__ == '__main__':
    {'resolve': resolve, 'build': build, 'publish': publish, 'cleanup': cleanup}[sys.argv[1]]()
