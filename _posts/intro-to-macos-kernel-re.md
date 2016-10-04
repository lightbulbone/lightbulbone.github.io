---
layout: post
title: "Introduction to macOS Kernel Debugging"
date: 2016-10-04 09:00:00
---

In macOS there is a kernel module named "Don't Steal Mac OS X" (DSMOS) which registers a function with the Mach-O loader to unpack binaries that have the `SG_PROTECTED_VERSION_1` flag set on their `__TEXT` segment. Finder, Dock, and loginwindow are a few examples of binaries that have this flag set.  As it turns out, this kernel module at one point [played a role in the myth](http://osxbook.com/book/bonus/chapter7/tpmdrmmyth/) that Apple had included a TPM in their Mac hardware.

I started reversing this kernel module because I was getting frustrated trying to reverse parts of the iOS kernel.  It occurred to me that I was trying to run before walking so it was time to slow down a little.  With that in mind, this post provides an introduction to kernel debugging.  My next post will expand on this and go through reversing the DSMOS kernel module.


## Kernel Debug Kits

Before we jump in, lets first cover why I switched to macOS when getting frustrated with iOS.  The reason is pretty straight forward: macOS and iOS are built from nearly-identical kernel (XNU) source.  In fact all of Apple's operating systems are.

The big advantage to starting with macOS is that Apple provides what are known as **Kernel Debug Kits (KDKs)**.  A KDK provides you with Development and Debug builds of the kernel as well as some useful lldb scripts to help with debugging.  One thing you may be wondering is what is the difference between the Debug and Development builds of the kernel? The short answer, as I understand it, is that the Development kernel is essentially the Release kernel with symbols while the Debug kernel has symbols as well as additional assertions/checks enabled.  For this foray into kernel reversing I used the Development kernel.

KDKs are provided by Apple and you can download them from [https://developer.apple.com/download/more/](https://developer.apple.com/download/more/).  When selecting a KDK be sure to choose the one with a kernel version that matches your target machine.  I highly recommend reading the documentation provided with the KDK and will assume you have.


## Configuring the Kernel Debugger

Unlike debugging an application, to debug the kernel you need to use two machines: the target and the host.  The host is where you'll be running lldb and doing all your work.  The target is the machine that is running the Development kernel and you will be debugging.  For the sake of efficacy, my host is an iMac (Late 2015) running macOS 10.12 (build 16A323) and my target is a Macbook Air (Mid 2011) running macOS 10.12 Beta (16A286aa).

A word on the target machine: it **does not** need to be physical hardware.  You can use a virtual machine.  The big difference is that on physical hardware you can easily trigger the kernel debugger using the NMI keys (more on this shortly).  There might be a way to do this in a virtual machine but I had hardware so didn't bother to figure it out.

When you install the KDK on your target machine one of the steps is to set `boot-args` in nvram.  Mine are set as follows:

```
airy:~ dean$ nvram boot-args
boot-args       debug=0x14e kcsuffix=development kext-dev-mode=1 kdp_match_name=en4 -v
```

Lets take a moment and go through each of these flags.

- `kcsuffix` simply instructs the boot loader which kernel it should look for.  In my case I used the Development kernel so `kcsuffix` should be set to `development`.
- `kext-dev-mode` causes kernel module signing requirements to be relaxed.
- `-v` enables verbose mode during boot.

The remaining two variables, `kdp_match_name` and `debug`, warrant a bit more discussion than a bullet point.

#### `kdp_name_match`

Remote kernel debugging, which we are going to do, requires either Ethernet or FireWire.  It does *not* work over WiFi or USB. This obviously begs the question of how one would go about remote debugging with a laptop that has no Ethernet port.  Thankfully, Apple has thought this through and the answer is the `kdp_match_name` `boot-args` variable coupled with a Thunderbolt-to-Ethernet adapter.  You can also use an Apple Cinema display if you have one of those.

The `kdp_match_name` variable instructs the kernel to bind the remote debugger to the specified interface.  You can find the interface name using `ifconfig` and checking which interface has the desired IP assigned.  You also need to use `kdp_match_name` if your Mac has multiple Ethernet interfaces.

#### `debug`

The role played by the `debug` variable is to configure the kernel debugger.  It's value is an OR of the `DB_*` constants defined in `osfmk/kern/debug.h` of the XNU source.  Table 1 documents many of the interesting and not-so-interesting constants.

| Flag                    | Value     | Description               |
|-------------------------|-----------|---------------------------|
| `DB_HALT`               | 0x1       | Wait for debugger on boot |
| `DB_PRT`                | 0x2       | Send `printf()` output to the console |
| `DB_NMI`                | 0x4       | Activates the kernel debugging facility, including support for NMI  |
| `DB_KPRT`               | 0x8       | Send `kprintf()` output to remote console |
| `DB_KDB`                | 0x10      | Use KDB instead of GDB |
| `DB_SLOG`               | 0x20      | Enable logging system diagnostics to the system log |
| `DB_ARP`                | 0x40      | Allows the kernel debugger nub to use ARP and thus support debugging across subnets. |
| `DB_KDP_BP_DIS`         | 0x80      | Deprecated, was used for old versions of GDB |
| `DB_LOG_PI_SCRN`        | 0x100     | Disable the graphical panic screen. |
| `DB_KDP_GETC_ENA`       | 0x200     | Prompt to enter KDB upon panic |
| `DB_KERN_DUMP_ON_PANIC` | 0x400     | Trigger core dump on panic |
| `DB_KERN_DUMP_ON_NMI`   | 0x800     | Trigger core dump on NMI |
| `DB_DBG_POST_CORE`      | 0x1000    | Wait in debugger after NMI core |
| `DB_PANICLOG_DUMP`      | 0x2000    | Send paniclog on panic,not core |
| `DB_REBOOT_POST_CORE`   | 0x4000    | Attempt to reboot after post-panic crashdump/paniclog dump. |
| `DB_NMI_BTN_ENA`        |  0x8000   | Enable button to directly trigger NMI |
| `DB_PRT_KDEBUG`         |  0x10000  | kprintf KDEBUG traces |
| `DB_DISABLE_LOCAL_CORE` |  0x20000  | ignore local core dump support |

Table 1: Summary of constants to use in `debug` boot-args variable.

Some of the common values I've seen are: 0x141, 0x144, and 0x14e. Note that they all have `DB_LOG_PI_SCRN` and `DB_ARP` set.


## Using the Kernel Debugger

Using the remote kernel debugger essentially boils down to installing the target KDK on the host and then running lldb on the host.  You'll want to install the target KDK on the host so that lldb has access to the symbolicated kernel as well as some handy lldb scripts developed by Apple.  One thing to keep in mind about the remote debugger: it is not always waiting for connections.  Put differently, you can only connect to it at boot if you set `DB_HALT`, during a panic, or an NMI if you set `DB_NMI`.  Being able to trigger the debugger using the NMI keys (left command, right command, and power all at once) can be very handy if you want to drop into the debugger and inspect the running kernel.

Once you've set your `boot-args` on the target and restarted your machine you can start debugging.  Assuming you've set your `debug` variable to 0x14e once you're machine has restarted you can trigger the kernel using the NMI keys (left command, right command, power all at once).  When you hit the NMI keys the IP address of the target will be shown on the screen. On your host you can then connect as follows.

```
(lldb) kdp-remote <target-ip>
Version: Darwin Kernel Version 16.0.0: Fri Aug  5 19:25:15 PDT 2016; root:xnu-3789.1.24~6/DEVELOPMENT_X86_64; UUID=4F6F13D1-366B-3A79-AE9C-44484E7FAB18; stext=0xffffff8006000000
Kernel UUID: 4F6F13D1-366B-3A79-AE9C-44484E7FAB18
Load Address: 0xffffff8006000000
Loading kernel debugging from /Library/Developer/KDKs/KDK_10.12_16A286a.kdk/System/Library/Kernels/kernel.development.dSYM/Contents/Resources/DWARF/../Python/kernel.py
LLDB version lldb-360.1.50
settings set target.process.python-os-plugin-path "/Library/Developer/KDKs/KDK_10.12_16A286a.kdk/System/Library/Kernels/kernel.development.dSYM/Contents/Resources/DWARF/../Python/lldbmacros/core/operating_system.py"
Target arch: x86_64
Instantiating threads completely from saved state in memory.
settings set target.trap-handler-names hndl_allintrs hndl_alltraps trap_from_kernel hndl_double_fault hndl_machine_check _fleh_prefabt _ExceptionVectorsBase _ExceptionVectorsTable _fleh_undef _fleh_dataabt _fleh_irq _fleh_decirq _fleh_fiq_generic _fleh_dec
command script import "/Library/Developer/KDKs/KDK_10.12_16A286a.kdk/System/Library/Kernels/kernel.development.dSYM/Contents/Resources/DWARF/../Python/lldbmacros/xnu.py"
xnu debug macros loaded successfully. Run showlldbtypesummaries to enable type summaries.


Kernel slid 0x5e00000 in memory.
Loaded kernel file /Library/Developer/KDKs/KDK_10.12_16A286a.kdk/System/Library/Kernels/kernel.development
Loading 119 kext modules warning: Can't find binary/dSYM for com.apple.kec.corecrypto (700E1192-8CD6-3F61-ABE9-D27C2CC1F164)

/*-- removed for clarity --*/

. done.
Target arch: x86_64
Instantiating threads completely from saved state in memory.
kernel.development was compiled with optimization - stepping may behave oddly; variables may not be available.
Process 1 stopped
* thread #2: tid = 0x00b6, 0xffffff800639a3de kernel.development`Debugger [inlined] hw_atomic_sub(delt=1) at locks.c:1513, name = '0xffffff8011639cf0', queue = '0x0', stop reason = signal SIGSTOP
    frame #0: 0xffffff800639a3de kernel.development`Debugger [inlined] hw_atomic_sub(delt=1) at locks.c:1513 [opt]
(lldb)
```

At this point you can use lldb as you normally would.  You will also have a bunch of additional commands provided throught the KDK.  For example you can list all kexts like so:

```
(lldb) showallkexts 
OverflowError: long too big to convert
UUID                                 kmod_info            address              size                  id  refs TEXT exec            size     
                         version name                          
0490CEBA-045D-344E-AC8B-1449598798F6 0xffffff7f88fdf528   0xffffff7f88fdb000   0x5000               147     0 0xffffff7f88fdb000   0x5000   
                            1.70 com.apple.driver.AudioAUUC    
92511291-6B64-35B1-A824-53034DEBDD39 0xffffff7f88fdacb8   0xffffff7f88fd6000   0x5000               146     0 0xffffff7f88fd6000   0x5000   
                         1.9.5d0 com.apple.driver.AppleHWSensor
EDC33E0C-CAA2-3E79-951D-1FC392284B4D 0xffffff7f88fd5508   0xffffff7f88fcd000   0x9000               145     0 0xffffff7f88fcd000   0x9000   
                             3.0 com.apple.filesystems.autofs  
CCC57A89-31FE-3D9F-88A3-0EC7D254477B 0xffffff7f88fcb028   0xffffff7f88fc8000   0x5000               144     1 0xffffff7f88fc8000   0x5000   
                             1.0 com.apple.kext.triggers       
E6E68296-809B-3884-ADEF-E85831F4B106 0xffffff7f88fc7090   0xffffff7f88fbb000   0xd000               143     0 0xffffff7f88fbb000   0xd000   
                               1 com.apple.driver.pmtelemetry  
                           
/*-- removed for clarity --*/
```

To find all the commands available to lldb just type `help` at the prompt.  The KDK adds a lot of them rather than going through them in this post your better off taking the time to pick a few interesting ones and seeing what they do.

At this point, you should be able to setup remote kernel debugging in macOS and be able to inspect a running kernel.  In the next post I will put some of this to use and look at the DSMOS kernel module.



