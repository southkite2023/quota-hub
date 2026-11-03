#!/usr/bin/env python3
"""Package a native Linux Flutter bundle; no cross-architecture relabeling."""
import hashlib,json,os,platform,shutil,subprocess,urllib.request
from pathlib import Path

def run(*args, **kwargs): subprocess.run(args, check=True, **kwargs)
root=Path(__file__).resolve().parents[2]
arch={'x86_64':'x64','aarch64':'arm64'}[platform.machine()]
debarch={'x64':'amd64','arm64':'arm64'}[arch]
rpmarch={'x64':'x86_64','arm64':'aarch64'}[arch]
version=next(x.split(':',1)[1].strip().split('+')[0] for x in (root/'apps/client/pubspec.yaml').read_text().splitlines() if x.startswith('version:'))
bundle=root/f'apps/client/build/linux/{arch}/release/bundle'
out=root/'linux-dist';out.mkdir(exist_ok=True)
work=root/'linux-package';shutil.rmtree(work,ignore_errors=True);work.mkdir()
name=f'Astracct-Linux-{version}-{rpmarch}'
stage=work/'root';app=stage/'opt/astracct';app.parent.mkdir(parents=True);shutil.copytree(bundle,app)
desktop='[Desktop Entry]\nType=Application\nName=Astracct\nComment=Balance and account dashboard\nExec=/opt/astracct/astracct\nIcon=com.yuashie.astracct\nTerminal=false\nCategories=Office;Finance;\n'
for path,content in [('usr/share/applications/com.yuashie.astracct.desktop',desktop)]:
 p=stage/path;p.parent.mkdir(parents=True,exist_ok=True);p.write_text(content)
icon=stage/'usr/share/icons/hicolor/256x256/apps/com.yuashie.astracct.png';icon.parent.mkdir(parents=True);shutil.copy(root/'apps/client/assets/app-icon.png',icon)
(app/'LINUX-README.txt').write_text('Astracct '+version+' Linux public test build\nRequires glibc 2.39+, GTK 3, libsecret, libayatana-appindicator3 and a running Secret Service (GNOME Keyring / compatible wallet).\nTested build baseline: Ubuntu 24.04. Other distributions require compatible libraries; RPM does not imply universal distro compatibility.\nRun ./astracct from the extracted directory. Keep the full bundle.\nAppImage requires FUSE or --appimage-extract-and-run. System GUI libraries are not bundled.\nSystem biometric unlock and automatic update installation are not supported on Linux. Install updates manually; user data is retained.\nTray availability depends on desktop extensions. Startup paths must remain installed.\n')
run('tar','-czf',str(out/(name+'.tar.gz')),'-C',str(app),'.')
control=stage/'DEBIAN/control';control.parent.mkdir();control.write_text(f'Package: astracct\nVersion: {version}\nArchitecture: {debarch}\nMaintainer: Astracct <noreply@yuashie.cn>\nDepends: libc6 (>= 2.39), libgtk-3-0t64, libsecret-1-0, libayatana-appindicator3-1\nRecommends: gnome-keyring\nDescription: Astracct balance dashboard (public test build)\n')
run('dpkg-deb','--root-owner-group','--build',str(stage),str(out/(name+'.deb')))
shutil.rmtree(control.parent)
rpmbuild=work/'rpmbuild';(rpmbuild/'SPECS').mkdir(parents=True)
spec=rpmbuild/'SPECS/astracct.spec';spec.write_text(f'''Name: astracct
Version: {version}
Release: 1
Summary: Astracct balance dashboard
License: Proprietary
BuildArch: {rpmarch}
Requires: gtk3, libsecret, libayatana-appindicator-gtk3
%description
Astracct public Linux test build. Requires glibc 2.39 or newer.
%install
mkdir -p %{{buildroot}}
cp -a {stage}/. %{{buildroot}}/
%files
/opt/astracct
/usr/share/applications/com.yuashie.astracct.desktop
/usr/share/icons/hicolor/256x256/apps/com.yuashie.astracct.png
''')
run('rpmbuild','--define',f'_topdir {rpmbuild}','--define','_build_id_links none','--define','__os_install_post %{nil}','-bb',str(spec))
shutil.copy(next((rpmbuild/'RPMS').rglob('*.rpm')),out/(name+'.rpm'))
appdir=work/'Astracct.AppDir';appdir.mkdir();shutil.copytree(app,appdir/'usr/lib/astracct')
(appdir/'com.yuashie.astracct.desktop').write_text(desktop.replace('/opt/astracct/astracct','astracct'))
shutil.copy(icon,appdir/'com.yuashie.astracct.png')
runner=appdir/'AppRun';runner.write_text('#!/bin/sh\nHERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)\nexec "$HERE/usr/lib/astracct/astracct" "$@"\n');runner.chmod(0o755)
request=urllib.request.Request('https://api.github.com/repos/AppImage/appimagetool/releases/latest',headers={'User-Agent':'Astracct-packager'})
release=json.load(urllib.request.urlopen(request))
asset=next(a for a in release['assets'] if a['name']==f'appimagetool-{rpmarch}.AppImage')
data=urllib.request.urlopen(asset['browser_download_url']).read()
assert asset.get('digest')=='sha256:'+hashlib.sha256(data).hexdigest(),'AppImage tool digest mismatch'
tool=work/'appimagetool';tool.write_bytes(data);tool.chmod(0o755)
run(str(tool),'--appimage-extract-and-run',str(appdir),str(out/(name+'.AppImage')),env={**os.environ,'ARCH':rpmarch,'VERSION':version})
records=[]
for p in sorted(out.glob(name+'.*')):
 records.append({'name':p.name,'version':version,'arch':rpmarch,'bytes':p.stat().st_size,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()})
assert len(records)==4
(out/f'packages-{rpmarch}.json').write_text(json.dumps(records,indent=2)+'\n')
(out/f'SHA256SUMS-{rpmarch}.txt').write_text(''.join(f"{p['sha256']}  {p['name']}\n" for p in records))
