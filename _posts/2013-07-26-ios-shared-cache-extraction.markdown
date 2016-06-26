---
layout: post
title: "iOS Shared Cache Extraction"
date: 2013-07-26 14:27:00
---

Having fallen off the iOS-exploration train due to completing my  Masters and other commitments, I have finally climbed back aboard in pursuit of understanding the telephony stack.

Like most things in iOS that are used frequently, the vast majority of the frameworks and libraries used in the telephony stack reside in the dyld shared cache located at `/System/Library/Caches/com.apple.dyld/dyld_shared_cache_armv7`.

In this post I am going to explain how to go about extracting this cache file so that you can then work with each library individually.

### Get The Cache

The first step in all of this is to copy the cache over to your local machine.  I did this using a program called iExplorer, but you can just as easily do it over SSH.  As a side note, you can connect to your iDevice using SSH over USB if you install a tool called iProxy.

### Building `dsc_extractor`

The easiest way I found to extract the cache is to use a program provided by Apple called `dsc_extractor`.  You can get the source for `dsc_extractor` by downloading the dyld package from Apples open source page at: http://opensource.apple.com/.

After downloading the package, unarchive it then go to the `launch-cache` subdirectory.

~~~
[dean@zippy tmp]$ tar -xvzf dyld-210.2.3.tar.gz
[dean@zippy tmp]$ cd dyld-210.2.3/launch-cache/
~~~

At this point we need to apply a patch to the `dsc_extractor` code so that it can be compiled and function properly.  The patch to be applied is available on GitHub at https://gist.github.com/lightbulbone/6092321.

The patch can be applied using the `patch` command; once patched `dsc_extractor` can then be compiled.

~~~
[dean@zippy launch-cache]$ patch < dsc_extractor.patch
[dean@zippy launch-cache]$ clang++ -o dsc_extractor dsc_extractor.cpp dsc_iterator.cpp
~~~

You should now have a working copy of `dsc_extractor`.

### Extracting The Cache

The last step is pretty simple.  All you need to do is run `dsc_extractor`.

~~~
[dean@zippy com.apple.dyld]$ dsc_extractor dyld_shared_cache_armv7 armv7/
~~~

If you then look inside the `armv7/` folder you’ll find all the extracted libraries used on iOS.

As a quick side note, you can also open the cache file directly in IDA Pro.  I found this be a bit cumbersome although you may have better luck.

Until next time, happy hacking!

