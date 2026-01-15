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

In your Spoons directory, create a directory named `PhotosServer`.
Download the two `.lua` files and the `resources` directory and
put them in there.

There is also a [command-line utitlity](#bonus) included in the `cli` directory that
might be useful.

### Automatic Installation

This has not yet been implemented. When I figure out how, I'll have
github generate a zip file with the packaged Spoon.

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

- **PhotosServer.config** is a table of three values:
  - **name** _string?_ : An optional name. The HTTP server will advertise itself with Bonjour using this name. (This is not the hostname of the server.) By default it is unset.
  - **host** _string_ : The address on which to serve; the default is **_127.0.0.1_**.
  - **port** _integer_ : The port to listen to; the default is **_6330_**. Note that the system will prevent you from setting this to a small number.

#### Methods

- **PhotosServer:start(** [ *config-table* ] **)** starts the HTTP server, If the optional _config-table_ is specified then the configure method will be called with it prior to starting the server.

- **PhotosServer:stop( )** stops the HTTP server.

- **PhotosServer:configure(** _config-table_ **)** changes values the of _PhotosServer.config_ as specified in the provided _config-table_. Only keys included in _config-table_ are altered in the config settings..

#### Functions

- **PhotosServer.photosSelection(** [ *properties...*] **)**:
  returns an array-like table of the media items currently selected in the Photos Application.
  Each media item is represented by a table of its properties.
  If any _properties_ are specified, only those properties will be included.
  ( This is more efficient if you want a single property for a large selection.)
  If no properties are specified, all available properties are included.

  The available properties are:

  - **keywords** _[ string ]?_ : A list of keywords associated with a media item
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
  - **location** _[ float?, float? ]_ : The GPS latitude and longitude,
    in an ordered list of 2 numbers or missing values.
    Latitude in range -90.0 to 90.0, longitude in range -180.0 to 180.0.

  If any provided properties are invalid, this function will return two values:
  _nil_ and the error table returned from the Photos application.

  **Note**:
  Calling this function as a method (i.e. with `:` notation)
  will produce an error, as _self_ is not a valid property.

## Usage

When the server is running, the address
`http://localhost:6330/<UUID>`
will provide the media item from the Photos library with that particular UUID.

I use a osascript which I have not included with this spoon
that is triggered by a key combination
which generates markdown links
for the currently selected media items in the Photo application.

A similar setup can be achieved by incorporating
the photosSelection function offered by this spoon
into you Hammerspoon configuration.
Once I figure out how that is done,
I will include and example

## Bonus

This Spoon includes a command-line utility
called `photos-selection`
that will print a json array of the media items
currently selected in the Photos application.
You could put a symbolic link to it somewhere on your path.

---

## Advanced Setup

I have this set up on my laptop accessible at <http://photos.local>
This explains how I did it.

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

### Redirect 127.0.0.3:80 to 127.0.0.1:6330

#### Create the packet filter rule

First create the rule.
Put it in a new file in the `/etc/pf.anchors` directory.
Mine is in a file called
`/etc/pf.anchors/ca.heckman.photos-server.redirect`.
This file should contain this single line:

```conf
rdr pass on lo0 inet proto tcp from any to 127.0.0.3 port 80 -> 127.0.0.1 port 6330
```

#### Enable the rule in the packet filter configuration

This requires editing the file `/etc/pf.conf`.

Two lines need to be added.
After all existing lines starting with `rdr-anchor` add one for our new rule.
Likewise, after all exiting `load anchor` lines we need to add one for our new rule.

After these additions, the uncommented lines of my `/etc/pf.conf` file looks like this:

```shell
scrub-anchor "com.apple/*"
nat-anchor "com.apple/*"
rdr-anchor "com.apple/*"
rdr-anchor "ca.heckman.photos-server"
dummynet-anchor "com.apple/*"
anchor "com.apple/*"
load anchor "com.apple" from "/etc/pf.anchors/com.apple"
load anchor "ca.heckman.photos-server" from "/etc/pf.anchors/ca.heckman.photos-server"
```

#### Flush the rules

The rules will be applied on restart.
We can can enable them immediately by flushing the rules

```shell
sudo pfctl -f /etc/pf.conf
```

This will produce a warning that flushing the rules
can mess up your system's existing rules.
This is fine.

Now an HTTP request to **127.0.0.3** will be redirected to **127.0.0.1:6330**

### Set a pretty host name

To get rid of the rest of the numbers,
we edit the file at `/etc/hosts`,
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
