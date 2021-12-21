# Restic backup

### Usage

`bkp.sh` - execute restic backup according to configuration

This script executes `sudo restic`, so it is a good idea to add NOPASSWD rule to sudoers configuration:

    Cmnd_Alias  BACKUP = /usr/bin/restic, /snap/bin/restic
    %wheel ALL=(ALL) ALL, NOPASSWD: BACKUP

# Restic pull backup

### Usage:

`bkp-pull.sh --help` - help and usage

`bkp-pull.sh host` - open ssh connection to host and execute restic remotely

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
backup
bkp-*.log
bkp-*.log.*
log
logs
.m2
target
*.class
*.pyc
*.o
*~
*.bak
*.tmp
*.temp
*.lock
*.part
tmp
temp
pkg
.trash*
.local
lost+found
```
