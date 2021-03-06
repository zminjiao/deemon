# Mosgi

Mosgi is the tool that connects to and extracts the needed data from the running vm (i.e. Xdebug file, php sessions). It uses ssh to first back up the
files it is interested in and then downloads the files onto the host. This is done on an external command issuing a save. Mosgi returns the OK back
to the external source as soon as the files are succesfully backupped and continues with saving the files asynchronously. The files are stored in
a local sqlite database. The main files are wrapped in a bashscript to enable easier starting of the underlying lisp program.

The usecase of mosgi is for it to start, connect to a VM, and wait for an external connection that gives it the download signals. The signals are
intergers followed by an id (also integer) that denotes the http-request the downloaded files belong to and under which the files shall be filed
in the sqlite database.


```
Usage: run.sh [-P|--php-session-folder ARG] [-x|--xdebug-trace-file ARG]
              [-p|--port ARG] [-i|--interface ARG] [-t|--target-system ARG]
              [-r|--target-root ARG] [-c|--host-pwd ARG] [-s|--sql-db-path ARG]

Available options:
  -P, --php-session-folder ARG
                           absolute path on the guest system to the folder where the relevant php-sessions are stored (default:/opt/bitnami/php/tmp/)
  -x, --xdebug-trace-file ARG
                           absolute path to the file containing machine readable trace generated by xdebug on the guest system (default:/tmp/xdebug.xt)
  -p, --port ARG           the port mosgi shall listen on for a command connection (default:8844)
  -i, --interface ARG      the ip-address mosgi shall listen on for a command connection (default:127.0.0.1)
  -t, --target-system ARG  the ip-address of the guest system to connect to via ssh - sshd needs to be running
  -r, --target-root ARG    the root user of the guest system (default:root)
  -c, --host-pwd ARG       the password for the root account of the guest system (default:bitnami)
  -s, --sql-db-path ARG    the file path to the sqlite db
```
