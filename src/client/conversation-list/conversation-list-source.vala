/*
 * Copyright © 2026 Christopher Harrison
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later). See the COPYING file in this distribution.
 */

/**
 * Source of conversations for the conversation list.
 *
 * This keeps the list UI decoupled from the concrete source of
 * conversations. The normal folder view is backed by a single
 * ConversationMonitor, while virtual views such as a combined inbox can
 * provide their own source implementation later.
 */
internal interface ConversationList.ConversationSource : GLib.Object {

    /** Minimum number of conversations the source should keep loaded. */
    public abstract int min_window_count { get; set; }

    /** Determines if the source can load more conversations. */
    public abstract bool can_load_more { get; }

    public signal void conversations_added(
        Gee.Collection<Geary.App.Conversation> conversations
    );

    public signal void conversations_removed(
        Gee.Collection<Geary.App.Conversation> conversations
    );

    public signal void conversation_appended(
        Geary.App.Conversation conversation,
        Gee.Collection<Geary.Email> emails
    );

    public signal void conversation_trimmed(
        Geary.App.Conversation conversation,
        Gee.Collection<Geary.Email> emails
    );

    public signal void scan_started();

    public signal void scan_completed();

    public abstract Geary.Folder get_source_folder(
        Geary.App.Conversation conversation
    );

    public abstract Gee.Collection<Geary.Folder> get_source_folders();

    public abstract string get_account_context(
        Geary.App.Conversation conversation
    );

}

/** Conversation source that aggregates multiple child sources. */
internal class ConversationList.AggregateSource : Geary.BaseObject, ConversationSource {

    public int min_window_count {
        get { return this._min_window_count; }
        set {
            this._min_window_count = value;
            foreach (ConversationSource source in this.sources) {
                source.min_window_count = value;
            }
        }
    }
    private int _min_window_count = 0;

    public bool can_load_more {
        get {
            foreach (ConversationSource source in this.sources) {
                if (source.can_load_more) {
                    return true;
                }
            }
            return false;
        }
    }

    private Gee.Collection<ConversationSource> sources;
    private Gee.Map<ConversationSource,Gee.List<ulong>> source_signal_ids =
        new Gee.HashMap<ConversationSource,Gee.List<ulong>>();
    private Gee.Map<Geary.App.Conversation,ConversationSource> source_map =
        new Gee.HashMap<Geary.App.Conversation,ConversationSource>();
    private int active_scans = 0;

    internal AggregateSource(Gee.Collection<ConversationSource> sources) {
        this.sources = new Gee.ArrayList<ConversationSource>();
        this.sources.add_all(sources);

        foreach (ConversationSource source in this.sources) {
            this._min_window_count = int.max(
                this._min_window_count,
                source.min_window_count
            );
            connect_source(source);
        }
    }

    ~AggregateSource() {
        foreach (ConversationSource source in this.sources) {
            disconnect_source(source);
        }
    }

    private void connect_source(ConversationSource source) {
        var ids = new Gee.ArrayList<ulong>();
        ids.add(source.conversations_added.connect((conversations) => {
            on_conversations_added(source, conversations);
        }));
        ids.add(source.conversation_appended.connect((conversation, emails) => {
            on_conversation_appended(source, conversation, emails);
        }));
        ids.add(source.conversation_trimmed.connect((conversation, emails) => {
            on_conversation_trimmed(conversation, emails);
        }));
        ids.add(source.conversations_removed.connect((conversations) => {
            on_conversations_removed(conversations);
        }));
        ids.add(source.scan_started.connect(on_scan_started));
        ids.add(source.scan_completed.connect(on_scan_completed));
        this.source_signal_ids.set(source, ids);
    }

    private void disconnect_source(ConversationSource source) {
        Gee.List<ulong>? ids = this.source_signal_ids.get(source);
        if (ids != null) {
            foreach (ulong id in ids) {
                source.disconnect(id);
            }
            this.source_signal_ids.unset(source);
        }
    }

    public Geary.Folder get_source_folder(Geary.App.Conversation conversation) {
        ConversationSource? source = this.source_map.get(conversation);
        assert(source != null);
        return source.get_source_folder(conversation);
    }

    public Gee.Collection<Geary.Folder> get_source_folders() {
        var folders = new Gee.ArrayList<Geary.Folder>();
        foreach (ConversationSource source in this.sources) {
            folders.add_all(source.get_source_folders());
        }
        return folders;
    }

    public string get_account_context(Geary.App.Conversation conversation) {
        Geary.Folder source_folder = get_source_folder(conversation);
        Geary.AccountInformation? recipient_account =
            get_recipient_account_context(conversation, source_folder);
        return recipient_account != null
            ? recipient_account.display_name
            : source_folder.account.information.display_name;
    }

    private Geary.AccountInformation? get_recipient_account_context(
        Geary.App.Conversation conversation,
        Geary.Folder source_folder
    ) {
        if (source_folder.used_as != Geary.Folder.SpecialUse.INBOX) {
            return null;
        }

        // Display-only: in a combined inbox, forwarded or duplicated
        // messages may live in one source account while being addressed
        // to another configured account. Action routing still uses the
        // real source folder.
        Gee.Collection<Geary.Folder> source_folders = get_source_folders();
        Gee.List<Geary.Email> emails = conversation.get_emails(
            Geary.App.Conversation.Ordering.RECV_DATE_ASCENDING
        );
        foreach (Geary.Email email in emails) {
            var recipients = new Geary.RFC822.MailboxAddresses();
            if (email.to != null) {
                recipients = recipients.merge_list(email.to);
            }
            if (email.cc != null) {
                recipients = recipients.merge_list(email.cc);
            }
            if (email.bcc != null) {
                recipients = recipients.merge_list(email.bcc);
            }

            foreach (Geary.RFC822.MailboxAddress address in recipients.get_all()) {
                Geary.AccountInformation? account = get_account_for_address(
                    address,
                    source_folders
                );
                if (account != null) {
                    return account;
                }
            }
        }
        return null;
    }

    private Geary.AccountInformation? get_account_for_address(
        Geary.RFC822.MailboxAddress address,
        Gee.Collection<Geary.Folder> source_folders
    ) {
        foreach (Geary.Folder folder in source_folders) {
            Gee.List<Geary.RFC822.MailboxAddress>? mailboxes =
                folder.account.information.sender_mailboxes;
            if (mailboxes == null) {
                continue;
            }

            foreach (Geary.RFC822.MailboxAddress mailbox in mailboxes) {
                if (mailbox.equal_to(address)) {
                    return folder.account.information;
                }
            }
        }
        return null;
    }

    private void on_conversations_added(
        ConversationSource source,
        Gee.Collection<Geary.App.Conversation> conversations
    ) {
        foreach (Geary.App.Conversation conversation in conversations) {
            this.source_map.set(conversation, source);
        }
        conversations_added(conversations);
    }

    private void on_conversations_removed(
        Gee.Collection<Geary.App.Conversation> conversations
    ) {
        conversations_removed(conversations);
        foreach (Geary.App.Conversation conversation in conversations) {
            this.source_map.unset(conversation);
        }
    }

    private void on_conversation_appended(
        ConversationSource source,
        Geary.App.Conversation conversation,
        Gee.Collection<Geary.Email> emails
    ) {
        this.source_map.set(conversation, source);
        conversation_appended(conversation, emails);
    }

    private void on_conversation_trimmed(
        Geary.App.Conversation conversation,
        Gee.Collection<Geary.Email> emails
    ) {
        conversation_trimmed(conversation, emails);
    }

    private void on_scan_started() {
        if (this.active_scans++ == 0) {
            scan_started();
        }
    }

    private void on_scan_completed() {
        assert(this.active_scans > 0);

        if (--this.active_scans == 0) {
            scan_completed();
        }
    }

}

/** Conversation source backed by a single Geary conversation monitor. */
internal class ConversationList.MonitorSource : Geary.BaseObject, ConversationSource {

    public int min_window_count {
        get { return this.monitor.min_window_count; }
        set { this.monitor.min_window_count = value; }
    }

    public bool can_load_more {
        get { return this.monitor.can_load_more; }
    }

    private Geary.App.ConversationMonitor monitor;
    private Geary.Folder base_folder {
        get { return this.monitor.base_folder; }
    }
    internal MonitorSource(Geary.App.ConversationMonitor monitor) {
        this.monitor = monitor;

        this.monitor.conversations_added.connect(on_conversations_added);
        this.monitor.conversation_appended.connect(on_conversation_appended);
        this.monitor.conversation_trimmed.connect(on_conversation_trimmed);
        this.monitor.conversations_removed.connect(on_conversations_removed);
        this.monitor.scan_started.connect(on_scan_started);
        this.monitor.scan_completed.connect(on_scan_completed);
    }

    ~MonitorSource() {
        this.monitor.conversations_added.disconnect(on_conversations_added);
        this.monitor.conversation_appended.disconnect(on_conversation_appended);
        this.monitor.conversation_trimmed.disconnect(on_conversation_trimmed);
        this.monitor.conversations_removed.disconnect(on_conversations_removed);
        this.monitor.scan_started.disconnect(on_scan_started);
        this.monitor.scan_completed.disconnect(on_scan_completed);
    }

    public Geary.Folder get_source_folder(Geary.App.Conversation conversation) {
        return this.base_folder;
    }

    public Gee.Collection<Geary.Folder> get_source_folders() {
        var folders = new Gee.ArrayList<Geary.Folder>();
        folders.add(this.base_folder);
        return folders;
    }

    public string get_account_context(Geary.App.Conversation conversation) {
        return this.base_folder.account.information.display_name;
    }

    private void on_conversations_added(
        Gee.Collection<Geary.App.Conversation> conversations
    ) {
        conversations_added(conversations);
    }

    private void on_conversations_removed(
        Gee.Collection<Geary.App.Conversation> conversations
    ) {
        conversations_removed(conversations);
    }

    private void on_conversation_appended(
        Geary.App.Conversation conversation,
        Gee.Collection<Geary.Email> emails
    ) {
        conversation_appended(conversation, emails);
    }

    private void on_conversation_trimmed(
        Geary.App.Conversation conversation,
        Gee.Collection<Geary.Email> emails
    ) {
        conversation_trimmed(conversation, emails);
    }

    private void on_scan_started() {
        scan_started();
    }

    private void on_scan_completed() {
        scan_completed();
    }

}
