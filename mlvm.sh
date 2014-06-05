#!/bin/bash

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

while getopts :fk opt; do
  case $opt in
    f) echo 'forcing version # in case of conflict' ;;
    k) echo keeping existing data ;;
  esac
done
shift $((OPTIND-1))

uninstall() {
  echo "uninstalling default MarkLogic"
  rm -fr ~/Library/Application\ Support/MarkLogic/Data
  rm -fr ~/Library/MarkLogic
  rm -fr ~/Library/Application\ Support/MarkLogic
  sudo rm -fr ~/Library/StartupItems/MarkLogic 
  rm -fr ~/Library/PreferencePanes/MarkLogic.prefPane
  pkgutil --export-plist com.marklogic.server > $SOURCE/versions/$2/pkg.plist
}

capture() {
  echo "capturing current installation as $1"
  mkdir -p $SOURCE/versions/$1
  cp -r ~/Library/Application\ Support/MarkLogic/Data $SOURCE/versions/$1/Data
  cp -r ~/Library/MarkLogic $SOURCE/versions/$1/Program
  cp -r ~/Library/Application\ Support/MarkLogic $SOURCE/versions/$1/Support
  cp -r ~/Library/StartupItems/MarkLogic $SOURCE/versions/$1/StartupItems
  cp -r ~/Library/PreferencePanes/MarkLogic.prefPane $SOURCE/versions/$1/PrefPane
}

# returns the PID of the running MarkLogic process, if there is one
mlpid() {
  return 0
}

switchto() {
  echo "switching to $1"
  #TODO update symlinks and system settings
}

isactive() {
  if [ ! -z $sym ] && [ $(basename $sym) = $1 ]; then
    return 0
  fi
  return 1
}

case "$1" in 

  # syntax:  mlvm list
  list)
    echo "Available MarkLogic Versions:"
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
    if [ "$#" -ne 2 ]; then 
      echo "You must specify which version to use.  'mlvm list' to see available versions"
      exit 1
    fi
    #TODO ensure the specified version exists
    #TODO check for any running MarkLogic processes
    if [ mlpid ]; then 
      echo "Stopping server" 
    fi
    switchto $2
    ;;

  # syntax:  mlvm install <version_name> <dmg_file>
  install) #installs a new .dmg version of ML
    #TODO download automatically, for now it requires the path to a previously downloaded .dmg
    vdir=$SOURCE/versions/$2
    if [ -d $vdir ]; then
      echo "$2 is already installed"
      exit 1
    fi
    # mount the dmg
    mpoint=$(date +%s)$RANDOM
    mpoint=$SOURCE/.mounts/$mpoint
    echo "Mounting dmg"
    mkdir -p $mpoint
    hdiutil attach $3 -nobrowse -quiet -mountpoint $mpoint
    mkdir -p $vdir
    echo "Extracting contents"
    tar xfz $mpoint/*.pkg/Contents/Archive.pax.gz -C $vdir
    mkdir -p $vdir/Support/Data
    echo "cleaning up"
    hdiutil detach $mpoint -quiet
    rm -fr $mpoint
    ;;

  # syntax: mlvm remove <version_name>
  remove)
    vdir=$SOURCE/versions/$2
    if [ ! -d $vdir ]; then
      echo "$2 is not installed"
      exit 1
    fi
    ;;

  # syntax: mlvm prepare [-k <version_name>]
  prepare) # prepares for use of mlvm by uninstalling existing MarkLogic, can optionally back up your existing install as a version
    #TODO requires sudo
    #uninstalls the current ML installation, should probably ask if user wants to capture or update before proceeding
    #TODO warn user
    #TODO check if any running MarkLogic processes
    uninstall
    #need to forget about the installed server to make sure we can install previous versions
    pkgutil --forget com.marklogic.server
    ;;

  *) 
    echo "usage: mlvm [list, use (version), prepare, capture (version)]"
    exit 1

esac 