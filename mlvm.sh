#!/bin/bash

mkdir -p ~/mlvm/versions
cd ~/mlvm/versions

while getopts :fk opt; do
  case $opt in
    f) echo 'forcing version # in case of conflict' ;;
    k) echo keeping existing data ;;
  esac
done
shift $((OPTIND-1))

uninstall() {
  echo "uninstalling existing MarkLogic"
  rm -fr ~/Library/Application\ Support/MarkLogic/Data
  rm -fr ~/Library/MarkLogic
  rm -fr ~/Library/Application\ Support/MarkLogic
  rm -fr ~/Library/StartupItems/MarkLogic 
  rm -fr ~/Library/PreferencePanes/MarkLogic.prefPane
}

capture() {
  echo "capturing current installation as $1"
  mkdir -p ~/mlvm/versions/$1
  pkgutil --export-plist com.marklogic.server > ~/mlvm/versions/$1/pkg.plist
  cp -r ~/Library/Application\ Support/MarkLogic/Data ~/mlvm/versions/$1/Data
  cp -r ~/Library/MarkLogic ~/mlvm/versions/$1/Program
  cp -r ~/Library/Application\ Support/MarkLogic ~/mlvm/versions/$1/Support
  cp -r ~/Library/StartupItems/MarkLogic ~/mlvm/versions/$1/StartupItems
  cp -r ~/Library/PreferencePanes/MarkLogic.prefPane ~/mlvm/versions/$1/PrefPane
}

case "$1" in 

  list)
    echo "Available MarkLogic Versions:"
    for file in *; do
      test -d "$file" && echo "- $2$file"
    done
    ;;

  use)
    if [ "$#" -ne 2 ]; then 
      echo "You must specify which version to use.  'mlvm list' to see available versions"
      exit 1
    fi
    #TODO ensure the specified version exists
    #TODO check for any running MarkLogic processes
    echo "switching to $2"
    #TODO acknowledge the -k keep option

    ;;

  update)
    #TODO this is the same as -f capture $2, just here for convenience
    rm -fr ~/mlvm/versions/$2
    capture $2
    ;;

  capture)
    #TODO check if version # is already present and instruct to use -f option 
    capture $2
    ;;

  prepare)
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