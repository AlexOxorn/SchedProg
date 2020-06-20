# SchedProg

A Perl/Tk GUI based Tool for creating Class Schedules.

Takes into account the following contraints
1. Teachers
2. Labs
3. Streams
4. Limits schedules based on current Collective Agreement Rules

Files are saved in YAML format, so they can be edited manually 
if  you are brave enough.

## MAC OS X

### Install perl (this version used 5.30.3)
[perl](https://www.perl.org/get.html#osx)
(build from source, don't use ActivePerl)

### Install required Perl Packages

Assuming that you installed perl into /usr/local/bin...

```bash
sudo /usr/local/bin/cpan install YAML
sudo /usr/local/bin/cpan -fi Tk         # must force install Tk
sudo /usr/local/bin/cpan install Text::CSV
sudo /usr/local/bin/cpan install Excel::Writer::XLSX
sudo /usr/local/bin/cpan install PDF::API2
```

### Install Scheduler
Download zip file and unzip

From a terminal window (bash)

```bash
cd ../SchedProg/schedule/
/usr/local/bin/perl SchedulerManager.pl &
```

### Third Party Software

A X-windows emulator must be installed on your system.

Recommended: XQuartz
