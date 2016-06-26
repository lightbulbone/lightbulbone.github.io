---
layout: post
title: "From Zero To SDR"
date: 2015-07-19 12:55:46
---

**Heads Up: This post is not complete. While updating the blog platform it snuck out.**

Software Defined Radio, usually referred to as SDR, is something that has fascinated me for a couple years but was always out of reach due to available time and resources.  With devices on the market now like the AirSpy, HackRF, B200/B210, BladeRF, and RTL-SDR the barrier to entry has come down significantly in the last couple years.  Since my knowledge of SDR and radio in general was pretty much nothing I thought I'd start with a $20 [RTL-SDR from Hak5](http://hakshop.myshopify.com/collections/software-defined-radio/products/software-defined-radio-kit-rtl-sdr?variant=424034573).

Not really knowing where to start after plugging the RTL-SDR in for the first time I took a look at the [Software Defined Radio with HackRF](http://greatscottgadgets.com/sdr/) lessons created by Michael Ossman.  The lessons are actually quite good, they provide a great introduction to GNU Radio and some of the fundamentals of radio.

I also tried reading books.  I picked up [Understanding Digial Signal Processing](http://www.amazon.ca/Understanding-Digital-Signal-Processing-Edition/dp/0137027419) by Richard Lyons thinking that knowing a bit about DSP would be useful.  Pro tip: reading a DSP textbook is extremely dry.  Even for someone who has a strong background in mathematics.  What I wanted to just the practical side of it for now thinking that as I got more into radio and DSP I'd learn the background.

It was around this time, frustrated that most resources I was finding focused on the mathematics, I found an application called [GQRX](http://gqrx.dk). GQRX is great. It lets you explore the radio spectrum using whatever SDR you've got connected to your computer.  It is built on top of GNU Radio so it has excellent support for hardware and it also provides several demodulators.  Personally, I found exploring the spectrum to be the most fun way to get into things.  At first it was a fun way to look for FM signals that I can listen too. Doing this I found several local taxi services, the public transit systems, and a few hotels.  I also found a bunch of signals that were clearly not FM and my curiousity kicked into fully swing.

Staring at interesting looking ("pretty") signals didn't really pan out very well.  I knew nothing about the device producing the signal, I knew nothing about modulation and carrier signals, and, on top of all that, I didn't know the tools.  At the time pretty much all the buttons in GQRX and blocks in GNU Radio were pretty much foreign. If I wanted to get anywhere, all of this needed to change.

### Picking a Device

The easiest unknown to solve was know the device that produced a signal.  My solution to this was pretty straight forward: buy something.  After a bit of poking around, I settled on the BIOS 315BC (Figure 1) from a local drug store.  It was cheap, advertised wireless functionality, and I was able to find the FCC filings for it. A bonus is that the device has a button on the back of the remote sensor alloBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBwing you to force a transmission.

{% figure img:/assets/images/2015/07/LDBIOS315BC.jpg fnum:1 caption:"BIOS 315BC wireless thermometer." %}

Once I had the device, the first step was to figure out what frequency it transmits on.  The packaging didn't seem to reveal any clues so I looked up the FCC filings. At the time, the extent of my FCC ID searching was limited to [https://fccid.io/](https://fccid.io/) which yielded a result claiming the device operates on 433.92 MHz.  I should note that I never did find the FCC ID on the device itself, I just Googled for it and came up with XK3315TX.  Part of me suspects that FCC ID is from a slightly different model because there was no mention of it being capable of operating on three channels and when I actually started looking I found the device transmitted on 433.96 MHz. Regardless, we have a starting frequency to investigate in GQRX.

{% sidenote %}
This device operates in what is known as an <i>ISM Band</i>.  The ISM Band is a set of frequencies that are unlicensed for use in industrial, scientific, and medical applications.  There are 12 such bands defined by the ITU-R with another common one being the 2.4 GHz band where microwave ovens, cordless phones, Bluetooth, and WiFI operate.
{% endsidenote %}

### First Steps With GQRX

With the frequency from the FCC report it is time to have a look at the surrounding spectrum in GQRX.  As I said earlier, GQRX is a great tool for viewing the radio spectrum.  The primary display consists of an _FFT plot_ on top and a _waterfall plot_ at the bottom. The FFT---Fast Fourier Transform---plot shows the power level instantaneously at each frequency while the waterfall plot shows the same information over time.  On the side of GQRX is a variety of configuration parameters.  For this initial investigation I left them all at the defaults.

{% figure img:/assets/images/2015/07/GQRX43396FM.jpg fnum:2 caption:"Initial capture of transmission in GQRX." %}

Figure 2 shows a screen shot of GQRX that was taken during a transmission from the remote temperature sensor. The first thing to note is that I have actually tuned to 433.96 MHz instead of 433.92 Mhz.  I did this because at the time I took the screen shot I already knew the original 433.92 MHz is incorrect; perhaps it is due to the channel switch on the back of the remote sensor. When I first saw this result on the FFT I was pretty excited, it works! It's sending the temperature! But... how?  Knowing nothing about radio transmisssions other than if I tune my radio to 91.3 I get to hear different music than if it's set to 103.5, it was time to start learning.

### A Brief Detour Into Digital Modulation

We're now at the point where we need to start thinking about how the temperature is transmitted over a radio signal to the base station.  To do accomplish this task the remote sensor must encode the temperature data in the signal such that it can be recovered again by the base station; for this we must _modulate_ the _carrier wave_.  The carrier wave is simply a radio wave emitted at a sufficiently high frequency such that the encoded data can be retrieved while modulation is the technique used to encode the data in the carrier wave.

With respect to digital modulation there are three broad categories: amplitude shift keying (ASK), frequency shift keying (FSK), and phase shift keying (PSK).  The notion of "keying" is just that the data is transmitted in one of a finite number of symbols.  Rather than delving into each of ASK, FSK, and PSK here I highly recommend reading through the Wikipedia articles.

### Identifying the Modulation Type

So the question we really want to answer now is this: how is this signal modulated?

My first guess was that it was something known as BPSK, binary phase shift keying. Some reading had lead me to believe that BPSK is a pretty common type of modulation and that it can be used to efficiently transmit binary data.  However, the more I looked at the FFT and waterfall plot the less I was convinced (check out the [Signal Identifcation Wiki](http://www.sigidwiki.com/wiki/Signal_Identification_Guide) for many examples).  Another thing that came up was the difficulty in demodulating a BPSK signal, it turns out that receiving a BPSK signal is somewhat difficult and is just not something you'd find on a cheap mass-production thermometer.  A similar thought exercise lead to me ruling out various forms of FSK modulation as well.

So this leaves us with ASK.  One of the simplest types of ASK modulation is _On-Off Keying (OOK)_.  This simply means that the presence of a signal indicates a binary 1 and the absence of a signal indicates a binary 0.  The duration of each on or off segment is then used to indicate the number of consecutive 1's or 0's in the binary stream.  This all seemed plausible, except that looking at the FFT or waterfall didn't seem to be all that useful at this point.

### Moving Beyond GQRX

Admittedly I was stuck at this point for a little while.  I didn't recognize the patterns I was seeing in the waterfall plot and the FFT, while pretty looking, wasn't giving me any other clues.  It wasn't until I read [this post](http://blog.atx.name/reverse-engineering-radio-weather-station/) that appeared on http://rtl-sdr.com that I managed move forward.  The key was to simply record an audio sample of the transmission and work from there to identify the bits and encoding.  To do this I simply used the record feature of GQRX and set the demodulation to AM thinking that the data has likely been through some kind of an ASK modulator.

{% figure img:/assets/images/2015/07/DirtyAudioWaveform.jpg fnum:3 caption:"Audio waveform from GQRX recording without any processing." %}

Figure 3 shows the waveform of the audio captured using GQRX.  As we can see, on the immediate left we have some noisy looking data and on the far right we have what looks like gradually increasing noise.  The center portion looks very structured and could possibly be data.  When listening to the sample you will indded hear this noise-structured-noise pattern.  A quick visual inspection shows us that there seems to be three durations of silence during packets: short, medium, and long.  Looking more it's probably a safe guess the long period of silence is a delimiter of some kind but the short and medium periods are a bit of a mystery.  What we do know though is that this is not On-Off Keying since we don't see the expected presence-of-the-carrier-absence-of-the-carrier pattern; instead we see periods of silence delimited by a very short spikes.

After staring at the waveform for awhile I decided that the short periods of silence represent a binary `0`, the medium periods represent a binary `1`, and the long periods represent a delimiter between repeated packets where each packet is five bytes.

### Processing The Waveform

At this point I could either (a) test this theory by translating everythign manually or (b) process the data and translate it with a script.  Option (b) seemed like the winner since I wanted to translate a bunch of different captured packets to help with identifying the packet structure.  This meant I neeed a script that did --- things: :q


