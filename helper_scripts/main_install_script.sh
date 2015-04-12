# Unified Plone installer build script
# Copyright (c) 2008-2014 Plone Foundation. Licensed under GPL v 2.
#

# Path for Root install
#
# Path for server-mode install of Python/Zope/Plone
if [ `uname` = "Darwin" ]; then
    PLONE_HOME=/Applications/Plone
else
    PLONE_HOME=/usr/local/Plone
fi
# Path options for Non-Root install
#
# Path for install of Python/Zope/Plone
LOCAL_HOME="$HOME/Plone"

# if we create a ZEO cluster, it will go here (inside $PLONE_HOME):
ZEOCLUSTER_HOME=zeocluster
# a stand-alone (non-zeo) instance will go here (inside $PLONE_HOME):
RINSTANCE_HOME=zinstance

INSTALL_LXML=no
INSTALL_ZLIB=auto
INSTALL_JPEG=auto
if [ `uname` = "Darwin" ]; then
  # Darwin ships with a readtext rather than readline; it doesn't work.
  INSTALL_READLINE=yes
else
  INSTALL_READLINE=auto
fi

# default user/group ids for root installs; ignored in non-root.
DAEMON_USER=plone_daemon
BUILDOUT_USER=plone_buildout
PLONE_GROUP=plone_group

# End of commonly configured options.
#################################################

readonly FOR_PLONE=5.0b2
readonly WANT_PYTHON=2.7

readonly PACKAGES_DIR=packages
readonly ONLINE_PACKAGES_DIR=opackages
readonly HSCRIPTS_DIR=helper_scripts
readonly TEMPLATE_DIR=buildout_templates

readonly PYTHON_URL=https://www.python.org/ftp/python/2.7.9/Python-2.7.9.tgz
readonly PYTHON_MD5=5eebcaa0030dc4061156d3429657fb83
readonly PYTHON_TB=Python-2.7.9.tgz
readonly PYTHON_DIR=Python-2.7.9
readonly JPEG_TB=jpegsrc.v9a.tar.bz2
readonly JPEG_DIR=jpeg-9a
readonly READLINE_TB=readline-6.2.tar.bz2
readonly READLINE_DIR=readline-6.2
readonly VIRTUALENV_TB=virtualenv-12.1.1.tar.gz
readonly VIRTUALENV_DIR=virtualenv-12.1.1

readonly NEED_XML2="2.7.8"
readonly NEED_XSLT="1.1.26"

DEBUG_OPTIONS=no

# Add message translations below:
case $LANG in
    # es_*)
    #     . helper_scripts//locales/es/LC_MESSAGES/messages.sh
    #     ;;
    *)
        # default to English
        . helper_scripts/locales/en/LC_MESSAGES/messages.sh
        ;;
esac

if [ `whoami` = "root" ]; then
    ROOT_INSTALL=1
else
    ROOT_INSTALL=0
    # set paths to local versions
    PLONE_HOME="$LOCAL_HOME"
    DAEMON_USER="$USER"
    BUILDOUT_USER="$USER"
fi


# normalize
PWD=`pwd`
CWD="$PWD"
PKG="$CWD/$PACKAGES_DIR"

. helper_scripts/shell_utils.sh

usage () {
    eval "echo \"$USAGE_MESSAGE\""
    if [ "$1" ]; then
        eval "echo \"***\" \"$@\""
    fi
    exit 1
}


#########################################################
# Pick up options from command line
#
#set defaults
INSTALL_ZEO=0
INSTALL_STANDALONE=0
INSTANCE_NAME=""
WITH_PYTHON=""
BUILD_PYTHON="no"
WITH_ZOPE=""
RUN_BUILDOUT=1
SKIP_TOOL_TESTS=0
INSTALL_LOG="$ORIGIN_PATH/install.log"
CLIENT_COUNT=2
TEMPLATE=buildout
WITHOUT_SSL="no"

USE_WHIPTAIL=0
if [ "$BASH_VERSION" ] && [ "X$1" == "X" ]; then
    . helper_scripts/whipdialog.sh
    USE_WHIPTAIL=1
fi

for option
do
    optarg=`expr "x$option" : 'x[^=]*=\(.*\)'`

    case $option in
        --with-python=* | -with-python=* | --withpython=* | -withpython=* )
            if [ "$optarg" ]; then
                WITH_PYTHON="$optarg"
            else
                usage
            fi
            ;;

        --build-python | --build-python=* )
            if [ "$optarg" ]; then
                BUILD_PYTHON="$optarg"
                if [ $BUILD_PYTHON != 'yes' ] && [ $BUILD_PYTHON != 'no' ]; then
                    usage $BAD_BUILD_PYTHON
                fi
            else
                BUILD_PYTHON="yes"
            fi
            ;;

        --target=* | -target=* )
            if [ "$optarg" ]; then
                PLONE_HOME="$optarg"
            else
                usage
            fi
            ;;

        --instance=* | -instance=* )
            if [ "$optarg" ]; then
                INSTANCE_NAME="$optarg"
            else
                usage
            fi
            ;;

        --var=* | -var=* )
            if [ "$optarg" ]; then
                INSTANCE_VAR="$optarg"
            else
                usage
            fi
            ;;

        --backup=* | -backup=* )
            if [ "$optarg" ]; then
                BACKUP_DIR="$optarg"
            else
                usage
            fi
            ;;

        --user=* | -user=* )
            usage $BAD_USER_OPTION
            ;;

        --daemon-user=* | -daemon-user=* )
            if [ "$optarg" ]; then
                DAEMON_USER="$optarg"
            else
                usage
            fi
            ;;

        --owner=* | -owner=* )
            if [ "$optarg" ]; then
                BUILDOUT_USER="$optarg"
            else
                usage
            fi
            ;;

        --group=* | -group=* )
            if [ "$optarg" ]; then
                PLONE_GROUP="$optarg"
            else
                usage
            fi
            ;;

        --jpeg=* | --libjpeg=* )
            if [ "$optarg" ]; then
                INSTALL_JPEG="$optarg"
            else
                usage
            fi
            ;;

        --readline=* | --libreadline=* )
            if [ "$optarg" ]; then
                INSTALL_READLINE="$optarg"
            else
                usage
            fi
            ;;

        --template=* )
            if [ "$optarg" ]; then
                TEMPLATE="$optarg"
                if [ ! -f "${TEMPLATE_DIR}/$TEMPLATE" ] && \
                   [ ! -f "${TEMPLATE_DIR}/${TEMPLATE}.cfg" ]; then
                   usage "$BAD_TEMPLATE"
                fi
            else
                usage
            fi
            ;;

        --static-lxml | --static-lxml=* )
            if [ "$optarg" ]; then
                INSTALL_LXML="$optarg"
            else
                INSTALL_LXML="yes"
            fi
            ;;

        --without-ssl | --without-ssl=* )
            if [ "$optarg" ]; then
                WITHOUT_SSL="$optarg"
            else
                WITHOUT_SSL="yes"
            fi
            ;;

        --password=* | -password=* )
            if [ "$optarg" ]; then
                PASSWORD="$optarg"
            else
                usage
            fi
            ;;

        --nobuild* | --no-build*)
            RUN_BUILDOUT=0
            ;;

        --skip-tool-tests )
            SKIP_TOOL_TESTS=1
            # don't test for availability of gnu build tools
            # this is mainly meant to be used when binaries
            # are known to be installed already
            ;;

        --install-log=* | --log=* )
            if [ "$optarg" ]; then
                INSTALL_LOG="$optarg"
            else
                usage
            fi
            ;;

        --clients=* | --client=* )
            if [ "$optarg" ]; then
                CLIENT_COUNT="$optarg"
            else
                usage
            fi
            ;;

        --debug-options )
            DEBUG_OPTIONS=yes
            ;;

        --help | -h )
            usage
            ;;

        *)
            case $option in
                zeo* | cluster )
                    INSTALL_ZEO=1
                    ;;
                standalone* | nozeo | stand-alone | sa )
                    INSTALL_STANDALONE=1
                    ;;
                none )
                    echo "$NO_METHOD_SELECTED"
                    INSTALL_STANDALONE=1
                    RUN_BUILDOUT=0
                    ;;
                *)
                    usage
                    ;;
            esac
        ;;
    esac
done

if [ "X$WITH_PYTHON" != "X" ] && [ "X$BUILD_PYTHON" = "Xyes" ]; then
    echo "$CONTRADICTORY_PYTHON_COMMANDS"
fi

whiptail_goodbye() {
    echo "$POLITE_GOODBYE"
    exit 0
}

if [ $USE_WHIPTAIL -eq 1 ]; then

    if ! WHIPTAIL \
        --title="$WELCOME" \
        --yesno \
        "$DIALOG_WELCOME"; then
        whiptail_goodbye
    fi

    if ! WHIPTAIL \
        --title="$INSTALL_TYPE_MSG" \
        --menu \
        --choices="$INSTALL_TYPE_CHOICES" \
        "$CHOOSE_CONFIG_MSG"; then
        whiptail_goodbye
    fi
    case $WHIPTAIL_RESULT in
        Standalone*)
            INSTALL_STANDALONE=1
            METHOD=Standalone
            ;;
        ZEO*)
            INSTALL_ZEO=1
            METHOD=zeocluster
            ;;
    esac

    if [ $INSTALL_ZEO -eq 1 ]; then
        if ! WHIPTAIL \
            --title="$CHOOSE_CLIENTS_TITLE" \
            --menu \
            --choices="$CLIENT_CHOICES" \
            "$CHOOSE_CLIENTS_PROMPT" ; then
            whiptail_goodbye
        fi
        CLIENTS=$WHIPTAIL_RESULT
        if [ "X$CLIENTS" != "X" ]; then
            CCHOICE="--clients=$CLIENTS"
        fi
    fi

    # hack alert -- nasty quoting
    INSTALL_DIR_PROMPT=$(eval "echo \"$INSTALL_DIR_PROMPT\"")
    if ! WHIPTAIL \
        --title="$INSTALL_DIR_TITLE" \
        --inputbox \
        "$INSTALL_DIR_PROMPT"; then
        whiptail_goodbye
    fi
    if [ "X$WHIPTAIL_RESULT" != "X" ]; then
        PLONE_HOME="$WHIPTAIL_RESULT"
    fi


    if ! WHIPTAIL \
        --title="$PASSWORD_TITLE" \
        --passwordbox \
        "$PASSWORD_PROMPT"; then
        whiptail_goodbye
    fi
    PASSWORD="$WHIPTAIL_RESULT"
    if [ "X$PASSWORD" != "X" ]; then
        PCHOICE="--password=\"$PASSWORD\""
    fi

    WHIPTAIL \
        --title="$Q_CONTINUE" \
        --yesno \
        "$CONTINUE_PROMPT
install.sh $METHOD \\
    --target=\"$PLONE_HOME\" $PCHOICE $CCHOICE"
    if [ $? -gt 0 ]; then
        whiptail_goodbye
    fi
fi

if [ $INSTALL_STANDALONE -eq 0 ] && [ $INSTALL_ZEO -eq 0 ]; then
    usage
fi
echo


if [ $ROOT_INSTALL -eq 1 ]; then
    if ! which sudo > /dev/null; then
        echo $SUDO_REQUIRED_MSG
	echo
        exit 1
    fi
    SUDO="sudo -u $BUILDOUT_USER -E"
else
    SUDO=""
fi


# Most files and directories we install should
# be group/world readable. We'll set individual permissions
# where that isn't adequate
umask 022
# Make sure CDPATH doesn't spoil cd
unset CDPATH


# set up the common build environment unless already existing
if [ "x$CFLAGS" = 'x' ]; then
    export CFLAGS='-fPIC'
    if [ `uname` = "Darwin" ]; then
        # try to undo Apple's attempt to prevent the use of their Python
        # for open-source development
        export CFLAGS='-fPIC -Qunused-arguments'
        export CPPFLAGS=$CFLAGS
        export ARCHFLAGS=-Wno-error=unused-command-line-argument-hard-error-in-future
        if [ -d /opt/local ]; then
            # include MacPorts directories, which typically have additional
            # and later libraries
            export CFLAGS='-fPIC -Qunused-arguments -I/opt/local/include'
            export CPPFLAGS=$CFLAGS
            export LDFLAGS='-L/opt/local/lib'
        fi
    fi
fi


if [ $SKIP_TOOL_TESTS -eq 0 ]; then
    # Abort install if this script is not run from within it's parent folder
    if [ ! -x "$PACKAGES_DIR" ] || [ ! -x "$HSCRIPTS_DIR" ]; then
	eval "echo \"$MISSING_PARTS_MSG\""
        exit 1
    fi

    # Abort install if no cc
    which cc > /dev/null
    if [ $? -gt 0 ]; then
        echo "$NO_GCC_MSG"
        exit 1
    fi

    # build environment setup
    # use configure (renamed preflight) to create a build environment file
    # that will allow us to check for headers and tools the same way
    # that the cmmi process will.
    if [ -f ./buildenv.sh ]; then
        rm -f ./buildenv.sh
    fi
    sh ./preflight -q
    if [ $? -gt 0 ] || [ ! -f "buildenv.sh" ]; then
        echo "$PREFLIGHT_FAILED_MSG"
        exit 1
    fi
    # suck in the results as shell variables that we can test.
    . ./buildenv.sh
fi

if [ -x "$PLONE_HOME/Python-${WANT_PYTHON}/bin/python" ] ; then
    HAVE_PYTHON=yes
    if [ "X$WITH_PYTHON" != "X" ]; then
        echo "$IGNORING_WITH_PYTHON"
	WITH_PYTHON=''
    fi
    if [ "X$BUILD_PYTHON" = "Xyes" ]; then
        echo "$IGNORING_BUILD_PYTHON"
        BUILD_PYTHON=no
    fi
else
    HAVE_PYTHON=no

    # shared message for need python
    python_usage () {
        eval "echo \"$NEED_INSTALL_PYTHON_MSG\""
        exit 1
    }

    # check to see if we've what we need to build a suitable python
    # Abort install if no libz
    if [ "X$HAVE_LIBZ" != "Xyes" ] ; then
        echo $NEED_INSTALL_LIBZ_MSG
        exit 1
    fi

    if [ "X$WITHOUT_SSL" != "Xyes" ]; then
        if [ "X$HAVE_LIBSSL" != "Xyes" ]; then
            echo $NEED_INSTALL_SSL_MSG
            exit 1
        fi
    fi

    if [ "X$BUILD_PYTHON" = "Xyes" ]; then
        # if OpenBSD, apologize and surrender
        if [ `uname` = "OpenBSD" ]; then
            eval "echo\"$SORRY_OPENSSL\""
            exit 1
        fi
    else
        if [ "X$WITH_PYTHON" = "X" ]; then
            # try to find a Python
            WITH_PYTHON=`which python${WANT_PYTHON}`
            if [ $? -gt 0 ] || [ "X$WITH_PYTHON" = "X" ]; then
                eval "echo \"$PYTHON_NOT_FOUND\""
                python_usage
            fi
        fi
        # check our python
        if [ -x "$WITH_PYTHON" ] && [ ! -d "$WITH_PYTHON" ]; then
            eval "echo \"$TESTING_WITH_PYTHON\""
            if "$WITH_PYTHON" "$HSCRIPTS_DIR"/checkPython.py --without-ssl=${WITHOUT_SSL}; then
                eval "echo \"$WITH_PYTHON_IS_OK\""
                echo
                # if the supplied Python is adequate, we don't need to build libraries
                INSTALL_ZLIB=no
                INSTALL_READLINE=no
                WITHOUT_SSL="yes"
            else
                eval "echo \"$WITH_PYTHON_IS_BAD\""
                python_usage
            fi
        else
            eval "echo \"$WITH_PYTHON_NOT_EX\""
            python_usage
        fi
    fi
fi

#############################
# Preflight dependency checks
# Binary path variables may have been filled in by literal paths or
# by 'which'. 'which' negative results may be empty or a message.

if [ $SKIP_TOOL_TESTS -eq 0 ]; then

    # Abort install if no gcc
    if [ "x$CC" = "x" ] ; then
        echo
        echo $MISSING_GCC
        exit 1
    fi

    # Abort install if no g++
    if [ "x$CXX" = "x" ] ; then
        echo
        echo $MISSING_GPP
        exit 1
    fi

    # Abort install if no make
    if [ "X$have_make" != "Xyes" ] ; then
        echo
        echo $MISSING_MAKE
        exit 1
    fi

    # Abort install if no tar
    if [ "X$have_tar" != "Xyes" ] ; then
        echo
        echo $MISSING_TAR
        exit 1
    fi

    # Abort install if no patch
    if [ "X$have_patch" != "Xyes" ] ; then
        echo
        echo $MISSING_PATCH
        exit 1
    fi

    # Abort install if no gunzip
    if [ "X$have_gunzip" != "Xyes" ] ; then
        echo
        echo $MISSING_GUNZIP
        exit 1
    fi

    # Abort install if no bunzip2
    if [ "X$have_bunzip2" != "Xyes" ] ; then
        echo
        echo $MISSING_BUNZIP2
        exit 1
    fi

    if [ "$INSTALL_LXML" = "no" ]; then
        # check for libxml2 / libxslt

        XSLT_XML_MSG () {
            eval "echo \"$MISSING_MINIMUM_XSLT\""
        }

        if [ "x$XSLT_CONFIG" = "x" ]; then
            echo
            echo $MISSING_XML2_DEV
            XSLT_XML_MSG
            exit 1
        fi
        if [ "x$XML2_CONFIG" = "x" ]; then
            echo
            echo $MISSING_XSLT_DEV
            XSLT_XML_MSG
            exit 1
        fi
        if ! config_version xml2 $NEED_XML2; then
            eval "echo \"$BAD_XML2_VERSION\""
            XSLT_XML_MSG
            exit 1
        fi
        if ! config_version xslt $NEED_XSLT; then
            eval "echo \"$BAD_XSLT_VERSION\""
            XSLT_XML_MSG
            exit 1
        fi
        FOUND_XML2=`xml2-config --version`
        FOUND_XSLT=`xslt-config --version`
    fi
fi # not skip tool tests


if [ "X$INSTALL_JPEG" = "Xauto" ] ; then
    if [ "X$HAVE_LIBJPEG" = "Xyes" ] ; then
        INSTALL_JPEG=no
    else
        INSTALL_JPEG=yes
    fi
fi

if [ "X$INSTALL_READLINE" = "Xauto" ] ; then
    if [ "X$HAVE_LIBREADLINE" = "Xyes" ] ; then
        INSTALL_READLINE=no
    else
        INSTALL_READLINE=yes
    fi
fi


######################################
# Pre-install messages
if [ $ROOT_INSTALL -eq 1 ]; then
    eval "echo \"$ROOT_INSTALL_CHOSEN\""
else
    eval "echo \"$ROOTLESS_INSTALL_CHOSEN\""
fi
echo

######################################
# DEBUG OPTIONS
if [ "X$DEBUG_OPTIONS" = "Xyes" ]; then
    echo "Installer Variables:"
    echo "PLONE_HOME=$PLONE_HOME"
    echo "LOCAL_HOME=$LOCAL_HOME"
    echo "ZEOCLUSTER_HOME=$ZEOCLUSTER_HOME"
    echo "RINSTANCE_HOME=$RINSTANCE_HOME"
    echo "INSTALL_LXML=$INSTALL_LXML"
    echo "INSTALL_ZLIB=$INSTALL_ZLIB"
    echo "INSTALL_JPEG=$INSTALL_JPEG"
    echo "INSTALL_READLINE=$INSTALL_READLINE"
    echo "DAEMON_USER=$DAEMON_USER"
    echo "BUILDOUT_USER=$BUILDOUT_USER"
    echo "PLONE_GROUP=$PLONE_GROUP"
    echo "FOR_PLONE=$FOR_PLONE"
    echo "WANT_PYTHON=$WANT_PYTHON"
    echo "PACKAGES_DIR=$PACKAGES_DIR"
    echo "ONLINE_PACKAGES_DIR=$ONLINE_PACKAGES_DIR"
    echo "HSCRIPTS_DIR=$HSCRIPTS_DIR"
    echo "ROOT_INSTALL=$ROOT_INSTALL"
    echo "PLONE_HOME=$PLONE_HOME"
    echo "DAEMON_USER=$DAEMON_USER"
    echo "BUILDOUT_USER=$BUILDOUT_USER"
    echo "ORIGIN_PATH=$ORIGIN_PATH"
    echo "PWD=$PWD"
    echo "CWD=$CWD"
    echo "PKG=$PKG"
    echo "WITH_PYTHON=$WITH_PYTHON"
    echo "BUILD_PYTHON=$BUILD_PYTHON"
    echo "HAVE_PYTHON=$HAVE_PYTHON"
    echo "CC=$CC"
    echo "CPP=$CPP"
    echo "CXX=$CXX"
    echo "GREP=$GREP"
    echo "have_bunzip2=$have_bunzip2"
    echo "have_gunzip=$have_gunzip"
    echo "have_tar=$have_tar"
    echo "have_make=$have_make"
    echo "have_patch=$have_patch"
    echo "XML2_CONFIG=$XML2_CONFIG"
    echo "XSLT_CONFIG=$XSLT_CONFIG"
    echo "HAVE_LIBZ=$HAVE_LIBZ"
    echo "HAVE_LIBJPEG=$HAVE_LIBJPEG"
    echo "HAVE_LIBSSL=$HAVE_LIBSSL"
    echo "HAVE_SSL2=$HAVE_SSL2"
    echo "HAVE_LIBREADLINE=$HAVE_LIBREADLINE"
    echo "FOUND_XML2=$FOUND_XML2"
    echo "FOUND_XSLT=$FOUND_XSLT"
    echo ""
    exit 0
fi


# set up log
if [ -f "$INSTALL_LOG" ]; then
    rm -f "$INSTALL_LOG"
fi
touch "$INSTALL_LOG" 2> /dev/null
if [ $? -gt 0 ]; then
    eval "echo \"$CANNOT_WRITE_LOG\""
    INSTALL_LOG="/dev/stdout"
else
    eval "echo \"$LOGGING_MSG\""
    echo "Detailed installation log" > "$INSTALL_LOG
    echo "Starting at `date`" >> "$INSTALL_LOG
fi
seelog () {
    eval "echo \"$SEE_LOG_EXIT_MSG\""
    exit 1
}


eval "echo \"$INSTALLING_NOW\""


#######################################
# create os users for root-level install
if [ $ROOT_INSTALL -eq 1 ]; then
    # source user/group utilities
    . helper_scripts/user_group_utilities.sh

    # see if we know how to do this on this platfrom
    check_ug_ability

    create_group $PLONE_GROUP
    create_user $DAEMON_USER $PLONE_GROUP
    check_user $DAEMON_USER $PLONE_GROUP
    create_user $BUILDOUT_USER $PLONE_GROUP
    check_user $BUILDOUT_USER $PLONE_GROUP

fi # if $ROOT_INSTALL


#######################################
# create plone home
if [ ! -x "$PLONE_HOME" ]; then
    mkdir "$PLONE_HOME"
    # normalize $PLONE_HOME so we can use it in prefixes
    if [ $? -gt 0 ] || [ ! -x "$PLONE_HOME" ]; then
        eval "echo \"$CANNOT_CREATE_HOME\""
        exit 1
    fi
    cd "$PLONE_HOME"
    PLONE_HOME=`pwd`
fi

cd "$CWD"


cd "$PLONE_HOME"
PLONE_HOME=`pwd`
# More paths
if [ ! "x$INSTANCE_NAME" = "x" ]; then
    # override instance home
    if echo "$INSTANCE_NAME" | grep "/"; then
        # we have a full destination, not just a name.
        # normalize
        ZEOCLUSTER_HOME=$INSTANCE_NAME
        RINSTANCE_HOME=$INSTANCE_NAME
    else
        ZEOCLUSTER_HOME=$PLONE_HOME/$INSTANCE_NAME
        RINSTANCE_HOME=$PLONE_HOME/$INSTANCE_NAME
    fi
else
    ZEOCLUSTER_HOME=$PLONE_HOME/$ZEOCLUSTER_HOME
    RINSTANCE_HOME=$PLONE_HOME/$RINSTANCE_HOME
fi

# Determine and check instance home
if [ $INSTALL_ZEO -eq 1 ]; then
    INSTANCE_HOME=$ZEOCLUSTER_HOME
elif [ $INSTALL_STANDALONE -eq 1 ]; then
    INSTANCE_HOME=$RINSTANCE_HOME
fi
if [ -x "$INSTANCE_HOME" ]; then
    eval "echo \"$INSTANCE_HOME_EXISTS\""
    exit 1
fi

cd "$CWD"

if  [ "X$INSTALL_ZLIB" = "Xyes" ] || \
    [ "X$INSTALL_JPEG" = "Xyes" ] || \
    [ "X$INSTALL_READLINE" = "Xyes" ]
then
    NEED_LOCAL=1
else
    NEED_LOCAL=0
fi


if [ "X$WITH_PYTHON" != "X" ] && [ "X$HAVE_PYTHON" = "Xno" ]; then
    PYBNAME=`basename "$WITH_PYTHON"`
    PY_HOME=$PLONE_HOME/Python-2.7
    cd "$PKG"
    untar $VIRTUALENV_TB
    cd $VIRTUALENV_DIR
    echo $CREATING_VIRTUALENV
    "$WITH_PYTHON" virtualenv.py "$PY_HOME"
    cd "$PKG"
    rm -r $VIRTUALENV_DIR
    PY=$PY_HOME/bin/python
    if [ ! -x "$PY" ]; then
        eval "echo \"$VIRTUALENV_CREATION_FAILED\""
        exit 1
    fi
    cd "$PY_HOME"/bin
    if [ ! -x python ]; then
        # add a symlink so that it's easy to use
        ln -s "$PYBNAME" python
    fi
    cd "$CWD"
    if ! "$WITH_PYTHON" "$HSCRIPTS_DIR"/checkPython.py --without-ssl=${WITHOUT_SSL}; then
        echo $VIRTUALENV_BAD
        exit 1
    fi
else # use already-placed python or build one
    PY_HOME=$PLONE_HOME/Python-2.7
    PY=$PY_HOME/bin/python
    if [ -x "$PY" ]; then
        # no point in installing zlib -- too late!
        INSTALL_ZLIB=no
    fi
fi


# Now we know where our Python is, and may finish setting our paths
LOCAL_HOME="$PY_HOME"
EI="$PY_HOME/bin/easy_install"
BUILDOUT_CACHE="$PLONE_HOME/buildout-cache"
BUILDOUT_DIST="$PLONE_HOME/buildout-cache/downloads/dist"

if [ ! -x "$LOCAL_HOME" ]; then
    mkdir "$LOCAL_HOME"
fi
if [ ! -x "$LOCAL_HOME" ]; then
    echo "Unable to create $LOCAL_HOME"
    exit 1
fi

. helper_scripts/build_libjpeg.sh

if [ ! -x "$PY" ]; then
    . helper_scripts/build_readline.sh

    if [ `uname` = "Darwin" ]; then
        # Remove dylib files that will prevent static linking,
        # which we need for relocatability
        rm -f "$PY_HOME/lib/"*.dylib
    fi

    # download python tarball if necessary
    cd "$PKG"
    if [ ! -f $PYTHON_TB ]; then
        eval "echo \"$DOWNLOADING_PYTHON\""
        download $PYTHON_URL $PYTHON_TB $PYTHON_MD5
    fi
    cd "$CWD"

    . helper_scripts/build_python.sh

    if "$PY" "$CWD/$HSCRIPTS_DIR"/checkPython.py --without-ssl=${WITHOUT_SSL}; then
        echo $PYTHON_BUILD_OK
    else
        echo $PYTHON_BUILD_BAD
        exit 1
    fi
fi


# From here on, we don't want any ad-hoc cflags or ldflags, as
# they will foul the modules built via distutils.
# Latest OS X is the exception, since their Mavericks Python
# supplies bad flags. How did they build that Python? Probably
# not with the latest XCode.
if [ `uname` != "Darwin" ]; then
    unset CFLAGS
    unset LDFLAGS
fi

if [ -f "${PKG}/buildout-cache.tar.bz2" ]; then
    if [ -x "$BUILDOUT_CACHE" ]; then
        eval "echo \"$FOUND_BUILDOUT_CACHE\""
    else
        eval "echo \"$UNPACKING_BUILDOUT_CACHE\""
        cd $PLONE_HOME
        untar "${PKG}/buildout-cache.tar.bz2"
        # # compile .pyc files in cache
        # echo "Compiling .py files in egg cache"
        # "$PY" "$PLONE_HOME"/Python*/lib/python*/compileall.py "$BUILDOUT_CACHE"/eggs > /dev/null 2>&1
    fi
    if [ ! -x "$BUILDOUT_CACHE"/eggs ]; then
        echo $BUILDOUT_CACHE_UNPACK_FAILED
        seelog
        exit 1
    fi
else
    mkdir "$BUILDOUT_CACHE"
    mkdir "$BUILDOUT_CACHE"/eggs
    mkdir "$BUILDOUT_CACHE"/extends
    mkdir "$BUILDOUT_CACHE"/downloads
fi

if [ -x "$CWD/Plone-docs" ] && [ ! -x "$PLONE_HOME/Plone-docs" ]; then
    echo "Copying Plone-docs"
    cp -R "$CWD/Plone-docs" "$PLONE_HOME/Plone-docs"
fi


cd "$CWD"

# The main install may be done via sudo (if a root install). If it is,
# our current directory may become unreachable. So, copy the resources
# we'll need into a tmp directory inside the install destination.
WORKDIR="${PLONE_HOME}/tmp"
mkdir "$WORKDIR" > /dev/null 2>&1
cp -R ./buildout_templates "$WORKDIR"
cp -R ./base_skeleton "$WORKDIR"
cp -R ./helper_scripts "$WORKDIR"

########################
# Instance install steps
########################

cd "$WORKDIR"

if [ $ROOT_INSTALL -eq 1 ]; then
    echo "Setting $PLONE_HOME ownership to $BUILDOUT_USER:$PLONE_GROUP"
    chown -R "$BUILDOUT_USER:$PLONE_GROUP" "$PLONE_HOME"
    # let's have whatever we create from now on sticky group'd
    chmod g+s "$PLONE_HOME"
    # including things copied from the work directory
    find "$WORKDIR" -type d -exec chmod g+s {} \;
fi

################################################
# Install the zeocluster or stand-alone instance
if [ $INSTALL_ZEO -eq 1 ]; then
    INSTALL_METHOD="cluster"
elif [ $INSTALL_STANDALONE -eq 1 ]; then
    INSTALL_METHOD="standalone"
    CLIENT_COUNT=0
fi
$SUDO "$PY" "$WORKDIR/helper_scripts/create_instance.py" \
    "--uidir=$WORKDIR" \
    "--plone_home=$PLONE_HOME" \
    "--instance_home=$INSTANCE_HOME" \
    "--daemon_user=$DAEMON_USER" \
    "--buildout_user=$BUILDOUT_USER" \
    "--root_install=$ROOT_INSTALL" \
    "--run_buildout=$RUN_BUILDOUT" \
    "--install_lxml=$INSTALL_LXML" \
    "--itype=$INSTALL_METHOD" \
    "--password=$PASSWORD" \
    "--instance_var=$INSTANCE_VAR" \
    "--backup_dir=$BACKUP_DIR" \
    "--template=$TEMPLATE" \
    "--clients=$CLIENT_COUNT" 2>> "$INSTALL_LOG"
if [ $? -gt 0 ]; then
    echo $BUILDOUT_FAILED
    seelog
    exit 1
fi
echo $BUILDOUT_SUCCESS

if [ $ROOT_INSTALL -eq 0 ]; then
    # for non-root installs, restrict var access.
    # root installs take care of this during buildout.
    chmod 700 "$INSTANCE_HOME/var"
fi

cd "$CWD"
# clear our temporary directory
rm -r "$WORKDIR"

PWFILE="$INSTANCE_HOME/adminPassword.txt"
RMFILE="$INSTANCE_HOME/README.html"

#######################
# Conclude installation
if [ -d "$PLONE_HOME" ]; then
    if [ $SKIP_TOOL_TESTS -eq 0 ]; then
        echo " "
        echo "#####################################################################"
        if [ $RUN_BUILDOUT -eq 1 ]; then
            eval "echo \"$INSTALL_COMPLETE\""
            cat $PWFILE
        else
            eval "echo \"$BUILDOUT_SKIPPED_OK\""
        fi
        echo $NEED_HELP_MSG
    fi
    echo "Finished at `date`" >> "$INSTALL_LOG"
else
    eval "echo \"$REPORT_ERRORS_MSG\""
    exit 1
fi
