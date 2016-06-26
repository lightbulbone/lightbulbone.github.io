---
layout: post
title: "I Spy ChatKit!"
date: 2012-09-08 22:14:00
---

In the last post I talked about starting to investigate MobileSMS (Messages app on iOS) and concluded with the mystery of the missing ChatKit.  I’m pleased to say that ChatKit wasn’t missing, it’s just hiding!

Admittedly I spent way to much time staring at the ChatKit.framework folder wondering where that stupid binary went.  Everything I’d read (mainly otool and IDA) told me this framework was being loaded but it wasn’t anywhere to be found on the file system.  I even went as far as writing a little script that identified every binary on the device that linked to this framework—it had to be somewhere.  Needless to say, I was pretty confused.

Well, onward and upward! If you run MobileSMS under GDB and have a peak at the loaded libraries you will indeed see that ChatKit is there with an address and everything.

~~~
lux0r:/Applications/MobileSMS.app root# gdb ./MobileSMS 
...
(gdb) b UIApplicationMain
Function "UIApplicationMain" not defined.
Make breakpoint pending on future shared library load? (y or [n]) y
Breakpoint 1 (UIApplicationMain) pending.
(gdb) r
...
Breakpoint 1, 0x31f988a6 in UIApplicationMain ()
(gdb) info sharedlibrary
...
Num Basename                Type Address         Reason | | Source     
  | |                          | |                    | | | |          
  1 dyld                       - 0x2fe00000        dyld Y Y /usr/lib/dyld at 0x2fe00000 (offset 0x0) with prefix "__dyld_"
  2 MobileSMS                  - 0x1000            exec Y Y /private/var/stash/Applications/MobileSMS.app/MobileSMS (offset 0x0)
  3 Foundation                 F 0x37dff000        dyld Y Y /System/Library/Frameworks/Foundation.framework/Foundation at 0x37dff000 (offset 0x48b000)
                                               (objfile is) [memory object "/System/Library/Frameworks/Foundation.framework/Foundation" at 0x37dff000]
  4 UIKit                      F 0x31f67000        dyld Y Y /System/Library/Frameworks/UIKit.framework/UIKit at 0x31f67000 (offset 0x48b000)
                                               (objfile is) [memory object "/System/Library/Frameworks/UIKit.framework/UIKit" at 0x31f67000]
  5 IMDPersistence             F 0x377c2000        dyld Y Y /System/Library/PrivateFrameworks/IMCore.framework/Frameworks/IMDPersistence.framework/IMDPersistence at 0x377c2000 (offset 0x48b000)
                                               (objfile is) [memory object "/System/Library/PrivateFrameworks/IMCore.framework/Frameworks/IMDPersistence.framework/IMDPersistence" at 0x377c2000]
  6 AddressBook                F 0x36aa5000        dyld Y Y /System/Library/Frameworks/AddressBook.framework/AddressBook at 0x36aa5000 (offset 0x48b000)
                                               (objfile is) [memory object "/System/Library/Frameworks/AddressBook.framework/AddressBook" at 0x36aa5000]
  7 AddressBookUI              F 0x365e2000        dyld Y Y /System/Library/Frameworks/AddressBookUI.framework/AddressBookUI at 0x365e2000 (offset 0x48b000)
                                               (objfile is) [memory object "/System/Library/Frameworks/AddressBookUI.framework/AddressBookUI" at 0x365e2000]
  8 ChatKit                    F 0x32d3a000        dyld Y Y /System/Library/PrivateFrameworks/ChatKit.framework/ChatKit at 0x32d3a000 (offset 0x48b000)
                                               (objfile is) [memory object "/System/Library/PrivateFrameworks/ChatKit.framework/ChatKit" at 0x32d3a000]
...
~~~

And if you have a peak at the address listed (0x32d3a000) you’ll even find a valid Mach-O header.

~~~
(gdb) x /7w 0x32d3a000
0x32d3a000:	0xfeedface	0x0000000c	0x00000009	0x00000006
0x32d3a010:	0x00000030	0x0000160c	0x801000b5
~~~

This thing was definitely coming from somewhere and it wasn’t the “normal” place in the file system.

After digging through the various plist files hoping to find a clue and running my script to find binaries linking against ChatKit many times I decided it was time to try and catch the loader in the act.  Once again in GDB load up MobileSMS but this time before starting the program set a breakpoint on `dlopen()`; the function responsible for opening dynamic libraries.

Now run the program and watch the first parameter to `dlopen()`.  A quick way to do this is to attach a command in GDB to the breakpoint.

~~~
lux0r:/Applications/MobileSMS.app root# gdb -q ./MobileSMS 
Reading symbols for shared libraries . done
(gdb) b dlopen
Function "dlopen" not defined.
Make breakpoint pending on future shared library load? (y or [n]) y
Breakpoint 1 (dlopen) pending.
(gdb) command 1
Type commands for when breakpoint 1 is hit, one per line.
End with a line saying just "end".
>x /s $r0
>end
~~~

This will cause GDB to interpret the value in register R0 (first parameter of a function) as a pointer to string and print the corresponding string.  Continue along until you see the path to ChatKit printed out.  This is great! The framework is loaded, but seriously where is this thing is coming from?  While I previously knew about the existence of the dlopen() function I’ve never really used it myself so I didn’t know much about the second parameter or how it works.

Well, it turns out the second parameter to dlopen() is used to tell it how to proceed.  Generally speaking, the second parameter of dlopen() is used to convey whether or not to use lazy binding and how symbols from the library should be exported.  It turns out that dlopen() can also double as a mechanism to check if a library has been loaded and, if so, get a handle to it (check out the man page).  You do this by specifying RTLD_NOLOAD.

So, back in our GDB session print out that second parameter (value in R1) passed to dlopen() for ChatKit.

~~~
Breakpoint 1, 0x3162957c in dlopen ()
0x32ca67c4:	 "/System/Library/PrivateFrameworks/ChatKit.framework/ChatKit"
(gdb) p /x $r1
$1 = 0x10
~~~

Alright, we have 0x10… great! What’s that mean?  Time to go source diving! From the man page for dlopen() we know the names given to the values we can pass in.  So it follows that some combination of those values should equate to 0x10.  And surely enough that is true.

First, head on over to [Apple's Open Source page](opensource.apple.com) and grab the latest version of the dyld package.  Note that while that link is to the packages for Mac OS 10.8 the implementations used in iOS are very similar (if not the same). Once you’ve got that unpacked, do a search for one of the symbols listed in the dlopen() man page (I chose `RTLD_LAZY`).

~~~
[dean@simba dyld-210.2.3]$ grep -rn RTLD_LAZY . | grep -v unit
...
./include/dlfcn.h:65:#define RTLD_LAZY	0x1
...
~~~

So we know the symbols accepted by dlopen() are listed in dlfcn.h which isn’t that surprising since that is the file you need to include for dlopen().

~~~
#if !defined(_POSIX_C_SOURCE) || defined(_DARWIN_C_SOURCE)
#define RTLD_NOLOAD     0x10
#define RTLD_NODELETE   0x80
#define RTLD_FIRST      0x100   /* Mac OS X 10.5 and later */

/*
 * Special handle arguments for dlsym().
 */
#define RTLD_NEXT       ((void *) -1)   /* Search subsequent objects. */
#define RTLD_DEFAULT    ((void *) -2)   /* Use default search algorithm. */
#define RTLD_SELF       ((void *) -3)   /* Search this and subsequent objects (Mac OS X 10.5 and later) */
#define RTLD_MAIN_ONLY  ((void *) -5)   /* Search main executable only (Mac OS X 10.5 and later) */
#endif /* not POSIX */
~~~

This chunk of code is only available in non-POSIX environments, which MobileSMS is! So here we see that the value 0x10 equates to the symbol `RTLD_NOLOAD`.  Which the man page says means:

~~~
RTLD_NOLOAD   —  The specified image is not loaded.  However, a valid handle is returned if the image already exists in the process. This provides a way to query if an image is already loaded.  The handle returned is ref-counted, so you eventually need a corresponding call to dlclose()
~~~

Alright, we know for a fact that MobileSMS is not actually loading ChatKit, it’s just checking to make sure it already has been loaded!

To solve this mystery of the missing ChatKit we need to consult the implementation of dlopen() which can be found in the dyld source. Rather than walking through the entire dyld codebase I’ll highlight the important parts.

When we call dlopen() using `RTLD_NOLOAD` the loader will essentially just verify that the specified image has been loaded and, if so, return a handle to it.  To do this dyld goes through a series of phases and at each one checks to see if some permutation of the given path name exists.  Eventually it gets to the point where it will decide the specified path must be part of the dyld cache.

The dyld cache is present on iOS and contains a variety of images in it.  You can find it at /System/Library/Caches/com.apple.dyld/dyld_shared_cache_armv7 on your device.  The cache is loaded early on in the initialization of dyld.

To verify that ChatKit was in this cache I opened it up in an awesome program called Synalyze It and created a smaller grammar to parse it.  You can see this in the screenshot above.

So there we have it folks! The ChatKit wasn’t missing after all, it was just being loaded from the cache rather than through the filesystem.

