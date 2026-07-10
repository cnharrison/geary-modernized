/*
 * Copyright © 2026 Christopher Harrison
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later). See the COPYING file in this distribution.
 */

/** Filter controls for the conversation list. */
public class Components.ConversationListTriageBar : Gtk.Box {

    public ConversationList.FilterMode filter_mode {
        get { return this._filter_mode; }
        set {
            if (this._filter_mode != value) {
                this._filter_mode = value;
                sync_buttons();
                notify_property("filter-mode");
            }
        }
    }
    private ConversationList.FilterMode _filter_mode = ConversationList.FilterMode.ALL;

    private Gtk.ToggleButton all_button;
    private Gtk.ToggleButton unread_button;
    private Gtk.ToggleButton starred_button;
    private bool syncing = false;


    public ConversationListTriageBar() {
        Object(
            orientation: Gtk.Orientation.HORIZONTAL,
            spacing: 0,
            margin_top: 6,
            margin_bottom: 6,
            margin_start: 6,
            margin_end: 6
        );
        get_style_context().add_class("linked");

        this.all_button = add_filter_button(
            _("All"),
            _("Show all conversations"),
            ConversationList.FilterMode.ALL
        );
        this.unread_button = add_filter_button(
            _("Unread"),
            _("Show unread conversations"),
            ConversationList.FilterMode.UNREAD
        );
        this.starred_button = add_filter_button(
            _("Starred"),
            _("Show starred conversations"),
            ConversationList.FilterMode.STARRED
        );
        sync_buttons();
        show_all();
    }

    private Gtk.ToggleButton add_filter_button(string label,
                                               string tooltip,
                                               ConversationList.FilterMode mode) {
        var button = new Gtk.ToggleButton.with_label(label);
        button.focus_on_click = false;
        button.tooltip_text = tooltip;
        button.clicked.connect(() => {
            if (!this.syncing) {
                if (this.filter_mode == mode) {
                    sync_buttons();
                } else {
                    this.filter_mode = mode;
                }
            }
        });
        add(button);
        return button;
    }

    private void sync_buttons() {
        this.syncing = true;
        this.all_button.active = this.filter_mode == ConversationList.FilterMode.ALL;
        this.unread_button.active = this.filter_mode == ConversationList.FilterMode.UNREAD;
        this.starred_button.active = this.filter_mode == ConversationList.FilterMode.STARRED;
        this.syncing = false;
    }

}
