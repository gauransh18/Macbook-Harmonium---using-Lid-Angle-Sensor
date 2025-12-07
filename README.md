# MacBook Harmonium – Lid Angle Sensor

Turn your MacBook into a playable pump organ using the lid as bellows. Play notes with your keyboard, control volume and tone by moving the lid—a fully polyphonic synthesizer powered by your laptop's built-in lid angle sensor.

**Note:** This project builds on the original [Lid Angle Sensor](https://github.com/samhenrigold/LidAngleSensor) discovery and implementation by [Sam Gold](https://samhenri.gold), who figured out how to tap into the MacBook's lid angle sensor via the human interface device utility.

## FAQ

**What is a lid angle sensor?**

Despite what the name would have you believe, it is a sensor that detects the angle of the lid.

**Which devices have a lid angle sensor?**

It was introduced with the 2019 16-inch MacBook Pro. If your laptop is newer, you probably have it. [People have reported](https://github.com/samhenrigold/LidAngleSensor/issues/13) that it **does not work on M1 devices**, I have not yet figured out a fix.

**My laptop should have it, why doesn't it show up?**

I've only tested this on my M4 MacBook Pro and have hard-coded it to look for a specific sensor. If that doesn't work, try running [this script](https://gist.github.com/samhenrigold/42b5a92d1ee8aaf2b840be34bff28591) and report the output in [an issue](https://github.com/samhenrigold/LidAngleSensor/issues/new/choose).

Known problematic models:

- M1 MacBook Air
- M1 MacBook Pro

**Can I use this on my iMac?**

~~Not yet tested. Feel free to slam your computer into your desk and make a PR with your results.~~

[It totally works](https://github.com/samhenrigold/LidAngleSensor/issues/33). If it doesn't work for you, try slamming your computer harder?

**Why?**

A lot of free time. I'm open to full-time work in NYC or remote. I'm a designer/design-engineer. https://samhenri.gold

**No I mean like why does my laptop need to know the exact angle of its lid?**

Oh. I don't know.

**Can I contribute?**

I guess.

**Why does it say it's by Lisa?**

I signed up for my developer account when I was a kid, used my mom's name, and now it's stuck that way forever and I can't change it. That's life.

**How come the audio feels kind of...weird?**

I'm bad at audio.

**Where did the sound effect come from?**

LEGO Batman 3: Beyond Gotham. But you knew that already.

**Can I turn off the sound?**

Yes, never click "Start Audio". But this energy isn't encouraged.

## How to Play

1. **Start the app** and click "Start Audio"
2. **Play notes** with your keyboard:
   - **Lower octave (C4–B4):** Z/S/X/D/C/V/G/B/H/N/J/M/,
   - **Upper octave (C5–B5):** Q/2/W/3/E/R/5/T/6/Y/7/U/I
3. **Control bellows (volume)** by moving your MacBook lid:
   - Slow, steady motion increases pressure
   - Stop moving and pressure gently decays to silence
4. **Tweak tone** using the stop controls (experimental)

**Tip:** Small, rhythmic lid movements give sustained chords a natural organ "breath."

## Building

According to [this issue](https://github.com/samhenrigold/LidAngleSensor/issues/12), building requires having Xcode installed. I've only tested this on Xcode 26. YMMV.

## Installation

Via Homebrew:

```shell
brew install lidanglesensor
```

## Foundation & Credits

- **Lid Angle Sensor detection:** [Sam Gold](https://samhenri.gold) — [original repository](https://github.com/samhenrigold/LidAngleSensor)
- **Harmonium synthesizer & UI:** This fork

## Related projects

- [Python library that taps into this sensor](https://github.com/tcsenpai/pybooklid)
- [Original Lid Angle Sensor project](https://github.com/samhenrigold/LidAngleSensor)
