/*
 * Copyright © 2026 Christopher Harrison
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later). See the COPYING file in this distribution.
 */

public class ConversationList.ViewTest : TestCase {

    private Application.Configuration config;
    private ConversationList.View view;


    public ViewTest() {
        base("ConversationList.ViewTest");
        add_test("tracks_source_availability", tracks_source_availability);
        add_test(
            "only_primary_pointer_selection_is_interactive",
            only_primary_pointer_selection_is_interactive
        );
        add_test(
            "only_all_allows_automatic_selection",
            only_all_allows_automatic_selection
        );
    }

    public override void set_up() {
        this.config = new Application.Configuration(Application.Client.SCHEMA_ID);
        this.view = new ConversationList.View(this.config);
    }

    public override void tear_down() {
        this.view.destroy();
        this.view = null;
        this.config = null;
    }

    public void tracks_source_availability() throws GLib.Error {
        assert(!this.view.has_source);

        this.view.set_source(new TestSource());
        assert(this.view.has_source);

        this.view.set_source(null);
        assert(!this.view.has_source);
    }

    public void only_primary_pointer_selection_is_interactive()
        throws GLib.Error {
        assert(View.is_pointer_selection_interactive(Gdk.BUTTON_PRIMARY));
        assert(!View.is_pointer_selection_interactive(Gdk.BUTTON_MIDDLE));
        assert(!View.is_pointer_selection_interactive(Gdk.BUTTON_SECONDARY));
    }

    public void only_all_allows_automatic_selection()
        throws GLib.Error {
        assert(View.allows_automatic_selection(FilterMode.ALL));
        assert(!View.allows_automatic_selection(FilterMode.UNREAD));
        assert(!View.allows_automatic_selection(FilterMode.STARRED));
    }

    private class TestSource : Geary.BaseObject, ConversationList.ConversationSource {

        public int min_window_count { get; set; default = 0; }
        public bool can_load_more { get { return false; } }

        public Geary.Folder get_source_folder(
            Geary.App.Conversation conversation
        ) {
            GLib.assert_not_reached();
        }

        public Gee.Collection<Geary.Folder> get_source_folders() {
            return new Gee.ArrayList<Geary.Folder>();
        }

        public string get_account_context(Geary.App.Conversation conversation) {
            GLib.assert_not_reached();
        }

    }

}
