/*
 * Copyright © 2026 Christopher Harrison
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later). See the COPYING file in this distribution.
 */

public class ConversationList.ModelTest : TestCase {

    private TestSource source;
    private ConversationList.Model model;
    private Gee.List<Geary.App.ConversationMonitor> monitors =
        new Gee.ArrayList<Geary.App.ConversationMonitor>();
    private Gee.List<Mock.Folder> folders = new Gee.ArrayList<Mock.Folder>();
    private Gee.List<Mock.Account> accounts = new Gee.ArrayList<Mock.Account>();


    public ModelTest() {
        base("ConversationList.ModelTest");
        add_test("filter_defaults_to_all", filter_defaults_to_all);
        add_test("filters_unread_conversations", filters_unread_conversations);
        add_test("filters_starred_conversations", filters_starred_conversations);
        add_test(
            "filter_updates_when_conversation_changes",
            filter_updates_when_conversation_changes
        );
        add_test(
            "filter_tracks_removed_conversations", filter_tracks_removed_conversations
        );
        add_test(
            "filter_updates_when_conversation_flags_change",
            filter_updates_when_conversation_flags_change
        );
    }

    public override void set_up() {
        this.source = new TestSource();
        this.model = new ConversationList.Model(this.source);
    }

    public override void tear_down() {
        for (int i = 0; i < this.monitors.size; i++) {
            stop_monitor(this.monitors[i], this.folders[i], this.accounts[i]);
        }
        this.monitors.clear();
        this.folders.clear();
        this.accounts.clear();
        this.model = null;
        this.source = null;
    }

    public void filter_defaults_to_all() throws GLib.Error {
        Geary.App.Conversation unread = load_conversation(1, true, false);
        Geary.App.Conversation read = load_conversation(2, false, false);

        this.source.add_conversations(collection(unread, read));

        assert_equal<uint?>(this.model.get_n_items(), 2);
        assert(this.model.get_item(0) == read);
        assert(this.model.get_item(1) == unread);
    }

    public void filters_unread_conversations() throws GLib.Error {
        Geary.App.Conversation unread = load_conversation(1, true, false);
        Geary.App.Conversation read = load_conversation(2, false, false);

        this.source.add_conversations(collection(unread, read));
        this.model.filter_mode = ConversationList.FilterMode.UNREAD;

        assert_equal<uint?>(this.model.get_n_items(), 1);
        assert(this.model.get_item(0) == unread);
    }

    public void filters_starred_conversations() throws GLib.Error {
        Geary.App.Conversation starred = load_conversation(1, false, true);
        Geary.App.Conversation unstarred = load_conversation(2, false, false);

        this.source.add_conversations(collection(starred, unstarred));
        this.model.filter_mode = ConversationList.FilterMode.STARRED;

        assert_equal<uint?>(this.model.get_n_items(), 1);
        assert(this.model.get_item(0) == starred);
    }

    public void filter_updates_when_conversation_changes() throws GLib.Error {
        Geary.App.Conversation conversation = load_conversation(1, false, false);
        Geary.Email email = Geary.Collection.first(
            conversation.get_emails(Geary.App.Conversation.Ordering.NONE)
        );

        this.source.add_conversations(Geary.Collection.single(conversation));
        this.model.filter_mode = ConversationList.FilterMode.UNREAD;
        assert_equal<uint?>(this.model.get_n_items(), 0);

        email.set_flags(new Geary.EmailFlags.with(Geary.EmailFlags.UNREAD));
        this.source.update_conversation(conversation, email);

        assert_equal<uint?>(this.model.get_n_items(), 1);
        assert(this.model.get_item(0) == conversation);
    }

    public void filter_tracks_removed_conversations() throws GLib.Error {
        Geary.App.Conversation unread = load_conversation(1, true, false);
        Geary.App.Conversation read = load_conversation(2, false, false);

        this.source.add_conversations(collection(unread, read));
        this.model.filter_mode = ConversationList.FilterMode.UNREAD;
        assert_equal<uint?>(this.model.get_n_items(), 1);

        this.source.remove_conversations(Geary.Collection.single(unread));
        assert_equal<uint?>(this.model.get_n_items(), 0);

        this.model.filter_mode = ConversationList.FilterMode.ALL;
        assert_equal<uint?>(this.model.get_n_items(), 1);
        assert(this.model.get_item(0) == read);
    }

    public void filter_updates_when_conversation_flags_change()
        throws GLib.Error {
        Geary.App.Conversation conversation = load_conversation(1, false, false);
        Geary.Email email = Geary.Collection.first(
            conversation.get_emails(Geary.App.Conversation.Ordering.NONE)
        );

        this.source.add_conversations(Geary.Collection.single(conversation));
        this.model.filter_mode = ConversationList.FilterMode.STARRED;
        assert_equal<uint?>(this.model.get_n_items(), 0);

        email.set_flags(new Geary.EmailFlags.with(Geary.EmailFlags.FLAGGED));
        conversation.email_flags_changed(email);

        assert_equal<uint?>(this.model.get_n_items(), 1);
        assert(this.model.get_item(0) == conversation);
    }

    private Geary.App.Conversation load_conversation(int id,
                                                     bool unread,
                                                     bool starred)
        throws GLib.Error {
        Mock.Account account = new_account("account%d".printf(id));
        Mock.Folder folder = new_folder(account);

        Geary.Email email = new Geary.Email(new Mock.EmailIdentifer(id));
        GLib.DateTime date = new GLib.DateTime.local(2026, 1, id, 12, 0, 0);
        email.set_email_properties(new Mock.EmailProperties(date));
        email.set_send_date(new Geary.RFC822.Date(date));
        email.set_message_subject(new Geary.RFC822.Subject("Subject %d".printf(id)));
        email.set_message_preview(new Geary.RFC822.PreviewText.from_string("Preview"));
        email.set_originators(
            new Geary.RFC822.MailboxAddresses.single(
                new Geary.RFC822.MailboxAddress("Sender", "sender@example.com")
            ),
            null,
            null
        );
        email.set_full_references(
            new Geary.RFC822.MessageID("message-%d@example.com".printf(id)),
            null,
            null
        );

        var flags = new Geary.EmailFlags();
        if (unread) {
            flags.add(Geary.EmailFlags.UNREAD);
        }
        if (starred) {
            flags.add(Geary.EmailFlags.FLAGGED);
        }
        email.set_flags(flags);

        Gee.List<Geary.Email> emails = new Gee.ArrayList<Geary.Email>();
        emails.add(email);
        Gee.MultiMap<Geary.EmailIdentifier, Geary.FolderPath> paths =
            new Gee.HashMultiMap<Geary.EmailIdentifier, Geary.FolderPath>();
        paths.set(email.id, folder.path);

        folder.expect_call("open_async");
        folder.expect_call("list_email_by_id_async").returns_object(emails);
        account.expect_call("get_special_folder");
        account.expect_call("get_special_folder");
        account.expect_call("get_special_folder");
        account.expect_call("local_search_message_id_async");
        account.expect_call("get_containing_folders_async").returns_object(paths);

        Geary.App.ConversationMonitor monitor = new Geary.App.ConversationMonitor(
            folder, Geary.Email.Field.NONE, 1
        );
        monitor.start_monitoring.begin(NONE, null, this.async_completion);
        monitor.start_monitoring.end(async_result());
        wait_for_signal(monitor, "conversations-added");

        this.monitors.add(monitor);
        this.folders.add(folder);
        this.accounts.add(account);
        return Geary.Collection.first(monitor.read_only_view);
    }

    private Mock.Account new_account(string label) {
        Geary.AccountInformation info = new Geary.AccountInformation(
            label,
            OTHER,
            new Mock.CredentialsMediator(),
            new Geary.RFC822.MailboxAddress(null, "%s@example.com".printf(label))
        );
        info.label = label;
        return new Mock.Account(info);
    }

    private Mock.Folder new_folder(Mock.Account account) {
        Geary.FolderRoot root = new Geary.FolderRoot("#" + account.information.id, false);
        return new Mock.Folder(
            account,
            new Mock.FolderPoperties(),
            root.get_child(Geary.Folder.SpecialUse.INBOX.to_string()),
            Geary.Folder.SpecialUse.INBOX,
            null
        );
    }

    private void stop_monitor(Geary.App.ConversationMonitor monitor,
                              Mock.Folder folder,
                              Mock.Account account) throws GLib.Error {
        folder.expect_call("close_async");
        monitor.stop_monitoring.begin(null, this.async_completion);
        monitor.stop_monitoring.end(async_result());
        folder.assert_expectations();
        account.assert_expectations();
    }

    private Gee.Collection<Geary.App.Conversation> collection(
        Geary.App.Conversation first,
        Geary.App.Conversation second
    ) {
        Gee.ArrayList<Geary.App.Conversation> conversations =
            new Gee.ArrayList<Geary.App.Conversation>();
        conversations.add(first);
        conversations.add(second);
        return conversations;
    }

    private class TestSource : Geary.BaseObject, ConversationList.ConversationSource {

        public int min_window_count { get; set; default = 0; }
        public bool can_load_more { get { return false; } }


        public Geary.Folder get_source_folder(
            Geary.App.Conversation conversation
        ) {
            return conversation.base_folder;
        }

        public Gee.Collection<Geary.Folder> get_source_folders() {
            return new Gee.ArrayList<Geary.Folder>();
        }

        public string get_account_context(Geary.App.Conversation conversation) {
            return conversation.base_folder.account.information.display_name;
        }

        public void add_conversations(
            Gee.Collection<Geary.App.Conversation> conversations
        ) {
            conversations_added(conversations);
        }

        public void update_conversation(Geary.App.Conversation conversation,
                                        Geary.Email email) {
            conversation_appended(conversation, Geary.Collection.single(email));
        }

        public void remove_conversations(
            Gee.Collection<Geary.App.Conversation> conversations
        ) {
            conversations_removed(conversations);
        }

    }

}
