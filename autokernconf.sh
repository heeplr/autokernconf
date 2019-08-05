#!/bin/bash
#
#  autoikernconf.sh : Kernal Automagical Configuration.
#
#  Copyright (C) 2000,2001,2007,2011  Giacomo Catenazzi  <cate@debian.org>
#  This is free software, see GNU General Public License v2 for details.
#
#  Version: 3.2 (24.III.2011)
#  Maintainer: Giacomo Catenazzi <cate@debian.org>
#  Mirror: http://cateee.net/autokernconf/
#  Mailing List: kautoconfigure-devel@lists.sourceforge.net
#  Credits:
#    Peter Samuelson [scan_PCI function]
#    William Stearns and Andreas Schwab [bash v.1 support]
#    Andreas Jellinghaus
#    tuantuan [handling CONFIG__UNKNOW__]
#
# This script try to autoconfigure the Linux kernel, detecting the
# hardware (devices, ...) and software (protocols, filesystems, ...).
# It uses soft detections: no direct IO access to unknow devices, thus
# it is always safe to run this script and it never hangs, but it cannot
# detect all hardware (mainly some very old hardware).
#
# Report errors, bugs, additions, wishes and comments <cate@debian.org>.
# 
# Usage:
#   General Hints:
#     you don't need super user privileges.
#     you can run this script on a target machine without the need of
#       the kernel sources.
#
# Extra information for the developers:
#   There are a lots of redundance: because user maybe has not already
#     installed the drivers (thus we use smart detection on PCI, USB,..)
#     and not all file methods are usable ('lspci' not installed,
#     '/proc' not mounted or 'dmesg' not usable).
#   We want to check the drivers that system needs, not the drivers
#     actually installed on actual system (in this case you should
#     simply check the 'System.map').
#
# This is a simple bash shell script. It use only the following external
#  program:
#   Req: bash[if,echo,test], grep/egrep, sed, uname, which, cp,mv,rm
#   Opt: dmesg
# and read this files:
#   Opt: /proc/*; /var/log/dmesg; /etc/fstab; linux/drivers/pci/pci.ids


#--- Configuration of kernautoconf ---#

CONF_AUTO=config.auto
AUTO_KAC=kdetect.list
LKDDB_URL="https://cateee.net/sources/lkddb/lkddb.list"

IFSorig="$IFS"
LANG=C

Null=/dev/null

if ! [ -f "$AUTO_KAC" ] ; then
    echo "$AUTO_KAC not found. please run ./kdetect.sh first."
    exit 1
fi

if ! [ -f lkddb.list ] ; then
    echo "lkddb.list not found"
    # try to download
    if [ -n "$(which wget)" ] ; then
        wget "$LKDDB_URL" || exit 1
    else if [ -n "$(which curl)" ] ; then
        curl -O "$LKDDB_URL" || exit 1
    fi
fi

echo "#" > $CONF_AUTO
echo "# Automagically generated file. Do not edit!" >> $CONF_AUTO
echo "# (autoprobe v1.5)" >> $CONF_AUTO
echo "#" >> $CONF_AUTO
#--- (Configuration of Autoconfigure) ---#


#--- Definition of the Configuration Interface ---#

# 'comment'      writes comments on output file
#
# comment 'some comment'
#
comment() {
    if [ "$PROVIDE_DEBUG" = "y" ]; then
	echo "# --- $@ ---" >> $CONF_AUTO
    fi
    echo "$@"
}
#
# 'define'    sets configuration (general funcions)
# 'found'     sets the value 'y/m' (driver detected)
# 'found_y'   sets the value 'y' (driver detected, forces built-in)
# 'found_m'   sets the value 'm' (driver detected, build as module)
# 'found_n'   sets the value 'n' (driver not needed)
# 'provide'   sets a PROVIDE_ variable (internal variable)
#
#  The priority is: y > m > n > 'other'
#
#  Rules:
#   string and and numeric variables: 'define'
#   important configuration (needed to boot): 'found_y'
#   normal detection: 'found'
#   ...: 'found_m'
#   not needed configuration: 'found_n'
#   not detected: '' (nothing)
#   internal uses: 'provide'
#
#  define    CONF  value
#  found     VAR
#  found_y   VAR_FOO
#  found_m   VAR_BAR
#  found_n   VAR_OTHER
#  provide   VAR_FOO_AND_BAR
#
define () {
    echo "$1=$2" >> $CONF_AUTO
    eval "$1=$2"
}
# "${!conf}" is available only on bash2. Too new for us!
raw_found () {
    define "CONFIG_$1" y
}

found () {
    for conf in $(echo "$@" | sed -ne 's/^.*:[ \t]*\(.*\)*[ \t]*:.*$/\1/p' - ) ; do
        if [ "$conf" == "CONFIG__UNKNOW__" ]; then
            echo "# $@" >> $CONF_AUTO
	elif [ "$(eval echo \$$conf)" != "y" ]; then
	    define "$conf" y
        fi
    done
}
found_y () {
    for conf in "$@" ; do
    	if [ "$(eval echo \$$conf)" != "y" ]; then
	    define "$conf" y
    	fi
    done
}
found_m () {
    for conf in "$@" ; do
    	if [ "$(eval echo \$$conf)" != "y"  -a  "$(eval echo \$$conf)" != "m" ]; then
	    define "$conf" m
    	fi
    done
}
found_n () {
    for conf in "$@" ; do
    	if [ -z "$(eval echo \$$conf)" ]; then
	    define "$conf" n
    	fi
    done
}
provide () {
    if [ "$(eval echo \$PROVIDE_$1)" != "y" ]; then
        eval "PROVIDE_$1=y"
    fi
}
#--- (Definition of Configuration Interface) ---#


is_mid () {
    [ $( (echo "$1"; echo "$2"; echo "$3") | sort -n | head -2 | tail -1 ) = "$2" ]
}


#--- Parse "autoconfig.rules" ---#


if grep -sqi '^pci [0-9]' $AUTO_KAC; then
    provide CONFIG_PCI
    found CONFIG_PCI
fi

hid () {
    if grep -sqe "^hid $1 $2 $3" $AUTO_KAC ; then
        found "$@"
    fi
}

hda () {
    if grep -sqe "^hda $1 $2" $AUTO_KAC ; then
        found "$@"
    fi
}

i2c () {
    if grep -sqe "^i2c $1" $AUTO_KAC ; then
        found "$@"
    fi
}

eisa () {
    if grep -sqe "^eisa $1" $AUTO_KAC ; then
        found "$@"
    fi
}

bcma () {
    if grep -sqe "^bcma $1 $2 $3 $4" $AUTO_KAC ; then
        found "$@"
    fi
}

input () {
    if grep -sqe "^input $1 $2 $3 $4 $5 $6 $7 $8 $9 $10 $11 $12 $13" $AUTO_KAC ; then
        found "$@"
    fi
}

i2c-snd () {
    if grep -sqe "^i2c-snd $1" $AUTO_KAC ; then
        found "$@"
    fi
}

parisc () {
    if grep -sqe "^parisc $1 $2 $3 $4" $AUTO_KAC ; then
        found "$@"
    fi
}

pcmcia () {
    if grep -sqe "^pcmcia $1 $2 $3 $4 $5 $6 $7 $8 $9" $AUTO_KAC ; then
        found "$@"
    fi
}

of () {
    if grep -sqe "^of $1 $2 $3" $AUTO_KAC ; then
        found "$@"
    fi
}

spi () {
    if grep -sqe "^spi $1" $AUTO_KAC ; then
        found "$@"
    fi
}

vio () {
    if grep -sqe "^vio $1 $2" $AUTO_KAC ; then
        found "$@"
    fi
}

virtio () {
    if grep -sqe "^virtio $1 $2" $AUTO_KAC ; then
        found "$@"
    fi
}

ssb () {
    if grep -sqe "^ssb $1 $2 $3" $AUTO_KAC ; then
        found "$@"
    fi
}

sdio () {
    if grep -sqe "^sdio $1 $2 $3" $AUTO_KAC ; then
        found "$@"
    fi
}

tc () {
    if grep -sqe "^tc $1 $2" $AUTO_KAC ; then
        found "$@"
    fi
}

zorro () {
    if grep -sqe "^zorro $1 $2" $AUTO_KAC ; then
        found "$@"
    fi
}

kver () {
    echo "kver is unsupported, yet"
}

pci () {
    if grep -sqe "^pci $1 $2 $3 $4 $5" $AUTO_KAC ; then
	found "$@"
    fi
}

pci_epf () {
    if grep -sqe "^pci_epf $1" $AUTO_KAC ; then
        found "$@"
    fi
}

rpmsg () {
    if grep -sqe "^rpmsg $1" $AUTO_KAC ; then
        found "$@"
    fi
}

slim () {
    if grep -sqe "^slim $1 $2 $3 $4" $AUTO_KAC ; then
        found "$@"
    fi
}

usb () {
    line=$(grep -oe "^usb $1 $2 $3 $4" $AUTO_KAC )
    if [ -n "$line" ] ; then
	bcd=$(echo "$line" | grep -o '....$' )
	if [ "$bcd" = "...." ] ; then
	    found "$@"
	else
	    if is_mid "$bcd" "$5" "$6" ; then
	        found "$@"
	    fi
	fi
    fi
}

ieee1394 () {
    if grep -sqe "^ieee1394 $1 $2 $3 $4" $AUTO_KAC ; then
        found "$@"
    fi
}

ccw () {
    if grep -sqe "^ccw $1 $2 $3 $4" $AUTO_KAC ; then
        found "$@"
    fi
}

ap () {
    if grep -sqe "^ap $1" $AUTO_KAC ; then
        found "$@"
    fi
}

acpi () {
    if grep -sqe  "^acpi $1" $AUTO_KAC ; then
        found "$@"
    fi
}

pnp () {
    if grep -sqe  "^pnp $1" $AUTO_KAC ; then
        found "$@"
    fi
}

serio () {
    if grep -sqe  "^serio $1 $2 $3 $4" $AUTO_KAC ; then
        found "$@"
    fi
}

platform () {
    if grep -sqe  "^platform $1" $AUTO_KAC ; then
        found "$@"
    fi
}

fs () {
    if grep -sqe  "^fs $1" $AUTO_KAC ; then
        found "$@"
    fi
}


module () {
    if grep -sqe  "^module $1" $AUTO_KAC ; then
        found "$@"
    fi
}

# ----
parse_kdetect_list () {
    for conf in $(grep "^config " $AUTO_KAC ) ; do
	if [ "$conf" != "config" ] ; then
	    raw_found $conf
	fi
    done	    
}



#----------#

lkddb () {
   [ "$1" = "pci"       ] && ( shift; pci	"$@" ; return )
   [ "$1" = "pci_epf"   ] && ( shift; pci_epf   "$@" ; return )
   [ "$1" = "usb"       ] && ( shift; usb	"$@" ; return )
   [ "$1" = "ieee1394"  ] && ( shift; ieee1394	"$@" ; return )
   [ "$1" = "ccw"       ] && ( shift; ccw	"$@" ; return )
   [ "$1" = "ap"   	] && ( shift; ap 	"$@" ; return )
   [ "$1" = "acpi" 	] && ( shift; acpi 	"$@" ; return )
   [ "$1" = "pnp"  	] && ( shift; pnp 	"$@" ; return )
   [ "$1" = "serio" 	] && ( shift; serio 	"$@" ; return )
   [ "$1" = "platform"  ] && ( shift; platform  "$@" ; return )
   [ "$1" = "fs"   	] && ( shift; fs 	"$@" ; return )
   [ "$1" = "module"    ] && ( shift; module    "$@" ; return )
   [ "$1" = "hid"       ] && ( shift; hid       "$@" ; return )
   [ "$1" = "hda"       ] && ( shift; hda       "$@" ; return )
   [ "$1" = "i2c"       ] && ( shift; i2c       "$@" ; return )
   [ "$1" = "eisa"      ] && ( shift; eisa      "$@" ; return )
   [ "$1" = "bcma"      ] && ( shift; bcma      "$@" ; return )
   [ "$1" = "input"     ] && ( shift; input     "$@" ; return )
   [ "$1" = "i2c-snd"   ] && ( shift; i2c-snd   "$@" ; return )
   [ "$1" = "parisc"    ] && ( shift; parisc    "$@" ; return )
   [ "$1" = "pcmcia"    ] && ( shift; pcmcia    "$@" ; return )
   [ "$1" = "of"        ] && ( shift; of        "$@" ; return )
   [ "$1" = "spi"       ] && ( shift; spi       "$@" ; return )
   [ "$1" = "vio"       ] && ( shift; vio       "$@" ; return )
   [ "$1" = "virtio"    ] && ( shift; virtio    "$@" ; return )
   [ "$1" = "ssb"       ] && ( shift; ssb       "$@" ; return )
   [ "$1" = "sdio"      ] && ( shift; sdio      "$@" ; return )
   [ "$1" = "tc"        ] && ( shift; tc        "$@" ; return )
   [ "$1" = "zorro"     ] && ( shift; zorro     "$@" ; return )
   [ "$1" = "rpmsg"     ] && ( shift; rpmsg     "$@" ; return )
   [ "$1" = "slim"      ] && ( shift; slim      "$@" ; return )
}
parse_kdetect_list

comment 'Parsing configuration database....'
comment '.... [please wait] ....'
. lkddb.list
comment 'Main detection finished'
#--- (Parse "autoconfig.rules") ---#



comment 'End of Autodetection'

exit 0


