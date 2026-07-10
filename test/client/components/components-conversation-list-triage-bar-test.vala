/*
 * Copyright © 2026 Christopher Harrison
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later). See the COPYING file in this distribution.
 */

public class Components.ConversationListTriageBarTest : TestCase {

    private ConversationListTriageBar bar;


    public ConversationListTriageBarTest() {
        base("Components.ConversationListTriageBarTest");
        add_test("defaults_to_all", defaults_to_all);
        add_test(
            "clicking_filter_updates_property", clicking_filter_updates_property
        );
        add_test(
            "setting_property_updates_buttons", setting_property_updates_buttons
        );
        add_test(
            "active_filter_cannot_be_toggled_off", active_filter_cannot_be_toggled_off
        );
        add_test("uses_plain_filter_labels", uses_plain_filter_labels);
        add_test("describes_complete_filters", describes_complete_filters);
    }

    public override void set_up() {
        this.bar = new ConversationListTriageBar();
    }

    public override void tear_down() {
        this.bar.destroy();
        this.bar = null;
    }

    public void defaults_to_all() throws GLib.Error {
        assert(this.bar.filter_mode == ConversationList.FilterMode.ALL);
        assert_button_state(true, false, false);
    }

    public void clicking_filter_updates_property() throws GLib.Error {
        filter_button(1).clicked();
        assert(this.bar.filter_mode == ConversationList.FilterMode.UNREAD);
        assert_button_state(false, true, false);

        filter_button(2).clicked();
        assert(this.bar.filter_mode == ConversationList.FilterMode.STARRED);
        assert_button_state(false, false, true);
    }

    public void setting_property_updates_buttons() throws GLib.Error {
        this.bar.filter_mode = ConversationList.FilterMode.STARRED;
        assert_button_state(false, false, true);

        this.bar.filter_mode = ConversationList.FilterMode.ALL;
        assert_button_state(true, false, false);
    }

    public void active_filter_cannot_be_toggled_off() throws GLib.Error {
        filter_button(0).clicked();

        assert(this.bar.filter_mode == ConversationList.FilterMode.ALL);
        assert_button_state(true, false, false);
    }

    public void uses_plain_filter_labels() throws GLib.Error {
        assert_equal<string>(filter_button(0).get_label(), "All");
        assert_equal<string>(filter_button(1).get_label(), "Unread");
        assert_equal<string>(filter_button(2).get_label(), "Starred");
    }

    public void describes_complete_filters() throws GLib.Error {
        assert_equal<string>(
            filter_button(0).tooltip_text, "Show all conversations"
        );
        assert_equal<string>(
            filter_button(1).tooltip_text, "Show unread conversations"
        );
        assert_equal<string>(
            filter_button(2).tooltip_text, "Show starred conversations"
        );
    }

    private Gtk.ToggleButton filter_button(uint index) {
        return this.bar.get_children().nth_data(index) as Gtk.ToggleButton;
    }

    private void assert_button_state(bool all, bool unread, bool starred)
        throws GLib.Error {
        assert(filter_button(0).active == all);
        assert(filter_button(1).active == unread);
        assert(filter_button(2).active == starred);
    }

}
