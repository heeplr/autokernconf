### autokernconf.sh - Kernel Automagical Configuration.



Copyright (C) 2000,2001,2007,2011  Giacomo Catenazzi  <cate@debian.org>.
This is free software, see GNU General Public License v2 for details.

* **Version:** 3.2 (24.III.2011)
* **Maintainer:** Giacomo Catenazzi <cate@debian.org>
* **Mirror:** http://cateee.net/autokernconf/
* **Mailing List:** kautoconfigure-devel@lists.sourceforge.net
* **Credits:**
  * Peter Samuelson [scan_PCI function]
  * William Stearns and Andreas Schwab [bash v.1 support]
  * Andreas Jellinghaus
  * tuantuan [handling CONFIG__UNKNOW__]


# About
This script tries to autoconfigure the Linux kernel, detecting the hardware (devices, ...) and software (protocols, filesystems, ...).
It uses soft detections: no direct IO access to unknow devices, thus it is always safe to run this script and it never hangs, but it cannot detect all hardware (mainly some very old hardware).

**Expect some false positives**

Report errors, bugs, additions, wishes and comments <cate@debian.org>.


# Usage
```
# run on target system to generate a list of detected hardware (kdetect.list):
./kdetect.sh
# run to download lkddb and match found hardware with kernel CONFIG_ options
./autokernconf.sh
```

Then merge the generated *config.auto* into your minimal/current/default kernel config.

General Hints:
* you don't need super user privileges.
* you can run this script on a target machine without the need of the kernel sources.


# Developing
There are a lots of redundance: because user maybe has not already installed the drivers (thus we use smart detection on PCI, USB,..)
and not all file methods are usable ('lspci' not installed, '/proc' not mounted or 'dmesg' not usable).
We want to check the drivers that system needs, not the drivers actually installed on actual system (in this case you should simply check the 'System.map').


# Requirements
This is a simple bash shell script. It uses only the following external programs:
* Required: bash[if,echo,test], grep/egrep, sed, uname, which, cp,mv,rm
* Optional: dmesg, wget or curl (for auto fetch of db)
It reads those files (all optional, but missing files reduces detection rate):
* /proc/*
* /var/log/dmesg
* /etc/fstab
* linux/drivers/pci/pci.ids
