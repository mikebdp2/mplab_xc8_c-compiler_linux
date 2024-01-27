#!/bin/bash
########################################################################
# build-avr-gnu-toolchain.sh
#
# This script builds the GNU toolchain for the AVR target.
#
# Copyright (C) 2006-2018 Microchip Technology Inc.
#
# This script is free software; you can redistribute it and/or modify
# it under the terms of the GNU Lesser General Public License as published by
# the Free Software Foundation version 2.1.
#
# This script is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public License
# along with this script; if not, write to the Free Software
# Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
#
########################################################################
#
# $Id: build-avr8-gnu-toolchain.sh 136524 2013-05-02 13:38:43Z skselvaraj $
#
########################################################################

usage="\
Usage: `basename $0` [OPTIONS] <package...>

This script builds the GNU toolchain for the AVR target.

Packages can be given as arguments. The order they are given defines the
build order. Use option '-l' to list default packages.

The script build the tools in the 'build' folder based on the sources in the
'source' folder. The tools are installed in the 'prefix' folder.
Default 'build' folder is a '<current>/build'. Change it with option '-b <folder>'.
Default 'source' folder is '<current>'. Change it with option '-s <folder>'.
Specify 'prefix' folder with option '-p <prefix>'.

Options:
  -b <folder>           Defines build folder
  -h                    Prints this help message
  -k                    Keep old build folder
  -l                    Lists default packages
  -p <prefix>           Sets the installation prefix
  -s <folder>           Defines source folder
  -x <folder>           Defines the XCLM containing directory

  -B <target>           sets build platform for 'configure'
  -H <target>           sets host platform for 'configure'

Enviroment:
  AVR_8_GNU_TOOLCHAIN_VERSION     Gives the version number of the toochain
  BUILD_NUMBER          Adds a build number to the version string if set
  PARALLEL_JOBS         Number of jobs to run in parallel (passed to make verbatim)"
  

######## General helper functions ###############################
function task_start () {
    printf "%-52s" "$1"
}

function task_success () {
    echo OK
}

function task_error () {
    echo FAILED
    echo $1
    [[ -n $2 ]] && grep -C 50 "error:" $2
    [[ -n $2 ]] && cat $2
    exit 1
}

function wipe_directory () {
    if [ -e "$1" ]; then
        task_start "Wiping $1 ($2)... "
        rm -rf "$1" && task_success || task_error
    fi
}

function do_make () {
    make $PARALLEL_JOBS $MAKEOPTS > make.out 2>&1 || task_error "$1" "make.out"
}

function do_make_install () {
    make $PARALLEL_JOBS install > make.install.out 2>&1 || task_error "$1" "make.install.out"
}

function do_pushd () {
    pushd $1 > /dev/null
}

function do_popd () {
    popd $1 > /dev/null
}

function do_mkpushd () {
    mkdir -p $1
    do_pushd $1
}

function start_timer () {
    begin_time=`date +%s`
}

function end_timer () {
    end_time=`date +%s`
}

function report_time() {
    elapsed=$[$end_time - $begin_time]
    hours=$[$elapsed/3600]
    mins=$[($elapsed%3600)/60]
    secs=$[$elapsed%60]
    echo "Finished at `date`"
    echo "Task completed in $hours hours, $mins minutes and $secs seconds."
}

######## Functions for avr gnu toolchain ###############################
function remove_build_folder()
{
    # arg1 = the package subfolder in builddir
    if test -d ${builddir}/$1 -a ${KEEP_BUILD_FOLDER} != "YES" ; then
        rm -rf ${builddir}/$1 || task_error "Could not remove $1 build folder."
    fi
}


#Tries to set platform types
# $1 = package
function set_platform_variables()
{
    build_platform=${srcdir}/${1}/config.guess
    if test -z ${host_platform}; then
        host_platform=${build_platform}
    fi
}

function record_version()
{
    local component=$1

    # Bail out early if git is not installed or if pwd is not a git repo
    type git &>/dev/null && git show &>/dev/null || return

    echo -n "${component} source version: " >> ${VERSIONS_FILE}
    git log -1 --format="%H %s" >> ${VERSIONS_FILE}
}

function unpack_upstream_source()
{
    local workdir=$1
    local archive_name=$2
    local archive_tar_flag=""

    case $archive_name in
        *.tar.gz|*.tgz)
            archive_tar_flag='--gzip';;
        *.tar.bz2|*.tbz2)
            archive_tar_flag='--bzip2';;
        *.tar)
            archive_tar_flag="";;
        *)
            task_error "Unknown archive format."
    esac

    if ! tar --directory ${workdir} ${archive_tar_flag} -x -f ${archive_name}; then
        task_error "Corrupt file ${archive_name}"
    fi
}


function apply_patches()
{
    local workdir=$1
    local archivedir=$2

    do_pushd ${workdir}

        # Patch Categories
        #    0x = Distribution specific (distro names and versions)
        #    1x = Host platform specific
        #    2x = Build system specific
        #    3x = New target features
        #    4x = Patches to fix target bugs
        #    5x = New devices

    if test -z "$(ls ${archivedir}/*.patch)"; then
        echo "No patch files, skipping patch"
        do_popd
        return
    fi

    for i in ${archivedir}/*.patch ; do
        echo "Patch: $i" >> patch.log
        patch --verbose --strip=0 --input="$i"  >> patch.log || task_error "Patching failed."
    done
    do_popd
}


############ Define functions used for the different tasks ########
function set_binutils_parameters()
{
    if test -f "${srcdir}/binutils/bfd/ATMEL-VER"; then
        read binutils_version_atmel < ${srcdir}/binutils/bfd/ATMEL-VER
    else
        binutils_version_atmel="microchip-$(date +%Y%m%d%H%M%Z)"
    fi
}

function set_xclm_shasum_macro()
{
    # ~~~~ generate SHASUM for XCLM, used by binutils, gcc builds ~~~~
    SHASUM256="shasum -a 256"
    if [ "x$XCLM_PATH" != "x" ]; then
      case ${host_platform} in
        x86_64*-*mingw32 )
          XCLM=$XCLM_PATH/client/bin/xclm.exe
          ;;
        * )
          XCLM=$XCLM_PATH/client/bin/xclm
          ;;
      esac
      if [ ! -e $XCLM ]; then
        task_error "Error: Missing $XCLM"
      fi
      local XCLM_SHASUM=`$SHASUM256 $XCLM | head -c 64`
      if [ ${#XCLM_SHASUM} != 64 ]; then
        task_error "Error: Failed to calculate SHASUM256 digest for $XCLM"
      fi
      XCLM_SHASUM_MACRO="-DMCHP_XCLM_SHA256_DIGEST=${XCLM_SHASUM} -DMCHP_FXCLM_SHA256_DIGEST=8727ea3da9bdd624fee0130eb6133188719892bcbee7da32606911a8b08a1a8d "
    fi
    # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
}

function binutils_prep()
{
    if test -f ${srcdir}/binutils/.prep_done
    then
        set_binutils_parameters
        return
    fi


    task_start "Preparing Binutils... "
    do_pushd ${srcdir}

    # Prepare for configuration.
    if [ ! -d ${srcdir}/binutils ] ; then
        echo "Can't find binutils source."
        exit 1
    fi

    set_binutils_parameters
    cd binutils
    record_version binutils

    # Some sed magic to make autotools work on platforms with different autotools version
    # Works for binutils 2.20.1. May work for other versions.
    ${sed_tool} -i 's/AC_PREREQ(2.64)/AC_PREREQ(2.63)/g' ./configure.ac || task_error "sed failed"
    ${sed_tool} -i 's/AC_PREREQ(2.64)/AC_PREREQ(2.63)/g' ./libiberty/configure.ac || task_error "sed failed"
    ${sed_tool} -i 's/  \[m4_fatal(\[Please use exactly Autoconf \]/  \[m4_errprintn(\[Please use exactly Autoconf \]/g' ./config/override.m4 || task_error "sed failed"

    autoconf || task_error "autoconf failed"
    for d in ld ; do
        do_pushd ${d}
        autoreconf	 || task_error "autoreconf in $d failed."
        do_popd
    done

    do_popd
    task_success
    touch ${srcdir}/binutils/.prep_done
}


function binutils_build()
{
    local binutils_target=${1}
    local binutils_extra_opts=""
    local binutils_doc_opts=""
    local binutils_extra_config=""

    task_start "Building Binutils for ${binutils_target}... "
    remove_build_folder "${binutils_target}-binutils"
    OLD_MAKEOPTS=$MAKEOPTS
    MAKEOPTS=""
    do_mkpushd ${builddir}/${binutils_target}-binutils
    case "${host_platform}" in
    i[3456]86*-linux*)
        binutils_extra_config=""
        ;;
    x86_64*-linux*)
        binutils_extra_config=""
        ;;
    x86_64*-mingw32*)
        binutils_extra_config=""
        ;;
    *)
        binutils_extra_config=""
    esac

    # Configure.
    CFLAGS="-Os -g0 ${XCLM_SHASUM_MACRO} ${CFLAGS}" \
    ${srcdir}/binutils/configure \
        --target=${binutils_target} \
        --host=${host_platform} \
        --build=${build_platform} \
        --prefix=$PREFIX \
        --with-pkgversion="AVR_8_bit_GNU_Toolchain_${avr_8_gnu_toolchain_version}_${BUILD_NUMBER}" \
        --with-bugurl="$bugurl" \
        --disable-nls \
        --enable-doc \
        --libdir=${PREFIX}/${LIB_DIR} \
        --infodir=${PREFIX}/info \
        --mandir=${PREFIX}/man \
        --docdir=${PREFIX}/doc/binutils \
        --disable-werror \
        --enable-install-libiberty \
        --enable-install-libbfd \
        --disable-gdb \
        --disable-libdecnumber \
        --disable-readline \
        --disable-sim \
        > configure.out 2>&1 || task_error "configure failed. See configure.out." "configure.out"

    # Build.
    make configure-host >> make.out 2>&1 || task_error "make configure-host failed. See make.out" "make.out"
    make ${binutils_extra_config} all html >> make.out 2>&1 || task_error "make failed. See make.out." "make.out"
    task_success

    # Install.
    task_start "Installing binutils for ${binutils_target}... "
    #do_make_install "make install failed. See make.install.out."
    # Do not call do_make_install() as binutils needs extra make targets.
    make $PARALLEL_JOBS install install-html > make.install.out 2>&1 || task_error "make install failed. See make.install.out." "make.install.out"
    make $PARALLEL_JOBS DESTDIR=${PREFIX_NOLM} prefix="" install > make.install_nolm.out 2>&1 || task_error "make install failed. See make.install_nolm.out"

    # Record binutils version in versions file

    case "${host_platform}" in
        x86_64*-linux*)
            echo -n "binutils version: " >> ${VERSIONS_FILE}
            ${PREFIX}/bin/avr-as --version | head -n 1 | cut -d' ' -f 4 >> ${VERSIONS_FILE}
            ;;
        *-darwin*)
            echo -n "binutils version: " >> ${VERSIONS_FILE}
            ${PREFIX}/bin/avr-as --version | head -n 1 | cut -d' ' -f 4 >> ${VERSIONS_FILE}
            ;;
    esac

    do_popd
    MAKEOPTS=$OLD_MAKEOPTS

    task_success
}


function set_gcc_parameters()
{
    if test -f "${srcdir}/gcc/gcc/BASE-VER"; then
        gcc_version_base=$(cat ${srcdir}/gcc/gcc/BASE-VER)
        case ${gcc_version_base} in
               [5678].[01234].*)
                read gcc_version_atmel < ${srcdir}/gcc/gcc/ATMEL-VER
                ;;
               4.[3456789].*)
                read gcc_version_atmel < ${srcdir}/gcc/gcc/ATMEL-VER
                ;;
               4.[12].*)
                # GCC 4.1.x or 4.2.x
                      gcc_version_atmel=`grep -E "define[[:space:]]{1,}VERSUFFIX" "${srcdir}/gcc/gcc/version.c" | ${sed_tool} -e 's/.*"\([^"]*\)".*/\1/'`

                # Add some version specific info for certain platforms
                case ${host_platform} in
                    x86_64*-*mingw32 )
                        sed 's/\(.*VERSUFFIX "\)\([^"]*\)/\1\2 (mingw32 special)/' ${srcdir}/gcc/gcc/version.c > ${srcdir}/gcc/gcc/version.c.new \
                            || task_error "error adding '(mingw32 special)' to gcc/version.c"
                        mv -f ${srcdir}/gcc/gcc/version.c.new ${srcdir}/gcc/gcc/version.c || task_error "error renaming gcc/version.c"
                        ;;
                    i68[3456]-*mingw64 )
                        sed 's/\(.*VERSUFFIX "\)\([^"]*\)/\1\2 (mingw64 special)/' ${srcdir}/gcc/gcc/version.c > ${srcdir}/gcc/gcc/version.c.new \
                             || task_error "error adding '(mingw64 special)' to gcc/version.c"
                        mv -f ${srcdir}/gcc/gcc/version.c.new ${srcdir}/gcc/gcc/version.c || task_error "error renaming gcc/version.c"
                        ;;
                    * )
                        ;;
                esac
                ;;
            4.0.*)
                # GCC 4.0.x
                      gcc_version_atmel=`grep version_string "gcc/version.c" | sed -e 's/.*"\([^"]*\)".*/\1/'`
                # Add some version specific info for certain platforms
                case ${host_platform} in
                    x86_64*-*mingw32 )
                        sed 's/\(.*VERSUFFIX "\)\([^"]*\)/\1\2 (mingw32 special)/' ${srcdir}/gcc/gcc/version.c > ${srcdir}/gcc/gcc/version.c.new \
                            || task_error "error adding '(mingw32 special)' to gcc/version.c"
                        mv -f ${srcdir}/gcc/gcc/version.c.new ${srcdir}/gcc/gcc/version.c || task_error "error renaming gcc/version.c"
                        ;;
                    i68[3456]-*mingw64 )
                        sed 's/\(.*VERSUFFIX "\)\([^"]*\)/\1\2 (mingw64 special)/' ${srcdir}/gcc/gcc/version.c > ${srcdir}/gcc/gcc/version.c.new \
                             || task_error "error adding '(mingw64 special)' to gcc/version.c"
                        mv -f ${srcdir}/gcc/gcc/version.c.new ${srcdir}/gcc/gcc/version.c || task_error "error renaming gcc/version.c"
                        ;;
                    * )
                        ;;
                esac
                ;;
            *)
            echo "unsupported GCC Version ${gcc_version_base}"
            exit 1
            ;;
        esac
    else
        # Cant't get gcc version, just set something usefull.
        gcc_version_base="4.3.2"
          gcc_version_atmel="microchip-$(date +%Y%m%d%H%M%Z)"
    fi

}


function gcc_prep()
{
    if test -f ${srcdir}/gcc/.prep_done
    then
        set_gcc_parameters
        return
    fi


    task_start "Preparing GCC... "
    do_pushd ${srcdir}

    # update time stamp of sources. tests such as _Pragma3 may fail. PR28123
    do_pushd ${srcdir}/gcc/
    record_version gcc
    contrib/gcc_update --touch > /dev/null
    do_popd

    # Prepare for configuration.
    if [ ! -d ${srcdir}/gcc ] ; then
        echo "Can't find gcc source."
        exit 1
    fi
    set_gcc_parameters

    cd gcc
    case ${gcc_version_base} in
         [5678].[01234].*)
            # Some sed magic to make autotools work on platforms with different autotools version
            ${sed_tool} -i 's/m4_copy(\[AC_PREREQ\]/m4_copy_force(\[AC_PREREQ\]/g' ./config/override.m4 || task_error "sed failed"
            ${sed_tool} -i 's/m4_copy(\[_AC_PREREQ\]/m4_copy_force(\[_AC_PREREQ\]/g' ./config/override.m4 || task_error "sed failed"
            ${sed_tool} -i 's/  \[m4_fatal(\[Please use exactly Autoconf \]/  \[m4_errprintn(\[Please use exactly Autoconf \]/g' ./config/override.m4 || task_error "sed failed"
            autoconf || task_error "autoconf failed"
            # Running autoreconf in libstdc++ does not seem to be necessary in 4.3.x
            # and it causes some problems on platform with auto-tool >2.61
            ;;
         4.[3456789].*)
            # Some sed magic to make autotools work on platforms with different autotools version
            ${sed_tool} -i 's/m4_copy(\[AC_PREREQ\]/m4_copy_force(\[AC_PREREQ\]/g' ./config/override.m4 || task_error "sed failed"
            ${sed_tool} -i 's/m4_copy(\[_AC_PREREQ\]/m4_copy_force(\[_AC_PREREQ\]/g' ./config/override.m4 || task_error "sed failed"
            ${sed_tool} -i 's/  \[m4_fatal(\[Please use exactly Autoconf \]/  \[m4_errprintn(\[Please use exactly Autoconf \]/g' ./config/override.m4 || task_error "sed failed"
            autoconf || task_error "autoconf failed"
            # Running autoreconf in libstdc++ does not seem to be necessary in 4.3.x
            # and it causes some problems on platform with auto-tool >2.61
            ;;
         *)
            echo "Unsupported GCC version ${gcc_version_base}"
            exit 1
            ;;
    esac

    do_popd
    task_success
    touch ${srcdir}/gcc/.prep_done
}


# First step building GCC.
# arg1 = target
function gcc_build_bootstrap()
{
    local gcc_target=${1}
    local gcc_extra_opts=""
    local gcc_doc_opts=""
    local gcc_extra_config=""
    local gcc_ldflags=""
    local gcc_cppflags=""

    task_start "Building bootstrap GCC for ${gcc_target}... "
    remove_build_folder "${gcc_target}-gcc-bootstrap"
    OLD_MAKEOPTS=$MAKEOPTS
    MAKEOPTS=""
    do_mkpushd ${builddir}/${gcc_target}-gcc-bootstrap

    # Are we doing a canadian cross?
    if ${canadian_cross}; then
        gcc_extra_opts=""
    else
        gcc_extra_opts=""
    fi

    case ${gcc_version_base} in
         [5678].[01234].*)
        gcc_extra_opts="${gcc_extra_opts} \
                   --with-pkgversion="AVR_Toolchain_3.0_$(date +%Y%m%d%H%M)" \
                   --with-bugurl="$bugurl"
                  "
        ;;
         4.[3456789].*)
        gcc_extra_opts="${gcc_extra_opts} \
                   --with-pkgversion="AVR_Toolchain_3.0_$(date +%Y%m%d%H%M)" \
                   --with-bugurl="$bugurl"
                  "
        ;;
         *)
         # Do nothing
         ;;
    esac

    gcc_ldflags="-L${PREFIX_HOSTLIBS}/${LIB_DIR}"
    gcc_cflags="-Os -g0 -DSKIP_LICENSE_MANAGER -I ${PREFIX_HOSTLIBS}/include/"
    gcc_cxxflags="-DSKIP_LICENSE_MANAGER -I ${PREFIX_HOSTLIBS}/include/"

    # Configure.
    ${srcdir}/gcc/configure \
        "CFLAGS=${gcc_cflags} ${CFLAGS}"  "CXXFLAGS=${gcc_cxxflags} ${CXX_FLAGS}" \
        "LDFLAGS=${gcc_ldflags}" "CPPFLAGS=${gcc_cppflags}" \
        --target=${gcc_target} \
        --host=${host_platform} \
        --build=${build_platform} \
        --prefix=${PREFIX_NOLM} \
        --libdir=${PREFIX_NOLM}/${LIB_DIR} \
        --enable-languages="c" \
        ${gcc_extra_opts} \
        --with-dwarf2 \
        --enable-doc \
        --disable-shared \
        --disable-libada \
        --disable-libssp \
        --disable-nls \
        --with-musl=yes \
        --with-avrlibc=no \
        --with-mpfr=${PREFIX_HOSTLIBS} \
        --with-gmp=${PREFIX_HOSTLIBS} \
        --with-mpc=${PREFIX_HOSTLIBS} \
        > configure.out 2>&1 || task_error "configure failed. See configure.out." "configure.out"

    # Build.
    do_make "Building failed. See make.out."
    task_success

    # Install.
    task_start "Installing bootstrap GCC for ${gcc_target}... "
    do_make_install "Installing failed. See make.install.out."

    # Make a copy of the prefix dir as the nolm dir
    task_start "Copying contents of ${PREFIX_NOLM} to ${NOLM_TOOLCHAIN_PATH}"
    cp -r ${PREFIX_NOLM}/* ${NOLM_TOOLCHAIN_PATH}

    do_popd
    MAKEOPTS=$OLD_MAKEOPTS
    task_success
}

# Build GCC again, after avr-libc has been built.
# arg1 = target
function gcc_build_full()
{
    set -x
    local gcc_target=${1}
    local gcc_extra_opts=""
    local gcc_doc_opts=""
    local gcc_extra_config=""
    local gcc_ldflags=""
    local gcc_cppflags=""

    task_start "Building full GCC for $1... (LM)"
    remove_build_folder "${1}-gcc-full-lm"
    OLD_MAKEOPTS=$MAKEOPTS
    MAKEOPTS=""
    do_mkpushd ${builddir}/${1}-gcc-full-lm

    # Make sure we always include the correct library folder when linking
    gcc_ldflags="-L${PREFIX_HOSTLIBS}/${LIB_DIR}"
    gcc_cflags="-Os -g0 ${XCLM_SHASUM_MACRO} -I ${PREFIX_HOSTLIBS}/include/"
    gcc_cxxflags="${XCLM_SHASUM_MACRO} -I ${PREFIX_HOSTLIBS}/include/"

    case ${gcc_version_base} in
        4.[789].*)
            gcc_extra_opts="${gcc_extra_opts} \
                   --with-pkgversion="AVR_8_bit_GNU_Toolchain_${avr_8_gnu_toolchain_version}_${BUILD_NUMBER}" \
                   --with-bugurl="$bugurl"
                  "
        ;;
        [5678].[01234].*)
            gcc_extra_opts="${gcc_extra_opts} \
                   --with-pkgversion="AVR_8_bit_GNU_Toolchain_${avr_8_gnu_toolchain_version}_${BUILD_NUMBER}" \
                   --with-bugurl="$bugurl"
                  "
        ;;
        4.[4568].*)
            gcc_extra_opts="${gcc_extra_opts} \
                --enable-fixed-point
            "
            gcc_extra_opts="${gcc_extra_opts} \
                   --with-pkgversion="AVR_8_bit_GNU_Toolchain_${avr_8_gnu_toolchain_version}_${BUILD_NUMBER}" \
                   --with-bugurl="$bugurl"
                  "
        ;;
        4.[3].*)
            gcc_extra_opts="${gcc_extra_opts} \
                   --with-pkgversion="AVR_8_bit_GNU_Toolchain_${avr_8_gnu_toolchain_version}_${BUILD_NUMBER}" \
                   --with-bugurl="$bugurl"
                  "
        ;;

         *)
         # Do nothing
         ;;
    esac

    # Configure.
    ${srcdir}/gcc/configure \
        "CFLAGS=${gcc_cflags} ${CFLAGS}"  "CXXFLAGS=${gcc_cxxflags} ${CXXFLAGS}" \
        "LDFLAGS=${gcc_ldflags}" "CPPFLAGS=${gcc_cppflags}" \
        --target=${gcc_target} \
        --host=${host_platform} \
        --build=${build_platform} \
        --prefix=${PREFIX} \
        --libdir=${PREFIX}/${LIB_DIR} \
        --enable-languages="c,c++" \
        --with-dwarf2 \
        --enable-doc \
        --disable-shared \
        --disable-libada \
        --disable-libssp \
        --disable-nls \
        --with-musl=yes \
        --with-avrlibc=no \
        --with-mpfr=${PREFIX_HOSTLIBS} \
        --with-gmp=${PREFIX_HOSTLIBS} \
        --with-mpc=${PREFIX_HOSTLIBS} \
        ${gcc_extra_opts} \
        ${gcc_doc_opts} \
        > configure.out 2>&1 || task_error "configure failed. See configure.out." "configure.out"


    # When cross-compiling to windows, cannot re-use same prefix folder as non-LM build, so
    # have to build libgcc multilib using all-gcc. Can get away with that on Linux/OSX, so just
    # build host binaries on those two platforms.
    case ${host_platform} in
        x86_64*-*mingw32 )
            gcc_make_target="all"
            gcc_make_install_target="install"
            ;;
        * )
            gcc_make_target="all-host"
            gcc_make_install_target="install-host"
            ;;
    esac

    # make - build gcc, g++ etc binaries, not multilibs
    make ${gcc_extra_config} ${gcc_make_target} html >> make.out 2>&1 || task_error "make failed. See make.out." "make.out"
    cat make.out
    task_success

    # install
    task_start "Install full GCC for ${gcc_target}... (LM)"
    make ${gcc_make_install_target} install-html $PARALLEL_JOB > make.install.out 2>&1 || task_error "make install failed. See make.install.out." "make.install.out"
    cat make.install.out

    # Record gcc version in versions file
    case "${host_platform}" in
        x86_64*-linux*)
            echo -n "gcc version: " >> ${VERSIONS_FILE}
            ${PREFIX}/bin/avr-gcc --version | head -n 1 | cut -d' ' -f 3 >> ${VERSIONS_FILE}
            ;;
        *-darwin*)
            echo -n "gcc version: " >> ${VERSIONS_FILE}
            ${PREFIX}/bin/avr-gcc --version | head -n 1 | cut -d' ' -f 3 >> ${VERSIONS_FILE}
            ;;
    esac

    do_popd
    MAKEOPTS=$OLD_MAKEOPTS
    task_success
}

function prep_headers () {
    task_start "Preparing Headers..."

    # Checking if headers exist. Error is it does not

    HEADER=$(ls -1 ${srcdir}/headers/ | tail -n 1)
    if test -z "$HEADER"
    then
      echo "No file present in the directory"
      exit 1
    fi

    # Unzipping the latest header in the
    unzip -qq -o ${srcdir}/headers/$HEADER -d ${srcdir}/avr-headers-latest/

    # copy avr8 devices headers to avr-libc include
    #  - new artifact puts device header inside each device directory
    #  - not all headers are auto-generated, some are legacy. Copy them separately (from legacy directory).

    for i in ${srcdir}/avr-headers-latest/**/avr/io[0-9a-zA-Z]*.h
    do
      cp -f $i ${srcdir}/avr-libc/include/avr/ || task_error "Replacing avr-libc headers with avr-headers"
    done

    for i in ${srcdir}/avr-headers-latest/legacy/io?*.h
    do
      cp -f $i ${srcdir}/avr-libc/include/avr/ || task_error "Replace avr-libc headers with legacy headers"
    done

    task_success
}

function avr_libc_prep()
{
    if test -f ${srcdir}/avr-libc/.prep_done
    then
        return
    fi

    do_pushd ${srcdir}/libc
    record_version libc
    do_popd

    # The avr-libc repo has a nested avr-libc dir containing the actual source - move everything one dir up
    mkdir -p ${srcdir}/avr-libc

    rm ${srcdir}/avr-libc/.prep_done
    rm -rf ${srcdir}/avr-libc/*
    cp -r ${srcdir}/libc/avr-libc/* ${srcdir}/avr-libc/

    task_start "Preparing avr-libc... "
    do_pushd ${srcdir}


    if [ ! -d ${srcdir}/avr-libc ] ; then
        echo "Can't find avr-libc source."
        exit 1
    fi

    # Prepare the headers before replacing
    prep_headers

    # Run the bootstrap script.
    cd ${srcdir}/avr-libc
    ./bootstrap > preparation.out 2>&1

    do_popd
    task_success
    touch ${srcdir}/avr-libc/.prep_done
}


function avr_libc_build()
{
    task_start "Building avr-libc ... "
    OLD_MAKEOPTS=$MAKEOPTS
    MAKEOPTS=""
    do_pushd ${srcdir}/avr-libc

    OLD_PATH=$PATH
    export PATH=${PREFIX_NOLM}/bin:$PATH

    # Do not enable doc for darwin build
    # TODO: Resolve avr-libc doc issues in darwin
    case "${host_platform}" in
        *-darwin*)
            ./configure \
              --host=avr \
              --prefix="$PREFIX" \
              --enable-device-lib \
              --libdir=${PREFIX}/${LIB_DIR} \
              --mandir="$PREFIX"/man \
              --datadir="$PREFIX" \
              > configure.out 2>&1 || \
              task_error "configure failed. See configure.out" "configure.out"
            ;;
        *)
            ./configure \
              --host=avr \
              --prefix="$PREFIX" \
              --enable-device-lib \
              --libdir=${PREFIX}/${LIB_DIR} \
              --enable-doc \
              --disable-versioned-doc \
              --enable-html-doc \
              --enable-pdf-doc \
              --enable-man-doc \
              --enable-xml-doc \
              --mandir="$PREFIX"/man \
              --datadir="$PREFIX" \
              > configure.out 2>&1 || \
              task_error "configure failed. See configure.out" "configure.out"
            ;;
    esac

    make >make.out 2>&1 || task_error "Building failed. See make.out." "make.out"
    task_success

    # Installing.
    task_start "Installing avr-libc ... "
    make $PARALLEL_JOBS install >make-install.out 2>&1 || task_error "Installing avr-libc failed. See make.install.out." "make.install.out"

    # Record avr-libc version in versions file
    case "${host_platform}" in
        x86_64*-linux*)
            echo -n "avr-libc version: " >> ${VERSIONS_FILE}
            grep __AVR_LIBC_VERSION_STRING__ ${srcdir}/avr-libc/include/avr/version.h | cut -d' ' -f3 >> ${VERSIONS_FILE}
            ;;
        *-darwin*)
            echo -n "avr-libc version: " >> ${VERSIONS_FILE}
            grep __AVR_LIBC_VERSION_STRING__ ${srcdir}/avr-libc/include/avr/version.h | cut -d' ' -f3 >> ${VERSIONS_FILE}
            ;;
    esac

    # todo: Convert line endings in examples, if host=mingw.
    # find $installdir/doc/avr-libc/examples -name '*.*' -print -exec $startdir/utils/bin/todos -o '{}' ';'


    # todo: Move man pages.
    # cp -rf "$PREFIX"/doc/avr-libc/man "$PREFIX"/man
    # rm -rf "$PREFIX"/doc/avr-libc/man


    do_popd
    MAKEOPTS=$OLD_MAKEOPTS
    export PATH=$OLD_PATH
    task_success
}


function musl_prep()
{
    if test -f ${srcdir}/xc-stdlib/.prep_done
    then
        return
    fi

    # just record version, nothing else to prepare to build MUSL for AVR

    do_pushd ${srcdir}/xc-stdlib
    record_version xc-stdlib
    do_popd

    task_success
    touch ${srcdir}/xc-stdlib/.prep_done
}

function musl_build()
{
    task_start "Building MUSL for avr... "
    remove_build_folder "musl-avr"
    do_mkpushd ${builddir}/musl-avr

    OLD_PATH=$PATH
    export PATH=${PREFIX_NOLM}/bin:$PATH

    CC=avr-gcc AR=avr-ar STRIP=avr-strip ${srcdir}/xc-stdlib/musl/configure \
      --prefix=${PREFIX}/avr/ \
      --target=avr \
      --src_list=sources-avr.mak \
      --enable-multilib=yes > configure.out 2>&1 || task_error "Configure musl for avr failed. See configure.out" "configure.out"

    make $PARALLEL_JOBS > make.out 2>&1 || task_error "Make musl for avr failied. See make.out" "make.out"
    make $PARALLEL_JOBS install > make.install.out 2>&1 || task_error "Installing musl failed. See make.install.out" "make.install.out"

    # Record musl version in versions file
    case "${host_platform}" in
        *-[linux|darwin]*)
            echo -n "musl version: " >> ${VERSIONS_FILE}
            # FIXME: if musl-1.1.18 directory in repo changed, below needs to be updated
            cat ${srcdir}/xc-stdlib/musl/musl-1.1.18/VERSION | cut -d' ' -f3 >> ${VERSIONS_FILE}
            ;;
    esac

    do_popd
    export PATH=$OLD_PATH
    task_success
}

function install_avr_target_headers()
{
    # AVR target headers such as io.h, eeprom.h, wdt.h etc are
    # not available with MUSL. They need to be copied.

    task_start "Copying AVR target header files from AVRLibc... "

    do_pushd ${srcdir}/libc
    record_version avrlibc

    # Record avr-libc version in versions file
    case "${host_platform}" in
        *-[linux|darwin]*)
            echo -n "avr-libc version: " >> ${VERSIONS_FILE}
            grep __AVR_LIBC_VERSION_STRING__ ${srcdir}/libc/avr-libc/include/avr/version.h | cut -d' ' -f3 >> ${VERSIONS_FILE}
            ;;
    esac

    # generate builtins.h, delay.h
    do_pushd ${srcdir}/libc/avr-libc/include/
    cp avr/builtins.h.in avr/builtins.h
    ${sed_tool} -i 's/@HAS_DELAY_CYCLES@/1/g' avr/builtins.h || task_error "sed (builtins.h) failed"
    cp util/delay.h.in util/delay.h
    ${sed_tool} -i 's/@HAS_DELAY_CYCLES@/1/g' util/delay.h || task_error "sed (delay.h) failed"
    do_popd

    # create avr directory in include
    mkdir -p ${PREFIX}/avr/include/avr
    # signal.h is obsolete
    HEADERS=(boot.h builtins.h common.h cpufunc.h delay.h eeprom.h fuse.h \
                    interrupt.h io.h lock.h pgmspace.h portpins.h power.h \
                    signature.h sfr_defs.h sleep.h wdt.h xmega.h)
    for h in "${HEADERS[@]}"
    do
        cp avr-libc/include/avr/$h ${PREFIX}/avr/include/avr/
    done

    # create util directory in include
    mkdir -p ${PREFIX}/avr/include/util
    # atomic.h crc16.h delay.h delay_basic.h parity.h setbaud.h twi.h
    # skipped eu_dst.h and usa_dst.h as functions in those headers are
    # not compatible with MUSL's time.h
    UTIL_HEADERS=(atomic.h crc16.h delay_basic.h delay.h parity.h \
                 setbaud.h twi.h)
    for u_hdr in "${UTIL_HEADERS[@]}"
    do
        cp avr-libc/include/util/$u_hdr ${PREFIX}/avr/include/util/
    done

    do_popd
    task_success
}


function set_gdb_parameters()
{
    if test -f "${srcdir}/gdb/bfd/ATMEL-VER"; then
        read gdb_version_atmel < ${srcdir}/gdb/bfd/ATMEL-VER
    else
        gdb_version_atmel="microchip-$(date +%Y%m%d%H%M%Z)"
    fi
}


function gdb_prep()
{
    if test -f ${srcdir}/gdb/.prep_done
    then
        set_gdb_parameters
        return
    fi

    task_start "Preparing GDB... "

    do_pushd ${srcdir}

    if [ ! -d ${srcdir}/gdb ] ; then
        echo "Can't find gdb source."
        exit 1
    fi

    cd ${srcdir}/gdb && record_version gdb
    set_gdb_parameters

    do_popd
    task_success
    touch ${srcdir}/gdb/.prep_done
}


function gdb_build()
{
    task_start "Building GDB for $1... "
    remove_build_folder "${1}-gdb"
    EXTRA_CONFIGOPTS=$2
    OLD_MAKEOPTS=$MAKEOPTS
    MAKEOPTS="all-gdb"
    do_mkpushd ${builddir}/${1}-gdb

    # Are we doing a canadian cross?
    if ${canadian_cross}; then
        case ${host_platform} in
            x86_64*-*mingw32 )
                export LDFLAGS="-L${PREFIX}/lib"
                export CPPFLAGS="-I${PREFIX}/include"
                ;;
            * )
                ;;
        esac
    else
        case "${host_platform}" in
            *-darwin*)
                export LDFLAGS=""
              ;;
            *)
              ;;
        esac
    fi


    # only from version 7.0 is --with-pkgversion and bugurls supported
#    LDFLAGS='-static' \
    CFLAGS="-I${PREFIX_HOSTLIBS}/include -L${PREFIX_HOSTLIBS}/lib ${CFLAGS}" \
    CXXFLAGS="-I${PREFIX_HOSTLIBS}/include -L${PREFIX_HOSTLIBS}/lib ${CXXFLAGS}" \
    ${srcdir}/gdb/configure \
        --with-pkgversion="AVR_8_bit_GNU_Toolchain_${avr_8_gnu_toolchain_version}_${BUILD_NUMBER}"\
        --with-bugurl="$bugurl"\
        --target=$1 \
        --host=${host_platform} \
        --build=${build_platform} \
        --libdir=${PREFIX}/${LIB_DIR} \
        --prefix="$PREFIX" \
        --disable-nls \
        --disable-werror \
        $EXTRA_CONFIGOPTS \
        > configure.out 2>&1 \
        || task_error "configure for $1 failed. See configure.out" "configure.out"

    # Build.
    do_make "Building for $1 failed. See make.out."
    task_success

    # Install.
    task_start "Installing GDB for $1... "
    # New versions of gdb share the same configure/make scripts with binutils. Running make install-gdb to
    # install just the gdb binaries.
    make $PARALLEL_JOBS install-gdb > make.install.out 2>&1 || task_error "Installing GDB for $1 failed. See make.install.out." "make.install.out"
    do_popd

    case "${host_platform}" in
        *-[linux|darwin]*)
            echo -n "gdb version: " >> ${VERSIONS_FILE}
            ${PREFIX}/bin/avr-gdb --version | head -n 1 | cut -d' ' -f 4 >> ${VERSIONS_FILE}
            ;;
    esac

    MAKEOPTS=$OLD_MAKEOPTS
    task_success
}

# expat lib required for code-coverage
function expat_prep() {
    task_start "Unpacking expat ... "
    tar xf ${srcdir}/expat/expat*.tar.gz -C ${srcdir} ||\
    task_error "Failed to unpack expat"
    task_success
}

function expat_build() {

    task_start "Building expat ..."
    do_mkpushd ${srcdir}/expat-*
    if [ -e Makefile ]; then
      make distclean > clean.out 2>&1 || task_error "expat dist clean failed."
    fi
    ./configure --build=${build_platform} --host=${host_platform} \
          --prefix=${PREFIX_HOSTLIBS} --disable-shared \
          > configure.out 2>&1 || task_error "configure failed. See configure.out." "configure.out"

    do_make  "Failed building expat. See make.out"
    task_success
    task_start "Installing expat ..."
    do_make_install "make install failed. See make.install.out."
    do_popd
    task_success
}

function mpfr_prep() {
    task_start "Unpacking mpfr... "
    tar xf ${srcdir}/mpfr/mpfr*.tar.gz -C ${srcdir} ||\
    task_error "Failed to unpack mpfr"
    task_success
}


function mpfr_build() {

    task_start "Building libmpfr ..."
    remove_build_folder "mpfr"
    do_mkpushd ${builddir}/mpfr

    CFLAGS="-fPIC ${CFLAGS}" $(ls -d ${srcdir}/mpfr-*)/configure \
        --build=${build_platform} \
        --host=${host_platform} \
        --prefix=${PREFIX_HOSTLIBS} \
        --libdir=${PREFIX_HOSTLIBS}/${LIB_DIR} \
        --with-gmp=${PREFIX_HOSTLIBS} \
        --disable-shared \
        --enable-static \
        > configure.out 2>&1 || task_error "configure failed. See configure.out." "configure.out"

    do_make  "Failed building libmphr. See make.out"
    task_success
    task_start "Installing mpfr ..."
    do_make_install "make install failed. See make.install.out."
    do_popd
    task_success

}

function gmp_prep() {
    task_start "Unpacking gmp... "
    upstream_source=$(ls ${srcdir}/gmp/gmp*)
    unpack_upstream_source ${srcdir} ${upstream_source}
    task_success
}


function gmp_build() {

    task_start "Building libgmp ..."
    remove_build_folder "gmp"
    do_mkpushd ${builddir}/gmp

    # GMP on apple M1 refuses to configure if host is set to arm-apple-darwin, works fine
    # if the arm part is changed to none. If gmp is built in-tree as part of gcc, this is
    # how it gets configured, so do the same thing there.
    gmp_host_platform_flag="${host_platform}"
    case "${host_platform}" in
        *-darwin*)
            gmp_host_platform_flag=$(echo ${host_platform} | ${sed_tool} s/arm/none/g)
            ;;
        * )
            ;;
    esac

    CFLAGS="-fPIC ${CFLAGS}" $(ls -d ${srcdir}/gmp-[0-9].*)/configure \
        --build=${build_platform} \
        --host=${gmp_host_platform_flag} \
        --libdir=${PREFIX_HOSTLIBS}/${LIB_DIR} \
        --prefix=${PREFIX_HOSTLIBS} \
        --disable-shared \
        --enable-static \
        > configure.out 2>&1 || task_error "configure failed. See configure.out." "configure.out"

    do_make  "Failed building libgmp. See make.out"
    task_success
    task_start "Installing gmp ..."
    do_make_install "make install failed. See make.install.out."
    do_popd
    task_success

}

function mpc_prep() {
    task_start "Unpacking mpc... "
    upstream_source=$(ls ${srcdir}/mpc/mpc*)
    unpack_upstream_source ${srcdir} ${upstream_source}
    task_success
}


function mpc_build() {

    task_start "Building libmpc ..."
    remove_build_folder "mpc"
    do_mkpushd ${builddir}/mpc

    CFLAGS="-fPIC ${CFLAGS}" $(ls -d ${srcdir}/mpc-[0-9].[0-9]*)/configure \
        --build=${build_platform} \
        --host=${host_platform} \
        --libdir=${PREFIX_HOSTLIBS}/${LIB_DIR} \
        --disable-shared \
        --enable-static \
        --prefix=${PREFIX_HOSTLIBS} \
        --with-mpfr=${PREFIX_HOSTLIBS} \
        --with-gmp=${PREFIX_HOSTLIBS} \
        > configure.out 2>&1 || task_error "configure failed. See configure.out." "configure.out"

    do_make  "Failed building libmpc. See make.out"
    task_success
    task_start "Installing mpc ..."
    do_make_install "make install failed. See make.install.out."
    do_popd
    task_success

}

function ncurses_prep() {
    task_start "Unpacking ncurses... "
    upstream_source=$(ls ${srcdir}/ncurses/ncurses*)
    unpack_upstream_source ${srcdir} ${upstream_source}

    task_success
}


function ncurses_build() {
    task_start "Building ncurses ..."
    remove_build_folder "ncurses"
    do_mkpushd ${builddir}/ncurses

    CFLAGS="-fPIC ${CFLAGS}" $(ls -d ${srcdir}/ncurses-[0-9].*)/configure \
        --build=${build_platform} \
        --host=${host_platform} \
        --libdir=${PREFIX_HOSTLIBS}/${LIB_DIR} \
        --without-shared \
        --without-sysmouse \
        --without-progs \
        --without-cxxbinding \
        --without-ada \
        --enable-termcap \
        --disable-database \
        --prefix=${PREFIX_HOSTLIBS} \
        > configure.out 2>&1 || task_error "configure failed. See configure.out." "configure.out"

    do_make  "Failed building ncurses. See make.out"
    task_success
    task_start "Installing ncurses ..."
    do_make_install "make install failed. See make.install.out."
    do_popd
    task_success
    case "${host_platform}" in
       *-darwin*)
            CC="$(which gcc)"
            ;;
    esac
}

############# Start of main program. ####################
start_timer

############ Set up some usable variables #######################
KEEP_BUILD_FOLDER="NO"
TIMESTAMP=$(date +%Y%m%d%H%M)
binutils_version_atmel="microchip-$(date +%Y%m%d%H%M%Z)"
gcc_version_atmel="microchip-$(date +%Y%m%d%H%M%Z)"
gdb_version_atmel="microchip-$(date +%Y%m%d%H%M%Z)"
platform_version=""
srcdir=
builddir=
execdir=`pwd`

# Set Toolchain version number
# Use env variable AVR_GNU_TOOLCHAIN_VERSION if set
avr_8_gnu_toolchain_version=${AVR_8_GNU_TOOLCHAIN_VERSION:-"3.4.4"}

# Set BUILD_NUMBER
# BUILD_NUMBER is set by Hudson build server or can be set before running this script
# If not set we use the date
BUILD_NUMBER=${BUILD_NUMBER:-$(date +%Y%m%d%H%M)}

# Set defaults
canadian_cross=false
build_platform=$(uname -m)-pc-linux-gnu
host_platform=$(uname -m)-pc-linux-gnu
distribution="unknown"

# Set up the packages to build
# The order gives the build order and is significant
packages="avr-binutils avr-gcc-bootstrap avr-libc avr-gcc-full avr-gdb"

sed_tool=sed

# See if we need to change or set some defaults
case "${OSTYPE}" in
    cygwin)
        build_platform=i686-pc-cygwin
        host_platform=i686-pc-cygwin
        ;;
    msys)
        build_platform=i686-pc-mingw32
        host_platform=i686-pc-mingw32
        ;;
    darwin*)
        build_platform=arm-apple-${OSTYPE}.0.0
        host_platform=arm-apple-${OSTYPE}.0.0
        sed_tool=gsed
        ;;
esac

############ Get and decode options given #########################
while getopts "B:b:klhH:n:p:P:s:T:x:" options; do
  case $options in
      B )
          build_platform=$OPTARG
          ;;
      b )
          builddir=$OPTARG
          ;;
      H )
          host_platform=$OPTARG
          ;;
      k )
          KEEP_BUILD_FOLDER="YES"
          ;;
      l )
          echo "Default packages and build order:"
          for package in $packages
          do
              echo $package
          done
          exit 1
          ;;
      n )
          NOLM_TOOLCHAIN_PATH=$OPTARG
          ;;
      p )
          AVR_PREFIX=$OPTARG
          ;;
      s )
          srcdir=$OPTARG
          ;;
      x )
          XCLM_PATH=$OPTARG
          ;;
      h )
          echo "$usage"
          exit 1;;
      \? )
          echo "$usage"
          exit 1;;
      * )
          echo "$usage"
          exit 1;;
  esac
done

shift $(($OPTIND - 1)) ## no need for expr in bash or other POSIX shell


######### Set packages to arguments given or to default ###########
if test $# -ne 0
then
    packages="$@"
fi


############ Check for source directory ###########################
if test -z $srcdir
then
    echo "Using current directory as source folder."
    srcdir=$(pwd)
else
    echo "Using '${srcdir}' as source folder."
fi

if [ -d ${srcdir} ]
then
    # Convert path to absolute path
    srcdir=$(cd ${srcdir}; pwd)
else
    echo "Error: Can't find source folder!"
    exit 1
fi


############ Make the build dir ###################################
builddir="${builddir:-build}"
mkdir -p ${builddir} || task_error "Cannot create build folder"

# Get absolute path for builddir
builddir=$(cd ${builddir}; pwd)

############# Set correct libdir #################################
LIB_DIR=lib

######### Check for crosscompile ###############

# If build_platform != host_platform != target_platform
# then we are doing canadian cross
# since target always is avr32 or avr32-linux we check only
# the build and host platforms
if test ${host_platform} != ${build_platform}
then
    canadian_cross=true;
fi

# Set some platform variables
case "${host_platform}" in
    i[3456]86*-linux*)
        platform_version="\(linux32_special\)"
        ;;
    x86_64*-linux*)
        platform_version="\(linux64_special\)"
        ;;
    i[3456]86*-cygwin*)
        platform_version="\(cygwin_special\)"
        ;;
    x86_64*-mingw32*)
        # Maybe check for some prerequisite?
        export CFLAGS="-D__USE_MINGW_ACCESS"
        platform_version="\(mingw32_special\)"
        ;;
    *-darwin*)
        ;;
    sparc*-sun-solaris2.[56789]*)
        ;;
    sparc*-sun-solaris*)
        ;;
    mips*-*-elf*)
        ;;
    * )
        echo "Unknown host platform: ${host_platform}"
        ;;
esac


############ Set PREFIX ############################
if test -z ${AVR_PREFIX}
then
    echo "Specify install prefix folder!"
    exit 1
fi

PREFIX_NOLM="${AVR_PREFIX}"
PREFIX="${AVR_PREFIX}"
# Make sure it is absolute path
mkdir ${PREFIX_NOLM}
PREFIX_NOLM=$(cd ${PREFIX_NOLM}; pwd)
PREFIX=$(cd ${PREFIX}; pwd)
PREFIX_HOSTLIBS="${PREFIX}-hostlibs"
mkdir ${PREFIX_HOSTLIBS}
PREFIX_HOSTLIBS=$(cd ${PREFIX_HOSTLIBS}; pwd)
mkdir ${NOLM_TOOLCHAIN_PATH}
NOLM_TOOLCHAIN_PATH=$(cd ${NOLM_TOOLCHAIN_PATH}; pwd)

PATH=$PATH:$PREFIX/bin
export PATH

VERSIONS_FILE=${builddir}/versions.txt
rm -f ${VERSIONS_FILE}

record_version buildscripts

############# Check if user has write access to prefix folder ####
if test ! -w ${PREFIX}
then
    echo "WARNING! You do not have write access to the $PREFIX folder! Installation will fail."
    exit 1
fi


############# Check for necessary programs #######################
for PREREQ in autoconf make gcc tar patch
do
    RUN=`type -ap $PREREQ |sort |uniq |wc -l`
    if [ $RUN -eq 0 ]
    then
        echo "$PREREQ is not found in command path. Can't continue"
        exit 1
    elif [ $RUN -gt 1 ]
    then
        echo -n "Found multiple versions of $PREREQ, using the one at "
        type -p $PREREQ
    fi
done


bugurl='http://www.microchip.com'

############# First we make necessary preparations ###############
for part in ${packages}
do
    case ${part} in
        "avr-binutils" )
            binutils_prep
            ;;
        "avr-gcc-bootstrap" | "avr-gcc-full" )
            gmp_prep
            mpfr_prep
            mpc_prep
            expat_prep
            gcc_prep
            ;;
        "avr-libc" )
            avr_libc_prep
            ;;
        "avr-gdb" )
            ncurses_prep
            gdb_prep
            ;;
        "musl" )
            musl_prep
            ;;
        * )
            echo "Error: Unknown package ${part}."
            exit 1
            ;;
    esac
done


############# Building and installing ###########
# The order of building is given by the order in the packages variable
for part in ${packages}
do
    set_xclm_shasum_macro
    case ${part} in
        "avr-binutils" )
            binutils_build "avr"
            ;;
        "avr-gcc-bootstrap" )
            gmp_build
            mpfr_build
            mpc_build
            expat_build
            gcc_build_bootstrap "avr"
            ;;
        "avr-libc" )
            avr_libc_build
            ;;
        "musl" )
            musl_build
            install_avr_target_headers
            ;;
        "avr-gcc-full" )
            case ${host_platform} in
                x86_64*-*mingw32 )
                    # we asume gmp and mpfr binaries is preinstalled.
                    gmp_build
                    mpfr_build
                    expat_build
                    ;;
                *linux* )
                    gmp_build
                    mpfr_build
                    expat_build
                    ;;
                *darwin* )
                    gmp_build
                    mpfr_build
                    ;;
                * )
                    ;;
            esac
            mpc_build
            gcc_build_full "avr"
            ;;
        "avr-gdb" )
            DISABLE_GUILE=
            case ${host_platform} in
                x86_64*-*mingw32 )
                    # we asume libtermcap binaries is preinstalled.
                    ;;
                *linux* )
                    ncurses_build
                    ;;
                *darwin* )
                    ncurses_build
                    DISABLE_GUILE="--without-guile"
                    ;;
                * )
                    ;;
            esac

            # Always build plain gdb, without python.
            gdb_build "avr" "--with-python=no $DISABLE_GUILE"

            # Set with_python for Linux 64 bit and Windows.
            case ${host_platform} in
                x86_64*-linux* )
                    with_python="yes"
            esac

            # if python_opts has a value, build avr-gdb-py
            [[ -n $with_python ]] && \
                gdb_build "avr" "--with-python=$with_python --program-prefix=avr-  --program-suffix=-py $DISABLE_GUILE"
            ;;
        * )
            echo "Error: Unknown package ${part}."
            exit 1
            ;;
    esac

done

task_start "Stripping binaries and libraries..."

find ${PREFIX}/bin -type f -perm -u+x -name '*' -exec strip '{}' ';'
if [ -e "${PREFIX}/libexec" ]; then
    find ${PREFIX}/libexec -type f -perm -u+x -name '*' -exec strip '{}' ';'
    find ${PREFIX}/libexec -type f -name '*.a' -print -exec strip '{}' ';'
fi
find ${PREFIX}/avr/lib ${PREFIX}/lib/gcc/avr -type f -name '*.a' -exec avr-strip --strip-debug '{}' ';'

task_success

end_timer
report_time
exit 0


##################################################################
# Now you should have a complete development enviroment for avr
# installed at 'prefix' location.
