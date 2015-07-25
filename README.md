# MarkLogic Version Manager
 Version Manager for using multiple versions of MarkLogic without using VMs or port numbers.  Note: only one version can be active at a time.

## Capabilities
 Currently this script can:

   -  install new versions (from a .dmg file on the local machine)
   -  capture an existing install to continue use with MLVM
   -  switch versions while maintaining data
   -  remove unused versions
 
 Since 1.1:  This script supports MacOSX.  This script supports use of the Preference Pane for starting/stopping the server (can also use mlvm start/stop)

## Installing MLVM
 Recommended installation on a Mac:

   -  clone the repository somewhere (git clone git@github.com:withjam/mlvm.git)
   -  create an alias in your bash profile for mlvm.sh like alias mlvm="&lt;cloned project dir&gt;/mlvm.sh"
   -  create an alias in your bash profile for sudo if you don't have one already:  alias sudo='sudo '
   -  if you have an existing ML install that you want to keep, execute: mlvm -k &lt;version_number&gt; prepare
   -  if you have an existing ML install but don't care to keep it, execute: mlvm -f prepare
   -  if you have no existing ML install execute: mlvm prepare (note: prepare command requires root privileges, so may require run as sudo)
   -  execute: mlvm list to see available versions

## Installing ML versions

 To install a new version you must:

   - download a valid .dmg installer file
   - execute: mlvm install <path to your .dmg installer> [<version_name>] - if no version_name is supplied it will derive one from the file name

For example:  

    mlvm install ~/Downloads/MarkLogic-7.0-2.3-x86_64.dmg 7.0.2.3
   
The version name you give it is optional and will uniquely identify it in your list and must be a valid directory name.  You can have multiples of the same MarkLogic server version as long as you give them each unique version names when installing via MLVM.  If you do not choose to supply a version name, a version name will be parsed from the name of the dmg file used.

## Listing installed versions

    mlvm list

## Switching to an installed version

    mlvm use <version_name>

## Credits

Author: Matt Pileggi

Contributors:  Justin Makeig, Paxton Hare
