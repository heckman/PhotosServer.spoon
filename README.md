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

Download
[PhotosServer.spoon.zip](https://github.com/hammerspoon/Spoons/raw/master/Spoons/PhotosServer.spoon.zip)
an unzip it.
If you have Hammerspooon installed,
it will look like a Spoon file
that you can double click to install.
Otherwise it will look like a folder.

## Configuration

This assumes you are somewhat familiar with Hammerspoon.

The simplest way to use this Spoon is to put this in your `lua.init` file:

```lua
hs.loadspoon("PhotosServer"):start()
```

This will serve on _127.0.0.1_ on port _6330_,
broadcasting over bonjour as _Photos_
(It might actually appear as _Photos.local_,
I haven't figured out to make use of bonjour yet.)

The start method will also take a configuration table.
This will cause the server to listen on port 8080
without changing the host address or bonjour name:

```lua
hs.loadspoon("PhotosServer"):start{port=8080}
```

### API

- **start(** [ *config-table* ] **)** starts the server. Only the keys specified
  in the provided _config-table_ are changed. The defaults are:

  ```lua
  { name='Photos', host='127.0.0.1', port=6330 }
  ```

- **stop(** **)** stops the server.

## Usage

When the server is running, the address `http://localhost:6330/<UUID>`
will provide the Photos media item with that particular UUID.

I have a osascript elsewhere that copies the UUID of the media item
currently selected in the Photos application. I will incorporate it
into this project very soon.

---

## Advanced Setup

I have this set up on my laptop accessible at
http://photos.local as well as http://localhost:6330.
I just like how it looks with the custom host name.

> **WARNING**: This is not for the faint of heart.
> Doing this wrong could be VERY VERY VERY bad.
> Don't do this unless you know what you're doing.
> If it goes horribly bad it is absolutely not my fault.

Also, these instructions are in their first draft,
so the word usements awkward may be.

To make things pretty we need to listen on port 80.
Unfortunately its a protected port, and often in use by a web server.
As a work-around we can redirect port 80
from another one of the loopback addresses.
I'm using **127.0.0.3**.

### Redirect 127.0.0.3:80 to 127.0.0.1:6330

#### Create the packet filter rule

First create the rule. Put it in a new file in the `/etx/pf.anchors` directory.
Mine is in a file called `/etc/pf.anchors/ca.heckman.photos-server.redirect`.
This file should contain this single line:

```conf
rdr pass on lo0 inet proto tcp from any to 127.0.0.3 port 80 -> 127.0.0.1 port 6330
```

#### Enable the rule in the packet filter configuration

This requires editing the file `/etc/pf.conf`.

Two lines need to be added. After all existing lines starting with `rdr-anchor`
add one for our new rule. Likewise, after all exiting `load anchor` lines
we need to add one for our new rule.

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

This will produce a warning that flushing the rules can mess up your system's existing rules. This is fine.

Now an HTTP request to **127.0.0.3** will be redirected to **127.0.0.1:6330**

### Set a pretty host name

Noe to get rid of the rest of the numbers. We edit the file at `/etc/hosts` and add a line like this:

```plain-text
127.0.0.3       photos.local
```

Now a request for **photos.local**
will re resolved to **127.0.0.3:80**
which will be redirected to **127.0.0.1:6330**.

I previously tried using plain `photos` as the host name
but my browsers kept appending `.com` to it.
I also tried `photos.app` but my clients didn't feel safe accessing it without `https:`.
For this reason, I recommend a `local` suffix, for which `http` is acceptable.

There may be a way to use the Bonjour service to avoid having to do this step.
Please let me know if you know how to do it.

## License

The project is shared under the MIT License
except for the two SVG icons whose copyrights are not held by me:

- The 'broken image' icon was created for Netscape Navigator
  by Marsh Chamberlin (<https://dataglyph.com>).
  The icon's [SVG code](https://gist.github.com/diachedelic/cbb7fdd2271afa52435b7d4185e6a4ad)
  was hand-coded by github user [diachedelic](https://gist.github.com/diachedelic).
  I added the white background.

- The 'sad mac' icon was created for Apple Inc.
  by Susan Kare (<https://kareprints.com>).
  I hand-crafted the SVG.
