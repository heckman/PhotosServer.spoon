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

The link for that image is http://photos.local/31F5FDDB-26D6-4EF6-A9E7-4A636F6E6EE2,
which resolves to this server, which fetches the image from Apple Photos.

The hotkey to copy the markdown link is not currently implemented here.
It's something I wrote earlier. I will incorporate it into this project soon.
Like tomorrow soon. By the end of the week at the latest.

## Installation

### Manual Installation

Download the two `.lua` files and the `resources` directory
and put them a directory named `PhotosServer`
within your Spoons directory.

There is also a [command-line utitlity](#bonus) included
in the `cli` directory that might be useful.

### Automatic Installation

This has not yet been implemented.
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

### API

#### Properties

The PhotosServer properties should not be accessed directly.
The _configure_ and _start_ take an optional argument that will set the options.

#### Methods

- **PhotosServer:start(** \[ _config-table_ \] **)** starts the HTTP server, If the optional _config-table_ is specified then the configure method will be called with it prior to starting the server.

- **PhotosServer:stop( )** stops the HTTP server.

- **PhotosServer:configure(** _config-table_ **)** if _config-table_ is not nil or empty, each of its keys will set
  and option. Options not included in the table are not affected. The available options are:

  - **name** _string?_ : An optional name. The HTTP server will advertise itself with Bonjour using this name. (This is not the hostname of the server.) By default it is unset.
  - **host** _string_ : The address on which to serve; the default is **_127.0.0.1_**.
  - **port** _integer_ : The port to listen to; the default is **_6330_**. Note that the system will prevent you from setting this to a small number.
  - **origin** _string_ : The origin of the server; the default is **_http://localhost:6330_**.
    This can be different from the host and port settings. It defines where media items can
    be accessed and is used when copying links from the media items selected in the Photos application.
    I have this set to **_http://photos.local_**.}.
    The [Advanced Setup](#advanced-setup) section explains how this works.
    When the feature that allows you to copy markdown links moves to its own Spoon,
    this setting will likely go with it.

#### Functions

These two functions are pointers to function in an internal table called
`PhotosServer.PhotosApplication`.
which will likely be split-off into its own Spoon in the near future.
They are included here in the mean time but will probably disappear,
as they don't share any code with the rest of the module.

Note that these functions are not methods, and calling them with the `:` notation
will result in undefined behaviour.

- **PhotosServer.copySelectionAsMarkdown()**: copies markdown links that will
  resolve to the media items currently selected in the Photos Application.

- **PhotosServer.photosSelection(** \[ _properties..._ \] **)**:
  returns an array of the media items currently selected in the Photos Application.

  Each media item is represented by a table of its properties.
  If any _properties_ are specified, only those properties will be included.
  ( This is more efficient if you want a single property for a large selection.)
  If no properties are specified, all available properties are included.

  The available properties are:

  - **keywords** _\[ string \]?_ : A list of keywords associated with a media item
  - **name** _string?_ : The name (title) of the media item.
  - **description** _string?_ : A description of the media item.
  - **favorite** _boolean?_ : Whether the media item has been favourited.
  - **date** _integer?_ : The date of the media item in seconds since the Unix epoch.
  - **id** _string_ : The unique ID of the media item.
  - **height** _integer_ : The height of the media item in pixels.
  - **width** _integer_ : The width of the media item in pixels.
  - **filename** _string_ : The name of the file on disk.
  - **altitude** _float?_ : The GPS altitude in meters.
  - **size** _integer_ : The selected media item file size.
  - **location** _\[ float?, float? \]_ : The GPS latitude and longitude,
    in an ordered list of 2 numbers or missing values.
    Latitude in range -90.0 to 90.0, longitude in range -180.0 to 180.0.

  If any provided properties are invalid, this function will return two values:
  _nil_ and the error table returned from the Photos application.

#### Key bindings

For now, the PhotosServer Spoon offers a single keybinding:

- **copyMarkdown** : Calls the `copySelectionAsMarkdown()` function.
  When the corresponding function is moved to a new Spoon,
  this keybinding will go with it.

## Usage

When the server is running, the address
`http://localhost:6330/<UUID>`
will provide the media item from the Photos library with that particular UUID.

This module currentl provides a keybinding to copy markdown links
of the media items currently selected in the Photos application.
This feature will soon be removed from this Spoon,
and moved to a new Spoon likely called `Photos`.

## Bonus

This Spoon includes a command-line utility
called `photos-selection`
that will print a json array of the media items
currently selected in the Photos application.
You could put a symbolic link to it somewhere on your path.

This too will be split off with the functions
into another spoon in the near future.

---

## Advanced Setup

On my machine, the contents of my Photos library
is accessible at <http://photos.local>.
This section explains how I set that up..

> **WARNING**: This is not for the faint of heart.
> Doing this wrong could be VERY VERY VERY bad.
> Don't do this unless you know what you're doing.
> If it goes horribly bad it is absolutely not my fault.

Also, these instructions are in their first draft,
so the word usements awkward may be.

To make things pretty we need to listen on port 80.
Unfortunately its a protected port,
and often in use by a web server.
As a work-around we can redirect port 80
from another one of the loopback addresses.
I'm using **127.0.0.3**.

There are two steps.

1. Redirect 127.0.0.3:80 to 127.0.0.1:6330

Copy the file `ca.heckman.photos-server` to `/etc/pf.anchors/`.
Doing this with `sudo` should make it owned by `root:wheel`,
which is what we want.

Copy the file `ca.heckman.photos-server.plist` to `/Library/LaunchDaemons/`.
Likewise owned by `root:wheel`, which `sudo` should do automatically.

Now load the launch daemon with
`launchctl load -w /Library/LaunchDaemons/ca.heckman.photos-server.plist`,
which will also require `sudo`.

This should enable the redirect immediately,
and it should persist after restarts and system updates.

(I previously did this by editing the file `/etc/pf.conf` directly,
but the settings were lost, either on an update or a reboot.)

To reverse these changes, unload the launch daemon with
`launchctl -w unload /Library/LaunchDaemons/ca.heckman.photos-server.plist`,
then delete the two files.

2. Set a pretty host name

To get rid of the rest of the numbers,
edit the file at `/etc/hosts`,
adding a line like this:

```plain-text
127.0.0.3       photos.local
```

Now a request for **photos.local**
will re resolved to **127.0.0.3:80**
which will be redirected to **127.0.0.1:6330**.

I previously tried using plain `photos`
as the host name but my browser kept appending `.com` to it.
I also tried `photos.app` but my clients
(Safari and Typora)
didn't feel safe accessing it without `https:`.
For this reason, I recommend a `local` suffix,
for which `http` is acceptable.

There may be a way to use the Bonjour service
to avoid having to do this step.
Please let me know if you know how to do it.

> I've included scripts
> in the advanced-installation/scripts directory,
> but using them is dangerous.
> They are are posix-shell compatible,
> so they can be sourced from most shells.
> But don't. Danger. Warning.

## Roadmap

This is my first Spoon, and I've only just started
working with Hammerspoon. My next steps are:

- Change the setup to follow Spoon conventions,
  which I'm still figuring out.
- Move the functions and keybindings to a new Spoon.

## License

The project is shared under the MIT License
except for the contents of the `/resources` directory,
which contains copies of the Apple Photos icon
as well as SVG versions of two historic icons:

- The 'broken image' icon was created for Netscape Navigator
  by Marsh Chamberlin (<https://dataglyph.com>).
  The icon's [SVG code](https://gist.github.com/diachedelic/cbb7fdd2271afa52435b7d4185e6a4ad)
  was hand-coded by github user [diachedelic](https://gist.github.com/diachedelic).
  I added the white background.

- The 'sad mac' icon was created for Apple Inc.
  by Susan Kare (<https://kareprints.com>).
  I hand-crafted the SVG.
