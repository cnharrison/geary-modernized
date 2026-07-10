# Geary Modernized

Geary Modernized is a personal downstream fork of [GNOME Geary](https://gitlab.gnome.org/GNOME/geary) with modern features.

## All Accounts View

Geary Modernized provides an **All Accounts View** for common folders like Inbox, Starred, Sent, Archive, All Mail, Trash, and Junk. It combines matching folders across accounts without creating server-side IMAP folders or moving messages out of their real accounts.

## Conversation triage

Switch between **All**, **Unread**, and **Starred** conversations in individual folders or across All Accounts. Unread and Starred cover the complete mailbox, not only messages already loaded in the list.

## Keyboard shortcuts

Geary Modernized includes Gmail- and Vim-style keyboard presets. Unlike upstream Geary, it supports Gmail-style two-key shortcuts such as `g i`. Shortcuts can be customized in Preferences, and the shortcut help reflects the active bindings.

## Status

**Alpha.** This is an actively dogfooded personal fork; expect breaking changes and rough edges.

## Building

See [BUILDING.md](./BUILDING.md). The original upstream project overview is preserved in [README.upstream.md](./README.upstream.md).

## Upstream

Based on GNOME Geary.

Related upstream issue: [GNOME/geary#53](https://gitlab.gnome.org/GNOME/geary/-/issues/53).

## License

Same as upstream Geary.
