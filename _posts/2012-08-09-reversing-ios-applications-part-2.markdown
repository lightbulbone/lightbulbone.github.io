---
layout: post
title: "Reversing iOS Applications (Part 2)"
date: 2012-08-09 20:59:53
---

In the first post of this series we talked about how to get an app from the App Store into a reversable state.  Essentially we had to run the app inside a debugger and dump the contents of memory to a file which was then used to patch the original (encrypted) binary.

After writing that post I started to work through Kik in IDA when I got a text message from a friend.  It then occurred to me, why bother with Kik when I can (in theory) target Apple’s iMessage service?  So I’ve swapped out Kik and replaced it with the default Messages app found on each and every iOS device.

With the new app selected I dutifully copied it from my iPod onto my machine and promptly ran `strings` expecting to see a bunch of jibberish returned.  To my surprise, there was human readable text!

~~~
[dean@simba MobileSMS]$ strings MobileSMS
...
message_guid
chat_identifier
IMDSpotlight
Unable to find a conversation for Message [%@] found row ID [%d] and group ID [%@]
No Message GUID in Spotlight URL [%@].  I have no idea what to show you.
Asked to _showSMSConversationAndMessageForSearchURL: [%@]
Asked to showConversationAndMessageForSearchURL: [%@]
MailAutosaveIdentifier
...

Well, that’s pretty cool! As you can see we clearly have readable strings containing various debug messages along with all the info required for Objective-C.  For the uninitiated (like myself), it turns out that the default apps shipping on iDevices are not encrypted.  I haven’t looked into why this is the case, but I suspect it has something to do with how code signing is implemented.  So we have an unencrypted app that when loaded into IDA doesn’t result in complaining what so ever.

Before digging deeper using IDA it is a good idea to see what libraries and frameworks this app uses.  As usual, this can be done using otool as follows.

[dean@simba MobileSMS]$ otool -VL MobileSMS
MobileSMS:
...
	/System/Library/PrivateFrameworks/IMCore.framework/Frameworks/IMDPersistence.framework/IMDPersistence (compatibility version 1.0.0, current version 800.0.0)
	time stamp 2 Wed Dec 31 16:00:02 1969
	/System/Library/PrivateFrameworks/ChatKit.framework/ChatKit (compatibility version 1.0.0, current version 1.0.0)
	time stamp 2 Wed Dec 31 16:00:02 1969
...
	/System/Library/PrivateFrameworks/Conference.framework/Conference (compatibility version 1.0.0, current version 1.0.0)
	time stamp 2 Wed Dec 31 16:00:02 1969
	/System/Library/PrivateFrameworks/IMCore.framework/IMCore (compatibility version 1.0.0, current version 800.0.0)
	time stamp 2 Wed Dec 31 16:00:02 1969
	/System/Library/PrivateFrameworks/FTClientServices.framework/FTClientServices (compatibility version 1.0.0, current version 800.0.0)
	time stamp 2 Wed Dec 31 16:00:02 1969
...
~~~

Among the usual suspects there are a few interestingly named frameworks linked.  The one that caught my eye the most was ChatKit.  When I looked at Messages in IDA I also found what seemed like an unusually high number of references to ChatKit as well and after a bit of digging I started to suspect that ChatKit is actually the framework that is responsible for sending/receiving messages.  With that suspicion let’s dig a little into ChatKit.

Once again, I dutifully got the path to ChatKit from `otool` and went to copy it to my machine.

~~~
lux0r:~ root# scp /System/Library/PrivateFrameworks/ChatKit.framework/ChatKit dean@192.168.1.11:~/
Password:
/System/Library/PrivateFrameworks/ChatKit.framework/ChatKit: No such file or directory
~~~

No such file or directory? What the heck? Upon convincing myself that I do indeed have the correct path I was pretty stumped.  Otool clearly states that MobileSMS (the Messages app) links against this framework and IDA shows me the exact same information.  Even some of the debug strings gathered earlier reference it!  Needless to say this definitely ticked me off.  All I wanted to do was disassemble and inspect ChatKit in peace, but iOS wasn’t having any of that.

Stay tuned for the next instalment of this series where we solve the case of the missing ChatKit!

