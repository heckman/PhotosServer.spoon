# PhotosServer.spoon

A Spoon for
[Hammerspoon](https://www.hammerspoon.org/)
that serves the contents of the
[Apple Photos](https://apps.apple.com/app/photos/id1584215428)
library on localhost via HTTP.

## Use case

I write markdown notes on my MacBook
and I want to include photos from my Photos Library.
I don't, however, want to make copies of the images
to be incldued in the git repository where I keep my notes.

I'm set up now where if I'm using the Photos app
and I a key-combination will copy markdown
that will show that image. It looks like this:

![](https://github.com/user-attachments/assets/16ac318c-68bb-4076-a2af-77be5abd7f88)

The link for the image in the video is http://photos.local/31F5FDDB-26D6-4EF6-A9E7-4A636F6E6EE2,
which is served by this spoon, fetching the photo from Apple Photos by specifying its uuid.

## Usage

I have written a sister spoon [Photos.spoon](http://github.com/heckman/photos.spoon) which provides hotkey bindings to copy markdown links for the media items currently selected in the Photos application.

## Installation

Download the two `.lua` files and the `resources` directory
and put them a directory named `PhotosServer`
within your Spoons directory.

When I figure out how,
I'll have github generate a zip file with the packaged Spoon.

<!--
Download
[PhotosServer.spoon.zip](https://github.com/hammerspoon/Spoons/raw/master/Spoons/PhotosServer.spoon.zip)
an unzip it.
If you have Hammerspooon installed,
it will look like a Spoon file
that you can double click to install.
Otherwise it will look like a folder. -->

## Configuration

This assumes you are somewhat familiar with Hammerspoon.

The simplest way to use this Spoon is to put this in your `lua.init` file:

```lua
hs.loadspoon("PhotosServer"):start()
```

This will listen to port _6330_ on _localhost_.

You can also start the server with custom settings in a single line such as:

```lua
hs.spoons.use("PhotoServer",{config={port=8080},start=true})
```

These are the available methods and settings:

### Methods

- **PhotosServer:start()** starts the HTTP server.
- **PhotosServer:stop( )** stops the HTTP server.

### Settings

PhotosServer has three properties that configure the HTTP server:

- **PhotosServer.host** _string_ : The address on which to serve; the default is **_127.0.0.1_**.

- **PhotosServer.port** _integer_ : The port to listen to; the default is **_6330_**. Note that the system will prevent you from setting this to a small number.

- **PhotosServer.bonjour** _string?_ : An optional name. The HTTP server will advertise itself with Bonjour using this name. (This is not the hostname of the server.) By default it is unset.

---

## Advanced Setup

On my machine, the contents of my Photos library
is accessible at <http://photos.local>.
This section explains how I set that up..

> **WARNING**: This is not for the faint of heart.
> Doing this wrong could be VERY VERY VERY bad.
> Don't do this unless you know what you're doing.
> If it goes horribly bad it is absolutely not my fault.

To make things pretty we need to listen on port 80.
Unfortunately it is a protected port,
and often in use by a web server.
As a work-around we can redirect port 80
from another one of the loopback addresses.
In these intructions we're using **127.0.0.3**.

There are two steps.

### Redirect **127.0.0.3:80** to **127.0.0.1:6330**

- Copy the file `ca.heckman.photos-server`
  to `/etc/pf.anchors/` using _sudo_.
  This defines the custom redirect rule.
- Copy the file `ca.heckman.photos-server.plist`
  to `/Library/LaunchDaemons/`, also with _sudo_.
  This file tells the system to enable the packet filter
  and to apply the redirect rule.
- Then load the launch daemon:
  ```shell
  sudo launchctl load -w /Library/LaunchDaemons/ca.heckman.photos-server.plist
  ```

This should enable the redirect immediately,
and it should persist after restarts and system updates.

> Aside: _I had previously been avoiding using a launch demon_ > _by editing the file `/etc/pf.conf` directly,_ > _but the settings were lost, either on an update or a reboot._

To reverse these changes,
unload the launch daemon (replace `load` with `unload`)
and then delete the two files.

### Set a pretty host name

To get rid of the rest of the numbers,
edit the file at `/etc/hosts`,
adding a line like this:

```plain-text
127.0.0.3       photos.local
```

Now a request for **photos.local**
will re resolved to **127.0.0.3:80**
which will be redirected to **127.0.0.1:6330**.

> Aside: _I previously tried using plain `photos`
> as the host name but my browser kept appending `.com` to it.
> I also tried `photos.app` but my clients
> (Safari and Typora)
> didn't feel safe accessing it without `https:`.
> For this reason, I recommend a `local` suffix,
> for which `http` is acceptable._
>
> _I also tried to use the Bonjour service
> to avoid having to do this step,
> but the Bonjour name is not the same thing
> as the hostname_

I've included scripts
in the advanced-installation/scripts directory,
but using them is dangerous.
They are posix-shell compatible,
so they can be sourced from most shells.
But don't. Danger. Warning.

## License

The project is shared under the MIT License
except for the contents of the `/resources` directory.
These resources include copies of the Apple Photos icon
as well as SVG versions of two historic icons:

- The 'broken image' icon was created for Netscape Navigator
  by Marsh Chamberlin (<https://dataglyph.com>).
  The icon's [SVG code](https://gist.github.com/diachedelic/cbb7fdd2271afa52435b7d4185e6a4ad)
  was hand-coded by github user [diachedelic](https://gist.github.com/diachedelic).
  I added the white background.

- The 'sad mac' icon was created for Apple Inc.
  by Susan Kare (<https://kareprints.com>).
  I hand-crafted the SVG.
