#!/bin/bash
#
# Version Manager for using multiple versions of MarkLogic without using VMs or port numbers.  Note: only one version can be active at a time.
# 
# Currently this script can:
#    - install new versions (from a .dmg file on the local machine)
#    - capture an existing install to continue use with MLVM
#    - switch versions while maintaining data
#    - remove unused versions
# 
# Since 1.1:  This script supports MacOSX.  This script supports use of the Preference Pane for starting/stopping the server (can also use mlvm start/stop)
#
# Recommended installation on a Mac:
#   -  clone the repository somewhere (git clone git@github.com:withjam/mlvm.git)
#   -  create an alias in your bash profile for mlvm.sh like alias mlvm="<cloned project dir>/mlvm.sh"
#   -  create an alias in your bash profile for sudo if you don't have one already:  alias sudo='sudo '
#   -  if you have an existing ML install that you want to keep, execute: mlvm -k <version_number> prepare
#   -  if you have an existing ML install but don't care to keep it, execute: mlvm -f prepare
#   -  if you have no existing ML install execute: mlvm prepare (note: prepare command requires root privileges, so may require run as sudo)
#   -  execute: mlvm list to see available versions
#
# To install a new version you must:
#   - download a valid .dmg installer file
#   - execute: mlvm install <version_name> <path to your .dmg installer>
#
#   For example:  mlvm install 7.0.2.3 ~/Downloads/MarkLogic-7.0-2.3-x86_64.dmg
#   The version name you give it will uniquely identify it in your list and must be a valid directory name.  You can have multiples of the same MarkLogic server version as long as you give them each unique version names when installing via MLVM
#
#
# Author: Matt Pileggi <Matt.Pileggi@marklogic.com>
# Contributors:  Justin Makeig <justin.makeig@marklogic.com>, Paxton Hare <Paxton.Hare@marklogic.com>
version=1.1

SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
  DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE" # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
done
SOURCE="$( cd -P "$( dirname "$SOURCE" )" && pwd )"

mkdir -p $SOURCE/versions
cd $SOURCE/versions

# current MarkLogic symlink
sym=$(readlink ~/Library/MarkLogic)

while getopts :fk: opt; do
  case $opt in
    f) forcing=true ;;
    k) keeping=$OPTARG ;;
  esac
done
shift $((OPTIND-1))

versiondir() {
  echo "$SOURCE/versions/$1"
}

hasversion() {
  vdir=$(versiondir $1)
  if [ ! -d $vdir ]; then
    return 1
  fi
  return 0
}

uninstall() {
  echo "Uninstalling conventional MarkLogic"
  rm -fr ~/Library/MarkLogic
  rm -fr ~/Library/Application\ Support/MarkLogic
  rm -fr ~/Library/StartupItems/MarkLogic 
  rm -fr ~/Library/PreferencePanes/MarkLogic.prefPane
}

capture() {
  echo "Keeping current installation as $1"
  vdir=$(versiondir $1)
  mkdir -p $vdir/StartupItems
  mkdir -p $vdir/PreferencePanes
  cp -a ~/Library/MarkLogic $SOURCE/versions/$1/MarkLogic
  cp -a ~/Library/Application\ Support/MarkLogic $SOURCE/versions/$1/Support
  cp -a ~/Library/StartupItems/MarkLogic $SOURCE/versions/$1/StartupItems/MarkLogic
  cp -a ~/Library/PreferencePanes/MarkLogic.prefPane $SOURCE/versions/$1/PreferencePanes/MarkLogic.prefPane
  # make sure everything is owned by this user
  _user=$(who am i | awk '{print $1}')
  _group=$(id -g $_user)
  chown -R $_user:$_group $SOURCE/versions/$1
}

switchto() {
  echo "switching to $1"
  #clear symlinks then recreate them
  rm ~/Library/MarkLogic
  rm ~/Library/Application\ Support/MarkLogic
  rm ~/Library/PreferencePanes/MarkLogic.prefPane
  rm $SOURCE/versions/.current/*
  vdir=$(versiondir $1)
  ln -s $vdir/MarkLogic ~/Library/MarkLogic
  ln -s $vdir/Support ~/Library/Application\ Support/MarkLogic
  ln -s $vdir/PreferencePanes/* ~/Library/PreferencePanes/
  # current version links for startup commands
  ln -s $vdir/StartupItems/MarkLogic/* $SOURCE/versions/.current
}

isactive() {
  if [[ ! -z $sym ]] && [[ $(basename $(dirname $sym)) = $1 ]]; then
    return 0
  fi
  return 1
}

startServer() {
  $SOURCE/versions/.current/MarkLogic start
}
stopServer() {
  $SOURCE/versions/.current/MarkLogic stop
}

case "$1" in 

  # syntax:  mlvm list
  list)
    echo "Installed MarkLogic Versions:"
    for file in *; do
      mark='-'
      if isactive $file ; then
        mark='*'
      fi
      test -d "$file" && echo "$mark $file"
    done
    ;;

  # syntax: mlvm use <version_name>
  use)
    if [ ! -d $SOURCE/versions/.current ] ; then
      echo "You have not yet prepared your environment to use MLVM.  Please execute: mlvm prepare first"
      exit 1
    fi
    if [ "$#" -ne 2 ]; then 
      echo "You must specify which version to use.  'mlvm list' to see available versions"
      exit 1
    fi
    if ! hasversion $2 ; then
      echo "There is no version \"$2\""
      exit 1
    fi
    stopServer
    switchto $2
    startServer
    ;;

  # syntax:  mlvm install <version_name> <dmg_file>
  install) #installs a new .dmg version of ML
    #TODO download automatically, for now it requires the path to a previously downloaded .dmg
    vdir=$(versiondir $2)
    if [ -d $vdir ]; then
      echo "$2 is already installed"
      exit 1
    fi
    
    # mount the dmg
    DMG="$3"
    mpoint=$(date +%s)$RANDOM
    mpoint=$SOURCE/.mounts/"$mpoint"
    mkdir -p "$mpoint"
    
    echo "Mounting $DMG to $mpoint"
    hdiutil attach "$DMG" -mountpoint "$mpoint" -nobrowse -quiet

    # <http://dxr.mozilla.org/mozilla-central/source/build/package/mac_osx/unpack-diskimage>
    TIMEOUT=15
    i=0
    while [ "$(echo $mpoint/*)" == "$mpoint/*" ]; do
        if [ $i -gt $TIMEOUT ]; then
            echo "No files found, exiting"
            exit 1
        fi
        ls -la "$mpoint"
        sleep 1
        i=$(expr $i + 1)
    done

    mkdir -p "$vdir"
    tar xfz "$mpoint"/*.pkg/Contents/Archive.pax.gz -C "$vdir"
    
    mkdir -p $vdir/Support/Data
    chmod +x $vdir/StartupItems/MarkLogic/MarkLogic
    echo "cleaning up"
    hdiutil detach $mpoint -quiet
    rm -fr $mpoint
    ;;

  # syntax: mlvm remove <version_name>
  remove)
    if [ -z $2 ]; then
      echo "usage: mlvm remove <version_name>"
      echo "use 'mlvm list' to see a list of available versions"
      exit 1
    fi
    vdir=$(versiondir $2)
    if [ ! -d $vdir ]; then
      echo "\"$2\" is not installed"
      exit 1
    fi
    if $(isactive $2) ; then
      echo "\"$2\" is the active version.  Use -f to force an uninstall or 'mlvm use <version_name>' to use a different version before removing \"$2\"."
      exit 1
    fi
    rm -fr $SOURCE/versions/$2
    echo "removed \"$2\""
    ;;

  stop)
    stopServer
    ;;

  start)
    startServer
    ;;

  status)
    if [ ! -d $SOURCE/versions/.current ]; then
      echo 'You are not currently using mlvm.'
      echo
      echo "Run 'mlvm install <version_name> <dmg_file>' to install a new version. (Note: this will remove an existing installation made without mlvm)"
      echo
      echo "If you have previously installed a version of MarkLogic, FIRST run 'mlvm -k <version_name> prepare' to retain it along with future mlvm installations. Otherwise it will be replaced and data will be lost."      
      exit 1
    fi
    echo "mlvm version: $version"
    if [ ! -z $sym ]; then
      echo "Active ML version: $(basename $(dirname $sym))"
    fi
    ;;

  # syntax: mlvm [-k <version_name>] prepare
  prepare) # prepares for use of mlvm by uninstalling existing MarkLogic, can optionally back up your existing install as a version
    if [ -d ~/Library/MarkLogic ]; then
      echo "Detected an existing installation of MarkLogic"
      if [ -z $keeping ] && [ -z $forcing ] ; then
        echo "Any existing MarkLogic data will be lost in the process unless kept.  You must either: "
        echo "  'mlvm -k <version_name> prepare' to retain the current version with mlvm, or "
        echo "  'mlvm -f prepare' to force an uninstallation and loss of data"
        exit 1
      fi
      if [ "$(id -u)" != "0" ]; then
        echo "This command requires root privileges.  Please run as sudo";
        exit 1
      fi
      #uninstalls the current ML installation, should probably ask if user wants to capture or update before proceeding
      #TODO check if any running MarkLogic processes
      if [ ! -z $keeping ]; then
        if hasversion $keeping ; then
          echo "\"$keeping\" already exists"
          exit 1
        fi
        capture $keeping
      fi
      uninstall
    else
      echo "Did not detect an existing install of MarkLogic"
    fi
    # this allows us to still use the prefpane and change current version without sudo later
    mkdir -p $SOURCE/versions/.current
    _user=$(who am i | awk '{print $1}')
    _group=$(id -g $_user)
    chown -R $_user:$_group $SOURCE/versions/
    ln -s $SOURCE/versions/.current/ ~/Library/StartupItems/MarkLogic

    echo "Ready to manage MarkLogic versions with mlvm."
    echo "Use 'mlvm list' to see installed versions"
    echo "Use 'mlvm install <version_name> <dmg_file>' to install a version"
    echo "Use 'mlvm use <version_name>' to switch to an installed version"
    echo "Use 'mlvm remove <version_name>' to remove an installed version (not recoverable)"
    ;;
  
  init)
    HOST=${2:-localhost}
    ADMINUSER=${3:-admin}

    unset ADMINPASSWORD
    prompt="Enter password for admin user, $ADMINUSER: "
    while IFS= read -p "$prompt" -r -s -n 1 char
    do
        if [[ $char == $'\0' ]]
        then
            break
        fi
        prompt='*'
        ADMINPASSWORD+="$char"
    done
    #echo "$ADMINPASSWORD"
    echo ""

    curl -fsS --head --digest --user "$ADMINUSER":"$ADMINPASSWORD" http://"$HOST":8001/admin/v1/timestamp &>/dev/null
    if [[ $? != 0 ]] ; then
        echo "Couldn't reach ${HOST}"
        exit 1
    fi

    # curl -X POST --data "" http://"$HOST":8001/admin/v1/init
    echo "Initializing…"
    curl --fail --show-error --silent -X POST --data "" http://"$HOST":8001/admin/v1/init 1>/dev/null
    if [[ $? != 0 ]] ; then
        echo "error on init"
        exit 1
    fi
    echo "Completed initialization. Waiting for restart…"

    # curl -fsS --head --digest --user admin:"$ADMINPASSWORD" http://"$HOST":8001/admin/v1/timestamp
    # One liner: until curl -fsS --head http://192.168.56.101:8001/admin/v1/timestamp --digest --user admin:admin; do sleep 5; done
    
    sleep 1
    until curl -fsS \
      --max-time 1 \
      --head \
      --digest --user "$ADMINUSER":"$ADMINPASSWORD" \
      http://"$HOST":8001/admin/v1/timestamp &>/dev/null
    do
      echo "Retrying…"
      sleep 2
    done

    # curl -X POST -H "Content-type: application/x-www-form-urlencoded" --data "admin-username=admin" --data "admin-password=********" http://localhost:8001/admin/v1/instance-admin
    echo "Starting instance administration…"
    curl -fsS \
      -X POST -H "Content-type: application/x-www-form-urlencoded" \
      --data "admin-username=${ADMINUSER}" --data "admin-password=${ADMINPASSWORD}" --data "realm=public" \
      http://"$HOST":8001/admin/v1/instance-admin 1>/dev/null
    if [[ $? != 0 ]] ; then
        echo "Error on instance-admin"
        exit 1
    fi

    echo "Completed instance administration. Waiting for restart…"
    sleep 1
    until curl -fsS \
      --head \
      --digest --user "$ADMINUSER":"$ADMINPASSWORD" \
      --max-time 1 \
      http://"$HOST":8001/admin/v1/timestamp &>/dev/null
    do
      echo "Retrying…"
      sleep 2
    done
    echo "Initialization completed"
    ;;
  
  *) 
    echo "usage: mlvm [list, use (version), prepare, capture (version)]"
    exit 1

esac 