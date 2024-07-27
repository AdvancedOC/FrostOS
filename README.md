# FrostOS
A simple and secure OpenComputers operating system.

It comes with a basic terminal called BTerm and a basic shell named Scute.
It supports drivers, basic filesystem utilities and running commands.
It also has a process-based model where there can be multiple process in a process tree (visible with ptree), which can each have multiple threads.

The important things missing are the login prompt, ability to install arbitrary software from a floppy disk, and running as administrator.

# Custom Shells and Environments

In the future, there will be `chsh` and `chenv`, which can be ran as a relatively privileged user to change the shell or environment.
These commands work by moding the symtab file.

# How to install?

If you're running OpenOS, simply run this command:
```
wget https://raw.githubusercontent.com/Blendi-Goose/FrostOS/main/installers/openos.lua frostOSInstaller.lua; frostOSInstaller.lua
```
