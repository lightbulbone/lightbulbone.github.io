---
layout: post
title: "IDA Processor Options - Oops."
date: 2014-07-21 15:58:33
---

So I've been working through the LLB code that I talked about in my last article and kept running into incorrectly decoded instructions.  I knew they were wrong because (A) the output IDA was giving made no sense and (B) I manually decoded some of them myself to check it.

The problem? I forgot to set the processor options when loading the LLB binary.

So, take my mistake as a learning experience.  When loading your binary, be sure to set your processor type.

![IDA Pro Load File Dialog](/content/images/2014/Jul/Load_IDA-phg.png)

And then, the important part, set the processor options.  In this case the default architecture selected by the ARM processor module was not inline with the architecture used by the LLB code.  For LLB, be sure to select **ARMv7-AR**.

![ARM Processor Options](/content/images/2014/Jul/ARM_Options.png)

Live and learn,

[@lightbulbone](https://twitter.com/lightbulbone)

