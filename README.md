# zw
zig web - light and fast local http server

## Install

### Build:

```bash
git clone https://github.com/beizbol/zw.git

cd zw

zig build -Doptimize=ReleaseSafe
```

### Windows:

```bash
mkdir 'C:/Program Files (x86)/zw'

cp zig-out/bin/zw.exe 'C:/Program Files (x86)/zw'
```
Add 'C:/Program Files (x86)/zw' to Path environment variable.

### Linux:

```bash
mkdir ~/bin

cp zig-out/bin/zw ~/bin/zw

sudo reboot
```

## Usage 

```bash
cd path/to/website/

zw
```

Starts the local http server from the current directory.