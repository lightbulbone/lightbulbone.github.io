---
layout: post
title: "Remote debugging with LLDB"
date: 2013-01-08 19:32:54
---

The other day I was working on a project in Xcode and was getting fed up with it crashing and just not behaving.  So I set out on a mission to figure out how to remote debug an iOS app.  The secret to it all is LLDB, the LLVM Debugger.  LLDB is now the default debugger in Xcode (has been for awhile) and is a pretty powerful debugger complete with scripting in Python and many other hidden gems.

To follow along you will need:

- A jailbroken iDevice setup for development
- Developer Tools (from Xcode) installed on a Mac

At a high-level this approach works by running a little server on the iDevice and then connecting remotely from your Mac.  To begin, SSH into your iDevice and find some program of interest (such as an iOS app you may be developing).  Then start the debug server on your iDevice.

~~~
iPhone:/Applications/FieldTest.app root# /Developer/usr/bin/debugserver localhost:12345 ./FieldTest
debugserver-189 for armv7.
Listening to port 12345...
~~~

Now on your Mac, we launch LLDB and then connect to the remote session.

~~~
[dean@simba ~]$ lldb
(lldb) platform select remote-ios
  Platform: remote-ios
 Connected: no
  SDK Path: "/Users/dean/Library/Developer/Xcode/iOS DeviceSupport/6.0.1 (10A523)"
 SDK Roots: [ 0] "/Users/dean/Library/Developer/Xcode/iOS DeviceSupport/5.1.1 (9B206)"
 SDK Roots: [ 1] "/Users/dean/Library/Developer/Xcode/iOS DeviceSupport/6.0.1 (10A523)"
(lldb) process connect connect://192.168.1.20:12345
Process 2237 stopped
* thread #1: tid = 0x1603, 0x2fe7a028 dyld`_dyld_start, stop reason = signal SIGSTOP
    frame #0: 0x2fe7a028 dyld`_dyld_start
dyld`_dyld_start:
-> 0x2fe7a028:  mov    r8, sp
   0x2fe7a02c:  sub    sp, sp, #16
   0x2fe7a030:  bic    sp, sp, #7
   0x2fe7a034:  ldr    r3, [pc, #112]            ; _dyld_start + 132
(lldb)
~~~

At this point you know have a remote connection to the process being debugged and can use LLDB as you would normally.  Note that this is the exact same way Xcode connects to an app being debugged so anything you can do in Xcode should be possible here.

Enjoy and happy hacking!

