# WordPress.org assets

These go in the plugin's **Subversion `assets/` folder** (not in the plugin zip), after the plugin is approved.

| File | Use |
|---|---|
| `icon-128x128.png`, `icon-256x256.png` | Plugin icon |
| `banner-772x250.png`, `banner-1544x500.png` | Directory banner (normal and retina) |
| `screenshot-1.png` to `screenshot-3.png` | Screenshots, in the order of the captions below |

Captions come from `readme.txt` in the plugin's `trunk/`, so add this section there at the first SVN commit:

    == Screenshots ==

    1. The settings page: paste your OpenTrust API key, choose which orders to check, and optionally put reported orders on hold.
    2. An order that other merchants have reported: the OpenTrust box and an order note listing what was reported.
    3. An order with no reports, and the "Share an experience" form for adding your own.

The screenshots were taken in a throwaway WordPress with made-up customers and the common placeholder number 98765 43210.
