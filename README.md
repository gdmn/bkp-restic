# Restic backup

### Usage

`bkp.sh` - execute restic backup according to configuration

This script executes `sudo restic`, so it is a good idea to add NOPASSWD rule to sudoers configuration:

    Cmnd_Alias  BACKUP = /usr/bin/restic, /snap/bin/restic
    Defaults!BACKUP    env_keep += "RESTIC_PASSWORD RESTIC_REPOSITORY"
    %wheel ALL=(ALL) ALL, NOPASSWD: BACKUP

# Restic pull backup

### Usage:

`bkp-pull.sh --help` - help and usage

`bkp-pull.sh host` - open ssh connection to a host and execute restic remotely

This script executes `sudo restic` remotely, so it is a good idea to add NOPASSWD rule to sudoers configuration.

### How does it work?

It opens SSH connection to the host and redirects a port (`60008` in the example)
to the restic rest server (`backuphost:8000` in the example).
Thanks to that, restic rest server can be in the local network without
any port exposed publicly.
Next, it creates temporary directory on the host with configuration files.
Include and exclude lists are normal files.
However, repository location, password and main script are FIFO sockets.
It means, that they can be read only once.
The last step is execution of the main script on the remote host,
which performs backup.

If the host has different location of restic main executable,
not available in the `PATH`, it can be
overriden (e.g. in the host specific configuration file):

	export RESTIC_EXE="/opt/bin/restic"

If the host does not have or need to use `sudo`,
it also can be overriden:

	export SUDO_RESTIC_EXE="/opt/bin/restic"

# Configuration

`$CONFIGURATION_DIR` is `$HOME/.config/bkp-restic`.

Main configuration file: `$CONFIGURATION_DIR/main.conf`

Host specific configuration file: `$CONFIGURATION_DIR/host.conf`

Host specific configuration overrides main configuration.

In case of `bkp-pull.sh`, `host` is the same value as the first argument to the script.

In case of `bkp.sh`, `host` is a local hostname (evaluated `$(hostnamectl status --transient)`).

##### Restic backup - example configuration

```
export BKP_RESTIC_PASSWORD='abc'

export BKP_REST_RESTIC_REPOSITORY="rest:http://admin:password@backuphost:8000/$REMOTE_HOST"

export BKP_RESTIC_INCLUDE_FILES="$CONFIGURATION_DIR/bkp-include.txt"
export BKP_RESTIC_EXCLUDE_FILES="$CONFIGURATION_DIR/bkp-exclude.txt"
```

`backuphost:8000` is the actual address of restic-rest server instance.
`BKP_RESTIC_INCLUDE_FILES` and `BKP_RESTIC_EXCLUDE_FILES` contain include and exclude patterns,
exclude file patterns are case insensitive.

##### Restic pull backup - example configuration

```
export BKP_RESTIC_PASSWORD='abc'

export BKP_FORWARDED_RESTIC_REPOSITORY="rest:http://admin:password@localhost:60008/$REMOTE_HOST"
export BKP_SSH_FORWARD_RULE='60008:backuphost:8000'

export BKP_RESTIC_INCLUDE_FILES="$CONFIGURATION_DIR/bkp-include.txt"
export BKP_RESTIC_EXCLUDE_FILES="$CONFIGURATION_DIR/bkp-exclude.txt"
```

`BKP_RESTIC_PASSWORD` and `BKP_FORWARDED_RESTIC_REPOSITORY` are stored as FIFO files in the remote temporary directory.
`BKP_SSH_FORWARD_RULE` is the SSH remote forward rule.
`backuphost:8000` is the actual address of restic-rest server instance.

### Example bkp-include.txt

```
/etc
/home
/root
```

### Example bkp-exclude.txt

```
cache
*cache
caches
Cache
*Cache
CacheStorage
.ds_store
backup
backups
bkp-*.log
bkp-*.log.*
*crash*.log
log
logs
.m2
.gradle
.cargo
go
target
*.class
*.pyc
*.o
*~
*.bak
*.old
*.tmp
*.temp
*.lock
*.part
.ptmp*
tmp
temp
pkg
.trash*
.local
lost+found
random*
generated
thumbs
thumbs.db
thumb
thumbnails
.thumbnails
```

# bkp-env.sh

The script imports the backup environment for a given host. When called without arguments,
it imports the environment for the current host (`hostnamectl status --transient`).

After running the script (`. bkp-env.sh`), current environment will contain
`RESTIC_REPOSITORY` and `RESTIC_PASSWORD` variables,
so it will be possible to run all `restic` commands without specyfing repository or password.

# bkp-prune.sh

It keeps repositories nice and tidy. Intended to be run periodically.
The script requires configuration variable `BKP_REAL_PATH_RESTIC_REPOSITORY` to be set
to the filesystem path with repositories.

# bkp-status.sh

It prints all snapshots for all repositories found
in the filesystem path `BKP_REAL_PATH_RESTIC_REPOSITORY`.

# bkp-stream.sh

Backup input stream. E.g. `tar -c /home | $(basename $0) home.tar` will create compressed `home.tar.zst` in the repository `hostname-streams` (repository can be configured by `BKP_REST_RESTIC_REPOSITORY` property).

# bkp-openwrt.sh

Backup openwrt router using lede `/cgi-bin/cgi-backup` endpoint. Default repository is `openwrt_IP`. It logs in using `root` user name and property `LUCI_PASSWORD`.

# bkp-mount.sh

Mount specific host backup.
