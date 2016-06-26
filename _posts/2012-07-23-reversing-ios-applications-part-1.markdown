---
layout: post
title: "Reversing iOS Applications (Part 1)"
date: 2012-07-23 21:23:00
---

Recently I acquired a 4th gen iPod Touch for reversing so before tackling something seemingly-impossible I thought I’d start with reversing an application.  In this post I’m going to focus on what I thought would be super easy; loading an application into IDA Pro.   The app I chose to play with is Kik (http://www.kik.com/), mostly because it looked interesting and I’d never used it before.

I’m pretty new to reversing iOS (spent way more time on OS X) and up until now had done very little reading about the security features implemented.  So for some all of what I’m about to say may seem obvious, but for us people new to iOS it’s probably pretty helpful.

Figure 1: Opening Kik in IDA Pro

Since our goal is to get a reverse-able app into IDA Pro the first step is to acquire the binary.  Originally, being super naive, I just downloaded the app in iTunes and opened up IDA Pro.  Well, that didn’t work so well.  Looking at Figure 1 you’ll see that the code produced by IDA is so clearly wrong that we know we need to take a different approach.  Not only this, but when opening IDA will tell you the file is encrypted and it’s output is probably going to be useless.

Alright, so it turns out Apple has decided to encrypt the binary. I didn’t read much about the encryption they use, but apparently it is some variant of FairPlay.  In reality though, since I have a handy-dandy jailbroken iPod Touch sitting right here, it doesn’t matter.  Apple was kind enough to give us a nicely working copy of GDB and Cydia was kind enough to give us access to the device over SSH.  Note that the version of GDB available in Cydia is busted, for instructions on how to get it installed check out http://pod2g-ios.blogspot.ca/2012/02/working-gnu-debugger-on-ios-43.html.  Another super useful utility is otool, available through Cydia.

At this point we will start by statically analyzing the Kik binary a bit.  First, let’s use otool to see what architectures are in the binary (remember Mach-O can what is known as a “fat binary”).

~~~
lux0r:/private/var/mobile/Applications/90E2C7FC-AD60-4F6B-940D-1EC8CC198560/Kik.app root# otool -arch all -Vh Kik
Kik (architecture armv6):
Mach header
      magic cputype cpusubtype  caps    filetype ncmds sizeofcmds      flags
   MH_MAGIC     ARM         V6  0x00     EXECUTE    32       3652   NOUNDEFS DYLDLINK TWOLEVEL
Kik (architecture cputype (12) cpusubtype (9)):
Mach header
      magic cputype cpusubtype  caps    filetype ncmds sizeofcmds      flags
   MH_MAGIC     ARM          9  0x00     EXECUTE    32       3652   NOUNDEFS DYLDLINK TWOLEVEL
~~~

Here we see that there are two binaries included in this fat binary: one for ARMv6, and one for ARMv7.  We’re interested in the ARMv7 stuff, but the Kik developers have apparently also included support for older devices.

Next we need to figure out what is actually encrypted in the binary.  For a full discussion on the Mach-O format check out Apple’s article, but basically the file is made up of three parts: a header, a list of load commands, and then the data.  To find out what part of the binary is encrypted we can use otool to print out the load commands and look at the `LC_ENCRYPTION_INFO` entry.

~~~
lux0r:/private/var/mobile/Applications/90E2C7FC-AD60-4F6B-940D-1EC8CC198560/Kik.app root# otool -arch all -Vl Kik | grep -A5 LC_ENCRYP
...
          cmd LC_ENCRYPTION_INFO
      cmdsize 20
 cryptoff  4096
 cryptsize 724992
 cryptid   1
...

This entry is telling us a couple of important pieces of information.  First, the cryptoff field is telling us that the first byte of encrypted data is 4096 bytes into the file.  Second, the cryptsize field is telling us that 724992 bytes of the file (starting at cryptoff) are encrypted.  And third, cryptid is telling us that the file is encrypted (we’ll come back to this shortly).
~~~

So now we know what portion of the binary is encrypted, how do we decrypt it?

As I said earlier, I didn’t look much into what encryption is used because it really doesn’t matter.  The wonderful thing about computers is that in order for something meaningful to occur the CPU must receive unencrypted instructions so all we need to do is let the iPod do it’s thing and dump the instructions.  This decryption occurs during the load phase so once the binary is mapped into memory it has been decrypted.  Therefore we can just use GDB to dump the memory to a file and patch the binary accordingly.

In order to dump the memory we first need to know what address range we should be grabbing.  Since we know that the encryption starts 4096 bytes into the file we just need to figure out where that is in memory and then work from there.  We can find this out by inspecting a couple other load commands present in the binary.

~~~
lux0r:/private/var/mobile/Applications/90E2C7FC-AD60-4F6B-940D-1EC8CC198560/Kik.app root# otool -arch all -Vl Kik
...
Kik (architecture cputype (12) cpusubtype (9)):
Load command 0
      cmd LC_SEGMENT
  cmdsize 56
  segname __PAGEZERO
   vmaddr 0x00000000
   vmsize 0x00001000
  fileoff 0
 filesize 0
  maxprot ---
 initprot ---
   nsects 0
    flags (none)
Load command 1
      cmd LC_SEGMENT
  cmdsize 464
  segname __TEXT
   vmaddr 0x00001000
   vmsize 0x000b2000
  fileoff 0
 filesize 729088
  maxprot r-x
 initprot r-x
   nsects 6
    flags (none)
...
~~~

So we see in the `LC_SEGMENT` for the `_TEXT` segment file offset 0 (the start of the file) is mapped to virtual address 0x1000.  For the curious if you look the command for `_PAGEZERO` you’ll see why `_TEXT` starts where it does.

Alright, this is great! We now know that the beginning of the file is mapped to 0x1000 and that decrypted data we’re after is starting at 0x2000 (remember it was 4096 bytes into the file).  Now comes the easy part, fire up GDB and dump the memory!

~~~
lux0r:/private/var/mobile/Applications/90E2C7FC-AD60-4F6B-940D-1EC8CC198560/Kik.app root# gdb -quiet ./Kik
Reading symbols for shared libraries .. done
(gdb) b UIApplicationMain
Function "UIApplicationMain" not defined.
Make breakpoint pending on future shared library load? (y or [n]) y
Breakpoint 1 (UIApplicationMain) pending.
(gdb) r
Starting program: /private/var/mobile/Applications/90E2C7FC-AD60-4F6B-940D-1EC8CC198560/Kik.app/Kik 
Removing symbols for unused shared libraries . done
Reading symbols for shared libraries ...+................................................................................................................................................ done
Breakpoint 1 at 0x31d348a6
Pending breakpoint 1 - "UIApplicationMain" resolved

Breakpoint 1, 0x31d348a6 in UIApplicationMain ()
(gdb) dump binary memory mem_dump.kik 0x2000 (0x2000 + 724992)
(gdb) q
The program is running.  Exit anyway? (y or n) y
~~~

BAM! We got our data in a file named `mem_dump.kik`, score! Now just copy it over to your desktop machine and we’re almost there! While you’re at it, it’s a good idea to copy over the Kik binary too so we can patch it.

To make our lives easier, we’ll extract the ARMv7 binary from within the universal Kik binary.  This is pretty simple, use lipo.

~~~
dean@BigBertha:~/Reversing/Apps/Kik_iOS $ lipo -thin armv7 -output patched_kik Kik_Fat 
dean@BigBertha:~/Reversing/Apps/Kik_iOS $ otool -arch all -Vh patched_kik 
patched_kik:
Mach header
      magic cputype cpusubtype  caps    filetype ncmds sizeofcmds      flags
   MH_MAGIC     ARM         V7  0x00     EXECUTE    32       3652   NOUNDEFS DYLDLINK TWOLEVEL
~~~

Let’s now just see what happens when we use class-dump on this unpatched binary.

~~~
dean@BigBertha:~/Reversing/Apps/Kik_iOS $ class-dump patched_kik 
/*
 *     Generated by class-dump 3.3.4 (64 bit).
 *
 *     class-dump is Copyright (C) 1997-1998, 2000-2001, 2004-2011 by Steve Nygard.
 */

#pragma mark -

/*
 * File: patched_kik
 * UUID: F88022A0-B96C-305F-9BDC-9D7FC2D2C76C
 * Arch: arm v7 (armv7)
 *
 *       Objective-C Garbage Collection: Unsupported
 *       This file is encrypted:
 *           cryptid: 0x00000001, cryptoff: 0x00001000, cryptsize: 0x000b1000
 */
~~~

Well, that’s not very helpful! Time to patch this thing.

To patch the file we need to do two things.  First we need to copy the decrypted data into the binary and, second, we need to disable the encryption load command.  Copying the data over can be done quite simply enough with the dd shell command.

~~~
dean@BigBertha:~/Reversing/Apps/Kik_iOS $ dd bs=1 seek=4096 conv=notrunc if=mem_dump.kik of=patched_kik 
724992+0 records in
724992+0 records out
724992 bytes transferred in 1.340430 secs (540865 bytes/sec)

Disabling the encryption load command is a little more involved, but still pretty easy.  All we need to do is set the cryptid field to 0x0.  This can be done using you’re favourite hex editor.  To find the address you can either use otool or, as I did, use a fun little tool called MachOView.
~~~

Figure 2: Patched Kik binary opened in MachOView

In Figure 2 you can see that the offset to the cryptid field is 0x848, so just go ahead and set that to 0x0.  Next, try class-dump again.

~~~
dean@BigBertha:~/Reversing/Apps/Kik_iOS $ class-dump patched_kik
/*
 *     Generated by class-dump 3.3.4 (64 bit).
 *
 *     class-dump is Copyright (C) 1997-1998, 2000-2001, 2004-2011 by Steve Nygard.
 */

#pragma mark Named Structures

struct CGAffineTransform {
    float _field1;
    float _field2;
    float _field3;
    float _field4;
    float _field5;
    float _field6;
};

struct CGPoint {
    float x;
    float y;
};
...
~~~

The output from class-dump should go on for a really long time; it turns out Kik is pretty huge!  Finally, we feel pretty confident in our efforts and it’s time to try opening in IDA.  When loading the binary make sure you switch the processor to ARM (it defaults to x86).

Figure 3: Patched Kik binary opened in IDA Pro

There you have it folks, Figure 3 is the patched (and decrypted) Kik binary opened up in IDA Pro ready to be reversed.

In my next post I’ll dive more into this app, as said in the beginning I’m most curious about how it’s network stuff is done.

