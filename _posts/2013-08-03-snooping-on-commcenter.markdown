---
layout: post
title: "Snooping on CommCenter"
date: 2013-08-03 11:13:59
---

CommCenter is a wonderful part of iOS since it is the single point that is responsible for communication between iOS and the baseband.  And with the baseband being responsible for controlling the telephony components I wanted to see what CommCenter was telling it.

To do this all you need to do is create a dynamic library with a few functions then shove that in between CommCenter and the baseband.  Easy, eh?

Before I begin I should note that I did this using an iPhone 4 running iOS 6.1 (jailbroken) and that on newer iPhones the process is slightly different.

All code is available on [GitHub](https://github.com/lightbulbone/ios).

### Creating The Library

To intercept the communication between CommCenter and the baseband what you need to do is replace the implementations of `open()`, `close()`, `read()`, and `write()`.  You can see how to do this in the file `ccsnoop.c`, but really the trick is to stick a map between your implementations and the original in a special section called `_interpose` in the `__DATA` section.

All that’s necessary now is to compile the code into a dynamic library (see `ccsnoop.c` for instructions).

### Loading The Library

In order to have the library loaded by CommCenter we first need to alter its plist to include the `DYLD_INSERT_LIBRARIES` environment variable.

~~~
<key>EnvironmentVariables</key>
<dict>
     <key>DYLD_INSERT_LIBRARIES</key>
     <string>/tmp/ccsnoop.dylib</string>
</dict>
~~~

The library should be located at `/tmp/ccsnoop.dylib`; a complete plist can be found on GitHub.

As previously mentioned, the key here is the usage of `DYLD_INSERT_LIBRARIES` which forces any specified libraries to be loaded before any libraries specified by CommCenter.  When this is combined with the interposition used in the library we are able to override the default implementations of the desired functions.

With both the dynamic library and the modified plist we can then restart CommCenter and watch our log file for anything of interest.  To restart CommCenter you can just run the `injectCommCenter.sh` script which essentially just uses `launchctl` to unload and load it.

### A Note About CommCenter

Beginning in iOS 6 (or earlier, I’m not entirely sure) Apple has created two versions of CommCenter: CommCenterClassic, and CommCenter.  Which is used depends on the hardware you are using.  For example, an iPhone 4 will use CommCenterClassic while an iPhone 5 will use CommCenter.  At this point it’s unclear to me what the difference is between the two; however, I have heard that newer devices use a different protocol to communicate with the baseband.

Until next time, happy hacking!

@lightbulbone

