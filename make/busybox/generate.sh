#!/bin/bash
# Generates a Config.in(.busybox) of Busybox for Freetz
BBDIR="$(dirname $(readlink -f $0))"
BBVER="${1:-$(sed -n 's/^$(call PKG_INIT_BIN,[^)]*),\([^,]*\),.*/\1/p' $BBDIR/busybox.mk)}"
BBOUT="$BBDIR/Config.in.busybox.$BBVER"
BBDEP="$BBDIR/busybox.rebuild-subopts.mk.in"
echo -n "BusyBox v$BBVER ... "

# supports int/bool/string/choice values
default() {
	sed -r -i '/(^config FREETZ_BUSYBOX_'"$1"'$|^[ \t]*prompt "'"$1"'")/,+5 {
		s,(\tdefault )("?)[^"]*\2,\1\2'"$2"'\2,
	}' "$BBOUT"
}

depends_on() {
	sed -r -i '/^config FREETZ_BUSYBOX_'"$1"'$/,/^[ \t]+help$/ {
		/^[ \t]+help$/ i\
	depends on '"$2"'
	}' "$BBOUT"
}

select_() {
	sed -r -i '/^config FREETZ_BUSYBOX_'"$1"'$/,/^[ \t]+help$/ {
		/^[ \t]+help$/ i\
	select '"$2"'
	}' "$BBOUT"
}

echo -n "unpacking ..."
rm -rf "$BBDIR/busybox-$BBVER"
tar xf "$BBDIR/../../dl/busybox-$BBVER.tar.bz2" -C "$BBDIR"

echo -n " patching ..."
cd "$BBDIR/busybox-$BBVER/"
for p in $BBDIR/patches/$BBVER/*.patch; do
	patch -p0 < $p >/dev/null
done

echo -n " building ..."
FREETZ_GENERATE_CONFIG_IN_ONLY=y ./scripts/gen_build_files.sh "$BBDIR/busybox-$BBVER/" "$BBDIR/busybox-$BBVER/" >/dev/null

echo -n " parsing ..."
echo -e "\n### Do not edit this file! Run generate.sh to create it. ###\n\n" > "$BBOUT"
echo -e "config _VERSION_${BBVER//\./_}\n\tbool\n\tdefault y\n\n" >> "$BBOUT"
$BBDIR/../../tools/parse-config Config.in >> "$BBOUT" 2>/dev/null
rm -rf "$BBDIR/busybox-$BBVER"

echo -n " searching ..."
nonfeature_symbols=""
feature_symbols=""
for symbol in $(sed -n 's/^config //p' "$BBOUT"); do
	if [ "${symbol:0:8}" != "FEATURE_" ]; then
		nonfeature_symbols="${nonfeature_symbols}${nonfeature_symbols:+|}${symbol}"
	else
		feature_symbols="${feature_symbols}${feature_symbols:+|}${symbol}"
	fi
done

echo -n " replacing ..."
sed -i -r \
	-e "s,([ (!])(${feature_symbols})($|[ )]),\1FREETZ_BUSYBOX_\2\3,g" \
	-e "/^[ \t#]*(config|default|depends|select|range|if)/{
		s,([ (!])(${nonfeature_symbols})($|[ )]),\1FREETZ_BUSYBOX_\2\3,g
		s,([ (!])(${nonfeature_symbols})($|[ )]),\1FREETZ_BUSYBOX_\2\3,g
	}" \
	"$BBOUT"
sed -i '/^mainmenu /d' "$BBOUT"
sed -i 's!\(^#*[\t ]*default \)y\(.*\)$!\1n\2!g;' "$BBOUT"

echo -n " finalizing ..."
echo -e "\n### Do not edit this file! Run generate.sh to create it. ###\n\n" | tee "$BBDEP.$BBVER" > "$BBDEP"
sed -n 's/^config /$(PKG)_REBUILD_SUBOPTS += /p' "$BBOUT" | sort -u >> "$BBDEP.$BBVER"
grep -vEh '^$|^#' $BBDEP.* | sort -u >> "$BBDEP"

default _VERSION_${BBVER//\./_} "y"
default MD5SUM "y" # for modsave
default FEATURE_COPYBUF_KB 64
default FEATURE_VI_MAX_LEN 1024
default SUBST_WCHAR 0
default LAST_SUPPORTED_WCHAR 0
default BUSYBOX_EXEC_PATH "/bin/busybox"
default "Buffer allocation policy" FREETZ_BUSYBOX_FEATURE_BUFFERS_GO_ON_STACK
depends_on LOCALE_SUPPORT "!FREETZ_TARGET_UCLIBC_0_9_28"
depends_on FEATURE_IPV6 "FREETZ_TARGET_IPV6_SUPPORT"
depends_on KLOGD "FREETZ_AVM_HAS_PRINTK"
depends_on RFKILL "!FREETZ_KERNEL_VERSION_2_6_13"
depends_on WGET "!FREETZ_PACKAGE_WGET \|\| FREETZ_WGET_ALWAYS_AVAILABLE"
depends_on XZ "!FREETZ_PACKAGE_XZ"
depends_on TELNETD "FREETZ_ADD_TELNETD || \(FREETZ_AVM_HAS_TELNETD \&\& !FREETZ_REMOVE_TELNETD\)"

depends_on UBIATTACH "FREETZ_KERNEL_VERSION_2_6_28_MIN \&\& !FREETZ_SYSTEM_TYPE_GRX5"
depends_on UBIDETACH "FREETZ_KERNEL_VERSION_2_6_28_MIN \&\& !FREETZ_SYSTEM_TYPE_GRX5"
depends_on UBIMKVOL "FREETZ_KERNEL_VERSION_2_6_28_MIN \&\& !FREETZ_SYSTEM_TYPE_GRX5"
depends_on UBIRENAME "FREETZ_KERNEL_VERSION_2_6_28_MIN \&\& !FREETZ_SYSTEM_TYPE_GRX5"
depends_on UBIRMVOL "FREETZ_KERNEL_VERSION_2_6_28_MIN \&\& !FREETZ_SYSTEM_TYPE_GRX5"
depends_on UBIRSVOL "FREETZ_KERNEL_VERSION_2_6_28_MIN \&\& !FREETZ_SYSTEM_TYPE_GRX5"
depends_on UBIUPDATEVOL "FREETZ_KERNEL_VERSION_2_6_28_MIN \&\& !FREETZ_SYSTEM_TYPE_GRX5"

# Freetz mandatory options BUSYBOX_FEATURE_PS_LONG & BUSYBOX_FEATURE_PS_WIDE both depend on !DESKTOP.
# Make DESKTOP depend on some non-existing symbol to prevent the user from (accidentally) selecting it
# in Freetz menuconfig. This ensures (as a side effect) that "ps -l" is always available.
depends_on DESKTOP "FREETZ_DISABLE_OPTION_BY_MAKING_IT_DEPEND_ON_NONEXISTING_SYMBOL"

# from-file-to-file mode is supported since 2.6.33, thus disabled
depends_on FEATURE_USE_SENDFILE "FREETZ_DISABLE_OPTION_BY_MAKING_IT_DEPEND_ON_NONEXISTING_SYMBOL"

# FEATURE_WGET_OPENSSL requires openssl binary
select_ FEATURE_WGET_OPENSSL "FREETZ_PACKAGE_OPENSSL"

# libbusybox is not supported by Freetz
depends_on BUILD_LIBBUSYBOX "FREETZ_DISABLE_OPTION_BY_MAKING_IT_DEPEND_ON_NONEXISTING_SYMBOL"

# Freetz is not Fedora
depends_on FEDORA_COMPAT "FREETZ_DISABLE_OPTION_BY_MAKING_IT_DEPEND_ON_NONEXISTING_SYMBOL"

# Ext*FS
depends_on MKE2FS "!FREETZ_PACKAGE_E2FSPROGS_E2MAKING"
depends_on MKFS_EXT2 "!FREETZ_PACKAGE_E2FSPROGS_E2MAKING"

# mdev requires kernel >= 2.6.27 since busybox 1.27.x, see the corresponding note on https://busybox.net/
# and this thread http://lists.busybox.net/pipermail/busybox/2017-March/085362.html for more details
# alternatively we might apply this patch http://busybox.net/0001-mdev-create-devices-from-sys-dev.patch
depends_on MDEV "FREETZ_KERNEL_VERSION_2_6_28_MIN"

# setns syscall is available since kernel 3.0 (s. http://man7.org/linux/man-pages/man2/setns.2.html#VERSIONS)
# and since uclibc-ng 1.0.1 (s. https://github.com/wbx-github/uclibc-ng/commit/5d5c77daae197b00f89ad1517ffb5a7a01a78cff)
depends_on NSENTER "FREETZ_KERNEL_VERSION_3_10_MIN \&\& ( FREETZ_AVM_UCLIBC_1_0_14 \|\| FREETZ_TARGET_UCLIBC_0_9_33 )"

# fallocate applet requires posix_fallocate which is available (in Freetz) since uClibc-0.9.33
depends_on FALLOCATE FREETZ_TARGET_UCLIBC_0_9_33

# ensure only SH_IS_ASH could be selected
depends_on SH_IS_HUSH "FREETZ_DISABLE_OPTION_BY_MAKING_IT_DEPEND_ON_NONEXISTING_SYMBOL"
#depends_on SH_IS_NONE "FREETZ_DISABLE_OPTION_BY_MAKING_IT_DEPEND_ON_NONEXISTING_SYMBOL"

depends_on FEATURE_PREFER_APPLETS "FREETZ_BUSYBOX__NOEXEC_NOFORK_OPTIMIZATIONS"
depends_on FEATURE_SH_NOFORK "FREETZ_BUSYBOX__NOEXEC_NOFORK_OPTIMIZATIONS"
depends_on FEATURE_SH_STANDALONE "FREETZ_BUSYBOX__NOEXEC_NOFORK_OPTIMIZATIONS"

depends_on FEATURE_USE_BSS_TAIL "FREETZ_DISABLE_OPTION_BY_MAKING_IT_DEPEND_ON_NONEXISTING_SYMBOL"

echo " done."
