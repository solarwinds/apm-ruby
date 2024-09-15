# Debug the c-code with gdb

inspired by: <https://dev.to/wataash/how-to-create-and-debug-ruby-gem-with-c-native-extension-3l8b>

## install ruby with sources

rbenv is your friend ;) -k means keep sources

```sh
rbenv install -k 2.7.5
rbenv shell 2.7.5

# check that ruby is debuggable
type ruby           # => ruby is /home/wsh/.rbenv/shims/ruby
rbenv which ruby    # => /home/wsh/.rbenv/versions/2.6.3/bin/ruby
```

## add debug info when compiling solarwinds_apm

enable `OBOE_DEBUG` to `true` to turn off optimization and enable debug information

```sh
export OBOE_DEBUG=true
```

## start ruby app with gdb

This will run ruby and load the app with a breakpoint in the Reporter::startThread
c-function.

```sh
bundle exec gdb -q -ex 'set breakpoint pending on' -ex 'b Reporter::startThread' -ex run --args ruby -e 'require "./app"'
```

If there is a bug in the ruby code or a ruby byebug binding that halts the
script, the debugger will hang without showing any output.
So, make sure `bundle exec ruby app.rb` runs.

use the gdb navigation commands to step through the code. If it says:

```console
(gdb) n
Single stepping until exit from function _ZN8Reporter11startThreadEv@plt,
which has no line number information.
```

type `c` and it may end up stopping in the right location.

## make ruby .gdbinit macros available

These macros are pretty elaborate. They are checked in the ruby github
repo: <https://github.com/ruby/ruby/blob/master/.gdbinit>
The code is nicely formatted and colorized in github and easiest to read there.

installation in the user's home dir:

```sh
wget https://github.com/ruby/ruby/blob/master/.gdbinit
```

## examples

Some inspiring examples here:

<https://jvns.ca/blog/2016/06/12/a-weird-system-call-process-vm-readv/>

<https://medium.com/@zanker/finding-a-ruby-bug-with-gdb-56d6b321bc86>

<!-- markdownlint-disable MD025 -->

# Debug the c-code with core dump

<!-- markdownlint-enable MD025 -->

If the core dump is produced, it's easier to check the backtrace with it in gdb

For example, `(core dumped)` indicate the crash file is dumped

```console
./start.sh: line 37:    65 Segmentation fault      (core dumped) ...
```

## Prepare

### 1. Check the core dump size is not constrained

```console
ulimit -c unlimited       # have to set this for unlimited core dump file size without trimmed error message
```

### 2. Check if the crash report program is configured correctly

Ubuntu use [apport](https://wiki.ubuntu.com/Apport); Debian use [kdump](https://mudongliang.github.io/2018/07/02/debian-enable-kernel-dump.html)

In ubuntu, if apport is disabled via `service apport stop`, the core dump file will be stored in the current directory and named `core`. If apport is enabled, find the crash file (typically under `/var/crash`) and extract the CoreDump file from it using `apport-unpack <filename>.crash <destination>`.

### 3. Install solarwinds_apm with comprehensive debug information

Set the environment variable `OBOE_DEBUG` to `true` that download the special version of liboboe.

This liboboe is compiled with RelWithDebInfo flag on, which include the debug symbol and other debug information.

```console
export OBOE_DEBUG=true
gem install solarwinds_apm
```

Reproduce the crash using this version of solarwinds_apm which provides extended debug information in the coredump.

## Debug by checking the backtrace after obtain core dump file

### 1. Check that ruby is debuggable

Ensure that `ruby.h` is present by verifying the existence of the Ruby development library (e.g., `ruby-dev`).

```console
type ruby           # => ruby is hashed (/root/.rbenv/shims/ruby)
rbenv which ruby    # => /root/.rbenv/versions/3.1.0/bin/ruby
```

### 2. Load the core dump file in gdb

```console
gdb /root/.rbenv/versions/3.1.0/bin/ruby core
(gdb) bt full      # backtrace full trace; investigate the issue from here
```
