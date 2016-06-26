---
layout: post
title: "Beginners Fun With iMessage"
date: 2012-08-01 21:00:00
---

A quick detour from my series on reversing iPhone applications, I’ve been looking at the Messages app and just found out that there are hidden settings!

The settings themselves are pretty fun (and super helpful) since they allow you to enable logging of iMessages.  You can access them from within the Settings app (under Messages). You don’t need a jailbroken device to activate these; however, I believe you need one in order to access the logs (haven’t confirmed this yet).  The logs are found at: `/private/var/mobile/Library/Logs/CrashReporter/iMessage`

If you want to try these out, all you need to do is install the configuration file below.  Installation is as simple as clicking the link and letting Safari do the rest!

iMessageDebug.mobileconfig

Lastly, note that similar configuration files exist for other applications that come with the device.

