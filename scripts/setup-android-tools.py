"""Download an isolated, checksum-verified Android build toolchain (Apple Silicon).
Does not modify global Java, Android Studio, or shell configuration.
"""
import hashlib, json, os, pathlib, subprocess, tarfile, urllib.request, zipfile
root=pathlib.Path(__file__).resolve().parent.parent
store=root/'.toolchains';store.mkdir(exist_ok=True)
def fetch(url,path):
    print('Downloading',path.name,flush=True)
    with urllib.request.urlopen(url,timeout=120) as response,path.open('wb') as output:
        while True:
            block=response.read(1024*1024)
            if not block:break
            output.write(block)
def checked(url,path,checksum):
    if not path.exists():fetch(url,path)
    if hashlib.sha256(path.read_bytes()).hexdigest()!=checksum:raise RuntimeError('Checksum mismatch: '+str(path))
if not (store/'jdk').exists():
    url='https://corretto.aws/downloads/latest/amazon-corretto-21-aarch64-macos-jdk.tar.gz'
    with urllib.request.urlopen('https://corretto.aws/downloads/latest_sha256/amazon-corretto-21-aarch64-macos-jdk.tar.gz',timeout=30) as r: checksum=r.read().decode().split()[0]
    package={'link':url,'checksum':checksum};archive=store/'jdk.tar.gz';checked(url,archive,checksum)
    with tarfile.open(archive) as tar:
        top=tar.getnames()[0].split('/')[0];tar.extractall(store,filter='data') if hasattr(tarfile,'data_filter') else tar.extractall(store)
    (store/top).rename(store/'jdk')
    (store/'jdk-source.json').write_text(json.dumps({'url':package['link'],'sha256':package['checksum']},indent=2))
archive=store/'gradle.zip'
if not (store/'gradle-8.11.1').exists():
    with urllib.request.urlopen('https://services.gradle.org/distributions/gradle-8.11.1-bin.zip.sha256',timeout=30) as r: checksum=r.read().decode().strip()
    checked('https://services.gradle.org/distributions/gradle-8.11.1-bin.zip',archive,checksum)
    with zipfile.ZipFile(archive) as z:z.extractall(store)
    (store/'gradle-8.11.1/bin/gradle').chmod(0o755)
archive=store/'android-tools.zip';sdk=store/'android-sdk'
if not (sdk/'cmdline-tools/latest').exists():
    checked('https://dl.google.com/android/repository/commandlinetools-mac_arm64-15859902_latest.zip',archive,'835b62a26162b229b441d1f6d4680383815a270809eb33522c0d480fa5002c4e')
    temp=store/'sdk-extract';temp.mkdir(exist_ok=True)
    with zipfile.ZipFile(archive) as z:z.extractall(temp)
    (sdk/'cmdline-tools').mkdir(parents=True,exist_ok=True);(temp/'cmdline-tools').rename(sdk/'cmdline-tools/latest')
    for p in (sdk/'cmdline-tools/latest/bin').iterdir():p.chmod(0o755)
env={**os.environ,'JAVA_HOME':str(store/'jdk/Contents/Home'),'ANDROID_HOME':str(sdk),'ANDROID_USER_HOME':str(store/'android-user'),'GRADLE_USER_HOME':str(store/'gradle-user')}
manager=str(sdk/'cmdline-tools/latest/bin/sdkmanager')
print('Installing SDK platform 35 and build tools; accepting standard SDK licenses for this local development environment.',flush=True)
subprocess.run([manager,'--sdk_root='+str(sdk),'--licenses'],input=('y\n'*100).encode(),env=env,check=True)
subprocess.run([manager,'--sdk_root='+str(sdk),'platforms;android-35','build-tools;35.0.0','platform-tools'],input=('y\n'*100).encode(),env=env,check=True)
(root/'android/local.properties').write_text('sdk.dir='+str(sdk)+'\n')
print('Android toolchain ready in',store,flush=True)
