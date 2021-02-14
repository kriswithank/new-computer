# new-computer
Post-install scripts to automatically set up a new computer

# Arch Linux

Follow the arch wiki install tutorial

Additionally make sure you install `networkmanager` (or some other way to connect to the internet) from the install media. If you don't you won't be able to access the internet after booting into the newly installed stystem.

After booting into the freshly installed system, simply run the following:

```
cd /tmp
curl -LO https://raw.githubusercontent.com/kriswithank/new-computer/main/new_arch.sh
bash ./new_arch.sh
```
