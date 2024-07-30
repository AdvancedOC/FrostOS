# FrostOS
A simple and secure OpenComputers operating system.

It comes with a basic terminal called BTerm and a basic shell named Scute.
It supports drivers, basic filesystem utilities and running commands.
It also has a process-based model where there can be multiple process in a process tree (visible with ptree), which can each have multiple threads.
It supports multiple users, with a login screen on boot, and running individual commands as the admin user using ``doas``.

The important thing missing is ability to easily install arbitrary software from a floppy disk.

# Custom Shells and Environments

In the future, there will be `chsh` and `chenv`, which can be ran as a relatively privileged user to change the shell or environment.
These commands work by moding the symtab file.

# How to install?

## From OpenOS
If you're running OpenOS, simply run this command to run the installer:
```
wget https://raw.githubusercontent.com/AdvancedOC/FrostOS/main/installers/openos.lua /tmp/frostOSInstaller.lua; /tmp/frostOSInstaller.lua
```
If you prefer to have a live environment to install from, you can use the live FrostOS environment inside OpenOS to install it. However, this is not recommended OpenOS's modifications to the system might cause crashes.
This can be done by running:
```
wget https://raw.githubusercontent.com/AdvancedOC/FrostOS/main/installers/live.lua /tmp/frostOSLive.lua; /tmp/frostOSLive.lua
```
and then using the ``install`` command in the live environment.

## From other OSes
There are currently no installers available for other OSes. You can try running the live installer from your OS, but it might not work.
If you do want to install FrostOS from another OS, you can try installing a netboot-compatible BIOS like CyanBIOS first, and then netbooting using this link:
```
https://raw.githubusercontent.com/AdvancedOC/FrostOS/main/installers/live.lua
```
Once you've done that, you can then use the ``install`` command inside of the live enviroment.