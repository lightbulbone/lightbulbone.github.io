---
layout: post
title: "Rails - Hex Rays Plugin Contest 2012"
date: 2012-09-14 14:25:42
---

This year I decided to try submitting to the annual Hex Rays plugin contest.  I’m pleased to announce my plugin, Rails.

Rails is a plugin that simplifies the task of working with multiple instances of IDA Pro.  There are three main advantages to Rails.  First, you won’t go insane trying to work with several instances at once.  Second, your project databases remain uncluttered from the addition of linked libraries and other bits of code.  And third, you don’t need to continuously reverse the same libraries over and over again.

The plugin is pretty straight forward to use.  Once you’ve opened up a database, just go to Edit->Plugins->Rails and enable it.  This will cause a new panel to appear in IDA which lists any other open instances of IDA that are using Rails as well as output from Rails.  With it you can select a function and then see the associated comments or jump to its definition where ever that may be.  Another handy feature is the ability to see the list of open instances and just jump to them by double clicking there name in the list.  For a demo check out the video below.

If you’d like to work with the code it is available on Github at

https://github.com/lightbulbone/rails

.  Note that the plugin currently only builds on Mac OS X; however, I will (very soon) make a build script for Windows.

