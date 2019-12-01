---
title: Remote unlocking LUKS-encrypted hard drive with TinySSH
published_date: "2019-12-01 21:12:43 +0000"
layout: default.liquid
is_draft: false
---
# Remote unlocking LUKS-encrypted hard drive with TinySSH

One of the pain points of having hard drive encrypted with LUKS was that I could not unlock the drive remotely. Finally, I found some time to configure this on my system, so here is the walkthrough (please note that this may slightly differ on your system).

First, install the dependencies. `mkinitcpio-*` packages are the `mkinitcpio` hooks, `tinyssh-convert` is used to convert Ed25519 public keys from the format used by OpenSSH to the one used by TinySSH.
```
sudo pacman -S mkinitcpio-netconf mkinitcpio-tinyssh mkinitcpio-utils
```

Next, we have to configure hooks in `/etc/mkinitcpio.conf`. We should already have something like this:

```
HOOKS="base udev autodetect keyboard keymap consolefont modconf block encrypt lvm2 filesystems fsck"
```

We have to add `netconf` and `tinyssh` hooks before `encrypt` and change `encrypt` to `encryptssh`:

```
HOOKS="base udev autodetect keyboard keymap consolefont modconf block netconf tinyssh encryptssh lvm2 filesystems fsck"
```

Before rebuilding initrd image we have to add the public keys we will use to log in (the keys are included in the image, so we have to rebuild it every time we add new keys):

```
cp path/to/public/keys.pub /etc/tinyssh/root_key
```

You can add a single key, or just copy `~/.ssh/authorized_keys` (but remember to always inspect the keys and only add the ones you will use). Please note that TinySSH only supports Ed25519 or ECDSA keys, so you will have to generate one if you use RSA (and you probably should upgrade them to Ed25519 anyway, so maybe it's a good excuse to [migrate away from RSA](https://blog.g3rt.nl/upgrade-your-ssh-keys.html)).

Now, we can rebuild the image:

```
mkinitcpio -p linux
```

Next, we have to add a kernel command line parameter to configure Ethernet interface. Please note that you have to use kernel device names, not udev's. For most cases this will just be `eth0`, but if you use more then one network card (like me) and are unsure which kernel name to use, you can run `ip a` to find out udev device names and then `dmesg | grep eth` to find out kernel device names:

```
[   25.548268 ] r8169 0000:03:00.0 enp3s0: renamed from eth0
[   25.565145 ] r8169 0000:05:00.0 enp5s0: renamed from eth1
```

In my case it was `eth1`. Edit `/etc/default/grub` and modify `GRUB_CMDLINE_LINUX` to look like this (note the `ip=::::...` part):


```
GRUB_CMDLINE_LINUX="cryptdevice=UUID=aaaaaaaa-bbbb-4ccc-dddd-eeeeeeeeeeee:cryptolvm root=/dev/mapper/vgroup-root ip=:::::eth1:dhcp"
```

I have IP address statically allocated on my router, so I used DHCP. You can also use static IP (for `eth0`):
`ip=192.168.1.2:::::eth0:none` or static IP with gateway and netmask specified: `ip=192.168.1.2::192.168.1.1:255.255.255.0::eth0:none`

With `ip` parameter configured we can build GRUB configuration with `grub-mkconfig -o /boot/grub/grub.cfg`.

You can now reboot your machine and ssh to it (using `root` account) to unlock it.

You can get a host key verification failure, because server keys of TinySSH and OpenSSH differ and have different fingerprints. Some people advise to disable host verification or configure SSH to use `/dev/null` for this particular host — however, this is a bad idea. The better solution is to set up a separate `known_hosts` file location. To do that, use something like this in your SSH config:

```
Host remote-host-tinyssh
  HostName remote-host.example.com
  User root
  UserKnownHostsFile /home/user/.ssh/known_hosts.tinyssh
```

This configuration gives you an easy way to remotely unlock your machine.
