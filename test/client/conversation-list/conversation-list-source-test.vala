/*
 * Copyright © 2026 Christopher Harrison
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later). See the COPYING file in this distribution.
 */

public class ConversationList.SourceTest : TestCase {

    public SourceTest() {
        base("ConversationList.SourceTest");
        add_test(
            "aggregate_uses_largest_child_window_count",
            aggregate_uses_largest_child_window_count
        );
        add_test(
            "aggregate_updates_child_window_counts",
            aggregate_updates_child_window_counts
        );
        add_test(
            "aggregate_reports_can_load_more",
            aggregate_reports_can_load_more
        );
        add_test(
            "aggregate_forwards_added_and_removed",
            aggregate_forwards_added_and_removed
        );
        add_test(
            "aggregate_coalesces_scan_signals",
            aggregate_coalesces_scan_signals
        );
        add_test(
            "aggregate_tracks_each_child_source_folder",
            aggregate_tracks_each_child_source_folder
        );
        add_test(
            "aggregate_prefers_matching_recipient_account_context",
            aggregate_prefers_matching_recipient_account_context
        );
    }

    public void aggregate_uses_largest_child_window_count() throws GLib.Error {
        TestSource first = new TestSource(50);
        TestSource second = new TestSource(100);
        AggregateSource aggregate = new AggregateSource(to_sources(first, second));

        assert_equal<int?>(aggregate.min_window_count, 100);
    }

    public void aggregate_updates_child_window_counts() throws GLib.Error {
        TestSource first = new TestSource();
        TestSource second = new TestSource();
        AggregateSource aggregate = new AggregateSource(to_sources(first, second));

        aggregate.min_window_count = 100;

        assert_equal<int?>(first.min_window_count, 100);
        assert_equal<int?>(second.min_window_count, 100);
        assert_equal<int?>(aggregate.min_window_count, 100);
    }

    public void aggregate_reports_can_load_more() throws GLib.Error {
        TestSource first = new TestSource();
        TestSource second = new TestSource();
        AggregateSource aggregate = new AggregateSource(to_sources(first, second));
        assert(!aggregate.can_load_more);

        second = new TestSource(0, true);
        aggregate = new AggregateSource(to_sources(first, second));
        assert(aggregate.can_load_more);
    }

    public void aggregate_forwards_added_and_removed() throws GLib.Error {
        TestSource first = new TestSource();
        TestSource second = new TestSource();
        AggregateSource aggregate = new AggregateSource(to_sources(first, second));
        int added = 0;
        int removed = 0;

        aggregate.conversations_added.connect(() => added++);
        aggregate.conversations_removed.connect(() => removed++);

        first.fire_conversations_added();
        second.fire_conversations_removed();

        assert_equal<int?>(added, 1);
        assert_equal<int?>(removed, 1);
    }

    public void aggregate_coalesces_scan_signals() throws GLib.Error {
        TestSource first = new TestSource();
        TestSource second = new TestSource();
        AggregateSource aggregate = new AggregateSource(to_sources(first, second));
        int started = 0;
        int completed = 0;

        aggregate.scan_started.connect(() => started++);
        aggregate.scan_completed.connect(() => completed++);

        first.fire_scan_started();
        second.fire_scan_started();
        first.fire_scan_completed();
        assert_equal<int?>(started, 1);
        assert_equal<int?>(completed, 0);

        second.fire_scan_completed();
        assert_equal<int?>(started, 1);
        assert_equal<int?>(completed, 1);
    }

    public void aggregate_tracks_each_child_source_folder() throws GLib.Error {
        Mock.Folder first_folder;
        Mock.Account first_account;
        Geary.App.Conversation first_conversation;
        Geary.App.ConversationMonitor first_monitor = load_conversation(
            "First", 1, out first_conversation, out first_folder, out first_account
        );
        Mock.Folder second_folder;
        Mock.Account second_account;
        Geary.App.Conversation second_conversation;
        Geary.App.ConversationMonitor second_monitor = load_conversation(
            "Second", 2, out second_conversation, out second_folder, out second_account
        );
        TestSource first = new TestSource.with_folder(first_folder);
        TestSource second = new TestSource.with_folder(second_folder);
        AggregateSource aggregate = new AggregateSource(to_sources(first, second));

        first.fire_conversations_added(first_conversation);
        second.fire_conversations_added(second_conversation);

        assert(aggregate.get_source_folder(first_conversation) == first_folder);
        assert(aggregate.get_source_folder(second_conversation) == second_folder);

        stop_monitor(first_monitor, first_folder, first_account);
        stop_monitor(second_monitor, second_folder, second_account);
    }

    public void aggregate_prefers_matching_recipient_account_context()
        throws GLib.Error {
        Mock.Account gmail_account = new_account("Gmail");
        Mock.Folder gmail_folder = new_folder("Gmail", gmail_account);
        Mock.Folder world_folder;
        Mock.Account world_account;
        Geary.App.Conversation world_conversation;
        Geary.App.ConversationMonitor world_monitor = load_conversation(
            "World",
            2,
            out world_conversation,
            out world_folder,
            out world_account,
            gmail_account.information.primary_mailbox
        );
        TestSource gmail = new TestSource.with_folder(gmail_folder);
        TestSource world = new TestSource.with_folder(world_folder);
        AggregateSource aggregate = new AggregateSource(to_sources(gmail, world));

        world.fire_conversations_added(world_conversation);

        assert_equal<string>(
            aggregate.get_account_context(world_conversation),
            "Gmail"
        );

        stop_monitor(world_monitor, world_folder, world_account);
    }

    private Gee.Collection<ConversationSource> to_sources(
        ConversationSource first,
        ConversationSource second
    ) {
        Gee.ArrayList<ConversationSource> sources = new Gee.ArrayList<ConversationSource>();
        sources.add(first);
        sources.add(second);
        return sources;
    }

    private Geary.App.ConversationMonitor load_conversation(
        string account_label,
        int id,
        out Geary.App.Conversation conversation,
        out Mock.Folder folder,
        out Mock.Account account,
        Geary.RFC822.MailboxAddress? recipient = null
    ) throws GLib.Error {
        account = new_account(account_label);
        folder = new_folder(account_label, account);

        Geary.Email email = new Geary.Email(new Mock.EmailIdentifer(id));
        GLib.DateTime now = new GLib.DateTime.now_local();
        email.set_email_properties(new Mock.EmailProperties(now));
        email.set_send_date(new Geary.RFC822.Date(now));
        email.set_message_subject(new Geary.RFC822.Subject(account_label));
        email.set_message_preview(new Geary.RFC822.PreviewText.from_string(account_label));
        email.set_originators(
            new Geary.RFC822.MailboxAddresses.single(
                new Geary.RFC822.MailboxAddress("Sender", "sender@example.com")
            ),
            null,
            null
        );
        email.set_receivers(
            new Geary.RFC822.MailboxAddresses.single(
                recipient ?? account.information.primary_mailbox
            ),
            null,
            null
        );
        email.set_full_references(
            new Geary.RFC822.MessageID("message-%d@example.com".printf(id)),
            null,
            null
        );
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

        conversation = Geary.Collection.first(monitor.read_only_view);
        return monitor;
    }

    private Mock.Account new_account(string label) {
        Geary.AccountInformation info = new Geary.AccountInformation(
            label.down(),
            OTHER,
            new Mock.CredentialsMediator(),
            new Geary.RFC822.MailboxAddress(null, "%s@example.com".printf(label.down()))
        );
        info.label = label;
        return new Mock.Account(info);
    }

    private Mock.Folder new_folder(string account_label,
                                   Mock.Account account) {
        Geary.Folder.SpecialUse use = Geary.Folder.SpecialUse.INBOX;
        Geary.FolderRoot root = new Geary.FolderRoot("#" + account_label, false);
        return new Mock.Folder(
            account,
            new Mock.FolderPoperties(),
            root.get_child(use.to_string()),
            use,
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

    private class TestSource : Geary.BaseObject, ConversationSource {

        public int min_window_count { get; set; default = 0; }
        public bool can_load_more { get { return this._can_load_more; } }
        private bool _can_load_more;

        private Geary.Folder source_folder;

        internal TestSource(int min_window_count = 0,
                            bool can_load_more = false) {
            this.min_window_count = min_window_count;
            this._can_load_more = can_load_more;
            this.source_folder = new_folder("test-source");
        }

        internal TestSource.with_folder(
            Geary.Folder source_folder,
            int min_window_count = 0,
            bool can_load_more = false
        ) {
            this.min_window_count = min_window_count;
            this._can_load_more = can_load_more;
            this.source_folder = source_folder;
        }

        public Geary.Folder get_source_folder(Geary.App.Conversation conversation) {
            return this.source_folder;
        }

        public Gee.Collection<Geary.Folder> get_source_folders() {
            var folders = new Gee.ArrayList<Geary.Folder>();
            folders.add(this.source_folder);
            return folders;
        }

        public string get_account_context(Geary.App.Conversation conversation) {
            return this.source_folder.account.information.display_name;
        }

        internal void fire_conversations_added(
            Geary.App.Conversation? conversation = null
        ) {
            conversations_added(to_conversations(conversation));
        }

        internal void fire_conversations_removed(
            Geary.App.Conversation? conversation = null
        ) {
            conversations_removed(to_conversations(conversation));
        }

        internal void fire_scan_started() {
            scan_started();
        }

        internal void fire_scan_completed() {
            scan_completed();
        }

        private Gee.Collection<Geary.App.Conversation> to_conversations(
            Geary.App.Conversation? conversation
        ) {
            var conversations = new Gee.ArrayList<Geary.App.Conversation>();
            if (conversation != null) {
                conversations.add(conversation);
            }
            return conversations;
        }

        private Mock.Folder new_folder(string label) {
            Geary.AccountInformation info = new Geary.AccountInformation(
                label,
                OTHER,
                new Mock.CredentialsMediator(),
                new Geary.RFC822.MailboxAddress(null, "%s@example.com".printf(label))
            );
            info.label = label;
            Mock.Account account = new Mock.Account(info);
            Geary.FolderRoot root = new Geary.FolderRoot("#" + label, false);
            return new Mock.Folder(
                account,
                new Mock.FolderPoperties(),
                root.get_child(Geary.Folder.SpecialUse.INBOX.to_string()),
                Geary.Folder.SpecialUse.INBOX,
                null
            );
        }

    }

}
